import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { OutboxService } from '../../events/outbox.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { confirmationPayload } from './booking_confirmation';
import { BOOKING_MODEL, type BookingRow, type BookingStatus } from './bookings_customer.service';

/*
 * The admin Bookings page: every booking with who, where, when and how much, one booking in
 * full, and sending the ticket message again. Nothing here changes a booking's seats or money:
 * cancelling and refunding come with Phase 4.
 */

type Stored = BookingRow & { _id: Types.ObjectId };

export interface AdminBookingRow {
  id: string;
  pnr: string;
  status: BookingStatus;
  customerName: string;
  customerPhone: string;
  customerEmail: string;
  route: string;
  operatorName: string;
  departureAt: string | null;
  seats: string;
  seatCount: number;
  amountPaise: number;
  paymentStatus: string;
  createdAt: string;
}

export interface OperatorBookingSummary {
  total: number;
  confirmed: number;
  cancelled: number;
  /** What customers paid for the bookings that stand, in paise. Abra's commission is taken off later, in settlements. */
  confirmedAmountPaise: number;
}

export interface AdminBookingDetail extends AdminBookingRow {
  tripId: string;
  baseFarePaise: number;
  gstPaise: number;
  convenienceFeePaise: number;
  discountPaise: number;
  couponCode: string | null;
  boardingPoint: string;
  droppingPoint: string;
  gstin: string | null;
  passengers: Array<{ seatId: string; name: string; age: number; gender: string; farePaise: number; status: string }>;
  payments: Array<{ id: string; status: string; amountPaise: number; gateway: string; refundedPaise: number; createdAt: string }>;
}

export interface BookingListFilters {
  search?: string | undefined;
  status?: string | undefined;
  operatorId?: string | undefined;
  from?: string | undefined;
  to?: string | undefined;
  page: number;
  pageSize: number;
}

const escapeRegex = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

@Injectable()
export class BookingsAdminService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(BOOKING_MODEL) private readonly bookings: Model<BookingRow>,
    private readonly outbox: OutboxService,
    private readonly changes: AuditedChangeRunner,
    private readonly transactions: TransactionRunner,
  ) {}

  /** Names of cities and operators for a set of bookings, found once. */
  private async lookups(rows: Stored[]) {
    const tripIds = [...new Set(rows.map((r) => r.tripId.toHexString()))].map((id) => new Types.ObjectId(id));
    const trips = await this.connection
      .collection<{
        _id: Types.ObjectId;
        operatorId?: Types.ObjectId;
        originCityId?: Types.ObjectId;
        destinationCityId?: Types.ObjectId;
        departureAt?: Date;
        boardingPoints?: Array<{ pointId: Types.ObjectId; name: string }>;
        droppingPoints?: Array<{ pointId: Types.ObjectId; name: string }>;
      }>('trips')
      .find({ _id: { $in: tripIds } })
      .toArray();
    const cityIds = trips.flatMap((t) => [t.originCityId, t.destinationCityId]).filter((id): id is Types.ObjectId => !!id);
    const cities = await this.connection
      .collection<{ _id: Types.ObjectId; name: string }>('cities')
      .find({ _id: { $in: cityIds } })
      .toArray();
    const operatorIds = trips.map((t) => t.operatorId).filter((id): id is Types.ObjectId => !!id);
    const operators = await this.connection
      .collection<{ _id: Types.ObjectId; displayName?: string; companyName?: string }>('operators')
      .find({ _id: { $in: operatorIds } })
      .toArray();
    const payments = await this.connection
      .collection<{ _id: Types.ObjectId; bookingId: Types.ObjectId; status: string; amountPaise: number; gateway: string; refundedPaise?: number; createdAt?: Date }>('payments')
      .find({ bookingId: { $in: rows.map((r) => r._id) } })
      .sort({ createdAt: -1 })
      .toArray();
    const cityName = (id?: Types.ObjectId) => cities.find((c) => id && c._id.equals(id))?.name ?? '';
    return { trips, payments, cityName, operators };
  }

  private rowOf(row: Stored, ctx: Awaited<ReturnType<BookingsAdminService['lookups']>>): AdminBookingRow {
    const trip = ctx.trips.find((t) => t._id.equals(row.tripId));
    const operator = ctx.operators.find((o) => trip?.operatorId && o._id.equals(trip.operatorId));
    const latest = ctx.payments.find((p) => p.bookingId.equals(row._id));
    return {
      id: row._id.toHexString(),
      pnr: row.pnr,
      status: row.status,
      customerName: row.passengers[0]?.name ?? '',
      customerPhone: row.contact.mobile,
      customerEmail: row.contact.email,
      route: [ctx.cityName(trip?.originCityId), ctx.cityName(trip?.destinationCityId)].filter(Boolean).join(' to '),
      operatorName: operator?.displayName ?? operator?.companyName ?? '',
      departureAt: (row.departureAt ?? trip?.departureAt)?.toISOString() ?? null,
      seats: row.passengers.map((p) => p.seatId).join(', '),
      seatCount: row.passengers.length,
      amountPaise: row.amountPaise,
      paymentStatus: latest?.status ?? 'NONE',
      createdAt: (row.createdAt ?? new Date(0)).toISOString(),
    };
  }

  async list(actor: AuthenticatedUserActor, filters: BookingListFilters): Promise<PaginatedResult<AdminBookingRow>> {
    assertStaff(actor);
    return this.rows(filters);
  }

  /** The operator's own bookings (client portal): the same rows, never another operator's. */
  async listForOperator(actor: AuthenticatedUserActor, filters: BookingListFilters): Promise<PaginatedResult<AdminBookingRow>> {
    return this.rows(filters, this.operatorOf(actor));
  }

  async getForOperator(actor: AuthenticatedUserActor, id: string): Promise<AdminBookingDetail> {
    const operatorId = this.operatorOf(actor);
    const row = await this.find(id);
    // Someone else's booking is "not found", not "forbidden": its existence is not the operator's business
    if (!row.operatorId || !row.operatorId.equals(operatorId)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'That booking was not found.');
    }
    return this.detailOf(row);
  }

  /** The numbers on top of the operator's page. A booking still waiting for payment is not counted. */
  async summaryForOperator(actor: AuthenticatedUserActor): Promise<OperatorBookingSummary> {
    const operatorId = this.operatorOf(actor);
    const groups = await this.bookings.aggregate<{ _id: BookingStatus; count: number; amountPaise: number }>([
      { $match: { operatorId, status: { $nin: ['PAYMENT_PENDING', 'FAILED', 'EXPIRED', 'INITIATED', 'SEAT_LOCKED'] } } },
      { $group: { _id: '$status', count: { $sum: 1 }, amountPaise: { $sum: '$amountPaise' } } },
    ]);
    const countOf = (statuses: BookingStatus[]) => groups.filter((g) => statuses.includes(g._id)).reduce((sum, g) => sum + g.count, 0);
    const paidOf = (statuses: BookingStatus[]) => groups.filter((g) => statuses.includes(g._id)).reduce((sum, g) => sum + g.amountPaise, 0);
    const live: BookingStatus[] = ['CONFIRMED', 'PARTIALLY_CANCELLED', 'COMPLETED'];
    const cancelled: BookingStatus[] = ['CANCELLED', 'REFUND_PENDING', 'REFUNDED'];
    return {
      total: countOf([...live, ...cancelled]),
      confirmed: countOf(live),
      cancelled: countOf(cancelled),
      confirmedAmountPaise: paidOf(live),
    };
  }

  private operatorOf(actor: AuthenticatedUserActor): Types.ObjectId {
    // Drivers and conductors also hold bookings.read (for passenger lists), but not the contact details
    if (actor.userType !== 'OPERATOR_STAFF' || !actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Only an operator account can see these bookings.');
    }
    return new Types.ObjectId(actor.operatorId);
  }

  /** The list itself, also used by the export (which needs its own permission, bookings.export). */
  async rows(filters: BookingListFilters, onlyOperator?: Types.ObjectId): Promise<PaginatedResult<AdminBookingRow>> {
    const where: Record<string, unknown> = {};
    if (onlyOperator) where.operatorId = onlyOperator;
    if (filters.status) where.status = filters.status;
    if (filters.from || filters.to) {
      where.createdAt = {
        ...(filters.from ? { $gte: new Date(`${filters.from}T00:00:00.000Z`) } : {}),
        ...(filters.to ? { $lt: new Date(new Date(`${filters.to}T00:00:00.000Z`).getTime() + 86_400_000) } : {}),
      };
    }
    if (!onlyOperator && filters.operatorId && Types.ObjectId.isValid(filters.operatorId)) {
      where.operatorId = new Types.ObjectId(filters.operatorId);
    }
    const search = filters.search?.trim();
    if (search) {
      const like = new RegExp(escapeRegex(search), 'i');
      where.$or = [
        { pnr: like },
        { 'contact.mobile': like },
        { 'contact.email': like },
        { 'passengers.name': like },
      ];
    }
    const [rows, total] = await Promise.all([
      this.bookings
        .find(where)
        .sort({ createdAt: -1 })
        .skip((filters.page - 1) * filters.pageSize)
        .limit(filters.pageSize)
        .lean<Stored[]>()
        .exec(),
      this.bookings.countDocuments(where),
    ]);
    const ctx = await this.lookups(rows);
    return new PaginatedResult(
      rows.map((row) => this.rowOf(row, ctx)),
      filters.page,
      filters.pageSize,
      total,
    );
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<AdminBookingDetail> {
    assertStaff(actor);
    return this.detailOf(await this.find(id));
  }

  private async detailOf(row: Stored): Promise<AdminBookingDetail> {
    const ctx = await this.lookups([row]);
    const trip = ctx.trips.find((t) => t._id.equals(row.tripId));
    return {
      ...this.rowOf(row, ctx),
      tripId: row.tripId.toHexString(),
      baseFarePaise: row.baseFarePaise,
      gstPaise: row.gstPaise ?? 0,
      convenienceFeePaise: row.convenienceFeePaise ?? 0,
      discountPaise: row.discountPaise,
      couponCode: row.couponCode ?? null,
      boardingPoint: (trip?.boardingPoints ?? []).find((p) => p.pointId.toHexString() === row.boardingPointId)?.name ?? '',
      droppingPoint: (trip?.droppingPoints ?? []).find((p) => p.pointId.toHexString() === row.droppingPointId)?.name ?? '',
      gstin: row.gst?.gstin ?? null,
      passengers: row.passengers.map((p) => ({
        seatId: p.seatId,
        name: p.name,
        age: p.age,
        gender: p.gender,
        farePaise: p.farePaise,
        status: p.status ?? 'ACTIVE',
      })),
      payments: ctx.payments
        .filter((p) => p.bookingId.equals(row._id))
        .map((p) => ({
          id: p._id.toHexString(),
          status: p.status,
          amountPaise: p.amountPaise,
          gateway: p.gateway,
          refundedPaise: p.refundedPaise ?? 0,
          createdAt: (p.createdAt ?? new Date(0)).toISOString(),
        })),
    };
  }

  /** Sends the confirmation WhatsApp and email again, for a paid booking. Audited. */
  async resendTicket(actor: AuthenticatedUserActor, id: string, client: ClientRequestInfo): Promise<{ queued: true }> {
    assertStaff(actor);
    const row = await this.find(id);
    if (!['CONFIRMED', 'PARTIALLY_CANCELLED', 'COMPLETED'].includes(row.status)) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'The ticket is sent once the payment is done.');
    }
    const payload = await confirmationPayload(this.connection, row);
    await this.changes.run<Stored>({
      actor,
      client,
      action: 'booking.ticket-resent',
      entityType: 'booking',
      before: { status: row.status },
      apply: async (session) => {
        await this.outbox.record(
          { type: 'booking.confirmed', aggregateType: 'booking', aggregateId: row._id.toHexString(), payload },
          session,
        );
        return row;
      },
      describe: (record) => ({ status: record.status, pnr: record.pnr }),
    });
    return { queued: true };
  }

  private async find(id: string): Promise<Stored> {
    const row = Types.ObjectId.isValid(id)
      ? await this.bookings.findById(id).lean<Stored>().exec()
      : null;
    if (!row) throw new ApiException('RESOURCE_NOT_FOUND', 'That booking was not found.');
    return row;
  }
}

/** The customer role also holds bookings.read (for their own trips), so the admin lists check the kind of account too. */
function assertStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'Only Abra staff can see this page.');
  }
}
