import { createHash, randomBytes } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { dayRange, skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { EmailDeliveryError, EmailService } from '../../../integrations/email/email.service';
import { PasswordHasher } from '../../authentication/services/password-hasher.service';
import { assertPasswordAcceptable } from '../../authentication/services/password-policy';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { RoleRepository } from '../../rbac/repositories/role.repository';
import { UsersService } from '../../users/services/users.service';
import {
  type AcceptInvitationDto,
  type InvitationListQueryDto,
  type InviteClientDto,
} from '../dto/onboarding.dto';
import { InvitationRepository, type StoredInvitation } from '../repositories/invitation.repository';
import { SubmissionRepository } from '../repositories/submission.repository';
import { OnboardingAuditor } from './onboarding-auditor';

const INVITATION_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface InvitationView {
  id: string;
  operatorId: string;
  companyName: string;
  ownerName: string;
  email: string;
  phone: string | null;
  status: string;
  /** True when the link is still valid; a pending invitation past its date is expired. */
  expired: boolean;
  expiresAt: string;
  emailStatus: string;
  /** Why the email was not sent, when it was not. */
  emailProblem: string | null;
  /**
   * The link the owner follows. Only outside production, so a developer without a mail server
   * can still sign an owner up; in production the link exists only in the email.
   */
  inviteUrl?: string;
  createdAt: string | null;
}

export interface InvitationPreview {
  companyName: string;
  ownerName: string;
  email: string;
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function invalidLink(): ApiException {
  return new ApiException(
    'RESOURCE_NOT_FOUND',
    'This invitation link is not valid or has expired.',
  );
}

/**
 * Inviting a bus owner: platform staff create the company and send a link; the owner follows it
 * and sets a password, which creates their account (OPERATOR_ADMIN of that company only). The link
 * carries a random token of which only a hash is kept, valid for seven days, usable once.
 */
@Injectable()
export class InvitationsService {
  constructor(
    private readonly invitations: InvitationRepository,
    private readonly submissions: SubmissionRepository,
    private readonly operators: OperatorRepository,
    private readonly users: UsersService,
    private readonly roles: RoleRepository,
    private readonly hasher: PasswordHasher,
    private readonly email: EmailService,
    private readonly config: AppConfigService,
    private readonly transactions: TransactionRunner,
    private readonly auditor: OnboardingAuditor,
  ) {}

  async invite(
    actor: AuthenticatedUserActor,
    input: InviteClientDto,
    client: ClientRequestInfo,
  ): Promise<InvitationView> {
    const email = input.email.toLowerCase();
    if (await this.users.findByLoginIdentifier(email)) {
      throw new ApiException('ALREADY_REGISTERED', 'An account already exists for this email.');
    }
    const token = newToken();
    const actorId = new Types.ObjectId(actor.userId);

    let created: StoredInvitation;
    try {
      created = await this.transactions.run(async (session) => {
        const operator = await this.operators.insertOne(
          {
            companyName: input.companyName,
            ...(input.displayName ? { displayName: input.displayName } : {}),
            status: 'PENDING_APPROVAL',
          },
          { session },
        );
        await this.submissions.insertOne(
          {
            operatorId: operator._id,
            subjectType: 'OPERATOR',
            status: 'DRAFT',
            documents: [],
            submitCount: 0,
            history: [{ at: new Date(), action: 'CREATED', byUserId: actorId }],
          },
          { session },
        );
        const invitation = await this.invitations.insert(
          {
            operatorId: operator._id,
            companyName: input.companyName,
            email,
            ownerName: input.ownerName,
            ...(input.phone ? { phone: input.phone } : {}),
            tokenHash: hashToken(token),
            expiresAt: new Date(Date.now() + INVITATION_DAYS * DAY_MS),
            status: 'PENDING',
            invitedBy: actorId,
            emailStatus: 'NOT_SENT',
          },
          session,
        );
        await this.auditor.record(
          {
            actor,
            action: 'onboarding.invited',
            entityType: 'onboarding_invitation',
            entityId: invitation._id,
            operatorId: operator._id,
            before: {},
            after: { companyName: input.companyName, email, ownerName: input.ownerName },
            client,
          },
          session,
        );
        return invitation;
      });
    } catch (error) {
      if (isDuplicateKeyError(error)) {
        throw new ApiException(
          'ALREADY_REGISTERED',
          'This email has already been invited. Resend that invitation instead.',
        );
      }
      throw error;
    }
    return this.deliver(created, token);
  }

  async list(query: InvitationListQueryDto): Promise<PaginatedResult<InvitationView>> {
    const now = new Date();
    const { items, total } = await this.invitations.list(
      {
        status: query.status === 'EXPIRED' ? 'PENDING' : query.status,
        ...(query.status === 'EXPIRED' ? { expiresAt: { $lt: now } } : {}),
        ...(query.status === 'PENDING' ? { expiresAt: { $gte: now } } : {}),
        createdAt: dayRange(query),
        search: query.search,
      },
      { skip: skipOf(query), limit: query.pageSize },
    );
    return new PaginatedResult(
      items.map((item) => this.viewOf(item)),
      query.page,
      query.pageSize,
      total,
    );
  }

  /** A new link (the old one stops working) and a new seven days. */
  async resend(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<InvitationView> {
    const before = await this.pending(id);
    const token = newToken();
    const updated = await this.transactions.run(async (session) => {
      const saved = await this.invitations.update(
        before._id,
        'PENDING',
        {
          tokenHash: hashToken(token),
          expiresAt: new Date(Date.now() + INVITATION_DAYS * DAY_MS),
          emailStatus: 'NOT_SENT',
        },
        session,
      );
      if (!saved) throw invalidState();
      await this.auditor.record(
        {
          actor,
          action: 'onboarding.invitation-resent',
          entityType: 'onboarding_invitation',
          entityId: saved._id,
          operatorId: saved.operatorId,
          before: { expiresAt: before.expiresAt.toISOString() },
          after: { expiresAt: saved.expiresAt.toISOString() },
          client,
        },
        session,
      );
      return saved;
    });
    return this.deliver(updated, token);
  }

  /** Withdraws an invitation that was not accepted. The company stays, awaiting a new invitation. */
  async revoke(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<InvitationView> {
    const before = await this.pending(id);
    const updated = await this.transactions.run(async (session) => {
      const saved = await this.invitations.update(
        before._id,
        'PENDING',
        { status: 'REVOKED' },
        session,
      );
      if (!saved) throw invalidState();
      await this.auditor.record(
        {
          actor,
          action: 'onboarding.invitation-revoked',
          entityType: 'onboarding_invitation',
          entityId: saved._id,
          operatorId: saved.operatorId,
          before: { status: before.status },
          after: { status: saved.status },
          client,
        },
        session,
      );
      return saved;
    });
    return this.viewOf(updated);
  }

  /** For the sign-up page: who is being invited. Reveals nothing about a bad token. */
  async inspect(token: string): Promise<InvitationPreview> {
    const invitation = await this.usable(token);
    return {
      companyName: invitation.companyName,
      ownerName: invitation.ownerName,
      email: invitation.email,
    };
  }

  /** The owner sets a password; this creates their account for the invited company. */
  async accept(input: AcceptInvitationDto): Promise<{ email: string }> {
    const invitation = await this.usable(input.token);
    const name = input.name ?? invitation.ownerName;
    assertPasswordAcceptable(input.password, { email: invitation.email, name });
    const [role] = await this.roles.findByKeys(['OPERATOR_ADMIN']);
    if (!role) throw new Error('The OPERATOR_ADMIN role is not set up');
    const passwordHash = await this.hasher.hash(input.password);

    await this.transactions.run(async (session) => {
      // Claim the invitation first: of two people using the link at once, only one gets past here
      const claimed = await this.invitations.update(
        invitation._id,
        'PENDING',
        { status: 'ACCEPTED', acceptedAt: new Date() },
        session,
      );
      if (!claimed) throw invalidLink();
      const user = await this.users.createOperatorAdmin(
        {
          name,
          email: invitation.email,
          phone: invitation.phone,
          passwordHash,
          roleIds: [role._id],
          operatorId: invitation.operatorId,
        },
        session,
      );
      await this.invitations.update(
        invitation._id,
        'ACCEPTED',
        { acceptedUserId: user._id },
        session,
      );
    });
    return { email: invitation.email };
  }

  private async pending(id: string): Promise<StoredInvitation> {
    const invitation = await this.invitations.findById(id);
    if (!invitation) throw new ApiException('RESOURCE_NOT_FOUND', 'Invitation not found');
    if (invitation.status !== 'PENDING') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        `This invitation is ${invitation.status.toLowerCase()}.`,
      );
    }
    return invitation;
  }

  /** The invitation behind a link, only while it can still be used. */
  private async usable(token: string): Promise<StoredInvitation> {
    const invitation = await this.invitations.findByTokenHash(hashToken(token));
    if (!invitation || invitation.status !== 'PENDING' || invitation.expiresAt < new Date()) {
      throw invalidLink();
    }
    return invitation;
  }

  /** Emails the link and records whether the mail server took it. A failure does not fail the invite. */
  private async deliver(invitation: StoredInvitation, token: string): Promise<InvitationView> {
    const link = `${this.config.get('CLIENT_PORTAL_URL').replace(/\/$/, '')}/#/accept-invite?token=${token}`;
    let emailStatus: 'SENT' | 'FAILED' = 'SENT';
    let problem: string | null = null;
    try {
      await this.email.send({
        to: invitation.email,
        subject: 'You are invited to Abra Travels',
        text:
          `Hello ${invitation.ownerName},\n\n` +
          `${invitation.companyName} has been invited to sell bus tickets on Abra Travels.\n` +
          `Open this link to set your password and submit your documents:\n\n${link}\n\n` +
          `The link works for ${INVITATION_DAYS} days and can be used once.\n`,
        html:
          `<p>Hello ${escapeHtml(invitation.ownerName)},</p>` +
          `<p><strong>${escapeHtml(invitation.companyName)}</strong> has been invited to sell bus tickets on Abra Travels.</p>` +
          `<p><a href="${link}">Set your password and submit your documents</a></p>` +
          `<p>The link works for ${INVITATION_DAYS} days and can be used once.</p>`,
      });
    } catch (error) {
      emailStatus = 'FAILED';
      problem =
        error instanceof EmailDeliveryError
          ? error.message
          : 'The invitation email could not be sent.';
    }
    const updated =
      (await this.invitations.update(invitation._id, 'PENDING', { emailStatus })) ?? invitation;
    return {
      ...this.viewOf({ ...updated, emailStatus }),
      emailProblem: problem,
      ...(this.config.isProduction ? {} : { inviteUrl: link }),
    };
  }

  private viewOf(invitation: StoredInvitation): InvitationView {
    return invitationViewOf(invitation);
  }
}

export function invitationViewOf(invitation: StoredInvitation): InvitationView {
  return {
    id: invitation._id.toHexString(),
    operatorId: invitation.operatorId.toHexString(),
    companyName: invitation.companyName,
    ownerName: invitation.ownerName,
    email: invitation.email,
    phone: invitation.phone || null,
    status: invitation.status,
    expired: invitation.status === 'PENDING' && invitation.expiresAt < new Date(),
    expiresAt: invitation.expiresAt.toISOString(),
    emailStatus: invitation.emailStatus,
    emailProblem: null,
    createdAt: invitation.createdAt?.toISOString() ?? null,
  };
}

function newToken(): string {
  return randomBytes(32).toString('base64url');
}

function invalidState(): ApiException {
  return new ApiException('INVALID_STATE_TRANSITION', 'This invitation changed. Reload it.');
}

function escapeHtml(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}
