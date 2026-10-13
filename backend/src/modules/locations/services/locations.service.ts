import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../../common/pipes/list-query';
import {
  hasPlatformScope,
  operatorForNewRecord,
} from '../../../common/request-context/operator-scope';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { CityRepository } from '../../cities/repositories/city.repository';
import { type GeoPoint } from '../../cities/schemas/city.schema';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type CreateLocationDto,
  type LocationListQueryDto,
  type UpdateLocationDto,
} from '../dto/location.dto';
import { LocationRepository, type StoredLocation } from '../repositories/location.repository';
import { type Location, type PlaceSource, type PlaceUse } from '../schemas/location.schema';

export interface LocationView {
  id: string;
  cityId: string;
  /** Null for a location every operator may use. */
  operatorId: string | null;
  name: string;
  address: string;
  landmark: string | null;
  instructions: string | null;
  contactPhone: string | null;
  latitude: number | null;
  longitude: number | null;
  usedFor: PlaceUse;
  source: PlaceSource;
  isActive: boolean;
  /** Trips whose boarding or dropping points use the place (lists only). */
  tripsUsing?: number;
}

export function locationViewOf(location: StoredLocation): LocationView {
  return {
    id: location._id.toHexString(),
    cityId: location.cityId.toHexString(),
    operatorId: location.operatorId?.toHexString() ?? null,
    name: location.name,
    address: location.address,
    landmark: location.landmark ?? null,
    instructions: location.instructions ?? null,
    contactPhone: location.contactPhone ?? null,
    latitude: location.location?.coordinates?.[1] ?? null,
    longitude: location.location?.coordinates?.[0] ?? null,
    usedFor: location.usedFor ?? 'BOTH',
    source: location.source ?? (location.operatorId ? 'OPERATOR' : 'ADMIN'),
    isActive: location.isActive,
  };
}

function pointOf(latitude?: number, longitude?: number): GeoPoint | undefined {
  if (latitude === undefined && longitude === undefined) return undefined;
  if (latitude === undefined || longitude === undefined) {
    throw new ApiException('VALIDATION_FAILED', 'latitude and longitude go together.');
  }
  return { type: 'Point', coordinates: [longitude, latitude] };
}

/** Places where passengers board and get off. */
@Injectable()
export class LocationsService {
  constructor(
    private readonly locations: LocationRepository,
    private readonly cities: CityRepository,
    private readonly operators: OperatorRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(query: LocationListQueryDto): Promise<PaginatedResult<LocationView>> {
    const search = query.query ? new RegExp(escapeRegExp(query.query), 'i') : undefined;
    const { items, total } = await this.locations.findVisible(
      {
        ...(query.cityId ? { cityId: new Types.ObjectId(query.cityId) } : {}),
        ...(query.active === undefined ? {} : { isActive: query.active }),
        // Places stored before "used for" existed count as BOTH
        ...(query.usedFor === 'BOTH'
          ? { usedFor: { $in: ['BOTH', null] } }
          : query.usedFor
            ? { usedFor: query.usedFor }
            : {}),
        ...(search ? { $or: [{ name: search }, { address: search }, { landmark: search }] } : {}),
      },
      { skip: skipOf(query), limit: query.pageSize },
    );
    const trips = await this.locations.tripCounts(items.map((item) => item._id));
    return new PaginatedResult(
      items.map((item) => ({
        ...locationViewOf(item),
        tripsUsing: trips.get(item._id.toHexString()) ?? 0,
      })),
      query.page,
      query.pageSize,
      total,
    );
  }

  async get(id: string): Promise<LocationView> {
    const location = await this.locations.findVisibleById(id);
    if (!location) throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
    return locationViewOf(location);
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateLocationDto,
    client: ClientRequestInfo,
    source?: PlaceSource,
  ): Promise<LocationView> {
    // Only platform staff may create a location without an operator (shared by all)
    const operatorId =
      hasPlatformScope(actor) && !input.operatorId
        ? undefined
        : operatorForNewRecord(actor, input.operatorId);
    if (operatorId) await this.operators.getById(operatorId.toHexString());
    const city = await this.cities.findById(input.cityId);
    if (!city?.isActive) {
      throw new ApiException('VALIDATION_FAILED', 'cityId is not an active city.');
    }
    const location = pointOf(input.latitude, input.longitude);
    const created = await this.changes.run({
      actor,
      client,
      action: 'catalogue.created',
      entityType: 'location',
      before: {},
      apply: (session) =>
        this.locations.insertOne(
          {
            ...(operatorId ? { operatorId } : {}),
            cityId: city._id,
            name: input.name,
            address: input.address,
            ...(input.landmark ? { landmark: input.landmark } : {}),
            ...(input.instructions ? { instructions: input.instructions } : {}),
            ...(input.contactPhone ? { contactPhone: input.contactPhone } : {}),
            ...(location ? { location } : {}),
            usedFor: input.usedFor ?? 'BOTH',
            source: source ?? (operatorId ? 'OPERATOR' : 'ADMIN'),
            isActive: true,
          },
          { session },
        ),
      describe: (record) => ({ ...locationViewOf(record) }),
      operatorIdOf: (record) => record.operatorId,
    });
    return locationViewOf(created);
  }

  /**
   * Changes a location within the caller's scope (shared locations: platform staff only). Trips
   * already published keep the copy they took; drafts take the new values when published.
   */
  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateLocationDto & { isActive?: boolean },
    client: ClientRequestInfo,
  ): Promise<LocationView> {
    const before = await this.locations.getById(id);
    const { latitude, longitude, ...fields } = input;
    const location = pointOf(latitude, longitude);
    const set: Partial<Location> = { ...(location ? { location } : {}) };
    const unset: Record<string, ''> = {};
    for (const [key, value] of Object.entries(fields)) {
      if (value === null) unset[key] = '';
      else if (value !== undefined) Object.assign(set, { [key]: value });
    }
    if (Object.keys(set).length + Object.keys(unset).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    const updated = await this.changes.run({
      actor,
      client,
      action: input.isActive === undefined ? 'catalogue.updated' : 'catalogue.status-changed',
      entityType: 'location',
      before: { ...locationViewOf(before) },
      apply: async (session) => {
        const saved = await this.locations.findOneAndUpdate(
          { _id: before._id },
          {
            ...(Object.keys(set).length > 0 ? { $set: set } : {}),
            ...(Object.keys(unset).length > 0 ? { $unset: unset } : {}),
          },
          { session },
        );
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
        return saved;
      },
      describe: (record) => ({ ...locationViewOf(record) }),
      operatorIdOf: (record) => record.operatorId,
    });
    return locationViewOf(updated);
  }
}
