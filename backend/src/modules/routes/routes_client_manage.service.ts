import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type HydratedDocument, type Model, Types } from 'mongoose';
import { type StoredDocument } from '../../database/scoped-repository.base';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { ROUTE_MODEL, type Route, type RouteStop, type RouteStatus, type StopType } from './schemas/route.schema';

export type StoredRouteDoc = StoredDocument<Route>;
export type RouteHydratedDoc = HydratedDocument<Route>;

interface UsageCountRow {
  _id: Types.ObjectId;
  count: number;
}

export interface ClientRouteStopView {
  placeId: string;
  name: string;
  city: string;
  offset: number;
  type: StopType;
}

export interface ClientRouteView {
  id: string;
  operatorId: string | null;
  name: string;
  from: string;
  to: string;
  km: number;
  hours: number;
  status: RouteStatus;
  stops: ClientRouteStopView[];
  tripsCount: number;
  faresCount: number;
  schedulesCount: number;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateClientRouteInput {
  from: string;
  to: string;
  name?: string;
  km: number;
  hours: number;
  stops: ClientRouteStopView[];
}

export interface UpdateClientRouteInput {
  from?: string;
  to?: string;
  name?: string;
  km?: number;
  hours?: number;
  status?: RouteStatus;
  stops?: ClientRouteStopView[];
}

export interface ClientRouteQueryInput {
  search?: string;
  status?: string;
  page?: number;
  pageSize?: number;
}

@Injectable()
export class RoutesClientManageService {
  constructor(
    @InjectModel(ROUTE_MODEL) private readonly routeModel: Model<Route>,
    @InjectConnection() private readonly connection: Connection,
    private readonly auditedChanges: AuditedChangeRunner,
  ) {}

  private validateStops(from: string, to: string, km: number, hours: number, stops: ClientRouteStopView[]): void {
    if (from.trim().toLowerCase() === to.trim().toLowerCase()) {
      throw new ApiException('VALIDATION_FAILED', 'From and To must be different');
    }
    if (km <= 0) {
      throw new ApiException('VALIDATION_FAILED', 'Distance must be greater than 0');
    }
    if (hours <= 0) {
      throw new ApiException('VALIDATION_FAILED', 'Duration must be greater than 0');
    }
    if (!stops || stops.length < 2) {
      throw new ApiException('VALIDATION_FAILED', 'A route needs at least 2 stops');
    }
    const hasBoarding = stops.some((s) => s.type !== 'DROPPING');
    if (!hasBoarding) {
      throw new ApiException('VALIDATION_FAILED', 'Add at least one boarding point');
    }
    const hasDropping = stops.some((s) => s.type !== 'BOARDING');
    if (!hasDropping) {
      throw new ApiException('VALIDATION_FAILED', 'Add at least one dropping point');
    }
    for (let i = 1; i < stops.length; i++) {
      const prev = stops[i - 1];
      const curr = stops[i];
      if (prev && curr && Number(curr.offset) < Number(prev.offset)) {
        throw new ApiException('VALIDATION_FAILED', `Stop ${i + 1} is earlier than the stop before it`);
      }
    }
  }

  private toView(route: StoredRouteDoc, tripsCount = 0, faresCount = 0, schedulesCount = 0): ClientRouteView {
    const rawStops: RouteStop[] = route.stops ?? [];
    const stops: ClientRouteStopView[] = rawStops.map((s, idx) => ({
      placeId: s.placeId ?? (s.cityId ? s.cityId.toString() : `PL${idx + 1}`),
      name: s.name ?? s.city ?? `Stop ${idx + 1}`,
      city: s.city ?? route.from ?? '',
      offset: s.offset !== undefined ? s.offset : s.offsetMinutes,
      type: s.type ?? 'BOTH',
    }));

    const firstStopCity = stops.length > 0 && stops[0] ? stops[0].city : '';
    const lastStopCity = stops.length > 0 && stops[stops.length - 1] ? stops[stops.length - 1]!.city : '';
    const from = route.from ?? firstStopCity ?? 'Origin';
    const to = route.to ?? lastStopCity ?? 'Destination';
    const km = route.km !== undefined ? route.km : route.distanceKm ?? 0;
    const hours = route.hours !== undefined ? route.hours : Math.round(route.estimatedDurationMinutes / 60);

    return {
      id: route._id.toString(),
      operatorId: route.operatorId ? route.operatorId.toString() : null,
      name: route.name,
      from,
      to,
      km,
      hours,
      status: route.status ?? 'ACTIVE',
      stops,
      tripsCount,
      faresCount,
      schedulesCount,
      createdAt: route.createdAt ? route.createdAt.toISOString() : undefined,
      updatedAt: route.updatedAt ? route.updatedAt.toISOString() : undefined,
    };
  }

  async list(actor: AuthenticatedUserActor, query: ClientRouteQueryInput): Promise<PaginatedResult<ClientRouteView>> {
    const operatorId = actor.operatorId ? new Types.ObjectId(actor.operatorId) : null;
    const filter: Record<string, unknown> = {
      isDeleted: { $ne: true },
    };

    if (operatorId) {
      filter.$or = [{ operatorId }, { operatorId: null }, { operatorId: { $exists: false } }];
    }

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status.toUpperCase();
    }

    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      const searchOr = [
        { name: { $regex: s, $options: 'i' } },
        { from: { $regex: s, $options: 'i' } },
        { to: { $regex: s, $options: 'i' } },
      ];
      const existingOr = filter.$or;
      if (Array.isArray(existingOr)) {
        filter.$and = [{ $or: existingOr }, { $or: searchOr }];
        delete filter.$or;
      } else {
        filter.$or = searchOr;
      }
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 50));
    const skip = skipOf({ page, pageSize });

    const [total, routes] = await Promise.all([
      this.routeModel.countDocuments(filter).exec(),
      this.routeModel.find(filter).sort({ createdAt: -1 }).skip(skip).limit(pageSize).lean<StoredRouteDoc[]>().exec(),
    ]);

    const routeIds = routes.map((r) => r._id);
    const [tripsCounts, faresCounts, schedsCounts] = await Promise.all([
      this.connection.collection('trips').aggregate<UsageCountRow>([
        { $match: { routeId: { $in: routeIds }, ...(operatorId ? { operatorId } : {}) } },
        { $group: { _id: '$routeId', count: { $sum: 1 } } },
      ]).toArray(),
      this.connection.collection('fares').aggregate<UsageCountRow>([
        { $match: { routeId: { $in: routeIds }, ...(operatorId ? { operatorId } : {}), isDeleted: { $ne: true } } },
        { $group: { _id: '$routeId', count: { $sum: 1 } } },
      ]).toArray(),
      this.connection.collection('schedules').aggregate<UsageCountRow>([
        { $match: { routeId: { $in: routeIds }, ...(operatorId ? { operatorId } : {}), isDeleted: { $ne: true } } },
        { $group: { _id: '$routeId', count: { $sum: 1 } } },
      ]).toArray(),
    ]);

    const tripMap = new Map(tripsCounts.map((c) => [c._id.toString(), c.count]));
    const fareMap = new Map(faresCounts.map((c) => [c._id.toString(), c.count]));
    const schedMap = new Map(schedsCounts.map((c) => [c._id.toString(), c.count]));

    const items = routes.map((r) => {
      const rId = r._id.toString();
      return this.toView(r, tripMap.get(rId) ?? 0, fareMap.get(rId) ?? 0, schedMap.get(rId) ?? 0);
    });

    return new PaginatedResult(items, page, pageSize, total);
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<ClientRouteView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route ID');
    }
    const operatorId = actor.operatorId ? new Types.ObjectId(actor.operatorId) : null;
    const route = await this.routeModel.findOne({
      _id: new Types.ObjectId(id),
      isDeleted: { $ne: true },
    }).lean<StoredRouteDoc>().exec();

    if (!route) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    if (route.operatorId && operatorId && route.operatorId.toString() !== operatorId.toString()) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    const [tripsCount, faresCount, schedulesCount] = await Promise.all([
      this.connection.collection('trips').countDocuments({ routeId: route._id, ...(operatorId ? { operatorId } : {}) }),
      this.connection.collection('fares').countDocuments({ routeId: route._id, ...(operatorId ? { operatorId } : {}), isDeleted: { $ne: true } }),
      this.connection.collection('schedules').countDocuments({ routeId: route._id, ...(operatorId ? { operatorId } : {}), isDeleted: { $ne: true } }),
    ]);

    return this.toView(route, tripsCount, faresCount, schedulesCount);
  }

  async create(actor: AuthenticatedUserActor, input: CreateClientRouteInput, info: ClientRequestInfo): Promise<ClientRouteView> {
    if (!actor.operatorId) {
      throw new ApiException('VALIDATION_FAILED', 'Operator ID required to create a route');
    }
    this.validateStops(input.from, input.to, input.km, input.hours, input.stops);

    const name = input.name?.trim() || `${input.from.trim()} to ${input.to.trim()}`;
    const operatorId = new Types.ObjectId(actor.operatorId);

    const stops: RouteStop[] = input.stops.map((s, idx) => ({
      placeId: s.placeId,
      name: s.name,
      city: s.city,
      offset: s.offset,
      offsetMinutes: s.offset,
      sequence: idx + 1,
      cityId: new Types.ObjectId(),
      type: s.type,
    }));

    const created = await this.auditedChanges.run<RouteHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.created',
      entityType: 'route',
      before: {},
      apply: async (session) => {
        const createdDocs = await this.routeModel.create(
          [
            {
              operatorId,
              originCityId: new Types.ObjectId(),
              destinationCityId: new Types.ObjectId(),
              from: input.from.trim(),
              to: input.to.trim(),
              name,
              km: input.km,
              hours: input.hours,
              distanceKm: input.km,
              estimatedDurationMinutes: input.hours * 60,
              stops,
              status: 'ACTIVE',
              isDeleted: false,
            },
          ],
          { session },
        );
        const doc = createdDocs[0];
        if (!doc) {
          throw new ApiException('INTERNAL_ERROR', 'Failed to create route document');
        }
        return doc;
      },
      describe: (record) => ({ id: record._id.toHexString(), name: record.name }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(created.toObject());
  }

  async update(actor: AuthenticatedUserActor, id: string, input: UpdateClientRouteInput, info: ClientRequestInfo): Promise<ClientRouteView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route ID');
    }
    const route = await this.routeModel.findOne({
      _id: new Types.ObjectId(id),
      isDeleted: { $ne: true },
    }).exec();

    if (!route) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    if (!route.operatorId) {
      throw new ApiException('VALIDATION_FAILED', 'Shared Abra route. Copy it to change the stops.');
    }

    if (actor.operatorId && route.operatorId.toString() !== actor.operatorId) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    const from = input.from ?? route.from ?? '';
    const to = input.to ?? route.to ?? '';
    const km = input.km ?? route.km ?? 0;
    const hours = input.hours ?? route.hours ?? 0;
    const rawStops = input.stops ?? (route.stops as unknown as ClientRouteStopView[]);

    this.validateStops(from, to, km, hours, rawStops);

    const name = input.name?.trim() || `${from.trim()} to ${to.trim()}`;
    const stops: RouteStop[] = rawStops.map((s, idx) => ({
      placeId: s.placeId,
      name: s.name,
      city: s.city,
      offset: s.offset,
      offsetMinutes: s.offset,
      sequence: idx + 1,
      cityId: new Types.ObjectId(),
      type: s.type,
    }));

    const updated = await this.auditedChanges.run<RouteHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.updated',
      entityType: 'route',
      before: { id: route._id.toHexString(), name: route.name, status: route.status },
      apply: async () => {
        route.from = from.trim();
        route.to = to.trim();
        route.name = name;
        route.km = km;
        route.hours = hours;
        route.distanceKm = km;
        route.estimatedDurationMinutes = hours * 60;
        route.stops = stops;
        if (input.status) {
          route.status = input.status;
        }
        await route.save();
        return route;
      },
      describe: (record) => ({ id: record._id.toHexString(), name: record.name }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async copy(actor: AuthenticatedUserActor, id: string, info: ClientRequestInfo): Promise<ClientRouteView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('VALIDATION_FAILED', 'Operator ID required');
    }

    const source = await this.routeModel.findOne({
      _id: new Types.ObjectId(id),
      isDeleted: { $ne: true },
    }).lean<StoredRouteDoc>().exec();

    if (!source) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    const operatorId = new Types.ObjectId(actor.operatorId);
    const newName = `${source.name} (mine)`;

    const copied = await this.auditedChanges.run<RouteHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.created',
      entityType: 'route',
      before: {},
      apply: async (session) => {
        const copyDocs = await this.routeModel.create(
          [
            {
              operatorId,
              originCityId: source.originCityId ?? new Types.ObjectId(),
              destinationCityId: source.destinationCityId ?? new Types.ObjectId(),
              from: source.from,
              to: source.to,
              name: newName,
              km: source.km,
              hours: source.hours,
              distanceKm: source.distanceKm ?? source.km,
              estimatedDurationMinutes: source.estimatedDurationMinutes ?? (source.hours ? source.hours * 60 : 60),
              stops: source.stops,
              status: 'ACTIVE',
              isDeleted: false,
            },
          ],
          { session },
        );
        const doc = copyDocs[0];
        if (!doc) {
          throw new ApiException('INTERNAL_ERROR', 'Failed to copy route document');
        }
        return doc;
      },
      describe: (record) => ({ id: record._id.toHexString(), name: record.name }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(copied.toObject());
  }

  async deleteRoute(actor: AuthenticatedUserActor, id: string, info: ClientRequestInfo): Promise<{ success: boolean }> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route ID');
    }
    const route = await this.routeModel.findOne({
      _id: new Types.ObjectId(id),
      isDeleted: { $ne: true },
    }).exec();

    if (!route) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    if (!route.operatorId) {
      throw new ApiException('VALIDATION_FAILED', 'Cannot delete shared Abra route');
    }

    if (actor.operatorId && route.operatorId.toString() !== actor.operatorId) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    const tripsUsingRoute = await this.connection.collection('trips').countDocuments({
      routeId: route._id,
      status: { $ne: 'CANCELLED' },
    });
    if (tripsUsingRoute > 0) {
      throw new ApiException('RESOURCE_IN_USE', 'Cannot delete route while active trips are using it');
    }

    await this.auditedChanges.run<RouteHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.deleted',
      entityType: 'route',
      before: { id: route._id.toHexString(), name: route.name },
      apply: async () => {
        route.isDeleted = true;
        route.deletedAt = new Date();
        await route.save();
        return route;
      },
      describe: (record) => ({ id: record._id.toHexString(), name: record.name }),
      operatorIdOf: (record) => record.operatorId,
    });

    return { success: true };
  }

  async exportList(actor: AuthenticatedUserActor): Promise<ClientRouteView[]> {
    const res = await this.list(actor, { page: 1, pageSize: 1000 });
    return res.items;
  }
}
