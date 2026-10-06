import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { operatorForNewRecord } from '../../../common/request-context/operator-scope';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { CityRepository } from '../../cities/repositories/city.repository';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type ChangeRouteStatusDto,
  type CreateRouteDto,
  type RouteListQueryDto,
  type UpdateRouteDto,
} from '../dto/route.dto';
import { RouteRepository, type StoredRoute } from '../repositories/route.repository';
import { type Route, type RouteStatus, type RouteStop } from '../schemas/route.schema';

export interface RouteView {
  id: string;
  operatorId: string;
  name: string;
  originCityId: string;
  destinationCityId: string;
  distanceKm: number | null;
  estimatedDurationMinutes: number;
  stops: {
    cityId: string;
    sequence: number;
    offsetMinutes: number;
    distanceFromOriginKm: number | null;
  }[];
  status: RouteStatus;
}

type StopInput = {
  cityId: string;
  offsetMinutes: number;
  distanceFromOriginKm?: number | undefined;
};

export function routeViewOf(route: StoredRoute): RouteView {
  return {
    id: route._id.toHexString(),
    operatorId: route.operatorId.toHexString(),
    name: route.name,
    originCityId: route.originCityId.toHexString(),
    destinationCityId: route.destinationCityId.toHexString(),
    distanceKm: route.distanceKm ?? null,
    estimatedDurationMinutes: route.estimatedDurationMinutes,
    stops: route.stops.map((stop) => ({
      cityId: stop.cityId.toHexString(),
      sequence: stop.sequence,
      offsetMinutes: stop.offsetMinutes,
      distanceFromOriginKm: stop.distanceFromOriginKm ?? null,
    })),
    status: route.status,
  };
}

function invalid(message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', message);
}

/** The paths operators run between cities. */
@Injectable()
export class RoutesService {
  constructor(
    private readonly routes: RouteRepository,
    private readonly cities: CityRepository,
    private readonly operators: OperatorRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(query: RouteListQueryDto): Promise<PaginatedResult<RouteView>> {
    const id = (value: string | undefined) => (value ? new Types.ObjectId(value) : undefined);
    const filter = {
      ...(query.operatorId ? { operatorId: id(query.operatorId) } : {}),
      ...(query.originCityId ? { originCityId: id(query.originCityId) } : {}),
      ...(query.destinationCityId ? { destinationCityId: id(query.destinationCityId) } : {}),
      ...(query.status ? { status: query.status } : {}),
    };
    const [items, total] = await Promise.all([
      this.routes.findMany(filter, {
        sort: { name: 1, _id: 1 },
        skip: skipOf(query),
        limit: query.pageSize,
      }),
      this.routes.count(filter),
    ]);
    return new PaginatedResult(items.map(routeViewOf), query.page, query.pageSize, total);
  }

  async get(id: string): Promise<RouteView> {
    return routeViewOf(await this.routes.getById(id));
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateRouteDto,
    client: ClientRequestInfo,
  ): Promise<RouteView> {
    const operatorId = operatorForNewRecord(actor, input.operatorId);
    await this.operators.getById(operatorId.toHexString());
    if (input.originCityId.toLowerCase() === input.destinationCityId.toLowerCase()) {
      throw invalid('Origin and destination must be different.');
    }
    const stops = await this.checkedStops(
      input.originCityId,
      input.destinationCityId,
      input.stops,
      input.estimatedDurationMinutes,
    );
    const created = await this.changes.run({
      actor,
      client,
      action: 'catalogue.created',
      entityType: 'route',
      before: {},
      apply: (session) =>
        this.routes.insertOne(
          {
            operatorId,
            originCityId: new Types.ObjectId(input.originCityId),
            destinationCityId: new Types.ObjectId(input.destinationCityId),
            name: input.name,
            ...(input.distanceKm !== undefined ? { distanceKm: input.distanceKm } : {}),
            estimatedDurationMinutes: input.estimatedDurationMinutes,
            stops,
            status: 'ACTIVE',
          },
          { session },
        ),
      describe: (record) => ({ ...routeViewOf(record) }),
      operatorIdOf: (record) => record.operatorId,
    });
    return routeViewOf(created);
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateRouteDto,
    client: ClientRequestInfo,
  ): Promise<RouteView> {
    const before = await this.routes.getById(id);
    const set: Partial<Route> = {};
    if (input.name !== undefined) set.name = input.name;
    if (input.distanceKm !== undefined) set.distanceKm = input.distanceKm;
    if (input.estimatedDurationMinutes !== undefined) {
      set.estimatedDurationMinutes = input.estimatedDurationMinutes;
    }
    if (input.stops !== undefined || input.estimatedDurationMinutes !== undefined) {
      set.stops = await this.checkedStops(
        before.originCityId.toHexString(),
        before.destinationCityId.toHexString(),
        input.stops ??
          before.stops.map((stop) => ({
            cityId: stop.cityId.toHexString(),
            offsetMinutes: stop.offsetMinutes,
            distanceFromOriginKm: stop.distanceFromOriginKm,
          })),
        input.estimatedDurationMinutes ?? before.estimatedDurationMinutes,
      );
    }
    if (Object.keys(set).length === 0) throw invalid('Nothing to change.');
    return routeViewOf(await this.save(actor, client, before, 'catalogue.updated', set));
  }

  /** A trip on an INACTIVE route cannot be published. */
  async changeStatus(
    actor: AuthenticatedUserActor,
    id: string,
    input: ChangeRouteStatusDto,
    client: ClientRequestInfo,
  ): Promise<RouteView> {
    const before = await this.routes.getById(id);
    if (before.status === input.status) return routeViewOf(before);
    return routeViewOf(
      await this.save(
        actor,
        client,
        before,
        'catalogue.status-changed',
        { status: input.status },
        input.reason,
      ),
    );
  }

  /**
   * Origin, destination and stops must be active cities, each used once, with stop times that
   * increase and fall inside the journey.
   */
  private async checkedStops(
    originCityId: string,
    destinationCityId: string,
    stops: readonly StopInput[],
    durationMinutes: number,
  ): Promise<RouteStop[]> {
    const cityIds = [originCityId, destinationCityId, ...stops.map((stop) => stop.cityId)].map(
      (id) => id.toLowerCase(),
    );
    if (new Set(cityIds).size !== cityIds.length) {
      throw invalid('A city can appear only once on a route.');
    }
    const active = await this.cities.findActiveByIds(cityIds.map((id) => new Types.ObjectId(id)));
    if (active.length !== cityIds.length) {
      throw invalid('Origin, destination and stops must be active cities.');
    }
    let previous = 0;
    return stops.map((stop, index) => {
      if (stop.offsetMinutes <= previous || stop.offsetMinutes >= durationMinutes) {
        throw invalid('Stop times must increase and fall within the journey time.');
      }
      previous = stop.offsetMinutes;
      return {
        cityId: new Types.ObjectId(stop.cityId),
        sequence: index + 1,
        offsetMinutes: stop.offsetMinutes,
        ...(stop.distanceFromOriginKm !== undefined
          ? { distanceFromOriginKm: stop.distanceFromOriginKm }
          : {}),
      };
    });
  }

  private save(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    before: StoredRoute,
    action: 'catalogue.updated' | 'catalogue.status-changed',
    set: Partial<Route>,
    reason?: string,
  ): Promise<StoredRoute> {
    return this.changes.run({
      actor,
      client,
      action,
      entityType: 'route',
      before: { ...routeViewOf(before) },
      reason,
      apply: async (session) => {
        const saved = await this.routes.findOneAndUpdate(
          { _id: before._id },
          { $set: set },
          { session },
        );
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
        return saved;
      },
      describe: (record) => ({ ...routeViewOf(record) }),
      operatorIdOf: (record) => record.operatorId,
    });
  }
}
