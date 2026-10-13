import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, Types } from 'mongoose';
import { FieldEncryptionService } from '../../common/crypto/field-encryption.service';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { operatorForNewRecord } from '../../common/request-context/operator-scope';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import {
  type DomainEventHandler,
  DomainEventHandlerRegistry,
} from '../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../events/domain-event.types';
import { OutboxService } from '../../events/outbox.service';
import { OPERATOR_MODEL, type Operator } from '../operators/schemas/operator.schema';
import { NotificationDispatcher } from '../notifications/services/notification-dispatcher.service';
import { ALL_PERMISSIONS_WILDCARD } from '../rbac/permissions/permission-registry';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { UsersService } from '../users/services/users.service';

// ===== 1. TYPES =====

type StoredOperator = Operator & { _id: Types.ObjectId };

/** The Company profile page of the client portal (`GET client/company`). */
export interface CompanyView {
  id: string;
  companyName: string;
  ownerName: string;
  email: string;
  supportPhone: string;
  city: string;
  gstin: string;
  /** Set by Abra; the operator only reads it. */
  payoutMode: 'AUTO_SPLIT' | 'MANUAL';
  /** Never the full account number: the last four digits only. */
  bank: {
    holderName: string;
    accountLast4: string;
    ifsc: string;
    status: 'PENDING' | 'VERIFIED' | 'FAILED';
    /** Why Abra could not verify it. */
    note: string | null;
  } | null;
}

export interface CompanyProfileInput {
  companyName: string;
  ownerName: string;
  email: string;
  supportPhone?: string | undefined;
  city?: string | undefined;
  gstin?: string | undefined;
}

export interface CompanyBankInput {
  holderName: string;
  accountNumber: string;
  ifsc: string;
}

// ===== 2. THE OPERATOR'S OWN COMPANY =====

/**
 * The client portal Company profile page: an operator reads and edits what customers and Abra
 * see about its company, and adds the bank account its payouts go to. Everyone sees only their own
 * operator. A changed bank account goes back to PENDING (and automatic payouts to manual) until
 * Abra verifies it; Abra staff are told.
 */
@Injectable()
export class CompanyClientService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly outbox: OutboxService,
    private readonly encryption: FieldEncryptionService,
  ) {}

  private get operators(): Model<Operator> {
    return this.connection.model<Operator>(OPERATOR_MODEL);
  }

  async get(actor: AuthenticatedUserActor): Promise<CompanyView> {
    return this.viewOf(await this.own(actor));
  }

  async updateProfile(
    actor: AuthenticatedUserActor,
    input: CompanyProfileInput,
    client: ClientRequestInfo,
  ): Promise<CompanyView> {
    const before = await this.own(actor);
    const contact = {
      ownerName: input.ownerName,
      email: input.email,
      supportPhone: input.supportPhone ?? '',
      city: input.city ?? '',
      gstin: input.gstin ?? '',
    };
    const saved = await this.changes.run<StoredOperator>({
      actor,
      client,
      action: 'operator.profile-updated',
      entityType: 'operator',
      before: { companyName: before.companyName, ...before.contact },
      operatorIdOf: (record) => record._id,
      apply: async (session) =>
        this.save(before._id, session, { companyName: input.companyName, contact }),
      describe: (record) => ({ companyName: record.companyName, ...record.contact }),
    });
    return this.viewOf(saved);
  }

  /**
   * Adds or replaces the bank account. The number is stored encrypted and is never returned or
   * written to the audit trail (only its last four digits). Verification starts again.
   */
  async saveBank(
    actor: AuthenticatedUserActor,
    input: CompanyBankInput,
    client: ClientRequestInfo,
  ): Promise<CompanyView> {
    const before = await this.own(actor);
    const last4 = input.accountNumber.slice(-4);
    const saved = await this.changes.run<StoredOperator>({
      actor,
      client,
      action: 'operator.bank-changed',
      entityType: 'operator',
      before: {
        bankLast4: before.bank?.accountLast4 ?? null,
        bankStatus: before.bank?.status ?? null,
      },
      operatorIdOf: (record) => record._id,
      apply: async (session) => {
        const record = await this.save(before._id, session, {
          bank: {
            holderName: input.holderName,
            accountNumberEncrypted: this.encryption.encrypt(input.accountNumber),
            accountLast4: last4,
            ifsc: input.ifsc,
            status: 'PENDING',
            addedAt: new Date(),
          },
          // Payouts wait for Abra to verify the new account
          payoutMode: 'MANUAL',
        });
        await this.outbox.record(
          {
            type: 'operator.bank-changed',
            aggregateType: 'operator',
            aggregateId: record._id.toHexString(),
            payload: {
              operatorId: record._id.toHexString(),
              companyName: record.displayName ?? record.companyName,
            },
          },
          session,
        );
        return record;
      },
      describe: (record) => ({
        bankLast4: record.bank?.accountLast4,
        bankStatus: record.bank?.status,
      }),
    });
    return this.viewOf(saved);
  }

  private async save(
    id: Types.ObjectId,
    session: ClientSession,
    set: Record<string, unknown>,
  ): Promise<StoredOperator> {
    const saved = await this.operators
      .findOneAndUpdate({ _id: id }, { $set: set }, { returnDocument: 'after', session })
      .lean<StoredOperator>()
      .exec();
    if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Company not found');
    return saved;
  }

  /** The caller's own operator; platform staff have no company of their own. */
  private async own(actor: AuthenticatedUserActor): Promise<StoredOperator> {
    if (actor.userType !== 'OPERATOR_STAFF' || actor.dataScope.type === 'ALL') {
      throw new ApiException(
        'PERMISSION_DENIED',
        'The company profile belongs to the operator. Abra staff use the Operators page.',
      );
    }
    const id = operatorForNewRecord(actor, undefined);
    const found = await this.operators.findById(id).lean<StoredOperator>().exec();
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Company not found');
    return found;
  }

  /** What was not typed yet falls back to the owner's own account. */
  private async viewOf(operator: StoredOperator): Promise<CompanyView> {
    const contact = operator.contact ?? {};
    const needsOwner = !contact.ownerName || !contact.email;
    const owner = needsOwner
      ? await this.connection
          .model<{ name?: string; email?: string }>('User')
          .findOne({ operatorId: operator._id })
          .sort({ createdAt: 1 })
          .lean<{ name?: string; email?: string }>()
          .exec()
      : null;
    return {
      id: operator._id.toHexString(),
      companyName: operator.companyName,
      ownerName: contact.ownerName ?? owner?.name ?? '',
      email: contact.email ?? owner?.email ?? '',
      supportPhone: contact.supportPhone ?? '',
      city: contact.city ?? '',
      gstin: contact.gstin ?? '',
      payoutMode: operator.payoutMode ?? 'MANUAL',
      bank: operator.bank
        ? {
            holderName: operator.bank.holderName,
            accountLast4: operator.bank.accountLast4,
            ifsc: operator.bank.ifsc,
            status: operator.bank.status,
            note:
              operator.bank.status === 'FAILED' ? (operator.bank.verificationNote ?? null) : null,
          }
        : null,
    };
  }
}

// ===== 3. TELLING ABRA =====

const text = (value: unknown): string => (typeof value === 'string' ? value : '');

/** The words Abra staff read when an operator changes its bank account. */
export function bankChangedNotice(
  event: DomainEventMessage,
): { title: string; body: string } | undefined {
  if (event.type !== 'operator.bank-changed') return undefined;
  return {
    title: 'Bank account changed',
    body: `${text(event.payload.companyName)} changed the payout bank account. Verify it.`,
  };
}

/** Tells the staff who can verify bank accounts. Runs in the worker. */
@Injectable()
export class CompanyNotificationHandler implements DomainEventHandler, OnModuleInit {
  readonly name = 'company-notifications';
  readonly eventTypes = ['operator.bank-changed'];
  private readonly logger = new Logger(CompanyNotificationHandler.name);

  constructor(
    private readonly registry: DomainEventHandlerRegistry,
    private readonly dispatcher: NotificationDispatcher,
    private readonly roles: RoleRepository,
    private readonly users: UsersService,
  ) {}

  onModuleInit(): void {
    this.registry.register(this);
  }

  async handle(event: DomainEventMessage): Promise<void> {
    const notice = bankChangedNotice(event);
    if (!notice) return;
    const approvers = (
      await this.users.findActiveByRoleIds(
        (await this.roles.findAll())
          .filter(
            (role) =>
              role.permissionKeys.includes(ALL_PERMISSIONS_WILDCARD) ||
              role.permissionKeys.includes('operators.approve'),
          )
          .map((role) => role._id),
      )
    ).filter((user) => user.userType === 'STAFF');
    if (approvers.length === 0) {
      this.logger.warn({ eventId: event.eventId }, 'Nobody to tell about a bank account change');
      return;
    }
    let failed = 0;
    for (const user of approvers) {
      const ok = await this.dispatcher.deliver(
        { userId: user._id, email: user.email, phone: user.phone },
        {
          eventId: event.eventId,
          type: event.type,
          title: notice.title,
          body: notice.body,
          data: {
            operatorId: text(event.payload.operatorId),
            route: `/operators/${text(event.payload.operatorId)}`,
          },
        },
      );
      if (!ok) failed += 1;
    }
    if (failed > 0) throw new Error(`${failed} recipient(s) had a channel that failed; will retry`);
  }
}
