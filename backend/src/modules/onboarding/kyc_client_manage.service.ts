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
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { TransactionRunner } from '../../database/transaction-runner.service';
import {
  DOCUMENT_TYPE_MODEL,
  type DocumentType,
} from '../document-types/schemas/document-type.schema';
import { type StoredDocumentType } from '../document-types/repositories/document-type.repository';
import { documentTypeViewOf } from '../document-types/services/document-types.service';
import {
  KYC_CONFIGURATION_MODEL,
  type KycAnswers,
  type KycConfiguration,
  resolveKycRequirements,
} from '../system-settings/admin_kyc_configuration';
import { type ClientKycSnapshot, kycProblems } from './client_kyc';
import {
  ONBOARDING_SUBMISSION_MODEL,
  type OnboardingSubmission,
} from './schemas/onboarding-submission.schema';
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

// ===== BUS KYC (Phase 1 step 9): the bus questions before its documents =====

interface BusRecord {
  _id: Types.ObjectId;
  operatorId: Types.ObjectId;
  registrationNumber: string;
  name?: string;
  status: string;
}

type StoredBusFile = OnboardingSubmission & { _id: Types.ObjectId };

/** What the bus KYC wizard shows. */
export interface BusKycView {
  busId: string;
  registrationNumber: string;
  busName: string | null;
  submissionId: string;
  status: string;
  /** True when Abra set bus questions or bus document rules: the wizard starts with questions. */
  hasQuestions: boolean;
  kyc: ClientKycSnapshot | null;
  problems: string[];
}

/**
 * Bus KYC from the client portal, only for a company Abra has approved. When the KYC
 * questionnaire has bus questions or bus document rules, the owner answers them first and the
 * answers decide which documents the bus needs (a snapshot kept for this review, as for the
 * company); without them every active bus document type applies, as before. Documents, submit
 * and corrections use the bus file's own document routes; after a rejection only the rejected
 * documents can change and the answers stay as they were.
 */
@Injectable()
export class BusKycClientService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    private readonly transactions: TransactionRunner,
  ) {}

  private model<T>(name: string): Model<T> {
    return this.connection.model<T>(name);
  }

  async describe(actor: AuthenticatedUserActor, busId: string): Promise<BusKycView> {
    const { bus, file } = await this.fileOf(actor, busId);
    return {
      busId: bus._id.toHexString(),
      registrationNumber: bus.registrationNumber,
      busName: bus.name ?? null,
      submissionId: file._id.toHexString(),
      status: file.status,
      hasQuestions: file.kycRequired === true,
      kyc: file.kyc ?? null,
      problems: kycProblems(file),
    };
  }

  /** Saves the answers and the documents they ask for, while the file can be edited. */
  async saveAnswers(
    actor: AuthenticatedUserActor,
    busId: string,
    answers: KycAnswers,
  ): Promise<BusKycView> {
    const { file } = await this.fileOf(actor, busId);
    if (!file.kyc) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This bus has no questions to answer. Add its documents.',
      );
    }
    if (!['DRAFT', 'REJECTED'].includes(file.status)) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This bus file was sent for review. Wait for the decision.',
      );
    }
    if (
      file.status === 'REJECTED' &&
      JSON.stringify(answers) !== JSON.stringify(file.kyc.answers)
    ) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Keep your answers while you correct the rejected documents.',
      );
    }
    const kyc = file.kyc;
    const result = resolveKycRequirements(kyc.configuration, kyc.documentCatalogue, 'BUS', answers);
    if (result.missingQuestions.length > 0) {
      throw new ApiException('VALIDATION_FAILED', 'Answer all required questions.');
    }
    if (result.documents.length === 0) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'Abra has not set which documents a bus needs for these answers. Contact Abra support.',
      );
    }
    await this.model<OnboardingSubmission>(ONBOARDING_SUBMISSION_MODEL)
      .updateOne(
        { _id: file._id, status: file.status },
        { $set: { kyc: { ...kyc, answers, requirements: result.documents } } },
      )
      .exec();
    return this.describe(actor, busId);
  }

  /** The bus and its review file; the file is made the first time (with the questions, if any). */
  private async fileOf(
    actor: AuthenticatedUserActor,
    busId: string,
  ): Promise<{ bus: BusRecord; file: StoredBusFile }> {
    if (actor.userType !== 'OPERATOR_STAFF' || actor.dataScope.type === 'ALL') {
      throw new ApiException('PERMISSION_DENIED', 'Bus KYC is done from the operator portal.');
    }
    const operatorId = operatorForNewRecord(actor, undefined);
    const operator = await this.model<Operator>(OPERATOR_MODEL)
      .findById(operatorId)
      .lean<Operator & { _id: Types.ObjectId }>()
      .exec();
    if (!operator) throw new ApiException('RESOURCE_NOT_FOUND', 'Company not found');
    if (operator.status !== 'ACTIVE') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Your company must be approved by Abra before you send bus documents.',
      );
    }
    const bus = Types.ObjectId.isValid(busId)
      ? await this.model<BusRecord>('Bus')
          .findOne({ _id: new Types.ObjectId(busId), operatorId })
          .lean<BusRecord>()
          .exec()
      : null;
    // Another operator's bus does not exist for the caller
    if (!bus) throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found');
    const files = this.model<OnboardingSubmission>(ONBOARDING_SUBMISSION_MODEL);
    const findFile = () =>
      files.findOne({ subjectType: 'BUS', busId: bus._id }).lean<StoredBusFile>().exec();
    const existing = await findFile();
    if (existing) return { bus, file: await this.withQuestions(existing) };
    if (bus.status !== 'PENDING_APPROVAL') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This bus does not need approval.');
    }
    try {
      const [created] = await this.transactions.run((session: ClientSession) =>
        files.create(
          [
            {
              operatorId: bus.operatorId,
              subjectType: 'BUS',
              busId: bus._id,
              status: 'DRAFT',
              documents: [],
              submitCount: 0,
              history: [
                { at: new Date(), action: 'CREATED', byUserId: new Types.ObjectId(actor.userId) },
              ],
            },
          ],
          { session },
        ),
      );
      if (!created) throw new Error('The bus file was not created');
      return { bus, file: await this.withQuestions(created.toObject()) };
    } catch (error) {
      if (!isDuplicateKeyError(error)) throw error;
      // Made by a request that ran at the same moment
      const winner = await findFile();
      if (!winner) throw error;
      return { bus, file: await this.withQuestions(winner) };
    }
  }

  /**
   * A new draft bus file gets a snapshot when Abra has set bus questions or rules, so the
   * questions asked do not change during this review.
   */
  private async withQuestions(file: StoredBusFile): Promise<StoredBusFile> {
    if (file.kyc || file.status !== 'DRAFT' || file.documents.length > 0) return file;
    const [config, documents] = await Promise.all([
      this.model<KycConfiguration & { version?: number }>(KYC_CONFIGURATION_MODEL)
        .findOne()
        .lean<KycConfiguration & { version?: number }>()
        .exec(),
      this.model<DocumentType>(DOCUMENT_TYPE_MODEL).find().lean<StoredDocumentType[]>().exec(),
    ]);
    const configuration: KycConfiguration = {
      schemaVersion: 1,
      questions: config?.questions ?? [],
      rules: config?.rules ?? [],
    };
    const asksBus =
      configuration.questions.some((q) => q.active && q.appliesTo === 'BUS') ||
      configuration.rules.some((r) => r.active && r.appliesTo === 'BUS');
    if (!asksBus) return file;
    const documentCatalogue = documents.map(documentTypeViewOf);
    const kyc: ClientKycSnapshot = {
      version: config?.version ?? 0,
      configuration,
      answers: {},
      documentCatalogue,
      requirements: resolveKycRequirements(configuration, documentCatalogue, 'BUS', {}).documents,
      // A bus has no introduction screen: the company read it already
      introductionAcceptedAt: new Date().toISOString(),
    };
    const files = this.model<OnboardingSubmission>(ONBOARDING_SUBMISSION_MODEL);
    await files
      .updateOne(
        { _id: file._id, status: 'DRAFT', kyc: { $exists: false } },
        { $set: { kyc, kycRequired: true } },
      )
      .exec();
    return (await files.findById(file._id).lean<StoredBusFile>().exec()) ?? file;
  }
}

// ===== KYC HISTORY (Phase 1 step 9): what happened to a company or bus file =====

const HISTORY_LABELS: Readonly<Record<string, string>> = {
  CREATED: 'Started',
  SUBMITTED: 'Submitted',
  RESUBMITTED: 'Corrections sent',
  DOCUMENT_APPROVED: 'Document accepted',
  DOCUMENT_REJECTED: 'Document rejected',
  APPROVED: 'Approved',
  REJECTED: 'Sent back for fixing',
};

/** One line of a KYC file's history, newest last. */
export interface KycHistoryEntryView {
  at: string;
  action: string;
  /** The words the demo shows ("Submitted", "Approved"). */
  label: string;
  /** Who did it: a person's name, or "Abra Travels" for staff when the viewer is the operator. */
  by: string | null;
  documentName: string | null;
  note: string | null;
}

/**
 * The History of a KYC file (admin "History" button, client waiting screen). Abra staff see any
 * file and who on their team acted; operator staff see only their own company's files.
 */
@Injectable()
export class KycHistoryService {
  constructor(@InjectConnection() private readonly connection: Connection) {}

  async history(actor: AuthenticatedUserActor, id: string): Promise<KycHistoryEntryView[]> {
    const isStaff = actor.userType === 'STAFF';
    const own = actor.dataScope.operatorIds.map((operatorId) => new Types.ObjectId(operatorId));
    const file = Types.ObjectId.isValid(id)
      ? await this.connection
          .model<OnboardingSubmission>(ONBOARDING_SUBMISSION_MODEL)
          .findOne({
            _id: new Types.ObjectId(id),
            ...(isStaff && actor.dataScope.type === 'ALL' ? {} : { operatorId: { $in: own } }),
          })
          .lean<StoredBusFile>()
          .exec()
      : null;
    // Another operator's file does not exist for the caller
    if (!file) throw new ApiException('RESOURCE_NOT_FOUND', 'Verification file not found.');
    const people = await this.connection
      .model<{ name?: string; userType: string }>('User')
      .find({ _id: { $in: file.history.map((entry) => entry.byUserId) } })
      .lean<Array<{ _id: Types.ObjectId; name?: string; userType: string }>>()
      .exec();
    const byId = new Map(people.map((person) => [person._id.toHexString(), person]));
    const documentNames = new Map(
      (file.kyc?.documentCatalogue ?? []).map((type) => [type.key, type.name]),
    );
    return file.history.map((entry) => {
      const person = byId.get(entry.byUserId.toHexString());
      const by = person?.userType === 'STAFF' && !isStaff ? 'Abra Travels' : (person?.name ?? null);
      return {
        at: entry.at.toISOString(),
        action: entry.action,
        label: HISTORY_LABELS[entry.action] ?? entry.action,
        by,
        documentName: entry.documentTypeKey
          ? (documentNames.get(entry.documentTypeKey) ?? entry.documentTypeKey)
          : null,
        note: entry.note ?? null,
      };
    });
  }
}
