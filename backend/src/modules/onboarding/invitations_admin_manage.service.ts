import { randomBytes } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { OPERATOR_MODEL, type Operator } from '../operators/schemas/operator.schema';
import { UsersService } from '../users/services/users.service';
import { InvitationRepository } from './repositories/invitation.repository';
import { type OnboardingInvitation } from './schemas/onboarding-invitation.schema';
import { hashToken, type InvitationView, invitationViewOf } from './services/invitations.service';
import { OnboardingAuditor } from './services/onboarding-auditor';

/** What an edit of a pending invitation may change. `null` clears the phone number. */
export interface InvitationChange {
  companyName?: string | undefined;
  ownerName?: string | undefined;
  email?: string | undefined;
  phone?: string | null | undefined;
  expiresAt?: Date | undefined;
}

const DAY_MS = 24 * 60 * 60 * 1000;
/** An invitation can be kept open for at most this long from now. */
export const MAX_INVITATION_DAYS = 30;

/**
 * Reading and editing one invitation. Only a pending one (valid or expired) can be edited. A new
 * email address makes the old link useless (a fresh secret replaces it) and the invitation must
 * be sent again; otherwise whoever holds the old link could create an account for the new address.
 */
@Injectable()
export class InvitationsManageService {
  constructor(
    private readonly invitations: InvitationRepository,
    private readonly users: UsersService,
    private readonly transactions: TransactionRunner,
    private readonly auditor: OnboardingAuditor,
    @InjectModel(OPERATOR_MODEL) private readonly operators: Model<Operator>,
  ) {}

  async get(id: string): Promise<InvitationView> {
    return invitationViewOf(await this.require(id));
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    change: InvitationChange,
    client: ClientRequestInfo,
  ): Promise<InvitationView> {
    const before = await this.require(id);
    if (before.status !== 'PENDING') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Only a pending invitation can be edited.',
      );
    }
    if (
      change.expiresAt &&
      change.expiresAt.getTime() > Date.now() + MAX_INVITATION_DAYS * DAY_MS
    ) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `An invitation can stay open for at most ${MAX_INVITATION_DAYS} days from today.`,
      );
    }
    const email = change.email?.toLowerCase();
    const emailChanged = email !== undefined && email !== before.email;
    if (emailChanged && (await this.users.findByLoginIdentifier(email))) {
      throw new ApiException('ALREADY_REGISTERED', 'An account already exists for this email.');
    }

    const set: Partial<OnboardingInvitation> = {};
    if (change.companyName !== undefined) set.companyName = change.companyName;
    if (change.ownerName !== undefined) set.ownerName = change.ownerName;
    if (change.phone !== undefined) set.phone = change.phone ?? '';
    if (change.expiresAt !== undefined) set.expiresAt = change.expiresAt;
    if (emailChanged) {
      set.email = email;
      set.tokenHash = hashToken(randomBytes(32).toString('base64url'));
      set.emailStatus = 'NOT_SENT';
    }
    const changed = Object.keys(set).filter((key) => key !== 'tokenHash');
    if (changed.length === 0) return invitationViewOf(before);

    try {
      const saved = await this.transactions.run(async (session) => {
        const updated = await this.invitations.update(before._id, 'PENDING', set, session);
        if (!updated) {
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            'Only a pending invitation can be edited.',
          );
        }
        if (set.companyName !== undefined) {
          // The company is still awaiting approval: its name follows the invitation
          await this.operators.updateOne(
            { _id: before.operatorId, status: 'PENDING_APPROVAL' },
            { $set: { companyName: set.companyName } },
            { session },
          );
        }
        await this.auditor.record(
          {
            actor,
            action: 'onboarding.invitation-updated',
            entityType: 'onboarding_invitation',
            entityId: updated._id,
            operatorId: updated.operatorId,
            before: pick(before, changed),
            after: {
              ...pick(updated, changed),
              ...(emailChanged ? { linkInvalidated: true } : {}),
            },
            client,
          },
          session,
        );
        return updated;
      });
      return invitationViewOf(saved);
    } catch (error) {
      if (isDuplicateKeyError(error)) {
        throw new ApiException(
          'ALREADY_REGISTERED',
          'This email has already been invited. Resend that invitation instead.',
        );
      }
      throw error;
    }
  }

  private async require(id: string) {
    const found = Types.ObjectId.isValid(id) ? await this.invitations.findById(id) : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Invitation not found');
    return found;
  }
}

/** The named fields of a record, dates as text, for the audit trail. Never the link's secret. */
function pick(record: object, fields: readonly string[]): Record<string, unknown> {
  const source = record as Record<string, unknown>;
  const result: Record<string, unknown> = {};
  for (const field of fields) {
    const value = source[field];
    result[field] = value instanceof Date ? value.toISOString() : value;
  }
  return result;
}
