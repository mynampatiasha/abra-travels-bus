import { Injectable } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { ProofFilesService } from '../files/files_core.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { SessionsService, type SessionSummary } from '../sessions/services/sessions.service';
import { USER_MODEL, type User, type UserStatus } from '../users/schemas/user.schema';
import {
  assertNoUpcomingBookings,
  fieldError,
  type ProfileView,
  profileViewOf,
  signInMethodOf,
  type StoredCustomerUser,
} from './customers_customer.service';
import { CUSTOMER_MODEL, type Customer } from './schemas/customer.schema';

/*
 * The admin Customers page (`/admin/customers`): the list with search and filters, one customer
 * with their bookings and devices, edit, block and unblock with a reason and proof, sign out of all
 * devices, and delete (which can be undone). The bookings are only read, by customer and status.
 */

export const CUSTOMER_LIST_STATUSES = ['ACTIVE', 'SUSPENDED', 'DEACTIVATED'] as const;
export const SIGN_IN_METHODS = ['google', 'whatsapp', 'apple', 'password'] as const;
export type SignInMethod = (typeof SIGN_IN_METHODS)[number];

const COUNTED_STATUSES = ['CONFIRMED', 'COMPLETED', 'CANCELLED', 'PARTIALLY_CANCELLED'];
const PAID_STATUSES = ['CONFIRMED', 'COMPLETED', 'PARTIALLY_CANCELLED'];
const MAX_REASON_LENGTH = 500;

export interface CustomerListQuery {
  search?: string | undefined;
  status?: (typeof CUSTOMER_LIST_STATUSES)[number] | undefined;
  signInMethod?: SignInMethod | undefined;
  page: number;
  pageSize: number;
}

export interface CustomerRowView extends ProfileView {
  status: UserStatus;
  bookings: number;
  spentPaise: number;
}

export interface CustomerBookingView {
  id: string;
  pnr: string;
  status: string;
  amountPaise: number;
  seats: number;
  bookedAt: string | null;
}

export interface CustomerDetailView extends CustomerRowView {
  blocked: { reason: string; at: string } | null;
  recentBookings: CustomerBookingView[];
  devices: SessionSummary[];
}

type StoredBlocked = NonNullable<Customer['blocked']>;
type StoredCustomerProfile = Customer & { _id: Types.ObjectId };

@Injectable()
export class CustomersAdminService {
  constructor(
    @InjectModel(USER_MODEL) private readonly users: Model<User>,
    @InjectModel(CUSTOMER_MODEL) private readonly customers: Model<Customer>,
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly sessions: SessionsService,
    private readonly moduleRef: ModuleRef,
  ) {}

  /**
   * The proof-file service is found when it is needed: importing the files module here would make
   * the modules import each other in a circle (files, operators, messages, authentication).
   */
  private get proofFiles(): ProofFilesService {
    return this.moduleRef.get(ProofFilesService, { strict: false });
  }

  // ----- reading -----

  async list(query: CustomerListQuery): Promise<PaginatedResult<CustomerRowView>> {
    const match: Record<string, unknown> = { userType: 'CUSTOMER' };
    if (query.status) match.status = query.status;
    const text = query.search?.trim();
    if (text) {
      const pattern = { $regex: escapeRegExp(text), $options: 'i' };
      match.$or = [{ name: pattern }, { email: pattern }, { phone: pattern }];
    }
    const method = query.signInMethod;
    if (method === 'google') match.$and = [{ $or: [{ googleFirebaseUid: { $type: 'string' } }, { authProvider: 'google' }] }];
    if (method === 'apple') match.$and = [{ $or: [{ appleFirebaseUid: { $type: 'string' } }, { authProvider: 'apple' }] }];
    if (method === 'password') {
      match.passwordHash = { $type: 'string' };
      match.authProvider = { $ne: 'whatsapp' };
      match.googleFirebaseUid = { $exists: false };
      match.appleFirebaseUid = { $exists: false };
    }
    if (method === 'whatsapp') {
      match.googleFirebaseUid = { $exists: false };
      match.appleFirebaseUid = { $exists: false };
      match.$and = [{ $or: [{ authProvider: 'whatsapp' }, { passwordHash: null }] }];
    }

    const [found] = await this.users
      .aggregate<{ items: StoredCustomerUser[]; total: Array<{ n: number }> }>([
        { $match: match },
        { $lookup: { from: 'customers', localField: '_id', foreignField: 'userId', as: 'profile' } },
        { $match: { profile: { $not: { $elemMatch: { deletedAt: { $ne: null } } } } } },
        {
          $facet: {
            items: [
              { $sort: { createdAt: -1, _id: -1 } },
              { $skip: skipOf(query) },
              { $limit: query.pageSize },
              { $project: { profile: 0, passwordHash: 0, mfa: 0 } },
            ],
            total: [{ $count: 'n' }],
          },
        },
      ])
      .exec();
    const items = found?.items ?? [];
    const totals = await this.bookingTotals(items.map((user) => user._id));
    return new PaginatedResult(
      items.map((user) => this.rowOf(user, totals.get(user._id.toHexString()))),
      query.page,
      query.pageSize,
      found?.total[0]?.n ?? 0,
    );
  }

  async get(id: string): Promise<CustomerDetailView> {
    const user = await this.customerUser(id, { includeDeleted: false });
    const profile = await this.profileOf(user._id);
    const [totals, recent, devices] = await Promise.all([
      this.bookingTotals([user._id]),
      this.recentBookings(user._id),
      this.sessions.listActive(user._id.toHexString(), ''),
    ]);
    return {
      ...this.rowOf(user, totals.get(user._id.toHexString())),
      blocked: profile?.blocked
        ? { reason: profile.blocked.reason, at: profile.blocked.at.toISOString() }
        : null,
      recentBookings: recent,
      devices,
    };
  }

  // ----- changing -----

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: { name?: string | undefined; email?: string | undefined },
    client: ClientRequestInfo,
  ): Promise<CustomerDetailView> {
    const before = await this.customerUser(id, { includeDeleted: false });
    const set: Record<string, unknown> = {};
    if (input.name !== undefined) {
      if (!input.name.trim()) throw fieldError('name', 'Enter the name');
      set.name = input.name.trim();
    }
    if (input.email !== undefined) {
      const email = input.email.trim().toLowerCase();
      if (!email) throw fieldError('email', 'Enter the email address');
      if (email !== before.email) {
        set.email = email;
        set.emailVerifiedAt = null;
      }
    }
    if (Object.keys(set).length > 0) {
      try {
        await this.changes.run({
          actor,
          client,
          action: 'customer.updated',
          entityType: 'customer',
          before: this.describe(before),
          apply: (session) => this.saveUser(before._id, { $set: set }, session),
          describe: (user) => this.describe(user),
        });
      } catch (error) {
        if (isDuplicateKeyError(error)) {
          throw new ApiException(
            'ALREADY_REGISTERED',
            'This email is already used by another account.',
          );
        }
        throw error;
      }
    }
    return this.get(id);
  }

  /** Blocks the account: the person is signed out everywhere and cannot sign in until unblocked. */
  async block(
    actor: AuthenticatedUserActor,
    id: string,
    input: { reason: string; proofFileIds?: string[] | undefined },
    client: ClientRequestInfo,
  ): Promise<CustomerDetailView> {
    const reason = input.reason.trim();
    if (!reason) throw fieldError('reason', 'Write why this account is blocked');
    if (reason.length > MAX_REASON_LENGTH) {
      throw fieldError('reason', `The reason can be up to ${MAX_REASON_LENGTH} characters`);
    }
    const before = await this.customerUser(id, { includeDeleted: false });
    if (before.status === 'SUSPENDED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This account is already blocked.');
    }
    if (before.status !== 'ACTIVE') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Only an active account can be blocked.');
    }
    await this.changes.run({
      actor,
      client,
      action: 'customer.blocked',
      entityType: 'customer',
      before: this.describe(before),
      reason,
      apply: async (session) => {
        const saved = await this.saveUser(
          before._id,
          { $set: { status: 'SUSPENDED' }, $inc: { permissionVersion: 1 } },
          session,
        );
        const blocked: StoredBlocked = {
          reason,
          at: new Date(),
          by: new Types.ObjectId(actor.userId),
        };
        await this.customers.updateOne({ userId: before._id }, { $set: { blocked } }, { session }).exec();
        await this.proofFiles.attach(
          input.proofFileIds,
          { type: 'customer-block', id: before._id },
          session,
        );
        await this.sessions.revokeAllForUser(before._id.toHexString(), 'ACCOUNT_DISABLED', {
          dbSession: session,
        });
        return saved;
      },
      describe: (user) => this.describe(user),
    });
    return this.get(id);
  }

  async unblock(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<CustomerDetailView> {
    const before = await this.customerUser(id, { includeDeleted: false });
    if (before.status !== 'SUSPENDED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This account is not blocked.');
    }
    await this.changes.run({
      actor,
      client,
      action: 'customer.unblocked',
      entityType: 'customer',
      before: this.describe(before),
      apply: async (session) => {
        const saved = await this.saveUser(
          before._id,
          { $set: { status: 'ACTIVE' }, $inc: { permissionVersion: 1 } },
          session,
        );
        await this.customers.updateOne({ userId: before._id }, { $set: { blocked: null } }, { session }).exec();
        return saved;
      },
      describe: (user) => this.describe(user),
    });
    return this.get(id);
  }

  /** Signs the customer out of every device. They can sign in again at once. */
  async revokeSessions(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<{ signedOut: number }> {
    const user = await this.customerUser(id, { includeDeleted: false });
    let signedOut = 0;
    await this.changes.run({
      actor,
      client,
      action: 'customer.sessions-revoked',
      entityType: 'customer',
      before: this.describe(user),
      apply: async (session) => {
        signedOut = await this.sessions.revokeAllForUser(user._id.toHexString(), 'REVOKED_BY_USER', {
          dbSession: session,
        });
        return user;
      },
      describe: (record) => ({ ...this.describe(record), signedOut }),
    });
    return { signedOut };
  }

  /** Staff delete: the account disappears from the list and cannot sign in; `restore` brings it back. */
  async remove(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<void> {
    const before = await this.customerUser(id, { includeDeleted: false });
    await assertNoUpcomingBookings(this.connection, before._id, 'this customer');
    await this.changes.run({
      actor,
      client,
      action: 'customer.deleted',
      entityType: 'customer',
      before: this.describe(before),
      apply: async (session) => {
        const saved = await this.saveUser(
          before._id,
          { $set: { status: 'DEACTIVATED' }, $inc: { permissionVersion: 1 } },
          session,
        );
        await this.customers
          .updateOne({ userId: before._id }, { $set: { deletedAt: new Date() } }, { session })
          .exec();
        await this.sessions.revokeAllForUser(before._id.toHexString(), 'ACCOUNT_DISABLED', {
          dbSession: session,
        });
        return saved;
      },
      describe: (user) => ({ ...this.describe(user), deleted: true }),
    });
  }

  async restore(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<CustomerDetailView> {
    const before = await this.customerUser(id, { includeDeleted: true });
    const profile = await this.profileOf(before._id);
    if (!profile?.deletedAt) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This account is not deleted.');
    }
    if (profile.anonymisedAt) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'The customer deleted their own account and their personal data is gone. It cannot be brought back.',
      );
    }
    await this.changes.run({
      actor,
      client,
      action: 'customer.restored',
      entityType: 'customer',
      before: this.describe(before),
      apply: async (session) => {
        const saved = await this.saveUser(
          before._id,
          { $set: { status: 'ACTIVE' }, $inc: { permissionVersion: 1 } },
          session,
        );
        await this.customers
          .updateOne({ userId: before._id }, { $set: { deletedAt: null, blocked: null } }, { session })
          .exec();
        return saved;
      },
      describe: (user) => this.describe(user),
    });
    return this.get(id);
  }

  // ----- helpers -----

  private async saveUser(
    id: Types.ObjectId,
    update: Record<string, unknown>,
    session: import('mongoose').ClientSession,
  ): Promise<StoredCustomerUser> {
    const saved = await this.users
      .findOneAndUpdate({ _id: id, userType: 'CUSTOMER' }, update, {
        returnDocument: 'after',
        session,
      })
      .lean<StoredCustomerUser>()
      .exec();
    if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'This customer no longer exists.');
    return saved;
  }

  private async customerUser(
    id: string,
    options: { includeDeleted: boolean },
  ): Promise<StoredCustomerUser> {
    const user = Types.ObjectId.isValid(id)
      ? await this.users
          .findOne({ _id: new Types.ObjectId(id), userType: 'CUSTOMER' })
          .lean<StoredCustomerUser>()
          .exec()
      : null;
    if (!user) throw new ApiException('RESOURCE_NOT_FOUND', 'This customer no longer exists.');
    if (!options.includeDeleted) {
      const profile = await this.profileOf(user._id);
      if (profile?.deletedAt) {
        throw new ApiException('RESOURCE_NOT_FOUND', 'This customer no longer exists.');
      }
    }
    return user;
  }

  private profileOf(userId: Types.ObjectId): Promise<StoredCustomerProfile | null> {
    return this.customers.findOne({ userId }).lean<StoredCustomerProfile>().exec();
  }

  private rowOf(
    user: StoredCustomerUser,
    totals: { bookings: number; spentPaise: number } | undefined,
  ): CustomerRowView {
    return {
      ...profileViewOf(user),
      signInMethod: signInMethodOf(user),
      status: user.status,
      bookings: totals?.bookings ?? 0,
      spentPaise: totals?.spentPaise ?? 0,
    };
  }

  /** How many bookings and how much money, for a set of customers. Read-only. */
  private async bookingTotals(
    ids: Types.ObjectId[],
  ): Promise<Map<string, { bookings: number; spentPaise: number }>> {
    const result = new Map<string, { bookings: number; spentPaise: number }>();
    if (ids.length === 0) return result;
    const rows = await this.connection
      .collection('bookings')
      .aggregate<{ _id: Types.ObjectId; bookings: number; spentPaise: number }>([
        { $match: { customerId: { $in: ids }, status: { $in: COUNTED_STATUSES } } },
        {
          $group: {
            _id: '$customerId',
            bookings: { $sum: 1 },
            spentPaise: {
              $sum: { $cond: [{ $in: ['$status', PAID_STATUSES] }, '$amountPaise', 0] },
            },
          },
        },
      ])
      .toArray();
    for (const row of rows) {
      result.set(row._id.toHexString(), { bookings: row.bookings, spentPaise: row.spentPaise });
    }
    return result;
  }

  private async recentBookings(customerId: Types.ObjectId): Promise<CustomerBookingView[]> {
    const rows = await this.connection
      .collection('bookings')
      .find({ customerId })
      .sort({ createdAt: -1 })
      .limit(20)
      .toArray();
    return rows.map((row) => ({
      id: String(row['_id']),
      pnr: String(row['pnr'] ?? ''),
      status: String(row['status'] ?? ''),
      amountPaise: Number(row['amountPaise'] ?? 0),
      seats: Array.isArray(row['passengers']) ? row['passengers'].length : 0,
      bookedAt: row['createdAt'] instanceof Date ? row['createdAt'].toISOString() : null,
    }));
  }

  /** What the audit trail keeps: the name and the state, never the phone or the email. */
  private describe(user: User): Record<string, unknown> {
    return { name: user.name ?? '', status: user.status };
  }
}
