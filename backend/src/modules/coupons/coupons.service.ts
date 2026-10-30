import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';

/*
 * Coupons (documentation/database-architecture.md `coupons`, `coupon_redemptions`). Admin makes
 * them; a customer checks one against a trip and a base fare; the booking reserves it. The discount
 * is always calculated here, never taken from the app.
 */

export const COUPON_MODEL = 'Coupon';
export const COUPON_STATUSES = ['ACTIVE', 'PAUSED'] as const;
export type CouponStatus = (typeof COUPON_STATUSES)[number];
export const DISCOUNT_TYPES = ['PERCENT', 'FLAT'] as const;

export interface CouponRow {
  code: string;
  title: string;
  description?: string;
  discountType: (typeof DISCOUNT_TYPES)[number];
  /** Percent (1 to 100) or paise. */
  value: number;
  maxDiscountPaise?: number;
  minBookingPaise: number;
  /** All customers together; 0 means no limit. */
  usageLimit: number;
  perCustomerLimit: number;
  usedCount: number;
  /** Who pays for the discount. */
  fundedBy: 'ABRA' | 'OPERATOR';
  restrictions: { operatorIds: Types.ObjectId[]; routeIds: Types.ObjectId[]; newUsersOnly: boolean };
  startsAt: Date;
  endsAt: Date;
  status: CouponStatus;
  createdAt?: Date;
  updatedAt?: Date;
}

export const couponSchema = new Schema<CouponRow>(
  {
    code: { type: String, required: true, uppercase: true, trim: true },
    title: { type: String, required: true },
    description: { type: String },
    discountType: { type: String, enum: DISCOUNT_TYPES, required: true },
    value: { type: Number, required: true },
    maxDiscountPaise: { type: Number },
    minBookingPaise: { type: Number, required: true, default: 0 },
    usageLimit: { type: Number, required: true, default: 0 },
    perCustomerLimit: { type: Number, required: true, default: 1 },
    usedCount: { type: Number, required: true, default: 0 },
    fundedBy: { type: String, enum: ['ABRA', 'OPERATOR'], required: true, default: 'ABRA' },
    restrictions: {
      operatorIds: { type: [Schema.Types.ObjectId], default: [] },
      routeIds: { type: [Schema.Types.ObjectId], default: [] },
      newUsersOnly: { type: Boolean, default: false },
    },
    startsAt: { type: Date, required: true },
    endsAt: { type: Date, required: true },
    status: { type: String, enum: COUPON_STATUSES, required: true, default: 'ACTIVE' },
  },
  { collection: 'coupons', timestamps: true, versionKey: false },
);
couponSchema.index({ code: 1 }, { unique: true });
couponSchema.index({ status: 1, endsAt: 1 });

export interface CouponView {
  id: string;
  code: string;
  title: string;
  description: string;
  discountType: string;
  value: number;
  maxDiscountPaise: number | null;
  minBookingPaise: number;
  usageLimit: number;
  perCustomerLimit: number;
  usedCount: number;
  fundedBy: string;
  newUsersOnly: boolean;
  startsAt: string;
  endsAt: string;
  status: CouponStatus;
}

export interface CouponCheck {
  code: string;
  valid: boolean;
  discountPaise: number;
  /** Why not, in words for the customer. */
  reason?: string;
}

/** An offer as a guest sees it: the code, what it gives, until when, and the conditions. */
export interface PublicOfferView {
  code: string;
  title: string;
  description: string;
  validTill: string;
  terms: string[];
}

export interface CouponUpdate {
  title?: string | undefined;
  description?: string | undefined;
  value?: number | undefined;
  maxDiscountPaise?: number | undefined;
  minBookingPaise?: number | undefined;
  usageLimit?: number | undefined;
  perCustomerLimit?: number | undefined;
  fundedBy?: 'ABRA' | 'OPERATOR' | undefined;
  newUsersOnly?: boolean | undefined;
  startsAt?: Date | undefined;
  endsAt?: Date | undefined;
}

export interface CouponUsage {
  code: string;
  usedCount: number;
  reserved: number;
  redeemed: number;
  released: number;
  discountGivenPaise: number;
  items: Array<{ bookingId: string; pnr: string; customerName: string; customerPhone: string; discountPaise: number; status: string; at: string | null }>;
}

export interface CouponInput {
  code: string;
  title: string;
  description?: string | undefined;
  discountType: 'PERCENT' | 'FLAT';
  value: number;
  maxDiscountPaise?: number | undefined;
  minBookingPaise: number;
  usageLimit: number;
  perCustomerLimit: number;
  fundedBy: 'ABRA' | 'OPERATOR';
  operatorIds?: string[] | undefined;
  newUsersOnly: boolean;
  startsAt: Date;
  endsAt: Date;
}

/** The discount for a base fare: percent (capped) or flat, never more than the fare. */
export function discountFor(coupon: Pick<CouponRow, 'discountType' | 'value' | 'maxDiscountPaise'>, basePaise: number): number {
  const raw = coupon.discountType === 'PERCENT' ? Math.floor((basePaise * coupon.value) / 100) : coupon.value;
  const capped = coupon.maxDiscountPaise ? Math.min(raw, coupon.maxDiscountPaise) : raw;
  return Math.max(0, Math.min(capped, basePaise));
}

@Injectable()
export class CouponsService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(COUPON_MODEL) private readonly coupons: Model<CouponRow>,
    private readonly changes: AuditedChangeRunner,
  ) {}

  private view(row: CouponRow & { _id: Types.ObjectId }): CouponView {
    return {
      id: row._id.toHexString(),
      code: row.code,
      title: row.title,
      description: row.description ?? '',
      discountType: row.discountType,
      value: row.value,
      maxDiscountPaise: row.maxDiscountPaise ?? null,
      minBookingPaise: row.minBookingPaise,
      usageLimit: row.usageLimit,
      perCustomerLimit: row.perCustomerLimit,
      usedCount: row.usedCount,
      fundedBy: row.fundedBy,
      newUsersOnly: row.restrictions.newUsersOnly,
      startsAt: row.startsAt.toISOString(),
      endsAt: row.endsAt.toISOString(),
      status: row.status,
    };
  }

  private redemptions() {
    return this.connection.collection('coupon_redemptions');
  }

  // ----- admin -----

  async list(): Promise<CouponView[]> {
    const rows = await this.coupons.find().sort({ createdAt: -1 }).limit(500).lean<Array<CouponRow & { _id: Types.ObjectId }>>().exec();
    return rows.map((row) => this.view(row));
  }

  /** The coupons for the export and for a paged list: the same filters as the page. */
  async rows(filters: {
    search?: string | undefined;
    status?: CouponStatus | undefined;
    funder?: 'ABRA' | 'OPERATOR' | undefined;
    page: number;
    pageSize: number;
  }): Promise<PaginatedResult<CouponView>> {
    const where: Record<string, unknown> = {};
    if (filters.status) where.status = filters.status;
    if (filters.funder) where.fundedBy = filters.funder;
    const search = filters.search?.trim();
    if (search) {
      const like = new RegExp(search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
      where.$or = [{ code: like }, { title: like }, { description: like }];
    }
    const [rows, total] = await Promise.all([
      this.coupons
        .find(where)
        .sort({ createdAt: -1 })
        .skip((filters.page - 1) * filters.pageSize)
        .limit(filters.pageSize)
        .lean<Array<CouponRow & { _id: Types.ObjectId }>>()
        .exec(),
      this.coupons.countDocuments(where),
    ]);
    return new PaginatedResult(rows.map((row) => this.view(row)), filters.page, filters.pageSize, total);
  }

  async create(actor: AuthenticatedUserActor, client: ClientRequestInfo, input: CouponInput): Promise<CouponView> {
    this.checkInput(input);
    const code = input.code.trim().toUpperCase();
    if (await this.coupons.exists({ code })) {
      throw new ApiException('ALREADY_REGISTERED', `The code ${code} is already used.`);
    }
    const saved = await this.changes.run<CouponRow & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'coupon.created',
      entityType: 'coupon',
      before: {},
      apply: async (session) => {
        const [created] = await this.coupons.create(
          [
            {
              code,
              title: input.title,
              ...(input.description ? { description: input.description } : {}),
              discountType: input.discountType,
              value: input.value,
              ...(input.maxDiscountPaise ? { maxDiscountPaise: input.maxDiscountPaise } : {}),
              minBookingPaise: input.minBookingPaise,
              usageLimit: input.usageLimit,
              perCustomerLimit: input.perCustomerLimit,
              usedCount: 0,
              fundedBy: input.fundedBy,
              restrictions: {
                operatorIds: (input.operatorIds ?? []).filter((id) => Types.ObjectId.isValid(id)).map((id) => new Types.ObjectId(id)),
                routeIds: [],
                newUsersOnly: input.newUsersOnly,
              },
              startsAt: input.startsAt,
              endsAt: input.endsAt,
              status: 'ACTIVE',
            },
          ],
          { session },
        );
        if (!created) throw new Error('The coupon could not be saved');
        return created.toObject() as CouponRow & { _id: Types.ObjectId };
      },
      describe: (row) => ({ code: row.code, discountType: row.discountType, value: row.value, usageLimit: row.usageLimit }),
    });
    return this.view(saved);
  }

  /** Changes what a coupon allows. The code and the kind of discount never change; the amount only before the first use. */
  async update(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    id: string,
    input: CouponUpdate,
  ): Promise<CouponView> {
    const before = await this.require(id);
    if (input.value !== undefined && input.value !== before.value && before.usedCount > 0) {
      throw new ApiException('RESOURCE_IN_USE', 'This coupon has been used, so its amount cannot change. Make a new coupon instead.');
    }
    if (input.value !== undefined) {
      if (before.discountType === 'PERCENT' && (input.value < 1 || input.value > 100)) {
        throw new ApiException('VALIDATION_FAILED', 'A percentage is from 1 to 100.');
      }
      if (before.discountType === 'FLAT' && input.value < 1) {
        throw new ApiException('VALIDATION_FAILED', 'A flat discount is at least 1 paisa.');
      }
    }
    const startsAt = input.startsAt ?? before.startsAt;
    const endsAt = input.endsAt ?? before.endsAt;
    if (endsAt <= startsAt) throw new ApiException('VALIDATION_FAILED', 'The end must be after the start.');
    if (input.usageLimit !== undefined && input.usageLimit > 0 && input.usageLimit < before.usedCount) {
      throw new ApiException('VALIDATION_FAILED', `Already used ${before.usedCount} times, so the limit cannot be lower.`);
    }
    const set: Record<string, unknown> = {};
    if (input.title !== undefined) set.title = input.title;
    if (input.description !== undefined) set.description = input.description;
    if (input.value !== undefined) set.value = input.value;
    if (input.maxDiscountPaise !== undefined) set.maxDiscountPaise = input.maxDiscountPaise;
    if (input.minBookingPaise !== undefined) set.minBookingPaise = input.minBookingPaise;
    if (input.usageLimit !== undefined) set.usageLimit = input.usageLimit;
    if (input.perCustomerLimit !== undefined) set.perCustomerLimit = input.perCustomerLimit;
    if (input.fundedBy !== undefined) set.fundedBy = input.fundedBy;
    if (input.newUsersOnly !== undefined) set['restrictions.newUsersOnly'] = input.newUsersOnly;
    if (input.startsAt !== undefined) set.startsAt = input.startsAt;
    if (input.endsAt !== undefined) set.endsAt = input.endsAt;
    const saved = await this.changes.run<CouponRow & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'coupon.updated',
      entityType: 'coupon',
      before: { title: before.title, value: before.value, usageLimit: before.usageLimit, perCustomerLimit: before.perCustomerLimit, endsAt: before.endsAt },
      apply: async (session) => {
        const row = await this.coupons
          .findOneAndUpdate({ _id: before._id }, { $set: set }, { session, returnDocument: 'after' })
          .lean<CouponRow & { _id: Types.ObjectId }>()
          .exec();
        if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'Coupon not found.');
        return row;
      },
      describe: (row) => ({ title: row.title, value: row.value, usageLimit: row.usageLimit, perCustomerLimit: row.perCustomerLimit, endsAt: row.endsAt }),
    });
    return this.view(saved);
  }

  async setStatus(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    id: string,
    status: CouponStatus,
  ): Promise<CouponView> {
    const before = await this.require(id);
    const saved = await this.changes.run<CouponRow & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'coupon.status-changed',
      entityType: 'coupon',
      before: { code: before.code, status: before.status },
      apply: async (session) => {
        const row = await this.coupons
          .findOneAndUpdate({ _id: before._id }, { $set: { status } }, { session, returnDocument: 'after' })
          .lean<CouponRow & { _id: Types.ObjectId }>()
          .exec();
        if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'Coupon not found.');
        return row;
      },
      describe: (row) => ({ code: row.code, status: row.status }),
    });
    return this.view(saved);
  }

  /** Deletes a coupon nobody has used. A used one is paused instead, so the bookings that used it stay explained. */
  async remove(actor: AuthenticatedUserActor, client: ClientRequestInfo, id: string): Promise<{ deleted: true }> {
    const before = await this.require(id);
    const used = before.usedCount > 0 || (await this.redemptions().countDocuments({ couponId: before._id })) > 0;
    if (used) {
      throw new ApiException('RESOURCE_IN_USE', 'This coupon has been used by bookings, so it cannot be deleted. Pause it instead.');
    }
    await this.changes.run<CouponRow & { _id: Types.ObjectId }>({
      actor,
      client,
      action: 'coupon.deleted',
      entityType: 'coupon',
      before: { code: before.code, title: before.title },
      apply: async (session) => {
        await this.coupons.deleteOne({ _id: before._id }, { session });
        return before;
      },
      describe: () => ({ deleted: true }),
    });
    return { deleted: true };
  }

  /** Who used a coupon: each booking, its customer, what it took off, and where that use stands. */
  async usage(id: string): Promise<CouponUsage> {
    const coupon = await this.require(id);
    const redemptions = await this.redemptions().find({ couponId: coupon._id }).sort({ createdAt: -1 }).limit(500).toArray();
    const bookings = await this.connection
      .collection<{ _id: Types.ObjectId; pnr: string; discountPaise: number; passengers: Array<{ name: string }>; contact: { mobile: string } }>('bookings')
      .find({ _id: { $in: redemptions.map((r) => r.bookingId as Types.ObjectId) } })
      .toArray();
    const items = redemptions.map((r) => {
      const booking = bookings.find((b) => b._id.equals(r.bookingId as Types.ObjectId));
      return {
        bookingId: String(r.bookingId),
        pnr: booking?.pnr ?? '',
        customerName: booking?.passengers[0]?.name ?? '',
        customerPhone: booking?.contact.mobile ?? '',
        discountPaise: booking?.discountPaise ?? 0,
        status: String(r.status),
        at: (r.createdAt as Date | undefined)?.toISOString() ?? null,
      };
    });
    const count = (status: string) => items.filter((i) => i.status === status).length;
    return {
      code: coupon.code,
      usedCount: coupon.usedCount,
      reserved: count('RESERVED'),
      redeemed: count('REDEEMED'),
      released: count('RELEASED'),
      discountGivenPaise: items.filter((i) => i.status === 'REDEEMED').reduce((sum, i) => sum + i.discountPaise, 0),
      items,
    };
  }

  private async require(id: string): Promise<CouponRow & { _id: Types.ObjectId }> {
    const row = Types.ObjectId.isValid(id)
      ? await this.coupons.findById(id).lean<CouponRow & { _id: Types.ObjectId }>().exec()
      : null;
    if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'Coupon not found.');
    return row;
  }

  private checkInput(input: CouponInput): void {
    if (!/^[A-Z0-9]{3,20}$/.test(input.code.trim().toUpperCase())) {
      throw new ApiException('VALIDATION_FAILED', 'The code has 3 to 20 letters or digits.');
    }
    if (input.discountType === 'PERCENT' && (input.value < 1 || input.value > 100)) {
      throw new ApiException('VALIDATION_FAILED', 'A percentage is from 1 to 100.');
    }
    if (input.discountType === 'FLAT' && input.value < 1) {
      throw new ApiException('VALIDATION_FAILED', 'A flat discount is at least 1 paisa.');
    }
    if (input.endsAt <= input.startsAt) {
      throw new ApiException('VALIDATION_FAILED', 'The end must be after the start.');
    }
  }

  // ----- customer -----

  /** Checks a code for a customer, a trip and a base fare. A refused code is an answer, not an error. */
  async check(customerId: Types.ObjectId, tripId: string, codeText: string, basePaise: number): Promise<CouponCheck> {
    const code = codeText.trim().toUpperCase();
    const refuse = (reason: string): CouponCheck => ({ code, valid: false, discountPaise: 0, reason });
    const coupon = await this.coupons.findOne({ code }).lean<CouponRow & { _id: Types.ObjectId }>().exec();
    if (!coupon) return refuse('This code is not valid.');
    const now = new Date();
    if (coupon.status !== 'ACTIVE' || coupon.startsAt > now || coupon.endsAt <= now) {
      return refuse('This code is not active right now.');
    }
    if (basePaise < coupon.minBookingPaise) {
      return refuse(`Book at least ₹${Math.ceil(coupon.minBookingPaise / 100)} to use this code.`);
    }
    if (coupon.usageLimit > 0 && coupon.usedCount >= coupon.usageLimit) {
      return refuse('This code has been used up.');
    }
    if (Types.ObjectId.isValid(tripId) && coupon.restrictions.operatorIds.length > 0) {
      const trip = await this.connection
        .collection<{ operatorId?: Types.ObjectId }>('trips')
        .findOne({ _id: new Types.ObjectId(tripId) }, { projection: { operatorId: 1 } });
      if (!trip?.operatorId || !coupon.restrictions.operatorIds.some((id) => id.equals(trip.operatorId))) {
        return refuse('This code is not for this bus company.');
      }
    }
    const used = await this.redemptions().countDocuments({
      couponId: coupon._id,
      customerId,
      status: { $in: ['RESERVED', 'REDEEMED'] },
    });
    if (used >= coupon.perCustomerLimit) return refuse('You have already used this code.');
    if (coupon.restrictions.newUsersOnly) {
      const bookings = await this.connection.collection('bookings').countDocuments({ customerId, status: 'CONFIRMED' });
      if (bookings > 0) return refuse('This code is for your first booking only.');
    }
    return { code, valid: true, discountPaise: discountFor(coupon, basePaise) };
  }

  /** Offers open to guests: active, in date and not used up, with the conditions in words. */
  async publicOffers(): Promise<PublicOfferView[]> {
    const rows = await this.suggestions();
    return rows.map((c) => {
      const rupees = (paise: number) => `Rs ${paise % 100 === 0 ? paise / 100 : (paise / 100).toFixed(2)}`;
      const gives =
        c.discountType === 'PERCENT'
          ? `${c.value}% off${c.maxDiscountPaise ? ` up to ${rupees(c.maxDiscountPaise)}` : ''}`
          : `${rupees(c.value)} off`;
      const terms: string[] = [];
      if (c.minBookingPaise > 0) terms.push(`Valid on bookings of ${rupees(c.minBookingPaise)} or more.`);
      if (c.newUsersOnly) terms.push('For your first booking only.');
      terms.push(c.perCustomerLimit === 1 ? 'One use for each customer.' : `Up to ${c.perCustomerLimit} uses for each customer.`);
      if (c.usageLimit > 0) terms.push('Limited number of uses in total.');
      return {
        code: c.code,
        title: c.title,
        description: c.description ? `${gives}. ${c.description}` : gives,
        validTill: c.endsAt,
        terms,
      };
    });
  }

  /** Codes worth showing for a trip: active, in date and not used up. */
  async suggestions(): Promise<CouponView[]> {
    const now = new Date();
    const rows = await this.coupons
      .find({ status: 'ACTIVE', startsAt: { $lte: now }, endsAt: { $gt: now } })
      .sort({ createdAt: -1 })
      .limit(10)
      .lean<Array<CouponRow & { _id: Types.ObjectId }>>()
      .exec();
    return rows.filter((row) => row.usageLimit === 0 || row.usedCount < row.usageLimit).map((row) => this.view(row));
  }

  /**
   * Holds a coupon for a booking: counts the use and records who. The limit is enforced in the
   * update itself, so two bookings can never both take the last use.
   */
  async reserve(
    customerId: Types.ObjectId,
    bookingId: Types.ObjectId,
    code: string,
    session: ClientSession,
  ): Promise<void> {
    const upper = code.trim().toUpperCase();
    const coupon = await this.coupons
      .findOneAndUpdate(
        {
          code: upper,
          $or: [{ usageLimit: 0 }, { $expr: { $lt: ['$usedCount', '$usageLimit'] } }],
        },
        { $inc: { usedCount: 1 } },
        { session, new: true },
      )
      .lean<CouponRow & { _id: Types.ObjectId }>()
      .exec();
    if (!coupon) throw new ApiException('COUPON_USAGE_EXCEEDED', 'This code has been used up.');
    await this.redemptions().insertOne(
      { couponId: coupon._id, customerId, bookingId, status: 'RESERVED', createdAt: new Date() },
      { session },
    );
  }
}
