import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequestContextService } from '../../common/request-context/request-context.service';
import {
  type DomainEventHandler,
  DomainEventHandlerRegistry,
} from '../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../events/domain-event.types';
import { OutboxService } from '../../events/outbox.service';
import {
  NotificationDispatcher,
  type Recipient,
} from '../notifications/services/notification-dispatcher.service';
import { MessageSenderService } from '../messages/messages_admin_manage.service';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { UsersService } from '../users/services/users.service';
import { type AdminOperatorListQueryDto } from './operators_admin_manage';
import {
  type BankStatus,
  OPERATOR_MODEL,
  type Operator,
  type OperatorStatus,
  type PayoutMode,
} from './schemas/operator.schema';

// ===== 1. TYPES =====

/** Trips that still run: a suspension keeps them and their bookings. */
const RUNNING_TRIP_STATUSES = ['SCHEDULED', 'BOARDING', 'DEPARTED', 'IN_TRANSIT', 'DELAYED'];

type StoredOperator = Operator & { _id: Types.ObjectId; deletedAt?: Date | null };

interface OwnerAccount {
  _id: Types.ObjectId;
  name?: string;
  email?: string;
  phone?: string;
}

/** The owner as the Overview tab shows them: the operator's first administrator. */
export interface OperatorOwnerView {
  name: string | null;
  email: string | null;
  phone: string | null;
}

/** One row of the admin Operators list. */
export interface AdminOperatorRow {
  id: string;
  companyName: string;
  displayName: string | null;
  status: OperatorStatus;
  /** Status of the company KYC file (DRAFT, SUBMITTED, APPROVED, REJECTED...), null when none. */
  kycStatus: string | null;
  owner: OperatorOwnerView;
  buses: number;
  trips: number;
  joinedAt: string | null;
}

/** The operator detail page (#/operators/:id). */
export interface AdminOperatorDetail extends AdminOperatorRow {
  numbers: {
    buses: number;
    trips: number;
    /** Bookings and sales arrive with the booking journey (Phase 3); 0 until then. */
    bookings: number;
    salesPaise: number;
  };
  /** What a suspension leaves running (shown in the Suspend window). */
  impact: { upcomingTrips: number; confirmedBookings: number };
  suspension: {
    reason: string;
    proofNote: string | null;
    proofFileIds: string[];
    at: string;
    reactivatedAt: string | null;
  } | null;
  /** The Commission and payout tab: how Abra pays this operator and where. */
  payout: {
    mode: PayoutMode;
    /** Never the full account number: the last four digits only. */
    bank: {
      holderName: string;
      accountLast4: string;
      ifsc: string;
      bankName: string | null;
      status: BankStatus;
      method: string | null;
      note: string | null;
      verifiedAt: string | null;
    } | null;
  };
}

// ===== 2. READING =====

/**
 * The admin Operators list and the operator detail page: company, owner, KYC state and the
 * numbers behind the tabs. Suspend, reactivate and "Message owner" change or announce, each
 * audited, with the owner told through the notification service.
 */
@Injectable()
export class OperatorsAdminService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly outbox: OutboxService,
    private readonly roles: RoleRepository,
  ) {}

  private model<T>(name: string): Model<T> {
    return this.connection.model<T>(name);
  }

  async list(query: AdminOperatorListQueryDto): Promise<PaginatedResult<AdminOperatorRow>> {
    assertStaffRequest();
    const search = query.query ? new RegExp(escapeRegExp(query.query), 'i') : undefined;
    const match = {
      ...(query.status ? { status: query.status } : {}),
      ...(search ? { $or: [{ companyName: search }, { displayName: search }] } : {}),
    };
    const operators = this.model<Operator>(OPERATOR_MODEL);
    const [items, total] = await Promise.all([
      operators
        .find(match)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredOperator[]>()
        .exec(),
      operators.countDocuments(match).exec(),
    ]);
    const rows = await this.rowsOf(items);
    return new PaginatedResult(rows, query.page, query.pageSize, total);
  }

  async detail(id: string): Promise<AdminOperatorDetail> {
    assertStaffRequest();
    const operator = await this.require(id);
    const [row] = await this.rowsOf([operator]);
    const upcomingTrips = await this.model('Trip')
      .countDocuments({
        operatorId: operator._id,
        status: { $in: RUNNING_TRIP_STATUSES },
        departureAt: { $gte: new Date() },
      })
      .exec();
    const suspension = operator.suspension;
    return {
      ...row!,
      numbers: { buses: row!.buses, trips: row!.trips, bookings: 0, salesPaise: 0 },
      impact: { upcomingTrips, confirmedBookings: 0 },
      suspension: suspension
        ? {
            reason: suspension.reason,
            proofNote: suspension.proofNote ?? null,
            proofFileIds: (suspension.proofFileIds ?? []).map((fileId) => fileId.toHexString()),
            at: suspension.at.toISOString(),
            reactivatedAt: suspension.reactivatedAt?.toISOString() ?? null,
          }
        : null,
      payout: {
        mode: operator.payoutMode ?? 'MANUAL',
        bank: operator.bank
          ? {
              holderName: operator.bank.holderName,
              accountLast4: operator.bank.accountLast4,
              ifsc: operator.bank.ifsc,
              bankName: operator.bank.bankName ?? null,
              status: operator.bank.status,
              method: operator.bank.method ?? null,
              note: operator.bank.verificationNote ?? null,
              verifiedAt: operator.bank.verifiedAt?.toISOString() ?? null,
            }
          : null,
      },
    };
  }

  /** Owner, KYC state and counts of a page of operators, with one query per collection. */
  private async rowsOf(operators: readonly StoredOperator[]): Promise<AdminOperatorRow[]> {
    const ids = operators.map((operator) => operator._id);
    if (ids.length === 0) return [];
    const ownerRoles = (await this.roles.findAll())
      .filter((role) => role.key === 'OPERATOR_ADMIN')
      .map((role) => role._id);
    const countBy = async (model: string): Promise<Map<string, number>> => {
      const rows = await this.model(model)
        .aggregate<{ _id: Types.ObjectId; count: number }>([
          { $match: { operatorId: { $in: ids } } },
          { $group: { _id: '$operatorId', count: { $sum: 1 } } },
        ])
        .exec();
      return new Map(rows.map((row) => [row._id.toHexString(), row.count]));
    };
    const [buses, trips, owners, files] = await Promise.all([
      countBy('Bus'),
      countBy('Trip'),
      this.model<OwnerAccount & { operatorId: Types.ObjectId }>('User')
        .find({ operatorId: { $in: ids }, roleIds: { $in: ownerRoles } })
        .sort({ createdAt: 1 })
        .lean<Array<OwnerAccount & { operatorId: Types.ObjectId }>>()
        .exec(),
      this.model<{ operatorId: Types.ObjectId; status: string }>('OnboardingSubmission')
        .find({ operatorId: { $in: ids }, subjectType: 'OPERATOR' })
        .lean<Array<{ operatorId: Types.ObjectId; status: string }>>()
        .exec(),
    ]);
    const ownerOf = new Map<string, OwnerAccount>();
    for (const owner of owners) {
      const key = owner.operatorId.toHexString();
      if (!ownerOf.has(key)) ownerOf.set(key, owner);
    }
    const kycOf = new Map(files.map((file) => [file.operatorId.toHexString(), file.status]));
    return operators.map((operator) => {
      const key = operator._id.toHexString();
      const owner = ownerOf.get(key);
      return {
        id: key,
        companyName: operator.companyName,
        displayName: operator.displayName ?? null,
        status: operator.status,
        kycStatus: kycOf.get(key) ?? null,
        owner: {
          name: owner?.name ?? null,
          email: owner?.email ?? null,
          phone: owner?.phone ?? null,
        },
        buses: buses.get(key) ?? 0,
        trips: trips.get(key) ?? 0,
        joinedAt: operator.createdAt?.toISOString() ?? null,
      };
    });
  }

  // ===== 3. CHANGES =====

  /**
   * Suspends an active operator: its trips leave customer search at once (the search reads the
   * status), trips already sold keep running. The reason is shown to the owner; the proof note is
   * kept for Abra staff. Audited; the owner is told.
   */
  async suspend(
    actor: AuthenticatedUserActor,
    id: string,
    input: {
      reason: string;
      proofNote?: string | undefined;
      proofFileIds?: string[] | undefined;
    },
    client: ClientRequestInfo,
  ): Promise<AdminOperatorDetail> {
    assertStaff(actor);
    const before = await this.require(id);
    if (before.status !== 'ACTIVE') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Only an active operator can be suspended.',
      );
    }
    await this.changeStatus(actor, client, before, {
      action: 'operator.suspended',
      reason: input.reason,
      status: 'SUSPENDED',
      set: {
        suspension: {
          reason: input.reason,
          ...(input.proofNote ? { proofNote: input.proofNote } : {}),
          // Stored as given; the files service checks and links them once proof uploads exist
          ...(input.proofFileIds?.length
            ? { proofFileIds: input.proofFileIds.map((fileId) => new Types.ObjectId(fileId)) }
            : {}),
          at: new Date(),
          by: new Types.ObjectId(actor.userId),
        },
      },
      event: { type: 'operator.suspended', payload: { reason: input.reason } },
    });
    return this.detail(id);
  }

  /** Lets a suspended operator sell again. Audited; the owner is told. */
  async reactivate(
    actor: AuthenticatedUserActor,
    id: string,
    note: string | undefined,
    client: ClientRequestInfo,
  ): Promise<AdminOperatorDetail> {
    assertStaff(actor);
    const before = await this.require(id);
    if (before.status !== 'SUSPENDED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This operator is not suspended.');
    }
    await this.changeStatus(actor, client, before, {
      action: 'operator.reactivated',
      reason: note,
      status: 'ACTIVE',
      set: {
        'suspension.reactivatedAt': new Date(),
        'suspension.reactivatedBy': new Types.ObjectId(actor.userId),
      },
      event: { type: 'operator.reactivated', payload: {} },
    });
    return this.detail(id);
  }

  /**
   * "Message owner": the owner gets it in the portal (notification) and by email and WhatsApp
   * through the notification service. The text is kept in the audit trail.
   */
  async messageOwner(
    actor: AuthenticatedUserActor,
    id: string,
    message: string,
    client: ClientRequestInfo,
  ): Promise<{ sent: true }> {
    assertStaff(actor);
    const operator = await this.require(id);
    await this.changes.run<StoredOperator>({
      actor,
      client,
      action: 'operator.messaged',
      entityType: 'operator',
      before: {},
      operatorIdOf: (record) => record._id,
      apply: async (session) => {
        await this.outbox.record(eventOf('operator.messaged', operator, { message }), session);
        return operator;
      },
      describe: () => ({ message }),
    });
    return { sent: true };
  }

  /**
   * Chooses how Abra pays the operator. AUTO_SPLIT needs a verified bank account; settlements
   * already drafted keep the mode they were drafted with. Audited.
   */
  async setPayoutMode(
    actor: AuthenticatedUserActor,
    id: string,
    mode: PayoutMode,
    client: ClientRequestInfo,
  ): Promise<AdminOperatorDetail> {
    assertStaff(actor);
    const before = await this.require(id);
    const current = before.payoutMode ?? 'MANUAL';
    if (current === mode) return this.detail(id);
    if (mode === 'AUTO_SPLIT' && before.bank?.status !== 'VERIFIED') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'The bank account must be verified before payouts can be automatic.',
      );
    }
    await this.changes.run<StoredOperator>({
      actor,
      client,
      action: 'operator.payout-mode-changed',
      entityType: 'operator',
      before: { payoutMode: current },
      operatorIdOf: (record) => record._id,
      apply: async (session) => {
        const saved = await this.model<Operator>(OPERATOR_MODEL)
          .findOneAndUpdate(
            {
              _id: before._id,
              ...(mode === 'AUTO_SPLIT' ? { 'bank.status': 'VERIFIED' } : {}),
            },
            { $set: { payoutMode: mode } },
            { returnDocument: 'after', session },
          )
          .lean<StoredOperator>()
          .exec();
        if (!saved) throw changedMeanwhile();
        return saved;
      },
      describe: (record) => ({ payoutMode: record.payoutMode }),
    });
    return this.detail(id);
  }

  /**
   * Records the result of checking the operator's bank account by hand (the penny-drop check
   * arrives with the payment gateway). A pass lets payouts be automatic; a fail tells the owner
   * why, and an operator paid automatically goes back to manual payouts. Audited.
   */
  async verifyBank(
    actor: AuthenticatedUserActor,
    id: string,
    input: { outcome: 'VERIFIED' | 'FAILED'; note: string },
    client: ClientRequestInfo,
  ): Promise<AdminOperatorDetail> {
    assertStaff(actor);
    const before = await this.require(id);
    if (!before.bank) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This operator has not added a bank account.',
      );
    }
    if (before.bank.status === 'VERIFIED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This bank account is already verified.');
    }
    const previous = before.bank.status;
    const failed = input.outcome === 'FAILED';
    const droppedToManual = failed && before.payoutMode === 'AUTO_SPLIT';
    await this.changes.run<StoredOperator>({
      actor,
      client,
      action: failed ? 'operator.bank-failed' : 'operator.bank-verified',
      entityType: 'operator',
      before: { bankStatus: previous, payoutMode: before.payoutMode ?? 'MANUAL' },
      reason: input.note,
      operatorIdOf: (record) => record._id,
      apply: async (session) => {
        const saved = await this.model<Operator>(OPERATOR_MODEL)
          .findOneAndUpdate(
            { _id: before._id, 'bank.status': previous },
            {
              $set: {
                'bank.status': input.outcome,
                'bank.method': 'MANUAL',
                'bank.verificationNote': input.note,
                'bank.verifiedAt': new Date(),
                'bank.verifiedBy': new Types.ObjectId(actor.userId),
                ...(droppedToManual ? { payoutMode: 'MANUAL' } : {}),
              },
            },
            { returnDocument: 'after', session },
          )
          .lean<StoredOperator>()
          .exec();
        if (!saved) throw changedMeanwhile();
        await this.outbox.record(
          eventOf(
            failed ? 'operator.bank-failed' : 'operator.bank-verified',
            saved,
            failed ? { reason: input.note } : {},
          ),
          session,
        );
        return saved;
      },
      describe: (record) => ({
        bankStatus: record.bank?.status,
        payoutMode: record.payoutMode,
      }),
    });
    return this.detail(id);
  }

  private async changeStatus(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    before: StoredOperator,
    change: {
      action: 'operator.suspended' | 'operator.reactivated';
      reason: string | undefined;
      status: OperatorStatus;
      set: Record<string, unknown>;
      event: {
        type: 'operator.suspended' | 'operator.reactivated';
        payload: Record<string, unknown>;
      };
    },
  ): Promise<StoredOperator> {
    return this.changes.run<StoredOperator>({
      actor,
      client,
      action: change.action,
      entityType: 'operator',
      before: { status: before.status },
      reason: change.reason,
      operatorIdOf: (record) => record._id,
      apply: async (session: ClientSession) => {
        const saved = await this.model<Operator>(OPERATOR_MODEL)
          .findOneAndUpdate(
            { _id: before._id, status: before.status },
            { $set: { status: change.status, ...change.set } },
            { returnDocument: 'after', session },
          )
          .lean<StoredOperator>()
          .exec();
        if (!saved) {
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            'Someone changed this operator a moment ago. Reload the page.',
          );
        }
        await this.outbox.record(eventOf(change.event.type, saved, change.event.payload), session);
        return saved;
      },
      describe: (record) => ({ status: record.status }),
    });
  }

  private async require(id: string): Promise<StoredOperator> {
    const found = Types.ObjectId.isValid(id)
      ? await this.model<Operator>(OPERATOR_MODEL).findById(id).lean<StoredOperator>().exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Operator not found');
    return found;
  }
}

/**
 * The admin list and detail show every operator, so only Abra staff may read them (operator
 * staff also hold operators.read, for their own company).
 */
function assertStaffRequest(): void {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER' || (actor as AuthenticatedUserActor).userType !== 'STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'Only Abra staff can see this list.');
  }
}

function assertStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'Only Abra staff can do this.');
  }
}

function changedMeanwhile(): ApiException {
  return new ApiException(
    'INVALID_STATE_TRANSITION',
    'Someone changed this operator a moment ago. Reload the page.',
  );
}

function eventOf(
  type:
    | 'operator.suspended'
    | 'operator.reactivated'
    | 'operator.messaged'
    | 'operator.bank-verified'
    | 'operator.bank-failed',
  operator: StoredOperator,
  payload: Record<string, unknown>,
): { type: string; aggregateType: string; aggregateId: string; payload: Record<string, unknown> } {
  return {
    type,
    aggregateType: 'operator',
    aggregateId: operator._id.toHexString(),
    payload: {
      operatorId: operator._id.toHexString(),
      companyName: operator.displayName ?? operator.companyName,
      ...payload,
    },
  };
}

// ===== 4. TELLING THE OWNER =====

const text = (value: unknown): string => (typeof value === 'string' ? value : '');

/** The words the owner reads for an operator event. */
export function operatorNotice(
  event: DomainEventMessage,
): { title: string; body: string } | undefined {
  const payload = event.payload;
  switch (event.type) {
    case 'operator.suspended':
      return {
        title: 'Your company is suspended',
        body: `New sales are stopped. Trips already sold still run. Reason: ${text(payload.reason)}`.trim(),
      };
    case 'operator.reactivated':
      return {
        title: 'Your company is active again',
        body: `${text(payload.companyName)} can sell seats again.`,
      };
    case 'operator.messaged':
      return { title: 'Message from Abra Travels', body: text(payload.message) };
    case 'operator.bank-verified':
      return {
        title: 'Your bank account is verified',
        body: 'Abra can now pay out to this account.',
      };
    case 'operator.bank-failed':
      return {
        title: 'Your bank account could not be verified',
        body: `Please check the details and add the account again. Reason: ${text(payload.reason)}`.trim(),
      };
    default:
      return undefined;
  }
}

/** Sends operator events to the operator's administrators. Runs in the worker. */
@Injectable()
export class OperatorNotificationHandler implements DomainEventHandler, OnModuleInit {
  readonly name = 'operator-notifications';
  readonly eventTypes = [
    'operator.suspended',
    'operator.reactivated',
    'operator.messaged',
    'operator.bank-verified',
    'operator.bank-failed',
  ];
  private readonly logger = new Logger(OperatorNotificationHandler.name);

  constructor(
    private readonly registry: DomainEventHandlerRegistry,
    private readonly dispatcher: NotificationDispatcher,
    private readonly messages: MessageSenderService,
    private readonly roles: RoleRepository,
    private readonly users: UsersService,
  ) {}

  onModuleInit(): void {
    this.registry.register(this);
  }

  async handle(event: DomainEventMessage): Promise<void> {
    const notice = operatorNotice(event);
    if (!notice) return;
    const owners = await this.users.findActiveByRoleIds(
      (await this.roles.findAll())
        .filter((role) => role.key === 'OPERATOR_ADMIN')
        .map((role) => role._id),
      { operatorId: new Types.ObjectId(text(event.payload.operatorId)) },
    );
    if (owners.length === 0) {
      this.logger.warn({ eventId: event.eventId }, 'Operator has no administrator to tell');
      return;
    }
    let failed = 0;
    for (const owner of owners) {
      // In the portal only (record, live and push): no email or phone here, so the dispatcher
      // skips those; email and WhatsApp go through the message log below, which can be resent
      const inApp: Recipient = { userId: owner._id };
      const ok = await this.dispatcher.deliver(inApp, {
        eventId: event.eventId,
        type: event.type,
        title: notice.title,
        body: notice.body,
        data: { operatorId: text(event.payload.operatorId), route: '/dashboard' },
      });
      if (!ok) failed += 1;
      for (const [channel, address] of [
        ['WHATSAPP', owner.phone],
        ['EMAIL', owner.email],
      ] as const) {
        if (!address) continue;
        const sent = await this.messages.send({
          channel,
          kind: 'GENERAL',
          userId: owner._id,
          recipientName: owner.name ?? 'Owner',
          address,
          subject: notice.title,
          body: notice.body,
          eventId: event.eventId,
        });
        if (sent.status === 'FAILED') failed += 1;
      }
    }
    if (failed > 0) throw new Error(`${failed} recipient(s) had a channel that failed; will retry`);
  }
}
