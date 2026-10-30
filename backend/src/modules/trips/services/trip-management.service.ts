import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection, Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { BusTypeRepository } from '../../bus-types/repositories/bus-type.repository';
import { BusRepository } from '../../buses/repositories/bus.repository';
import { CityRepository } from '../../cities/repositories/city.repository';
import { LocationRepository } from '../../locations/repositories/location.repository';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import { RouteRepository } from '../../routes/repositories/route.repository';
import {
  type CreateTripDto,
  type TripListQueryDto,
  type UpdateTripDto,
} from '../dto/trip-management.dto';
import { TripRepository, type StoredTrip } from '../repositories/trip.repository';
import { type Trip, type TripPoint, type TripStatus } from '../schemas/trip.schema';
import { planOf, tripFieldsOf, type TripPlan, type TripPlanContext } from './trip-plan';
import { addDays, isCalendarDate, localDateOf } from './travel-date';
import { assertBusDocumentsValid } from '../bus_document_check';

/** How far ahead a trip can be planned. */
export const TRIP_PLANNING_HORIZON_DAYS = 180;

/** Statuses in which a bus is committed to a trip. */
const BUS_COMMITTED_STATUSES: readonly TripStatus[] = [
  'SCHEDULED',
  'BOARDING',
  'DEPARTED',
  'IN_TRANSIT',
  'DELAYED',
];

export interface ManagedTripPointView {
  pointId: string;
  locationId: string | null;
  name: string;
  offsetMinutes: number;
  time: string;
}

/** A trip as the people who run it see it. */
export interface ManagedTripView {
  id: string;
  operatorId: string;
  busId: string;
  routeId: string;
  status: TripStatus;
  travelDate: string;
  departureTime: string;
  departureAt: string;
  arrivalAt: string;
  durationMinutes: number;
  startingFarePaise: number;
  currency: string;
  bus: Trip['bus'];
  boardingPoints: ManagedTripPointView[];
  droppingPoints: ManagedTripPointView[];
  seatCounts: Trip['seatCounts'];
  publishedAt: string | null;
  cancelledAt: string | null;
  cancellationReason: string | null;
}

export function managedTripViewOf(trip: StoredTrip): ManagedTripView {
  const plan = planOf(trip);
  const points = (list: TripPoint[]): ManagedTripPointView[] =>
    list.map((point) => ({
      pointId: point.pointId.toHexString(),
      locationId: point.locationId?.toHexString() ?? null,
      name: point.name,
      offsetMinutes: Math.round((point.time.getTime() - trip.departureAt.getTime()) / 60_000),
      time: point.time.toISOString(),
    }));
  return {
    id: trip._id.toHexString(),
    operatorId: trip.operatorId.toHexString(),
    busId: trip.busId.toHexString(),
    routeId: trip.routeId.toHexString(),
    status: trip.status,
    travelDate: trip.travelDate,
    departureTime: plan.departureTime,
    departureAt: trip.departureAt.toISOString(),
    arrivalAt: trip.arrivalAt.toISOString(),
    durationMinutes: trip.durationMinutes,
    startingFarePaise: trip.startingFarePaise,
    currency: trip.currency,
    bus: { ...trip.bus, amenities: [...trip.bus.amenities] },
    boardingPoints: points(trip.boardingPoints),
    droppingPoints: points(trip.droppingPoints),
    seatCounts: { ...trip.seatCounts },
    publishedAt: trip.publishedAt?.toISOString() ?? null,
    cancelledAt: trip.cancelledAt?.toISOString() ?? null,
    cancellationReason: trip.cancellationReason ?? null,
  };
}

function auditStateOf(trip: StoredTrip): Record<string, unknown> {
  const view = managedTripViewOf(trip);
  return {
    status: view.status,
    busId: view.busId,
    routeId: view.routeId,
    travelDate: view.travelDate,
    departureTime: view.departureTime,
    durationMinutes: view.durationMinutes,
    startingFarePaise: view.startingFarePaise,
    boardingLocationIds: view.boardingPoints.map((point) => point.locationId),
    droppingLocationIds: view.droppingPoints.map((point) => point.locationId),
    ...(view.cancellationReason ? { cancellationReason: view.cancellationReason } : {}),
  };
}

/**
 * The fields of a rebuilt trip without its owner. A trip never changes operator (the bus and
 * route of an edit are checked to belong to the same one), and the repository refuses any
 * update that touches the ownership field.
 */
function withoutOwner(fields: Omit<Trip, 'status'>): Omit<Trip, 'status' | 'operatorId'> {
  const rest: Partial<Omit<Trip, 'status'>> = { ...fields };
  delete rest.operatorId;
  return rest as Omit<Trip, 'status' | 'operatorId'>;
}

/** Trip management is for platform and operator staff, whatever else holds trips.read. */
function assertStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'STAFF' && actor.userType !== 'OPERATOR_STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'You do not have access to trip management.');
  }
}

function invalid(message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', message);
}

/**
 * Creating, editing, publishing and cancelling trips (state-machines.md §5).
 *
 * DRAFT is private to the operator. Publishing (DRAFT to SCHEDULED) is the only way a trip
 * reaches customers, and it is refused unless everything the trip depends on is in order.
 * CANCELLED takes it off sale again. The running states (BOARDING to ARRIVED) belong to trip
 * operations and are not changed here.
 */
@Injectable()
export class TripManagementService {
  constructor(
    private readonly trips: TripRepository,
    private readonly buses: BusRepository,
    private readonly busTypes: BusTypeRepository,
    private readonly routes: RouteRepository,
    private readonly locations: LocationRepository,
    private readonly operators: OperatorRepository,
    private readonly cities: CityRepository,
    private readonly changes: AuditedChangeRunner,
    @InjectConnection() private readonly connection: Connection,
  ) {}

  async list(
    actor: AuthenticatedUserActor,
    query: TripListQueryDto,
  ): Promise<PaginatedResult<ManagedTripView>> {
    assertStaff(actor);
    const id = (value: string) => new Types.ObjectId(value);
    const filter = {
      ...(query.operatorId ? { operatorId: id(query.operatorId) } : {}),
      ...(query.busId ? { busId: id(query.busId) } : {}),
      ...(query.routeId ? { routeId: id(query.routeId) } : {}),
      ...(query.travelDate ? { travelDate: query.travelDate } : {}),
      ...(query.status ? { status: query.status } : {}),
    };
    const [items, total] = await Promise.all([
      this.trips.findMany(filter, {
        sort: { departureAt: 1, _id: 1 },
        skip: skipOf(query),
        limit: query.pageSize,
      }),
      this.trips.count(filter),
    ]);
    return new PaginatedResult(items.map(managedTripViewOf), query.page, query.pageSize, total);
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<ManagedTripView> {
    assertStaff(actor);
    return managedTripViewOf(await this.trips.getById(id));
  }

  /** Creates a draft. Nothing is visible to customers until it is published. */
  async create(
    actor: AuthenticatedUserActor,
    input: CreateTripDto,
    client: ClientRequestInfo,
  ): Promise<ManagedTripView> {
    const { fields } = await this.build(input, undefined);
    const created = await this.changes.run({
      actor,
      client,
      action: 'catalogue.created',
      entityType: 'trip',
      before: {},
      apply: (session) => this.trips.insertOne({ ...fields, status: 'DRAFT' }, { session }),
      describe: auditStateOf,
      operatorIdOf: (record) => record.operatorId,
    });
    return managedTripViewOf(created);
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateTripDto,
    client: ClientRequestInfo,
  ): Promise<ManagedTripView> {
    const before = await this.trips.getById(id);
    this.requireStatus(before, ['DRAFT'], 'Only a draft can be edited.');
    const changes = Object.fromEntries(
      Object.entries(input).filter(([, value]) => value !== undefined),
    ) as Partial<TripPlan>;
    if (Object.keys(changes).length === 0) throw invalid('Nothing to change.');
    const { fields } = await this.build({ ...planOf(before), ...changes }, before);
    return managedTripViewOf(
      await this.save(actor, client, before, 'catalogue.updated', { $set: withoutOwner(fields) }),
    );
  }

  /**
   * Puts a draft on sale. Refused unless, right now: the operator is ACTIVE, the bus is ACTIVE
   * with a seat capacity and an active bus type, the route is ACTIVE with active origin and
   * destination cities, every boarding and dropping location is active, the departure is in the
   * future, and the bus is not committed to another trip at the same time. The trip takes fresh
   * copies of bus and locations at this moment.
   */
  async publish(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<ManagedTripView> {
    const before = await this.trips.getById(id);
    this.requireStatus(before, ['DRAFT'], 'Only a draft can be published.');
    const { fields, context } = await this.build(planOf(before), before);

    const operator = await this.operators.getById(before.operatorId.toHexString());
    if (operator.status !== 'ACTIVE') throw invalid('The operator is not active.');
    if (context.bus.status !== 'ACTIVE') throw invalid('The bus is not active.');
    if (!context.busType.isActive) throw invalid('The bus type is not active.');
    const capacity = context.bus.seatCapacity;
    if (!capacity) throw invalid('The bus has no seat capacity.');
    if (context.route.status !== 'ACTIVE') throw invalid('The route is not active.');
    const endCities = [context.route.originCityId, context.route.destinationCityId];
    if ((await this.cities.findActiveByIds(endCities)).length !== endCities.length) {
      throw invalid('The origin or destination city is not active.');
    }
    const inactive = [...context.locations.values()].find((location) => !location.isActive);
    if (inactive) throw invalid(`The location "${inactive.name}" is not active.`);
    if (fields.departureAt.getTime() <= Date.now()) {
      throw invalid('The departure time has already passed.');
    }
    await assertBusDocumentsValid(this.connection, context.bus, fields.departureAt);
    const overlapping = await this.trips.count({
      _id: { $ne: before._id },
      busId: before.busId,
      status: { $in: [...BUS_COMMITTED_STATUSES] },
      departureAt: { $lt: fields.arrivalAt },
      arrivalAt: { $gt: fields.departureAt },
    });
    if (overlapping > 0) {
      throw invalid('The bus is already on another trip during this time.');
    }

    return managedTripViewOf(
      await this.save(
        actor,
        client,
        before,
        'trip.published',
        {
          $set: {
            ...withoutOwner(fields),
            status: 'SCHEDULED',
            publishedAt: new Date(),
            // Until seat inventory exists every seat of the bus is available
            seatCounts: { total: capacity, available: capacity, locked: 0, booked: 0, blocked: 0 },
          },
        },
        undefined,
        // Guards against two publish requests at once
        { status: 'DRAFT' },
      ),
    );
  }

  /**
   * Cancels a draft or a trip on sale; it disappears from customer search at once. A reason is
   * required. (Refunding bookings is part of cancellation once bookings exist.)
   */
  async cancel(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string,
    client: ClientRequestInfo,
  ): Promise<ManagedTripView> {
    const before = await this.trips.getById(id);
    this.requireStatus(
      before,
      ['DRAFT', 'SCHEDULED'],
      `A trip that is ${before.status} cannot be cancelled here.`,
    );
    return managedTripViewOf(
      await this.save(
        actor,
        client,
        before,
        'trip.cancelled',
        { $set: { status: 'CANCELLED', cancelledAt: new Date(), cancellationReason: reason } },
        reason,
        { status: before.status },
      ),
    );
  }

  private requireStatus(trip: StoredTrip, allowed: readonly TripStatus[], message: string): void {
    if (!allowed.includes(trip.status)) {
      throw new ApiException('INVALID_STATE_TRANSITION', message);
    }
  }

  /** Loads what the plan refers to (within the caller's data scope) and builds the trip. */
  private async build(
    plan: TripPlan,
    existing: StoredTrip | undefined,
  ): Promise<{ fields: Omit<Trip, 'status'>; context: TripPlanContext }> {
    const today = localDateOf(new Date());
    if (
      !isCalendarDate(plan.travelDate) ||
      plan.travelDate < today ||
      plan.travelDate > addDays(today, TRIP_PLANNING_HORIZON_DAYS)
    ) {
      throw invalid(
        `travelDate must be between ${today} and ${addDays(today, TRIP_PLANNING_HORIZON_DAYS)}.`,
      );
    }
    // Scoped reads: a bus or route of another operator does not exist for the caller
    const bus = await this.buses.findById(plan.busId);
    if (!bus) throw invalid('busId is not a bus you can use.');
    const route = await this.routes.findById(plan.routeId);
    if (!route) throw invalid('routeId is not a route you can use.');
    const busType = await this.busTypes.findById(bus.busTypeId);
    if (!busType) throw invalid('The bus has no valid bus type.');

    const locationIds = [...plan.boardingPoints, ...plan.droppingPoints]
      .map((point) => point.locationId)
      .filter((locationId) => Types.ObjectId.isValid(locationId));
    const usable = await this.locations.findUsableBy(
      bus.operatorId,
      locationIds.map((locationId) => new Types.ObjectId(locationId)),
    );
    const existingPointIds = new Map<string, Types.ObjectId>();
    for (const point of existing?.boardingPoints ?? []) {
      if (point.locationId)
        existingPointIds.set(`boarding:${point.locationId.toHexString()}`, point.pointId);
    }
    for (const point of existing?.droppingPoints ?? []) {
      if (point.locationId)
        existingPointIds.set(`dropping:${point.locationId.toHexString()}`, point.pointId);
    }
    const context: TripPlanContext = {
      bus,
      busType,
      route,
      locations: new Map(usable.map((location) => [location._id.toHexString(), location])),
      existingPointIds,
      newPointId: () => new Types.ObjectId(),
    };
    const fields = tripFieldsOf(plan, context);
    if (existing && !fields.operatorId.equals(existing.operatorId)) {
      throw invalid('A trip cannot be moved to another operator.');
    }
    return { fields, context };
  }

  private save(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    before: StoredTrip,
    action: 'catalogue.updated' | 'trip.published' | 'trip.cancelled',
    update: Record<string, unknown>,
    reason?: string,
    guard: Record<string, unknown> = {},
  ): Promise<StoredTrip> {
    return this.changes.run({
      actor,
      client,
      action,
      entityType: 'trip',
      before: auditStateOf(before),
      reason,
      apply: async (session) => {
        const saved = await this.trips.findOneAndUpdate({ _id: before._id, ...guard }, update, {
          session,
        });
        if (!saved) {
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            'The trip was changed by someone else. Reload it and try again.',
          );
        }
        return saved;
      },
      describe: auditStateOf,
      operatorIdOf: (record) => record.operatorId,
    });
  }
}
