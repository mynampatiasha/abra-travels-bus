import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { type BookingRow } from '../bookings/bookings_customer.service';
import { PAYMENT_MODEL, type PaymentRow, PAYMENT_STATUSES } from './payments_customer.service';

/** The admin Payments page: what was paid, for which booking, and what was sent back. Read only. */

type Stored = PaymentRow & { _id: Types.ObjectId; createdAt?: Date };

export interface AdminPaymentRow {
  id: string;
  pnr: string;
  bookingId: string;
  customerName: string;
  customerPhone: string;
  gateway: string;
  gatewayOrderId: string;
  gatewayPaymentId: string;
  amountPaise: number;
  refundedPaise: number;
  status: string;
  failureReason: string;
  refundDue: boolean;
  paidAt: string | null;
  createdAt: string;
}

export interface AdminPaymentDetail extends AdminPaymentRow {
  refunds: Array<{ gatewayRefundId: string; amountPaise: number; reason: string; status: string; at: string }>;
}

export interface PaymentListFilters {
  search?: string | undefined;
  status?: (typeof PAYMENT_STATUSES)[number] | undefined;
  refundDue?: boolean | undefined;
  from?: string | undefined;
  to?: string | undefined;
  page: number;
  pageSize: number;
}

const escapeRegex = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

@Injectable()
export class PaymentsAdminService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(PAYMENT_MODEL) private readonly payments: Model<PaymentRow>,
  ) {}

  private async bookingsOf(rows: Stored[]) {
    return this.connection
      .collection<BookingRow & { _id: Types.ObjectId }>('bookings')
      .find({ _id: { $in: rows.map((r) => r.bookingId) } })
      .toArray();
  }

  private rowOf(row: Stored, bookings: Array<BookingRow & { _id: Types.ObjectId }>): AdminPaymentRow {
    const booking = bookings.find((b) => b._id.equals(row.bookingId));
    return {
      id: row._id.toHexString(),
      pnr: booking?.pnr ?? '',
      bookingId: row.bookingId.toHexString(),
      customerName: booking?.passengers[0]?.name ?? '',
      customerPhone: booking?.contact.mobile ?? '',
      gateway: row.gateway,
      gatewayOrderId: row.gatewayOrderId,
      gatewayPaymentId: row.gatewayPaymentId ?? '',
      amountPaise: row.amountPaise,
      refundedPaise: row.refundedPaise ?? 0,
      status: row.status,
      failureReason: row.failureReason ?? '',
      refundDue: row.refundDue !== undefined,
      paidAt: row.paidAt ? row.paidAt.toISOString() : null,
      createdAt: (row.createdAt ?? new Date(0)).toISOString(),
    };
  }

  async list(actor: AuthenticatedUserActor, filters: PaymentListFilters): Promise<PaginatedResult<AdminPaymentRow>> {
    assertStaff(actor);
    return this.rows(filters);
  }

  /** The list itself, also used by the export (which needs its own permission, payments.export). */
  async rows(filters: PaymentListFilters): Promise<PaginatedResult<AdminPaymentRow>> {
    const where: Record<string, unknown> = {};
    if (filters.status) where.status = filters.status;
    if (filters.refundDue) where.refundDue = { $exists: true };
    if (filters.from || filters.to) {
      where.createdAt = {
        ...(filters.from ? { $gte: new Date(`${filters.from}T00:00:00.000Z`) } : {}),
        ...(filters.to ? { $lt: new Date(new Date(`${filters.to}T00:00:00.000Z`).getTime() + 86_400_000) } : {}),
      };
    }
    const search = filters.search?.trim();
    if (search) {
      const like = new RegExp(escapeRegex(search), 'i');
      const bookingIds = (
        await this.connection
          .collection('bookings')
          .find({ $or: [{ pnr: like }, { 'contact.mobile': like }, { 'passengers.name': like }] }, { projection: { _id: 1 } })
          .limit(500)
          .toArray()
      ).map((b) => b._id);
      where.$or = [{ gatewayOrderId: like }, { gatewayPaymentId: like }, { bookingId: { $in: bookingIds } }];
    }
    const [rows, total] = await Promise.all([
      this.payments
        .find(where)
        .sort({ createdAt: -1 })
        .skip((filters.page - 1) * filters.pageSize)
        .limit(filters.pageSize)
        .lean<Stored[]>()
        .exec(),
      this.payments.countDocuments(where),
    ]);
    const bookings = await this.bookingsOf(rows);
    return new PaginatedResult(
      rows.map((row) => this.rowOf(row, bookings)),
      filters.page,
      filters.pageSize,
      total,
    );
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<AdminPaymentDetail> {
    assertStaff(actor);
    const row = Types.ObjectId.isValid(id) ? await this.payments.findById(id).lean<Stored>().exec() : null;
    if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'That payment was not found.');
    const bookings = await this.bookingsOf([row]);
    return {
      ...this.rowOf(row, bookings),
      refunds: (row.refunds ?? []).map((r) => ({ ...r, at: r.at.toISOString() })),
    };
  }
}

/** The customer role also holds bookings.read (for their own trips), so the admin lists check the kind of account too. */
function assertStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'Only Abra staff can see this page.');
  }
}
