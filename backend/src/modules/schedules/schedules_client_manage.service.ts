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
import {
  activeFareFor,
  busSnapshotOf,
  healRouteCities,
  missingFareMessage,
  requireBusType,
  routePointsOf,
} from '../trips/trip_snapshots';

export const SCHEDULE_MODEL = 'Schedule';

export const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'] as const;
export type Weekday = (typeof WEEKDAYS)[number];

export interface ClientSchedule {
  operatorId: Types.ObjectId;
  routeId: Types.ObjectId;
  route: string;
  busId: Types.ObjectId;
  bus: string;
  time: string;
  days: string[];
  from: string;
  to: string;
  status: 'ACTIVE' | 'INACTIVE';
  fare: number;
  isDeleted: boolean;
  deletedAt?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredScheduleDoc = StoredDocument<ClientSchedule>;
export type ScheduleHydratedDoc = HydratedDocument<ClientSchedule>;

export interface ClientScheduleView {
  id: string;
  operatorId: string;
  routeId: string;
  route: string;
  busId: string;
  bus: string;
  time: string;
  days: string[];
  from: string;
  to: string;
  status: 'ACTIVE' | 'INACTIVE';
  fare: number;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateClientScheduleInput {
  routeId: string;
  busId: string;
  time: string;
  days: string[];
  from: string;
  to: string;
  status?: 'ACTIVE' | 'INACTIVE';
}

export interface UpdateClientScheduleInput {
  routeId?: string;
  busId?: string;
  time?: string;
  days?: string[];
  from?: string;
  to?: string;
  status?: 'ACTIVE' | 'INACTIVE';
}

export interface ClientScheduleQueryInput {
  status?: string;
  search?: string;
  page?: number;
  pageSize?: number;
}

export interface GenerateTripsResult {
  createdCount: number;
  skippedCount: number;
  message: string;
}

@Injectable()
export class SchedulesClientManageService {
  constructor(
    @InjectModel(SCHEDULE_MODEL) private readonly scheduleModel: Model<ClientSchedule>,
    @InjectConnection() private readonly connection: Connection,
    private readonly auditedChanges: AuditedChangeRunner,
  ) {}

  private toView(sc: StoredScheduleDoc): ClientScheduleView {
    return {
      id: sc._id.toString(),
      operatorId: sc.operatorId.toString(),
      routeId: sc.routeId.toString(),
      route: sc.route,
      busId: sc.busId.toString(),
      bus: sc.bus,
      time: sc.time,
      days: sc.days,
      from: sc.from,
      to: sc.to,
      status: sc.status,
      fare: sc.fare,
      createdAt: sc.createdAt ? sc.createdAt.toISOString() : undefined,
      updatedAt: sc.updatedAt ? sc.updatedAt.toISOString() : undefined,
    };
  }

  async list(actor: AuthenticatedUserActor, query: ClientScheduleQueryInput): Promise<PaginatedResult<ClientScheduleView>> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }
    const operatorId = new Types.ObjectId(actor.operatorId);
    const filter: Record<string, unknown> = {
      operatorId,
      isDeleted: { $ne: true },
    };

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status.toUpperCase();
    }

    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      filter.$or = [
        { route: { $regex: s, $options: 'i' } },
        { bus: { $regex: s, $options: 'i' } },
      ];
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 50));
    const skip = skipOf({ page, pageSize });

    const [total, schedules] = await Promise.all([
      this.scheduleModel.countDocuments(filter).exec(),
      this.scheduleModel.find(filter).sort({ createdAt: -1 }).skip(skip).limit(pageSize).lean<StoredScheduleDoc[]>().exec(),
    ]);

    const items = schedules.map((sc) => this.toView(sc));
    return new PaginatedResult(items, page, pageSize, total);
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<ClientScheduleView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid schedule ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const sc = await this.scheduleModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).lean<StoredScheduleDoc>().exec();

    if (!sc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Schedule not found');
    }

    return this.toView(sc);
  }

  async create(actor: AuthenticatedUserActor, input: CreateClientScheduleInput, info: ClientRequestInfo): Promise<ClientScheduleView> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }
    if (!input.days || input.days.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Pick at least one day');
    }
    if (input.to < input.from) {
      throw new ApiException('VALIDATION_FAILED', 'Till must be after From');
    }
    if (!Types.ObjectId.isValid(input.routeId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route ID');
    }
    if (!Types.ObjectId.isValid(input.busId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid bus ID');
    }

    const operatorId = new Types.ObjectId(actor.operatorId);
    const routeId = new Types.ObjectId(input.routeId);
    const busId = new Types.ObjectId(input.busId);

    // Verify route and bus
    const [routeDoc, busDoc] = await Promise.all([
      this.connection.collection('routes').findOne<{ name?: string }>({ _id: routeId, isDeleted: { $ne: true } }),
      this.connection.collection('buses').findOne<{ registrationNumber?: string; name?: string; busTypeId?: Types.ObjectId; status?: string }>({
        _id: busId,
        operatorId,
        isDeleted: { $ne: true },
      }),
    ]);

    if (!routeDoc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }
    if (!busDoc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found or does not belong to operator');
    }

    const busReg = busDoc.registrationNumber ?? busDoc.name ?? 'Bus';
    // The bus's real bus type decides the fare; without a fare there is no price to invent
    const busType = await requireBusType(this.connection, {
      busTypeId: busDoc.busTypeId,
      registrationNumber: busReg,
    });
    const fareDoc = await activeFareFor(this.connection, operatorId, routeId, busType);
    if (!fareDoc) {
      throw new ApiException('VALIDATION_FAILED', missingFareMessage(routeDoc.name ?? 'this route', busType));
    }
    const farePaise = fareDoc.weekday;

    const created = await this.auditedChanges.run<ScheduleHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.created',
      entityType: 'schedule',
      before: {},
      apply: async (session) => {
        const docs = await this.scheduleModel.create(
          [
            {
              operatorId,
              routeId,
              route: routeDoc.name ?? 'Route',
              busId,
              bus: busReg,
              time: input.time,
              days: input.days,
              from: input.from,
              to: input.to,
              status: input.status ?? 'ACTIVE',
              fare: farePaise,
              isDeleted: false,
            },
          ],
          { session },
        );
        const doc = docs[0];
        if (!doc) {
          throw new ApiException('INTERNAL_ERROR', 'Failed to create schedule');
        }
        return doc;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.route, bus: record.bus }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(created.toObject());
  }

  async update(actor: AuthenticatedUserActor, id: string, input: UpdateClientScheduleInput, info: ClientRequestInfo): Promise<ClientScheduleView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid schedule ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const sc = await this.scheduleModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).exec();

    if (!sc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Schedule not found');
    }

    const days = input.days ?? sc.days;
    if (days.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Pick at least one day');
    }

    const from = input.from ?? sc.from;
    const to = input.to ?? sc.to;
    if (to < from) {
      throw new ApiException('VALIDATION_FAILED', 'Till must be after From');
    }

    let routeName = sc.route;
    let busReg = sc.bus;

    if (input.routeId && input.routeId !== sc.routeId.toString()) {
      const routeDoc = await this.connection.collection('routes').findOne<{ name?: string }>({
        _id: new Types.ObjectId(input.routeId),
      });
      if (routeDoc?.name) routeName = routeDoc.name;
      sc.routeId = new Types.ObjectId(input.routeId);
    }

    if (input.busId && input.busId !== sc.busId.toString()) {
      const busDoc = await this.connection.collection('buses').findOne<{ registrationNumber?: string; name?: string }>({
        _id: new Types.ObjectId(input.busId),
        operatorId: sc.operatorId,
      });
      if (busDoc) busReg = busDoc.registrationNumber ?? busDoc.name ?? busReg;
      sc.busId = new Types.ObjectId(input.busId);
    }

    const updated = await this.auditedChanges.run<ScheduleHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.updated',
      entityType: 'schedule',
      before: { id: sc._id.toHexString(), route: sc.route, bus: sc.bus },
      apply: async () => {
        sc.route = routeName;
        sc.bus = busReg;
        sc.time = input.time ?? sc.time;
        sc.days = days;
        sc.from = from;
        sc.to = to;
        if (input.status) {
          sc.status = input.status;
        }
        await sc.save();
        return sc;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.route, bus: record.bus }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async deleteSchedule(actor: AuthenticatedUserActor, id: string, info: ClientRequestInfo): Promise<{ success: boolean }> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid schedule ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const sc = await this.scheduleModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).exec();

    if (!sc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Schedule not found');
    }

    await this.auditedChanges.run<ScheduleHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.deleted',
      entityType: 'schedule',
      before: { id: sc._id.toHexString(), route: sc.route },
      apply: async () => {
        sc.isDeleted = true;
        sc.deletedAt = new Date();
        await sc.save();

        // Safely remove only future DRAFT trips with zero bookings created by this schedule
        await this.connection.collection('trips').deleteMany({
          scheduleId: sc._id,
          operatorId: sc.operatorId,
          status: 'DRAFT',
          departureAt: { $gt: new Date() },
          'seatCounts.booked': { $lte: 0 },
        });

        return sc;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.route }),
      operatorIdOf: (record) => record.operatorId,
    });

    return { success: true };
  }

  async generateTrips(actor: AuthenticatedUserActor, id: string, info: ClientRequestInfo): Promise<GenerateTripsResult> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid schedule ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const sc = await this.scheduleModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).lean<StoredScheduleDoc>().exec();

    if (!sc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Schedule not found');
    }

    if (sc.status !== 'ACTIVE') {
      throw new ApiException('VALIDATION_FAILED', 'Activate the schedule first');
    }

    const [route, bus] = await Promise.all([
      this.connection.collection('routes').findOne<{
        _id: Types.ObjectId;
        name: string;
        from?: string;
        to?: string;
        hours?: number;
        originCityId?: Types.ObjectId;
        destinationCityId?: Types.ObjectId;
        stops?: unknown[];
      }>({ _id: sc.routeId }),
      this.connection.collection('buses').findOne<{
        _id: Types.ObjectId;
        name?: string;
        registrationNumber?: string;
        busTypeId?: Types.ObjectId;
        amenities?: string[];
        seatCapacity?: number;
        status?: string;
      }>({ _id: sc.busId, operatorId: sc.operatorId }),
    ]);

    if (!bus || bus.status !== 'ACTIVE') {
      throw new ApiException('VALIDATION_FAILED', 'The bus is not active');
    }
    if (!route) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }

    const busReg = bus.registrationNumber ?? bus.name ?? 'Bus';
    const seatCapacity = bus.seatCapacity ?? 40;

    // The bus's real bus type decides the fare and what the trip says about the bus
    const busType = await requireBusType(this.connection, { busTypeId: bus.busTypeId, registrationNumber: busReg });
    const fareDoc = await activeFareFor(this.connection, sc.operatorId, sc.routeId, busType);
    if (!fareDoc) {
      throw new ApiException('VALIDATION_FAILED', missingFareMessage(route.name, busType));
    }
    // Real cities and places of the route (a route saved with made-up ids is repaired here)
    const routeCities = await healRouteCities(this.connection, route);

    const now = new Date();
    let n = 0;
    let skip = 0;
    const ONE_DAY = 24 * 60 * 60 * 1000;
    const [depHour, depMin] = sc.time.split(':').map((v) => parseInt(v, 10));
    const h = isNaN(depHour ?? 0) ? 21 : (depHour ?? 0);
    const m = isNaN(depMin ?? 0) ? 30 : (depMin ?? 0);

    const tripsToInsert: Record<string, unknown>[] = [];

    for (let k = 0; k < 14; k++) {
      const d = new Date(now.getTime() + k * ONE_DAY);
      const di = (d.getDay() + 6) % 7;
      const dayName = WEEKDAYS[di];
      if (!dayName || !sc.days.includes(dayName)) continue;

      const ds = d.toISOString().slice(0, 10);
      if (ds < sc.from || ds > sc.to) continue;

      d.setHours(h, m, 0, 0);
      if (d.getTime() <= now.getTime()) continue;

      // Check conflict: existing non-cancelled trip for same bus on same day
      const startOfDay = new Date(d);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(d);
      endOfDay.setHours(23, 59, 59, 999);

      const existingTrip = await this.connection.collection('trips').findOne({
        busId: bus._id,
        departureAt: { $gte: startOfDay, $lte: endOfDay },
        status: { $ne: 'CANCELLED' },
      });

      if (existingTrip) {
        skip++;
        continue;
      }

      const isWeekend = di >= 5;
      const startingFare = isWeekend ? fareDoc.weekend : fareDoc.weekday;
      const durationHours = route.hours ?? 8;
      const points = await routePointsOf(this.connection, routeCities.stops, d);

      tripsToInsert.push({
        operatorId: sc.operatorId,
        scheduleId: sc._id,
        routeId: route._id,
        route: route.name,
        busId: bus._id,
        travelDate: ds,
        timezone: 'Asia/Kolkata',
        departureAt: d,
        arrivalAt: new Date(d.getTime() + durationHours * 3600000),
        departureMinuteOfDay: h * 60 + m,
        durationMinutes: durationHours * 60,
        originCityId: routeCities.originCityId,
        destinationCityId: routeCities.destinationCityId,
        stopCityIds: [
          ...new Map(
            points.stopCityIds
              .filter((id) => !id.equals(routeCities.originCityId) && !id.equals(routeCities.destinationCityId))
              .map((id) => [id.toHexString(), id] as const),
          ).values(),
        ],
        boardingPoints: points.boardingPoints,
        droppingPoints: points.droppingPoints,
        bus: busSnapshotOf(bus, busType),
        ...(fareDoc.fareRuleSetVersionId ? { fareRuleSetVersionId: fareDoc.fareRuleSetVersionId } : {}),
        startingFarePaise: startingFare,
        currency: 'INR',
        status: 'DRAFT',
        seatCounts: {
          total: seatCapacity,
          available: seatCapacity,
          locked: 0,
          booked: 0,
          blocked: 0,
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      n++;
    }

    if (tripsToInsert.length > 0) {
      await this.connection.collection('trips').insertMany(tripsToInsert);
    }

    const message = `${n} draft trips created${skip ? `, ${skip} skipped (bus already busy that day)` : ''}. Publish them in Trips.`;

    await this.auditedChanges.run<ScheduleHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.created',
      entityType: 'trip',
      before: {},
      apply: () => Promise.resolve(sc as unknown as ScheduleHydratedDoc),
      describe: () => ({ scheduleId: sc._id.toHexString(), createdTrips: n, skippedTrips: skip }),
      operatorIdOf: () => sc.operatorId,
    });

    return { createdCount: n, skippedCount: skip, message };
  }
}
