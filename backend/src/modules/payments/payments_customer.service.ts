import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { BOOKING_MODEL, type BookingRow } from '../bookings/bookings_customer.service';
import { SeatLocksService } from '../inventory/seat_locks_customer.service';
import { PAYMENT_GATEWAY, type PaymentGateway } from './payment_gateway';

/*
 * Paying for a booking (documentation/payment-flow.md). handlePaid is the only place that marks a
 * payment SUCCESS and confirms the booking: it needs a good signature, the right amount and a
 * payment that was not already handled. When the payment fails, or the hold runs out, the seats go
 * back on sale and the coupon use is given back.
 */

export const PAYMENT_MODEL = 'Payment';
export const PAYMENT_STATUSES = ['CREATED', 'SUCCESS', 'FAILED'] as const;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

export interface PaymentRow {
  bookingId: Types.ObjectId;
  customerId: Types.ObjectId;
  gateway: string;
  gatewayOrderId: string;
  keyId: string;
  gatewayPaymentId?: string;
  amountPaise: number;
  currency: string;
  status: PaymentStatus;
  failureReason?: string;
  /** Set when money was taken but the seats could not be kept: the customer is owed a refund. */
  refundDue?: 'LOCK_EXPIRED_AFTER_PAYMENT';
  paidAt?: Date;
  createdAt?: Date;
}

export const paymentSchema = new Schema<PaymentRow>(
  {
    bookingId: { type: Schema.Types.ObjectId, required: true },
    customerId: { type: Schema.Types.ObjectId, required: true },
    gateway: { type: String, required: true },
    gatewayOrderId: { type: String, required: true },
    keyId: { type: String, required: true },
    gatewayPaymentId: { type: String },
    amountPaise: { type: Number, required: true },
    currency: { type: String, required: true },
    status: { type: String, enum: PAYMENT_STATUSES, required: true },
    failureReason: { type: String },
    refundDue: { type: String },
    paidAt: { type: Date },
  },
  { collection: 'payments', timestamps: true, versionKey: false },
);
paymentSchema.index({ gatewayOrderId: 1 }, { unique: true });
paymentSchema.index({ bookingId: 1, status: 1 });
paymentSchema.index(
  { gatewayPaymentId: 1 },
  { unique: true, partialFilterExpression: { gatewayPaymentId: { $type: 'string' } } },
);

export interface PaymentOrderView {
  paymentId: string;
  bookingId: string;
  gateway: string;
  gatewayOrderId: string;
  keyId: string;
  amountPaise: number;
  currency: string;
}

export interface PaymentResultView {
  paymentId: string;
  status: PaymentStatus;
  bookingStatus: string;
  /** Money was taken but the seats were lost: a refund is due. */
  refundDue: boolean;
}

type BookingDoc = BookingRow & { _id: Types.ObjectId };
type PaymentDoc = PaymentRow & { _id: Types.ObjectId };

class SeatsLost extends Error {}

@Injectable()
export class PaymentsCustomerService {
  private readonly logger = new Logger(PaymentsCustomerService.name);

  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(PAYMENT_MODEL) private readonly payments: Model<PaymentRow>,
    @InjectModel(BOOKING_MODEL) private readonly bookings: Model<BookingRow>,
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
    private readonly transactions: TransactionRunner,
    private readonly seatLocks: SeatLocksService,
  ) {}

  private seats() {
    return this.connection.collection('seat_inventory');
  }

  private objectId(id: string, what: string): Types.ObjectId {
    if (!Types.ObjectId.isValid(id)) throw new ApiException('RESOURCE_NOT_FOUND', `${what} not found`);
    return new Types.ObjectId(id);
  }

  private async ownPayment(actor: AuthenticatedUserActor, paymentId: string): Promise<PaymentDoc> {
    const row = await this.payments
      .findOne({ _id: this.objectId(paymentId, 'Payment'), customerId: new Types.ObjectId(actor.userId) })
      .lean<PaymentDoc>()
      .exec();
    if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'Payment not found.');
    return row;
  }

  private orderView(payment: PaymentDoc): PaymentOrderView {
    return {
      paymentId: payment._id.toHexString(),
      bookingId: payment.bookingId.toHexString(),
      gateway: payment.gateway,
      gatewayOrderId: payment.gatewayOrderId,
      keyId: payment.keyId,
      amountPaise: payment.amountPaise,
      currency: payment.currency,
    };
  }

  // ----- order -----

  /** The order to pay for a booking. Asking again while one is open gives the same order. */
  async createOrder(actor: AuthenticatedUserActor, bookingIdText: string): Promise<PaymentOrderView> {
    if (actor.userType !== 'CUSTOMER') {
      throw new ApiException('PERMISSION_DENIED', 'Only a customer account can pay for a booking.');
    }
    const customerId = new Types.ObjectId(actor.userId);
    const booking = await this.bookings
      .findOne({ _id: this.objectId(bookingIdText, 'Booking'), customerId })
      .lean<BookingDoc>()
      .exec();
    if (!booking) throw new ApiException('RESOURCE_NOT_FOUND', 'Booking not found.');
    if (booking.status !== 'PAYMENT_PENDING') {
      throw new ApiException('INVALID_STATE_TRANSITION', `This booking is ${booking.status.toLowerCase()} and cannot be paid.`);
    }
    if (booking.holdExpiresAt <= new Date()) {
      throw new ApiException('SEAT_LOCK_EXPIRED', 'Your seat hold ran out. Please choose your seats again.');
    }
    const open = await this.payments.findOne({ bookingId: booking._id, status: 'CREATED' }).lean<PaymentDoc>().exec();
    if (open) return this.orderView(open);

    const order = await this.gateway.createOrder({
      amountPaise: booking.amountPaise,
      currency: booking.currency,
      receipt: booking.pnr,
    });
    const created = await this.payments.create({
      bookingId: booking._id,
      customerId,
      gateway: this.gateway.key,
      gatewayOrderId: order.gatewayOrderId,
      keyId: order.keyId,
      amountPaise: booking.amountPaise,
      currency: booking.currency,
      status: 'CREATED',
    });
    return this.orderView(created.toObject() as PaymentDoc);
  }

  // ----- paid -----

  /** The app says it paid: the signature proves it. */
  async clientCallback(
    actor: AuthenticatedUserActor,
    paymentId: string,
    input: { gatewayPaymentId: string; signature: string },
  ): Promise<PaymentResultView> {
    const payment = await this.ownPayment(actor, paymentId);
    if (!this.gateway.verifyPaymentSignature(payment.gatewayOrderId, input.gatewayPaymentId, input.signature)) {
      throw new ApiException('VALIDATION_FAILED', 'The payment could not be verified.');
    }
    return this.handlePaid(payment._id, input.gatewayPaymentId);
  }

  /** Development gateway only: finish the test payment as paid or failed, through the same checks. */
  async developmentComplete(
    actor: AuthenticatedUserActor,
    paymentId: string,
    outcome: 'success' | 'failure',
  ): Promise<PaymentResultView> {
    if (this.gateway.key !== 'development' || !this.gateway.signForDevelopment) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Not found.');
    }
    const payment = await this.ownPayment(actor, paymentId);
    if (outcome === 'failure') return this.handleFailed(payment._id, 'DECLINED');
    const gatewayPaymentId = `dev_pay_${payment._id.toHexString()}`;
    const signature = this.gateway.signForDevelopment(payment.gatewayOrderId, gatewayPaymentId);
    return this.clientCallback(actor, paymentId, { gatewayPaymentId, signature });
  }

  /** The app says the payment failed or was cancelled. */
  async clientFailed(actor: AuthenticatedUserActor, paymentId: string, reason: string): Promise<PaymentResultView> {
    const payment = await this.ownPayment(actor, paymentId);
    return this.handleFailed(payment._id, reason);
  }

  private async result(paymentId: Types.ObjectId): Promise<PaymentResultView> {
    const payment = await this.payments.findById(paymentId).lean<PaymentDoc>().exec();
    if (!payment) throw new ApiException('RESOURCE_NOT_FOUND', 'Payment not found.');
    const booking = await this.bookings.findById(payment.bookingId).lean<BookingDoc>().exec();
    return {
      paymentId: paymentId.toHexString(),
      status: payment.status,
      bookingStatus: booking?.status ?? 'UNKNOWN',
      refundDue: payment.refundDue !== undefined,
    };
  }

  /** The one place a payment becomes SUCCESS and the booking CONFIRMED. */
  async handlePaid(paymentId: Types.ObjectId, gatewayPaymentId: string): Promise<PaymentResultView> {
    const payment = await this.payments.findById(paymentId).lean<PaymentDoc>().exec();
    if (!payment) throw new ApiException('RESOURCE_NOT_FOUND', 'Payment not found.');
    // Already handled: the webhook and the app can both report the same payment
    if (payment.status !== 'CREATED') return this.result(paymentId);

    const booking = await this.bookings.findById(payment.bookingId).lean<BookingDoc>().exec();
    if (!booking) throw new ApiException('RESOURCE_NOT_FOUND', 'Booking not found.');
    if (payment.amountPaise !== booking.amountPaise || payment.currency !== booking.currency) {
      await this.payments.updateOne({ _id: paymentId, status: 'CREATED' }, { $set: { status: 'FAILED', failureReason: 'AMOUNT_MISMATCH', gatewayPaymentId } });
      throw new ApiException('PAYMENT_AMOUNT_MISMATCH', 'The amount paid does not match the booking.');
    }

    try {
      await this.transactions.run(async (session) => {
        // Only one caller moves the payment out of CREATED
        const claimed = await this.payments.findOneAndUpdate(
          { _id: paymentId, status: 'CREATED' },
          { $set: { status: 'SUCCESS', gatewayPaymentId, paidAt: new Date() } },
          { session },
        );
        if (!claimed) return;
        await this.takeSeats(booking, session);
        await this.bookings.updateOne({ _id: booking._id }, { $set: { status: 'CONFIRMED' } }, { session });
        await this.connection
          .collection('seat_lock_groups')
          .updateOne({ lockId: booking.lockId }, { $set: { status: 'CONSUMED' }, $unset: { idempotencyKey: '' } }, { session });
        await this.connection
          .collection('coupon_redemptions')
          .updateOne({ bookingId: booking._id, status: 'RESERVED' }, { $set: { status: 'REDEEMED' } }, { session });
        await this.seatLocks.recount(booking.tripId, session);
      });
    } catch (error) {
      if (!(error instanceof SeatsLost)) throw error;
      // The money was taken but another customer has the seats: keep the facts, owe a refund
      await this.payments.updateOne(
        { _id: paymentId, status: 'CREATED' },
        { $set: { status: 'SUCCESS', gatewayPaymentId, paidAt: new Date(), refundDue: 'LOCK_EXPIRED_AFTER_PAYMENT' } },
      );
      await this.release(booking._id, 'EXPIRED');
    }
    return this.result(paymentId);
  }

  /** Seats LOCKED by this booking's hold become BOOKED. A hold that ran out may be taken again if the seats are still free. */
  private async takeSeats(booking: BookingDoc, session: ClientSession): Promise<void> {
    if (!['PAYMENT_PENDING', 'EXPIRED'].includes(booking.status)) throw new SeatsLost();
    const numbers = booking.passengers.map((p) => p.seatId);
    const now = new Date();
    const result = await this.seats().updateMany(
      {
        tripId: booking.tripId,
        seatNumber: { $in: numbers },
        $or: [
          { status: 'LOCKED', 'lock.lockId': booking.lockId },
          { status: 'AVAILABLE' },
          { status: 'LOCKED', 'lock.expiresAt': { $lte: now } },
        ],
      },
      { $set: { status: 'BOOKED', bookingId: booking._id, updatedAt: now }, $unset: { lock: '' }, $inc: { version: 1 } },
      { session },
    );
    if (result.modifiedCount !== numbers.length) throw new SeatsLost();
  }

  async handleFailed(paymentId: Types.ObjectId, reason: string): Promise<PaymentResultView> {
    const payment = await this.payments.findById(paymentId).lean<PaymentDoc>().exec();
    if (!payment) throw new ApiException('RESOURCE_NOT_FOUND', 'Payment not found.');
    if (payment.status === 'CREATED') {
      await this.payments.updateOne({ _id: paymentId, status: 'CREATED' }, { $set: { status: 'FAILED', failureReason: reason.slice(0, 80) } });
      await this.release(payment.bookingId, 'FAILED');
    }
    return this.result(paymentId);
  }

  /**
   * Gives everything a booking held back: the seats, the hold and the coupon use. Only a booking
   * that is still waiting for payment is released, so a confirmed booking is never touched.
   */
  async release(bookingId: Types.ObjectId, status: 'FAILED' | 'EXPIRED'): Promise<boolean> {
    return this.transactions.run(async (session) => {
      const booking = await this.bookings
        .findOneAndUpdate({ _id: bookingId, status: 'PAYMENT_PENDING' }, { $set: { status } }, { session, new: true })
        .lean<BookingDoc>()
        .exec();
      if (!booking) return false;
      await this.seats().updateMany(
        { tripId: booking.tripId, 'lock.lockId': booking.lockId },
        { $set: { status: 'AVAILABLE' }, $unset: { lock: '' } },
        { session },
      );
      await this.connection
        .collection('seat_lock_groups')
        .updateOne({ lockId: booking.lockId, status: 'ACTIVE' }, { $set: { status: 'RELEASED' }, $unset: { idempotencyKey: '' } }, { session });
      const redemption = await this.connection
        .collection('coupon_redemptions')
        .findOneAndUpdate({ bookingId, status: 'RESERVED' }, { $set: { status: 'RELEASED' } }, { session });
      if (redemption) {
        await this.connection.collection('coupons').updateOne({ _id: redemption.couponId }, { $inc: { usedCount: -1 } }, { session });
      }
      // An expired booking keeps its open payment: a payment that still arrives is handled as a late payment
      if (status === 'FAILED') {
        await this.payments.updateMany({ bookingId, status: 'CREATED' }, { $set: { status: 'FAILED', failureReason: status } }, { session });
      }
      await this.seatLocks.recount(booking.tripId, session);
      return true;
    });
  }

  /** The expiry job: bookings whose hold ran out without a payment give their seats and coupon back. */
  async expireUnpaid(now = new Date()): Promise<{ bookings: number }> {
    const overdue = await this.bookings
      .find({ status: 'PAYMENT_PENDING', holdExpiresAt: { $lte: now } })
      .limit(200)
      .lean<BookingDoc[]>()
      .exec();
    let released = 0;
    for (const booking of overdue) {
      try {
        if (await this.release(booking._id, 'EXPIRED')) released++;
      } catch (error) {
        this.logger.warn(
          { bookingId: booking._id.toHexString(), message: error instanceof Error ? error.message : 'unknown' },
          'An unpaid booking could not be released; it will be tried again',
        );
      }
    }
    return { bookings: released };
  }
}
