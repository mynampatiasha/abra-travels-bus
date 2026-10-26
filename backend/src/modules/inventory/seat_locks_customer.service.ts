import { randomUUID } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';

/*
 * Seat map and seat hold of a trip, for customers (documentation/seat-locking.md).
 *
 * The hold lives in MongoDB, in the same row as the seat, and is taken with one conditional update
 * per seat inside a transaction: two customers asking for the same seat can never both win. A hold
 * that has run out counts as free at once (lazy expiry); the expiry job in the worker only tidies
 * the rows and the counters. Redis is not needed for correctness.
 */

/** 10 minutes, as in the demo. */
export const SEAT_HOLD_SECONDS = 600;
/** At most this many seats in one hold. */
export const MAX_SEATS_PER_HOLD = 6;

export const SEAT_LOCK_GROUP_MODEL = 'SeatLockGroup';
export const LOCK_GROUP_STATUSES = ['ACTIVE', 'RELEASED', 'EXPIRED', 'CONSUMED'] as const;
export type LockGroupStatus = (typeof LOCK_GROUP_STATUSES)[number];

export interface SeatLockGroup {
  lockId: string;
  tripId: Types.ObjectId;
  holderId: Types.ObjectId;
  seatNumbers: string[];
  boardingPointId?: string;
  droppingPointId?: string;
  status: LockGroupStatus;
  expiresAt: Date;
  idempotencyKey?: string | undefined;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `seat_lock_groups`: one row per hold, so a hold can be found, released or expired as a whole. */
export const seatLockGroupSchema = new Schema<SeatLockGroup>(
  {
    lockId: { type: String, required: true },
    tripId: { type: Schema.Types.ObjectId, required: true },
    holderId: { type: Schema.Types.ObjectId, required: true },
    seatNumbers: { type: [String], required: true },
    boardingPointId: { type: String },
    droppingPointId: { type: String },
    status: { type: String, enum: LOCK_GROUP_STATUSES, required: true, default: 'ACTIVE' },
    expiresAt: { type: Date, required: true },
    idempotencyKey: { type: String },
  },
  { collection: 'seat_lock_groups', timestamps: true, versionKey: false },
);
seatLockGroupSchema.index({ lockId: 1 }, { unique: true });
seatLockGroupSchema.index({ tripId: 1, holderId: 1, status: 1 });
seatLockGroupSchema.index({ status: 1, expiresAt: 1 });
seatLockGroupSchema.index(
  { holderId: 1, idempotencyKey: 1 },
  { unique: true, partialFilterExpression: { idempotencyKey: { $type: 'string' } } },
);

// ===== Views =====

export type SeatMapStatus = 'AVAILABLE' | 'BOOKED' | 'LADIES_ONLY' | 'BLOCKED';

export interface SeatView {
  id: string;
  deck: 'LOWER' | 'UPPER';
  row: number;
  column: number;
  status: SeatMapStatus;
  farePaise: number;
}

export interface SeatMapView {
  tripId: string;
  berthType: string;
  /** The aisle runs between this column and the next. */
  aisleAfterColumn: number;
  seats: SeatView[];
}

export interface SeatLockView {
  lockId: string;
  tripId: string;
  seatIds: string[];
  expiresAt: string;
  holdSeconds: number;
}

interface TripRow {
  _id: Types.ObjectId;
  status: string;
  departureAt: Date;
  bus?: { berthType?: string };
  boardingPoints?: Array<{ pointId: Types.ObjectId }>;
  droppingPoints?: Array<{ pointId: Types.ObjectId }>;
}

interface SeatRow {
  _id: Types.ObjectId;
  tripId: Types.ObjectId;
  seatNumber: string;
  deck?: 'LOWER' | 'UPPER';
  seatType?: string;
  status: 'AVAILABLE' | 'BLOCKED' | 'LOCKED' | 'BOOKED';
  pricePaise: number;
  lock?: { lockId: string; holderId: Types.ObjectId; expiresAt: Date } | null;
}

const ON_SALE_STATUSES = ['SCHEDULED', 'BOARDING'];

/** "2", "10", "A1" in the order a person reads them. */
function naturalOrder(a: string, b: string): number {
  return a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' });
}

function isSleeper(berthType: string | undefined): boolean {
  return (berthType ?? '').toUpperCase().includes('SLEEPER');
}

/** Rows and columns of the seats, front to back, when the layout does not say (2 + 2, or 2 + 1 per deck). */
export function placeSeats(seats: readonly SeatRow[], berthType: string | undefined): SeatView[] {
  const sleeper = isSleeper(berthType);
  const sorted = [...seats].sort((a, b) => naturalOrder(a.seatNumber, b.seatNumber));
  const perRow = sleeper ? 3 : 4;
  const hasUpperDeck = sorted.some((seat) => seat.deck === 'UPPER');
  const lowerCount = hasUpperDeck || !sleeper ? 0 : Math.ceil(sorted.length / 2);
  const decks = { LOWER: 0, UPPER: 0 };
  return sorted.map((seat, index) => {
    const deck: 'LOWER' | 'UPPER' = hasUpperDeck
      ? seat.deck === 'UPPER'
        ? 'UPPER'
        : 'LOWER'
      : sleeper && index >= lowerCount
        ? 'UPPER'
        : 'LOWER';
    const position = decks[deck]++;
    const now = new Date();
    const taken =
      seat.status === 'BOOKED' ||
      (seat.status === 'LOCKED' && seat.lock != null && seat.lock.expiresAt > now);
    const status: SeatMapStatus = seat.status === 'BLOCKED' ? 'BLOCKED' : taken ? 'BOOKED' : 'AVAILABLE';
    return {
      id: seat.seatNumber,
      deck,
      row: Math.floor(position / perRow),
      column: position % perRow,
      status,
      farePaise: seat.pricePaise,
    };
  });
}

@Injectable()
export class SeatLocksService {
  private readonly logger = new Logger(SeatLocksService.name);

  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(SEAT_LOCK_GROUP_MODEL) private readonly groups: Model<SeatLockGroup>,
    private readonly transactions: TransactionRunner,
  ) {}

  private trips() {
    return this.connection.collection<TripRow>('trips');
  }

  private seats() {
    return this.connection.collection<SeatRow>('seat_inventory');
  }

  private objectId(id: string, what: string): Types.ObjectId {
    if (!Types.ObjectId.isValid(id)) throw new ApiException('RESOURCE_NOT_FOUND', `${what} not found`);
    return new Types.ObjectId(id);
  }

  private async tripOnSale(tripId: Types.ObjectId, session?: ClientSession): Promise<TripRow> {
    const trip = await this.trips().findOne(
      { _id: tripId },
      session ? { session } : undefined,
    );
    if (!trip || !ON_SALE_STATUSES.includes(trip.status) || trip.departureAt <= new Date()) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'This trip is not on sale.');
    }
    return trip;
  }

  // ----- the seat map (public) -----

  async seatMap(tripIdText: string): Promise<SeatMapView> {
    const tripId = this.objectId(tripIdText, 'Trip');
    const trip = await this.tripOnSale(tripId);
    const rows = await this.seats().find({ tripId }).toArray();
    const berthType = trip.bus?.berthType ?? 'SEATER';
    return {
      tripId: tripId.toHexString(),
      berthType,
      aisleAfterColumn: 1,
      seats: placeSeats(rows, berthType),
    };
  }

  // ----- the hold -----

  /** Counts of a trip, from the seats themselves (a hold that has run out counts as free). */
  async recount(tripId: Types.ObjectId, session?: ClientSession): Promise<void> {
    const now = new Date();
    const rows = await this.seats()
      .find({ tripId }, session ? { session, projection: { status: 1, lock: 1 } } : { projection: { status: 1, lock: 1 } })
      .toArray();
    const counts = { total: rows.length, available: 0, locked: 0, booked: 0, blocked: 0 };
    for (const row of rows) {
      if (row.status === 'BOOKED') counts.booked++;
      else if (row.status === 'BLOCKED') counts.blocked++;
      else if (row.status === 'LOCKED' && row.lock && row.lock.expiresAt > now) counts.locked++;
      else counts.available++;
    }
    await this.trips().updateOne({ _id: tripId }, { $set: { seatCounts: counts } }, session ? { session } : undefined);
  }

  private view(group: SeatLockGroup): SeatLockView {
    return {
      lockId: group.lockId,
      tripId: group.tripId.toHexString(),
      seatIds: group.seatNumbers,
      expiresAt: group.expiresAt.toISOString(),
      holdSeconds: SEAT_HOLD_SECONDS,
    };
  }

  async lock(
    actor: AuthenticatedUserActor,
    tripIdText: string,
    input: { seatIds: string[]; boardingPointId?: string | undefined; droppingPointId?: string | undefined },
    idempotencyKey?: string,
  ): Promise<SeatLockView> {
    if (actor.userType !== 'CUSTOMER') {
      throw new ApiException('PERMISSION_DENIED', 'Only a customer account can hold seats.');
    }
    const tripId = this.objectId(tripIdText, 'Trip');
    const holderId = new Types.ObjectId(actor.userId);
    const seatNumbers = [...new Set(input.seatIds.map((id) => id.trim()).filter((id) => id !== ''))].sort(
      naturalOrder,
    );
    if (seatNumbers.length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Choose at least one seat.');
    }
    if (seatNumbers.length > MAX_SEATS_PER_HOLD) {
      throw new ApiException('VALIDATION_FAILED', `You can hold at most ${MAX_SEATS_PER_HOLD} seats at a time.`);
    }

    // The same request sent twice gives the same hold
    if (idempotencyKey) {
      const earlier = await this.groups.findOne({ holderId, idempotencyKey }).lean<SeatLockGroup>().exec();
      if (earlier && earlier.tripId.equals(tripId) && earlier.status === 'ACTIVE' && earlier.expiresAt > new Date()) {
        return this.view(earlier);
      }
    }

    const trip = await this.tripOnSale(tripId);
    const boardingOk = (trip.boardingPoints ?? []).length === 0 ||
      (trip.boardingPoints ?? []).some((point) => point.pointId.toHexString() === input.boardingPointId);
    const droppingOk = (trip.droppingPoints ?? []).length === 0 ||
      (trip.droppingPoints ?? []).some((point) => point.pointId.toHexString() === input.droppingPointId);
    if (!boardingOk) throw new ApiException('VALIDATION_FAILED', 'Choose a boarding point of this trip.');
    if (!droppingOk) throw new ApiException('VALIDATION_FAILED', 'Choose a dropping point of this trip.');

    const lockId = randomUUID();
    const expiresAt = new Date(Date.now() + SEAT_HOLD_SECONDS * 1000);

    const group = await this.transactions.run(async (session) => {
      const now = new Date();
      // Seats this customer already holds on this trip and does not ask for again go back on sale
      const previous = await this.groups
        .find({ tripId, holderId, status: 'ACTIVE' }, null, { session })
        .lean<SeatLockGroup[]>()
        .exec();
      for (const old of previous) {
        await this.seats().updateMany(
          { tripId, 'lock.lockId': old.lockId, seatNumber: { $nin: seatNumbers } },
          { $set: { status: 'AVAILABLE' }, $unset: { lock: '' } },
          { session },
        );
        await this.groups.updateOne(
          { lockId: old.lockId },
          { $set: { status: 'RELEASED' }, $unset: { idempotencyKey: '' } },
          { session },
        );
      }
      // An old hold with the same request key (expired) frees the key
      if (idempotencyKey) {
        await this.groups.updateMany(
          { holderId, idempotencyKey },
          { $unset: { idempotencyKey: '' } },
          { session },
        );
      }

      // One conditional update per seat, in a fixed order: a seat is taken only if it is free,
      // its hold has run out, or this same customer already holds it
      for (const seatNumber of seatNumbers) {
        const taken = await this.seats().findOneAndUpdate(
          {
            tripId,
            seatNumber,
            $or: [
              { status: 'AVAILABLE' },
              { status: 'LOCKED', 'lock.expiresAt': { $lte: now } },
              { status: 'LOCKED', 'lock.holderId': holderId },
            ],
          },
          {
            $set: { status: 'LOCKED', lock: { lockId, holderId, expiresAt }, updatedAt: now },
            $inc: { version: 1 },
          },
          { session, returnDocument: 'after' },
        );
        if (!taken) {
          throw new ApiException('SEAT_NOT_AVAILABLE', `Seat ${seatNumber} was just taken. Please choose another seat.`, {
            seatId: seatNumber,
          });
        }
      }

      const [created] = await this.groups.create(
        [
          {
            lockId,
            tripId,
            holderId,
            seatNumbers,
            ...(input.boardingPointId ? { boardingPointId: input.boardingPointId } : {}),
            ...(input.droppingPointId ? { droppingPointId: input.droppingPointId } : {}),
            status: 'ACTIVE',
            expiresAt,
            ...(idempotencyKey ? { idempotencyKey } : {}),
          },
        ],
        { session },
      );
      if (!created) throw new Error('The hold could not be saved');
      await this.recount(tripId, session);
      return created.toObject();
    });
    return this.view(group);
  }

  async release(actor: AuthenticatedUserActor, lockId: string): Promise<{ released: boolean }> {
    const holderId = new Types.ObjectId(actor.userId);
    const group = await this.groups.findOne({ lockId, holderId }).lean<SeatLockGroup>().exec();
    if (!group) throw new ApiException('RESOURCE_NOT_FOUND', 'Hold not found.');
    if (group.status !== 'ACTIVE') return { released: false };
    await this.transactions.run(async (session) => {
      await this.seats().updateMany(
        { tripId: group.tripId, 'lock.lockId': lockId },
        { $set: { status: 'AVAILABLE' }, $unset: { lock: '' } },
        { session },
      );
      await this.groups.updateOne(
        { lockId, status: 'ACTIVE' },
        { $set: { status: 'RELEASED' }, $unset: { idempotencyKey: '' } },
        { session },
      );
      await this.recount(group.tripId, session);
    });
    return { released: true };
  }

  /** The expiry job: puts the seats of holds that ran out back on sale and keeps the counters right. */
  async expireOverdue(now = new Date()): Promise<{ groups: number; seats: number }> {
    const overdue = await this.groups
      .find({ status: 'ACTIVE', expiresAt: { $lte: now } })
      .limit(500)
      .lean<SeatLockGroup[]>()
      .exec();
    let seats = 0;
    const tripIds = new Map<string, Types.ObjectId>();
    for (const group of overdue) {
      try {
        await this.transactions.run(async (session) => {
          const result = await this.seats().updateMany(
            { tripId: group.tripId, status: 'LOCKED', 'lock.lockId': group.lockId, 'lock.expiresAt': { $lte: now } },
            { $set: { status: 'AVAILABLE' }, $unset: { lock: '' } },
            { session },
          );
          seats += result.modifiedCount;
          await this.groups.updateOne(
            { lockId: group.lockId, status: 'ACTIVE' },
            { $set: { status: 'EXPIRED' }, $unset: { idempotencyKey: '' } },
            { session },
          );
          await this.recount(group.tripId, session);
        });
        tripIds.set(group.tripId.toHexString(), group.tripId);
      } catch (error) {
        this.logger.warn(
          { lockId: group.lockId, message: error instanceof Error ? error.message : 'unknown' },
          'A seat hold could not be expired; it will be tried again',
        );
      }
    }
    return { groups: overdue.length, seats };
  }
}
