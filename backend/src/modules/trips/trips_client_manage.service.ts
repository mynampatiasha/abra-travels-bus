import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type HydratedDocument, type Model, Types } from 'mongoose';
import { type StoredDocument } from '../../database/scoped-repository.base';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { ProofFilesService } from '../files/files_core.service';
import { TRIP_MODEL, type Trip, type TripPoint, type TripStatus } from './schemas/trip.schema';
import { SEAT_INVENTORY_MODEL, type SeatInventoryItem } from './schemas/seat-inventory.schema';

export type StoredTripDoc = StoredDocument<Trip>;
export type TripHydratedDoc = HydratedDocument<Trip>;

export interface ClientTripKpis {
  onSale: number;
  drafts: number;
  running: number;
  noDriver: number;
}

export interface ClientTripView {
  id: string;
  operatorId: string;
  routeId: string;
  route: string;
  busId: string;
  bus: string;
  busName?: string;
  busType: string;
  travelDate: string;
  departureAt: string;
  arrivalAt: string;
  departureTime: string;
  startingFarePaise: number;
  seatLayoutVersionId?: string;
  fareRuleSetVersionId?: string;
  status: TripStatus;
  totalSeats: number;
  availableSeats: number;
  bookedSeats: number;
  heldSeats: number;
  blockedSeats: number;
  driver?: string;
  conductor?: string;
  delayMinutes?: number;
  delayReason?: string;
  cancellationReason?: string;
  boardingPoints?: TripPoint[];
  droppingPoints?: TripPoint[];
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateClientTripInput {
  routeId: string;
  busId: string;
  travelDate: string; // YYYY-MM-DD
  departureTime: string; // HH:mm
  startingFarePaise: number;
  publish?: boolean;
  driverId?: string;
  conductorId?: string;
}

export interface UpdateClientTripInput {
  travelDate?: string;
  departureTime?: string;
  startingFarePaise?: number;
  busId?: string;
  routeId?: string;
}

export interface ClientTripQueryInput {
  status?: string;
  when?: 'up' | 'today' | 'past' | 'all';
  routeId?: string;
  busId?: string;
  travelDate?: string;
  search?: string;
  page?: number;
  pageSize?: number;
  sort?: string;
  dir?: number;
}

@Injectable()
export class TripsClientManageService {
  constructor(
    @InjectModel(TRIP_MODEL) private readonly tripModel: Model<Trip>,
    @InjectModel(SEAT_INVENTORY_MODEL) private readonly seatModel: Model<SeatInventoryItem>,
    @InjectConnection() private readonly connection: Connection,
    private readonly auditedChanges: AuditedChangeRunner,
    private readonly proofFiles: ProofFilesService,
  ) {}

  private toView(t: StoredTripDoc): ClientTripView {
    const busReg = t.bus?.registrationNumber ?? 'Bus';
    const busType = t.bus?.busTypeName ?? t.bus?.busTypeKey ?? 'AC Sleeper';
    const busName = t.bus?.name;

    const [hh, mm] = t.departureTimeLocal
      ? t.departureTimeLocal.split(':')
      : [
          String(Math.floor(t.departureMinuteOfDay / 60)).padStart(2, '0'),
          String(t.departureMinuteOfDay % 60).padStart(2, '0'),
        ];
    const depTime = `${hh}:${mm}`;

    const total = t.seatCounts?.total ?? 40;
    const available = t.seatCounts?.available ?? total;
    const booked = t.seatCounts?.booked ?? 0;
    const held = t.seatCounts?.locked ?? 0;
    const blocked = t.seatCounts?.blocked ?? 0;

    return {
      id: t._id.toString(),
      operatorId: t.operatorId.toString(),
      routeId: t.routeId.toString(),
      route: (t as unknown as { route?: string }).route ?? 'General Route',
      busId: t.busId.toString(),
      bus: busReg,
      busName,
      busType,
      travelDate: t.travelDate,
      departureAt: t.departureAt.toISOString(),
      arrivalAt: t.arrivalAt.toISOString(),
      departureTime: depTime,
      startingFarePaise: t.startingFarePaise,
      seatLayoutVersionId: t.seatLayoutVersionId ? t.seatLayoutVersionId.toString() : undefined,
      fareRuleSetVersionId: t.fareRuleSetVersionId ? t.fareRuleSetVersionId.toString() : undefined,
      status: t.status,
      totalSeats: total,
      availableSeats: available,
      bookedSeats: booked,
      heldSeats: held,
      blockedSeats: blocked,
      driver: t.driverName,
      conductor: t.conductorName,
      delayMinutes: t.delayMinutes,
      delayReason: t.delayReason,
      cancellationReason: t.cancellationReason,
      boardingPoints: t.boardingPoints,
      droppingPoints: t.droppingPoints,
      createdAt: t.createdAt ? t.createdAt.toISOString() : undefined,
      updatedAt: t.updatedAt ? t.updatedAt.toISOString() : undefined,
    };
  }

  async list(
    actor: AuthenticatedUserActor,
    query: ClientTripQueryInput,
  ): Promise<{ items: ClientTripView[]; page: number; pageSize: number; total: number; kpis: ClientTripKpis }> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }
    const operatorId = new Types.ObjectId(actor.operatorId);
    const filter: Record<string, unknown> = {
      operatorId,
    };

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status.toUpperCase();
    }

    const now = new Date();
    const todayStr = now.toISOString().slice(0, 10);

    if (query.when === 'up') {
      filter.departureAt = { $gt: now };
    } else if (query.when === 'today') {
      filter.travelDate = todayStr;
    } else if (query.when === 'past') {
      filter.departureAt = { $lt: now };
    }

    if (query.travelDate) {
      filter.travelDate = query.travelDate;
    }

    if (query.routeId && Types.ObjectId.isValid(query.routeId)) {
      filter.routeId = new Types.ObjectId(query.routeId);
    }

    if (query.busId && Types.ObjectId.isValid(query.busId)) {
      filter.busId = new Types.ObjectId(query.busId);
    }

    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      filter.$or = [
        { route: { $regex: s, $options: 'i' } },
        { 'bus.registrationNumber': { $regex: s, $options: 'i' } },
        { 'bus.name': { $regex: s, $options: 'i' } },
        { driverName: { $regex: s, $options: 'i' } },
      ];
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 50));
    const skip = skipOf({ page, pageSize });

    const sortField = query.sort === 'depart' ? 'departureAt' : 'departureAt';
    const sortDir = (query.dir ?? 1) === -1 ? -1 : 1;

    const [total, trips, onSale, drafts, running, noDriver] = await Promise.all([
      this.tripModel.countDocuments(filter).exec(),
      this.tripModel
        .find(filter)
        .sort({ [sortField]: sortDir })
        .skip(skip)
        .limit(pageSize)
        .lean<StoredTripDoc[]>()
        .exec(),
      this.tripModel.countDocuments({
        operatorId,
        departureAt: { $gt: now },
        status: 'SCHEDULED',
      }),
      this.tripModel.countDocuments({ operatorId, status: 'DRAFT' }),
      this.tripModel.countDocuments({
        operatorId,
        status: { $in: ['BOARDING', 'IN_TRANSIT', 'DEPARTED', 'DELAYED'] },
      }),
      this.tripModel.countDocuments({
        operatorId,
        departureAt: { $gt: now },
        status: { $ne: 'CANCELLED' },
        $or: [{ driverName: null }, { driverName: { $exists: false } }, { driverName: '' }],
      }),
    ]);

    const items = trips.map((t) => this.toView(t));
    return {
      items,
      page,
      pageSize,
      total,
      kpis: { onSale, drafts, running, noDriver },
    };
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<ClientTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const trip = await this.tripModel
      .findOne({
        _id: new Types.ObjectId(id),
        operatorId: new Types.ObjectId(actor.operatorId),
      })
      .lean<StoredTripDoc>()
      .exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }

    return this.toView(trip);
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateClientTripInput,
    info: ClientRequestInfo,
  ): Promise<ClientTripView> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }
    if (!Types.ObjectId.isValid(input.routeId) || !Types.ObjectId.isValid(input.busId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route or bus ID');
    }

    const operatorId = new Types.ObjectId(actor.operatorId);
    const routeId = new Types.ObjectId(input.routeId);
    const busId = new Types.ObjectId(input.busId);

    const [operator, route, bus] = await Promise.all([
      this.connection.collection('operators').findOne<{ _id: Types.ObjectId; status: string }>({
        _id: operatorId,
        isDeleted: { $ne: true },
      }),
      this.connection.collection('routes').findOne<{
        _id: Types.ObjectId;
        name: string;
        hours?: number;
        originCityId?: Types.ObjectId;
        destinationCityId?: Types.ObjectId;
        stops?: unknown[];
      }>({ _id: routeId, isDeleted: { $ne: true } }),
      this.connection.collection('buses').findOne<{
        _id: Types.ObjectId;
        registrationNumber: string;
        name: string;
        busTypeId: Types.ObjectId;
        type?: string;
        busTypeName?: string;
        seatCapacity?: number;
        activeSeatLayoutVersionId?: Types.ObjectId;
        status: string;
      }>({ _id: busId, operatorId, isDeleted: { $ne: true } }),
    ]);

    if (!operator) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Operator not found');
    }
    if (!route) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Route not found');
    }
    if (!bus) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found');
    }

    // Check conflict: bus cannot have two non-cancelled trips on the same date
    const existing = await this.tripModel.findOne({
      busId,
      travelDate: input.travelDate,
      status: { $ne: 'CANCELLED' },
    });
    if (existing) {
      throw new ApiException('VALIDATION_FAILED', 'This bus already has a trip on this date');
    }

    const [hhStr, mmStr] = input.departureTime.split(':');
    const hh = parseInt(hhStr ?? '21', 10);
    const mm = parseInt(mmStr ?? '30', 10);
    const depMinute = hh * 60 + mm;

    const depDate = new Date(`${input.travelDate}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00`);
    const durationHours = route.hours ?? 8;
    const arrDate = new Date(depDate.getTime() + durationHours * 3600000);

    const busTypeKey = bus.type ?? bus.busTypeName ?? 'AC Sleeper';
    const busReg = bus.registrationNumber ?? bus.name ?? 'Bus';
    const seatCap = bus.seatCapacity ?? 40;

    let driverName: string | undefined;
    if (input.driverId && Types.ObjectId.isValid(input.driverId)) {
      const driverDoc = await this.connection.collection('operator_crew').findOne<{
        name: string;
        status: string;
        licenseExpiryDate?: Date;
      }>({
        _id: new Types.ObjectId(input.driverId),
        operatorId,
        isDeleted: { $ne: true },
      });
      if (driverDoc && driverDoc.status === 'ACTIVE') {
        if (driverDoc.licenseExpiryDate && new Date(driverDoc.licenseExpiryDate) < depDate) {
          throw new ApiException('VALIDATION_FAILED', 'Driver license has expired');
        }
        driverName = driverDoc.name;
      }
    }

    const initialStatus: TripStatus = input.publish ? 'SCHEDULED' : 'DRAFT';

    if (input.publish) {
      if (operator.status !== 'ACTIVE') {
        throw new ApiException('VALIDATION_FAILED', 'Operator KYC is not approved');
      }
      if (bus.status !== 'ACTIVE') {
        throw new ApiException('VALIDATION_FAILED', 'Bus KYC is not approved');
      }
      if (!bus.activeSeatLayoutVersionId) {
        throw new ApiException('VALIDATION_FAILED', 'Bus has no active seat layout');
      }
    }

    const created = await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: input.publish ? 'trip.published' : 'catalogue.created',
      entityType: 'trip',
      before: {},
      apply: async (session) => {
        const docs = await this.tripModel.create(
          [
            {
              operatorId,
              routeId,
              route: route.name,
              busId,
              travelDate: input.travelDate,
              timezone: 'Asia/Kolkata',
              departureAt: depDate,
              arrivalAt: arrDate,
              departureMinuteOfDay: depMinute,
              durationMinutes: durationHours * 60,
              originCityId: route.originCityId ?? new Types.ObjectId(),
              destinationCityId: route.destinationCityId ?? new Types.ObjectId(),
              stopCityIds: [],
              boardingPoints: [],
              droppingPoints: [],
              bus: {
                name: bus.name ?? busReg,
                registrationNumber: busReg,
                busTypeKey,
                busTypeName: busTypeKey,
                isAc: true,
                berthType: 'SEATER',
                amenities: [],
              },
              startingFarePaise: input.startingFarePaise,
              currency: 'INR',
              seatLayoutVersionId: bus.activeSeatLayoutVersionId,
              status: initialStatus,
              publishedAt: input.publish ? new Date() : undefined,
              departureTimeLocal: input.departureTime,
              driverId: input.driverId ? new Types.ObjectId(input.driverId) : undefined,
              driverName,
              seatCounts: {
                total: seatCap,
                available: seatCap,
                locked: 0,
                booked: 0,
                blocked: 0,
              },
            },
          ],
          { session },
        );
        const doc = docs[0];
        if (!doc) {
          throw new ApiException('INTERNAL_ERROR', 'Failed to create trip');
        }

        if (input.publish) {
          await this.populateSeatInventory(doc, bus.activeSeatLayoutVersionId, seatCap, input.startingFarePaise, session);
        }

        return doc;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.bus?.name, status: record.status }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(created.toObject());
  }

  private async populateSeatInventory(
    trip: TripHydratedDoc,
    layoutVersionId: Types.ObjectId | undefined,
    seatCap: number,
    pricePaise: number,
    session?: ClientSession,
  ): Promise<void> {
    const layout = layoutVersionId
      ? await this.connection.collection('seat_layouts').findOne<{ seats?: { seatNumber: string; deck?: string; seatType?: string }[] }>({
          _id: layoutVersionId,
        })
      : null;

    const seatsToInsert: Record<string, unknown>[] = [];
    if (layout?.seats && layout.seats.length > 0) {
      for (const s of layout.seats) {
        seatsToInsert.push({
          tripId: trip._id,
          operatorId: trip.operatorId,
          seatNumber: s.seatNumber,
          deck: s.deck === 'UPPER' ? 'UPPER' : 'LOWER',
          seatType: s.seatType ?? 'SEATER',
          status: 'AVAILABLE',
          pricePaise,
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }
    } else {
      for (let i = 1; i <= seatCap; i++) {
        seatsToInsert.push({
          tripId: trip._id,
          operatorId: trip.operatorId,
          seatNumber: String(i),
          deck: 'LOWER',
          seatType: 'SEATER',
          status: 'AVAILABLE',
          pricePaise,
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }
    }

    if (seatsToInsert.length > 0) {
      await this.connection.collection('seat_inventory').insertMany(seatsToInsert, { ...(session ? { session } : {}) });
    }
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateClientTripInput,
    info: ClientRequestInfo,
  ): Promise<ClientTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }
    if (trip.status !== 'DRAFT') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Only a DRAFT can be edited');
    }

    const updated = await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'catalogue.updated',
      entityType: 'trip',
      before: { id: trip._id.toHexString(), status: trip.status },
      apply: async () => {
        if (input.startingFarePaise !== undefined) {
          trip.startingFarePaise = input.startingFarePaise;
        }
        if (input.travelDate) {
          trip.travelDate = input.travelDate;
        }
        if (input.departureTime) {
          trip.departureTimeLocal = input.departureTime;
          const [hhStr, mmStr] = input.departureTime.split(':');
          const hh = parseInt(hhStr ?? '21', 10);
          const mm = parseInt(mmStr ?? '30', 10);
          trip.departureMinuteOfDay = hh * 60 + mm;
          const dep = new Date(`${trip.travelDate}T${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:00`);
          trip.departureAt = dep;
          trip.arrivalAt = new Date(dep.getTime() + trip.durationMinutes * 60000);
        }
        await trip.save();
        return trip;
      },
      describe: (record) => ({ id: record._id.toHexString(), status: record.status }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async publish(actor: AuthenticatedUserActor, id: string, info: ClientRequestInfo): Promise<ClientTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }
    if (trip.status !== 'DRAFT') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Only DRAFT trips can be published');
    }

    const [operator, bus] = await Promise.all([
      this.connection.collection('operators').findOne<{ _id: Types.ObjectId; status: string }>({
        _id: trip.operatorId,
        isDeleted: { $ne: true },
      }),
      this.connection.collection('buses').findOne<{
        _id: Types.ObjectId;
        status: string;
        activeSeatLayoutVersionId?: Types.ObjectId;
        seatCapacity?: number;
      }>({ _id: trip.busId, isDeleted: { $ne: true } }),
    ]);

    if (!operator || operator.status !== 'ACTIVE') {
      throw new ApiException('VALIDATION_FAILED', 'Operator KYC is not approved');
    }
    if (!bus || bus.status !== 'ACTIVE') {
      throw new ApiException('VALIDATION_FAILED', 'Bus KYC is not approved');
    }
    if (!bus.activeSeatLayoutVersionId) {
      throw new ApiException('VALIDATION_FAILED', 'Bus has no active seat layout');
    }

    // Lookup active fare for this route & seat type if trip has none
    let fareRuleSetVersionId = trip.fareRuleSetVersionId;
    if (!fareRuleSetVersionId) {
      const fare = await this.connection.collection('fares').findOne<{
        fareRuleSetVersionId?: Types.ObjectId;
      }>({
        operatorId: trip.operatorId,
        routeId: trip.routeId,
        status: 'ACTIVE',
        isDeleted: { $ne: true },
      });
      fareRuleSetVersionId = fare?.fareRuleSetVersionId;
    }

    const updated = await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'trip.published',
      entityType: 'trip',
      before: { id: trip._id.toHexString(), status: trip.status },
      apply: async (session) => {
        trip.status = 'SCHEDULED';
        trip.publishedAt = new Date();
        trip.seatLayoutVersionId = bus.activeSeatLayoutVersionId;
        if (fareRuleSetVersionId) {
          trip.fareRuleSetVersionId = fareRuleSetVersionId;
        }
        await trip.save({ session });

        await this.populateSeatInventory(
          trip,
          bus.activeSeatLayoutVersionId,
          bus.seatCapacity ?? trip.seatCounts.total,
          trip.startingFarePaise,
          session,
        );

        return trip;
      },
      describe: (record) => ({ id: record._id.toHexString(), status: record.status }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async cancel(
    actor: AuthenticatedUserActor,
    id: string,
    input: { reason: string; proofFileIds?: string[] },
    info: ClientRequestInfo,
  ): Promise<ClientTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    if (!input.reason || input.reason.trim().length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Cancellation reason is required');
    }

    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }
    if (['CANCELLED', 'ARRIVED'].includes(trip.status)) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Trip cannot be cancelled');
    }

    const updated = await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'trip.cancelled',
      entityType: 'trip',
      before: { id: trip._id.toHexString(), status: trip.status },
      reason: input.reason.trim(),
      apply: async (session) => {
        trip.status = 'CANCELLED';
        trip.cancelledAt = new Date();
        trip.cancellationReason = input.reason.trim();
        await trip.save({ session });

        if (input.proofFileIds && input.proofFileIds.length > 0) {
          await this.proofFiles.attach(
            input.proofFileIds,
            { type: 'trip-cancel', id: trip._id, operatorId: trip.operatorId },
            session,
          );
        }

        return trip;
      },
      describe: (record) => ({ id: record._id.toHexString(), status: record.status, reason: record.cancellationReason }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async delay(
    actor: AuthenticatedUserActor,
    id: string,
    input: { delayMinutes: number; reason: string; proofFileIds?: string[] },
    info: ClientRequestInfo,
  ): Promise<ClientTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    if (input.delayMinutes < 5 || input.delayMinutes > 720) {
      throw new ApiException('VALIDATION_FAILED', 'Delay must be between 5 and 720 minutes');
    }
    if (!input.reason || input.reason.trim().length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Delay reason is required');
    }

    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }

    const updated = await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'trip.delayed',
      entityType: 'trip',
      before: { id: trip._id.toHexString(), status: trip.status, delayMinutes: trip.delayMinutes },
      reason: input.reason.trim(),
      apply: async (session) => {
        trip.status = 'DELAYED';
        trip.delayMinutes = input.delayMinutes;
        trip.delayReason = input.reason.trim();
        trip.arrivalAt = new Date(trip.arrivalAt.getTime() + input.delayMinutes * 60000);
        await trip.save({ session });

        if (input.proofFileIds && input.proofFileIds.length > 0) {
          await this.proofFiles.attach(
            input.proofFileIds,
            { type: 'trip-delay', id: trip._id, operatorId: trip.operatorId },
            session,
          );
        }

        return trip;
      },
      describe: (record) => ({ id: record._id.toHexString(), status: record.status, delayMinutes: record.delayMinutes }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async assignCrew(
    actor: AuthenticatedUserActor,
    id: string,
    input: { driverId?: string; conductorId?: string },
    info: ClientRequestInfo,
  ): Promise<ClientTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }

    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }

    let driverName: string | undefined;
    if (input.driverId && Types.ObjectId.isValid(input.driverId)) {
      const crew = await this.connection.collection('operator_crew').findOne<{
        name: string;
        role: string;
        status: string;
        licenseExpiryDate?: Date;
      }>({
        _id: new Types.ObjectId(input.driverId),
        operatorId: trip.operatorId,
        isDeleted: { $ne: true },
      });

      if (!crew) {
        throw new ApiException('RESOURCE_NOT_FOUND', 'Driver not found');
      }
      if (crew.role !== 'DRIVER') {
        throw new ApiException('VALIDATION_FAILED', 'Crew member is not a driver');
      }
      if (crew.status !== 'ACTIVE') {
        throw new ApiException('VALIDATION_FAILED', 'Driver is not active');
      }
      if (crew.licenseExpiryDate && new Date(crew.licenseExpiryDate) < trip.departureAt) {
        throw new ApiException('VALIDATION_FAILED', 'Driver license has expired');
      }
      driverName = crew.name;
    }

    const updated = await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'trip.crew-assigned',
      entityType: 'trip',
      before: { id: trip._id.toHexString(), driver: trip.driverName },
      apply: async () => {
        trip.driverId = input.driverId ? new Types.ObjectId(input.driverId) : undefined;
        trip.driverName = driverName;
        await trip.save();
        return trip;
      },
      describe: (record) => ({ id: record._id.toHexString(), driver: record.driverName }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async manifest(actor: AuthenticatedUserActor, id: string): Promise<{ bookings: unknown[]; message: string }> {
    await this.get(actor, id);
    return {
      bookings: [],
      message: 'No bookings yet.',
    };
  }

  async listSeats(actor: AuthenticatedUserActor, tripId: string): Promise<SeatInventoryItem[]> {
    await this.get(actor, tripId);
    return this.seatModel.find({ tripId: new Types.ObjectId(tripId) }).lean<SeatInventoryItem[]>().exec();
  }

  async blockSeats(
    actor: AuthenticatedUserActor,
    tripId: string,
    seatNumbers: string[],
    reason: string,
    info: ClientRequestInfo,
  ): Promise<{ blockedCount: number }> {
    if (!seatNumbers || seatNumbers.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Pick at least one seat');
    }
    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(tripId),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }

    await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'seat.blocked',
      entityType: 'seat_inventory',
      before: { tripId: trip._id.toHexString(), seatNumbers },
      reason,
      apply: async (session) => {
        await this.seatModel.updateMany(
          {
            tripId: trip._id,
            seatNumber: { $in: seatNumbers },
            status: 'AVAILABLE',
          },
          {
            $set: {
              status: 'BLOCKED',
              blockReason: reason,
              blockedBy: { userId: new Types.ObjectId(actor.userId), userType: actor.userType },
              blockedAt: new Date(),
            },
          },
          { session },
        );

        const [avail, blk] = await Promise.all([
          this.seatModel.countDocuments({ tripId: trip._id, status: 'AVAILABLE' }).session(session),
          this.seatModel.countDocuments({ tripId: trip._id, status: 'BLOCKED' }).session(session),
        ]);
        trip.seatCounts.available = avail;
        trip.seatCounts.blocked = blk;
        await trip.save({ session });
        return trip;
      },
      describe: (record) => ({ tripId: record._id.toHexString(), blockedSeats: record.seatCounts.blocked }),
      operatorIdOf: (record) => record.operatorId,
    });

    return { blockedCount: seatNumbers.length };
  }

  async unblockSeats(
    actor: AuthenticatedUserActor,
    tripId: string,
    seatNumbers: string[],
    info: ClientRequestInfo,
  ): Promise<{ unblockedCount: number }> {
    if (!seatNumbers || seatNumbers.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Pick at least one seat');
    }
    const trip = await this.tripModel.findOne({
      _id: new Types.ObjectId(tripId),
      operatorId: new Types.ObjectId(actor.operatorId),
    }).exec();

    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }

    await this.auditedChanges.run<TripHydratedDoc>({
      actor,
      client: info,
      action: 'seat.unblocked',
      entityType: 'seat_inventory',
      before: { tripId: trip._id.toHexString(), seatNumbers },
      apply: async (session) => {
        await this.seatModel.updateMany(
          {
            tripId: trip._id,
            seatNumber: { $in: seatNumbers },
            status: 'BLOCKED',
          },
          {
            $set: { status: 'AVAILABLE' },
            $unset: { blockReason: '', blockedBy: '', blockedAt: '' },
          },
          { session },
        );

        const [avail, blk] = await Promise.all([
          this.seatModel.countDocuments({ tripId: trip._id, status: 'AVAILABLE' }).session(session),
          this.seatModel.countDocuments({ tripId: trip._id, status: 'BLOCKED' }).session(session),
        ]);
        trip.seatCounts.available = avail;
        trip.seatCounts.blocked = blk;
        await trip.save({ session });
        return trip;
      },
      describe: (record) => ({ tripId: record._id.toHexString(), blockedSeats: record.seatCounts.blocked }),
      operatorIdOf: (record) => record.operatorId,
    });

    return { unblockedCount: seatNumbers.length };
  }
}
