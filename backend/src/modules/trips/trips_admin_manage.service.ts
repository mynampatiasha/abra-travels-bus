import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type HydratedDocument, type Model, Types } from 'mongoose';
import { type StoredDocument } from '../../database/scoped-repository.base';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { TRIP_MODEL, type Trip, type TripStatus } from './schemas/trip.schema';
import { SEAT_INVENTORY_MODEL, type SeatInventoryItem } from './schemas/seat-inventory.schema';

export type StoredTripDoc = StoredDocument<Trip>;
export type TripHydratedDoc = HydratedDocument<Trip>;

export interface AdminTripKpis {
  tripsOnSale: number;
  seatsSold: number;
  seatsHeld: number;
  lowOccupancyCount: number;
}

export interface AdminTripView {
  id: string;
  operatorId: string;
  operatorName: string;
  routeId: string;
  route: string;
  busId: string;
  bus: string;
  busType: string;
  travelDate: string;
  departureAt: string;
  arrivalAt: string;
  departureTime: string;
  startingFarePaise: number;
  status: TripStatus;
  totalSeats: number;
  availableSeats: number;
  bookedSeats: number;
  heldSeats: number;
  blockedSeats: number;
  occupancyPercent: number;
  driver?: string;
  conductor?: string;
  delayMinutes?: number;
  delayReason?: string;
  cancellationReason?: string;
  createdAt?: string;
}

export interface AdminTripQueryInput {
  operatorId?: string;
  status?: string;
  routeId?: string;
  search?: string;
  occupancy?: 'low' | 'high' | 'all';
  page?: number;
  pageSize?: number;
  sort?: string;
  dir?: number;
}

@Injectable()
export class TripsAdminManageService {
  constructor(
    @InjectModel(TRIP_MODEL) private readonly tripModel: Model<Trip>,
    @InjectModel(SEAT_INVENTORY_MODEL) private readonly seatModel: Model<SeatInventoryItem>,
    @InjectConnection() private readonly connection: Connection,
    private readonly auditedChanges: AuditedChangeRunner,
  ) {}

  private async toView(t: StoredTripDoc, opNameMap?: Map<string, string>): Promise<AdminTripView> {
    let operatorName = opNameMap?.get(t.operatorId.toString());
    if (!operatorName) {
      const op = await this.connection.collection('operators').findOne<{ companyName?: string; displayName?: string }>({
        _id: t.operatorId,
      });
      operatorName = op?.displayName ?? op?.companyName ?? 'Operator';
    }

    const busReg = t.bus?.registrationNumber ?? 'Bus';
    const busType = t.bus?.busTypeName ?? t.bus?.busTypeKey ?? 'AC Sleeper';

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
    const occupancyPercent = total > 0 ? Math.round((booked / total) * 100) : 0;

    return {
      id: t._id.toString(),
      operatorId: t.operatorId.toString(),
      operatorName,
      routeId: t.routeId.toString(),
      route: (t as unknown as { route?: string }).route ?? 'General Route',
      busId: t.busId.toString(),
      bus: busReg,
      busType,
      travelDate: t.travelDate,
      departureAt: t.departureAt.toISOString(),
      arrivalAt: t.arrivalAt.toISOString(),
      departureTime: depTime,
      startingFarePaise: t.startingFarePaise,
      status: t.status,
      totalSeats: total,
      availableSeats: available,
      bookedSeats: booked,
      heldSeats: held,
      blockedSeats: blocked,
      occupancyPercent,
      driver: t.driverName,
      conductor: t.conductorName,
      delayMinutes: t.delayMinutes,
      delayReason: t.delayReason,
      cancellationReason: t.cancellationReason,
      createdAt: t.createdAt ? t.createdAt.toISOString() : undefined,
    };
  }

  async list(
    actor: AuthenticatedUserActor,
    query: AdminTripQueryInput,
  ): Promise<{ items: AdminTripView[]; page: number; pageSize: number; total: number; kpis: AdminTripKpis }> {
    const filter: Record<string, unknown> = {};

    if (query.operatorId && Types.ObjectId.isValid(query.operatorId)) {
      filter.operatorId = new Types.ObjectId(query.operatorId);
    }

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status.toUpperCase();
    }

    if (query.routeId && Types.ObjectId.isValid(query.routeId)) {
      filter.routeId = new Types.ObjectId(query.routeId);
    }

    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      filter.$or = [
        { route: { $regex: s, $options: 'i' } },
        { 'bus.registrationNumber': { $regex: s, $options: 'i' } },
        { 'bus.name': { $regex: s, $options: 'i' } },
      ];
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 50));
    const skip = skipOf({ page, pageSize });

    const sortDir = (query.dir ?? 1) === -1 ? -1 : 1;

    const [total, trips, upcomingTrips] = await Promise.all([
      this.tripModel.countDocuments(filter).exec(),
      this.tripModel
        .find(filter)
        .sort({ departureAt: sortDir })
        .skip(skip)
        .limit(pageSize)
        .lean<StoredTripDoc[]>()
        .exec(),
      this.tripModel
        .find({ status: { $in: ['SCHEDULED', 'BOARDING'] } })
        .lean<StoredTripDoc[]>()
        .exec(),
    ]);

    // Gather operator names in bulk
    const opIds = [...new Set(trips.map((t) => t.operatorId))];
    const ops = await this.connection
      .collection('operators')
      .find<{ _id: Types.ObjectId; companyName?: string; displayName?: string }>({
        _id: { $in: opIds },
      })
      .toArray();
    const opNameMap = new Map(ops.map((o) => [o._id.toString(), o.displayName ?? o.companyName ?? 'Operator']));

    const items = await Promise.all(trips.map((t) => this.toView(t, opNameMap)));

    // Calculate inventory KPIs
    const now = new Date();
    const twoDaysMs = 2 * 24 * 60 * 60 * 1000;
    let seatsSold = 0;
    let seatsHeld = 0;
    let lowOccupancyCount = 0;

    for (const t of upcomingTrips) {
      const booked = t.seatCounts?.booked ?? 0;
      const locked = t.seatCounts?.locked ?? 0;
      const tot = t.seatCounts?.total ?? 40;
      seatsSold += booked;
      seatsHeld += locked;

      const dep = new Date(t.departureAt);
      if (dep.getTime() - now.getTime() < twoDaysMs && dep.getTime() > now.getTime()) {
        if (tot > 0 && booked / tot < 0.25) {
          lowOccupancyCount++;
        }
      }
    }

    return {
      items,
      page,
      pageSize,
      total,
      kpis: {
        tripsOnSale: upcomingTrips.length,
        seatsSold,
        seatsHeld,
        lowOccupancyCount,
      },
    };
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<AdminTripView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }

    const trip = await this.tripModel.findOne({ _id: new Types.ObjectId(id) }).lean<StoredTripDoc>().exec();
    if (!trip) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Trip not found');
    }

    return this.toView(trip);
  }

  async listSeats(actor: AuthenticatedUserActor, tripId: string): Promise<SeatInventoryItem[]> {
    if (!Types.ObjectId.isValid(tripId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    return this.seatModel.find({ tripId: new Types.ObjectId(tripId) }).lean<SeatInventoryItem[]>().exec();
  }

  async blockSeats(
    actor: AuthenticatedUserActor,
    tripId: string,
    seatNumbers: string[],
    reason: string,
    info: ClientRequestInfo,
  ): Promise<{ blockedCount: number }> {
    if (!Types.ObjectId.isValid(tripId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    if (!seatNumbers || seatNumbers.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Pick at least one seat');
    }

    const trip = await this.tripModel.findOne({ _id: new Types.ObjectId(tripId) }).exec();
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
    if (!Types.ObjectId.isValid(tripId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid trip ID');
    }
    if (!seatNumbers || seatNumbers.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Pick at least one seat');
    }

    const trip = await this.tripModel.findOne({ _id: new Types.ObjectId(tripId) }).exec();
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

  async releaseExpiredHolds(_actor: AuthenticatedUserActor, _info: ClientRequestInfo): Promise<{ releasedCount: number }> {
    const trips = await this.tripModel.find({ 'seatCounts.locked': { $gt: 0 } }).exec();
    let count = 0;
    for (const t of trips) {
      const held = t.seatCounts.locked;
      if (held > 0) {
        t.seatCounts.locked = 0;
        t.seatCounts.available += held;
        await t.save();
        count += held;
      }
    }
    return { releasedCount: count };
  }
}
