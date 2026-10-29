import { randomBytes } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { CouponsService } from '../coupons/coupons.service';
import { computeFare } from './booking_pricing';

/*
 * A booking for held seats (documentation/state-machines.md section 3). The customer sends the hold
 * and the passengers; the server reads the seat prices itself, so the amount can never be set by
 * the app. The booking waits in PAYMENT_PENDING for the payment (next step); the seats stay held
 * until the hold runs out.
 */

export const BOOKING_MODEL = 'Booking';
export const BOOKING_STATUSES = [
  'INITIATED',
  'SEAT_LOCKED',
  'PAYMENT_PENDING',
  'CONFIRMED',
  'FAILED',
  'EXPIRED',
  'PARTIALLY_CANCELLED',
  'CANCELLED',
  'REFUND_PENDING',
  'REFUNDED',
  'COMPLETED',
] as const;
export type BookingStatus = (typeof BOOKING_STATUSES)[number];

export interface BookingPassenger {
  seatId: string;
  name: string;
  age: number;
  gender: 'MALE' | 'FEMALE' | 'OTHER';
  farePaise: number;
}

export interface BookingRow {
  customerId: Types.ObjectId;
  tripId: Types.ObjectId;
  operatorId?: Types.ObjectId;
  lockId: string;
  status: BookingStatus;
  pnr: string;
  passengers: BookingPassenger[];
  contact: { mobile: string; email: string };
  gst?: { gstin: string; company: string };
  boardingPointId?: string;
  droppingPointId?: string;
  couponCode?: string;
  baseFarePaise: number;
  gstPaise: number;
  convenienceFeePaise: number;
  discountPaise: number;
  amountPaise: number;
  currency: string;
  holdExpiresAt: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

const passengerSchema = new Schema<BookingPassenger>(
  {
    seatId: { type: String, required: true },
    name: { type: String, required: true },
    age: { type: Number, required: true },
    gender: { type: String, enum: ['MALE', 'FEMALE', 'OTHER'], required: true },
    farePaise: { type: Number, required: true },
  },
  { _id: false },
);

/** `bookings`: one row per booking. One booking per hold (unique lockId) makes creating it idempotent. */
export const bookingSchema = new Schema<BookingRow>(
  {
    customerId: { type: Schema.Types.ObjectId, required: true },
    tripId: { type: Schema.Types.ObjectId, required: true },
    operatorId: { type: Schema.Types.ObjectId },
    lockId: { type: String, required: true },
    status: { type: String, enum: BOOKING_STATUSES, required: true },
    pnr: { type: String, required: true },
    passengers: { type: [passengerSchema], required: true },
    contact: { mobile: { type: String, required: true }, email: { type: String, required: true } },
    gst: { gstin: { type: String }, company: { type: String } },
    boardingPointId: { type: String },
    droppingPointId: { type: String },
    couponCode: { type: String },
    baseFarePaise: { type: Number, required: true },
    gstPaise: { type: Number, required: true, default: 0 },
    convenienceFeePaise: { type: Number, required: true, default: 0 },
    discountPaise: { type: Number, required: true, default: 0 },
    amountPaise: { type: Number, required: true },
    currency: { type: String, required: true, default: 'INR' },
    holdExpiresAt: { type: Date, required: true },
  },
  { collection: 'bookings', timestamps: true, versionKey: false },
);
bookingSchema.index({ lockId: 1 }, { unique: true });
bookingSchema.index({ pnr: 1 }, { unique: true });
bookingSchema.index({ customerId: 1, createdAt: -1 });
bookingSchema.index({ tripId: 1, status: 1 });

export interface CreateBookingInput {
  lockId: string;
  passengers: Array<{ seatId: string; name: string; age: number; gender: 'MALE' | 'FEMALE' | 'OTHER' }>;
  contact: { mobile: string; email: string };
  gst?: { gstin: string; company: string } | undefined;
  couponCode?: string | undefined;
  expectedAmountPaise?: number | undefined;
}

export interface BookingView {
  bookingId: string;
  pnr: string;
  status: BookingStatus;
  tripId: string;
  seatIds: string[];
  baseFarePaise: number;
  gstPaise: number;
  convenienceFeePaise: number;
  discountPaise: number;
  amountPaise: number;
  currency: string;
  holdExpiresAt: string;
}

interface LockGroupRow {
  lockId: string;
  tripId: Types.ObjectId;
  holderId: Types.ObjectId;
  seatNumbers: string[];
  boardingPointId?: string;
  droppingPointId?: string;
  status: string;
  expiresAt: Date;
}

interface SeatRow {
  seatNumber: string;
  status: string;
  pricePaise: number;
  operatorId?: Types.ObjectId;
  lock?: { lockId: string; holderId: Types.ObjectId; expiresAt: Date } | null;
}

const PNR_LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** "ABR" and 7 letters or digits, without the easily mixed ones (0 O 1 I). */
export function newPnr(): string {
  const bytes = randomBytes(7);
  let out = 'ABR';
  for (const byte of bytes) out += PNR_LETTERS[byte % PNR_LETTERS.length];
  return out;
}

@Injectable()
export class BookingsCustomerService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(BOOKING_MODEL) private readonly bookings: Model<BookingRow>,
    private readonly transactions: TransactionRunner,
    private readonly coupons: CouponsService,
  ) {}

  private view(row: BookingRow & { _id: Types.ObjectId }): BookingView {
    return {
      bookingId: row._id.toHexString(),
      pnr: row.pnr,
      status: row.status,
      tripId: row.tripId.toHexString(),
      seatIds: row.passengers.map((p) => p.seatId),
      baseFarePaise: row.baseFarePaise,
      gstPaise: row.gstPaise ?? 0,
      convenienceFeePaise: row.convenienceFeePaise ?? 0,
      discountPaise: row.discountPaise,
      amountPaise: row.amountPaise,
      currency: row.currency,
      holdExpiresAt: row.holdExpiresAt.toISOString(),
    };
  }

  async create(actor: AuthenticatedUserActor, input: CreateBookingInput): Promise<BookingView> {
    if (actor.userType !== 'CUSTOMER') {
      throw new ApiException('PERMISSION_DENIED', 'Only a customer account can book seats.');
    }
    const customerId = new Types.ObjectId(actor.userId);

    // The same hold gives the same booking, so a repeated tap or a retry never books twice
    const earlier = await this.bookings.findOne({ lockId: input.lockId, customerId }).lean<BookingRow & { _id: Types.ObjectId }>().exec();
    if (earlier) return this.view(earlier);

    const group = await this.connection
      .collection<LockGroupRow>('seat_lock_groups')
      .findOne({ lockId: input.lockId, holderId: customerId });
    if (!group) throw new ApiException('RESOURCE_NOT_FOUND', 'Seat hold not found.');
    if (group.status !== 'ACTIVE' || group.expiresAt <= new Date()) {
      throw new ApiException('SEAT_LOCK_EXPIRED', 'Your seat hold ran out. Please choose your seats again.');
    }

    // One passenger for each held seat, no more and no fewer
    const seatIds = input.passengers.map((p) => p.seatId);
    const held = [...group.seatNumbers].sort();
    if (new Set(seatIds).size !== seatIds.length || [...seatIds].sort().join('|') !== held.join('|')) {
      throw new ApiException('VALIDATION_FAILED', 'Give one passenger for each held seat.', { seats: held });
    }

    // The prices come from the seats the customer still holds
    const seatRows = await this.connection
      .collection<SeatRow>('seat_inventory')
      .find({ tripId: group.tripId, 'lock.lockId': group.lockId })
      .toArray();
    const priceOf = new Map(seatRows.map((row) => [row.seatNumber, row.pricePaise]));
    if (held.some((seat) => !priceOf.has(seat))) {
      throw new ApiException('SEAT_LOCK_EXPIRED', 'Your seat hold ran out. Please choose your seats again.');
    }
    const passengers: BookingPassenger[] = input.passengers.map((p) => ({
      seatId: p.seatId,
      name: p.name,
      age: p.age,
      gender: p.gender,
      farePaise: priceOf.get(p.seatId) ?? 0,
    }));
    const baseFarePaise = passengers.reduce((sum, p) => sum + p.farePaise, 0);
    // The discount is worked out here from the coupon, never taken from the app
    let discountPaise = 0;
    if (input.couponCode) {
      const check = await this.coupons.check(customerId, group.tripId.toHexString(), input.couponCode, baseFarePaise);
      if (!check.valid) throw new ApiException('COUPON_INVALID', check.reason ?? 'This code is not valid.');
      discountPaise = check.discountPaise;
    }
    const fare = computeFare(baseFarePaise, discountPaise);
    const amountPaise = fare.amountPaise;
    if (input.expectedAmountPaise !== undefined && input.expectedAmountPaise !== amountPaise) {
      throw new ApiException('PAYMENT_AMOUNT_MISMATCH', 'The price changed. Please check the new amount.', {
        amountPaise,
      });
    }

    const operatorId = seatRows.find((row) => row.operatorId)?.operatorId;
    const created = await this.transactions.run(async (session) => {
      const [row] = await this.bookings.create(
        [
          {
            customerId,
            tripId: group.tripId,
            ...(operatorId ? { operatorId } : {}),
            lockId: group.lockId,
            status: 'PAYMENT_PENDING',
            pnr: newPnr(),
            passengers,
            contact: input.contact,
            ...(input.gst ? { gst: input.gst } : {}),
            ...(group.boardingPointId ? { boardingPointId: group.boardingPointId } : {}),
            ...(group.droppingPointId ? { droppingPointId: group.droppingPointId } : {}),
            ...(input.couponCode ? { couponCode: input.couponCode } : {}),
            baseFarePaise,
            gstPaise: fare.gstPaise,
            convenienceFeePaise: fare.convenienceFeePaise,
            discountPaise: fare.discountPaise,
            amountPaise,
            currency: 'INR',
            holdExpiresAt: group.expiresAt,
          },
        ],
        { session },
      );
      if (!row) throw new Error('The booking could not be saved');
      if (input.couponCode) await this.coupons.reserve(customerId, row._id, input.couponCode, session);
      return row.toObject() as BookingRow & { _id: Types.ObjectId };
    });
    return this.view(created);
  }

  async read(actor: AuthenticatedUserActor, bookingId: string): Promise<BookingView> {
    if (!Types.ObjectId.isValid(bookingId)) throw new ApiException('RESOURCE_NOT_FOUND', 'Booking not found.');
    const row = await this.bookings
      .findOne({ _id: new Types.ObjectId(bookingId), customerId: new Types.ObjectId(actor.userId) })
      .lean<BookingRow & { _id: Types.ObjectId }>()
      .exec();
    if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'Booking not found.');
    return this.view(row);
  }
}
