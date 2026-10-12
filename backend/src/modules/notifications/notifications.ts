import { type DomainEventMessage } from '../../events/domain-event.types';

/** Who a message is for: platform staff who can review, or the owner(s) of the company concerned. */
export type Audience = 'REVIEWERS' | 'OWNERS';

export interface OnboardingNotice {
  audience: Audience;
  type: string;
  title: string;
  body: string;
  /** Small string values for the app to open the right screen. */
  data: Record<string, string>;
}

interface RejectedDocument {
  name?: unknown;
  reason?: unknown;
}

const text = (value: unknown): string => (typeof value === 'string' ? value : '');

function labelOf(payload: Record<string, unknown>): { subject: string; isBus: boolean } {
  const company = text(payload.companyName) || 'A company';
  const registration = text(payload.busRegistrationNumber);
  const isBus = payload.subjectType === 'BUS';
  return { subject: isBus && registration ? `${company}, bus ${registration}` : company, isBus };
}

/** The reasons a reviewer gave, short enough for a push notification. */
function reasonsOf(payload: Record<string, unknown>): string {
  const rejected = Array.isArray(payload.rejectedDocuments)
    ? (payload.rejectedDocuments as RejectedDocument[])
    : [];
  const parts = rejected.map((item) => {
    const name = text(item.name) || 'Document';
    const reason = text(item.reason);
    return reason ? `${name}: ${reason}` : name;
  });
  const joined = parts.join('; ');
  return joined.length > 400 ? `${joined.slice(0, 397)}...` : joined;
}

/**
 * Words the notification for an onboarding event, or nothing for an event this does not handle.
 * Reviewers hear about a file waiting; the owner hears the decision, with the reasons when
 * documents were rejected, so they can fix them without opening anything first.
 */
export function onboardingNotice(event: DomainEventMessage): OnboardingNotice | undefined {
  const payload = event.payload;
  const submissionId = text(payload.submissionId);
  if (!submissionId) return undefined;
  const { subject, isBus } = labelOf(payload);
  const data: Record<string, string> = {
    submissionId,
    subjectType: text(payload.subjectType),
    ...(text(payload.busId) ? { busId: text(payload.busId) } : {}),
    route: `/onboarding/${submissionId}`,
  };

  switch (event.type) {
    case 'onboarding.submitted': {
      const again = payload.resubmission === true;
      return {
        audience: 'REVIEWERS',
        type: event.type,
        title: again ? 'Corrected documents to review' : 'New documents to review',
        body: `${subject} sent ${again ? 'corrected ' : ''}documents for review.`,
        data,
      };
    }
    case 'onboarding.approved':
      return {
        audience: 'OWNERS',
        type: event.type,
        title: isBus ? 'Bus approved' : 'Company approved',
        body: isBus
          ? `${subject} has been approved and is ready for trips.`
          : `${subject} has been approved. You can now add buses and trips.`,
        data,
      };
    case 'onboarding.rejected': {
      const reasons = reasonsOf(payload);
      const note = text(payload.note);
      return {
        audience: 'OWNERS',
        type: event.type,
        title: 'Documents need fixing',
        body:
          `${subject}: please fix and send again.` +
          (reasons ? ` ${reasons}.` : '') +
          (note ? ` ${note}` : ''),
        data,
      };
    }
    default:
      return undefined;
  }
}

import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Types } from 'mongoose';
import {
  DomainEventHandlerRegistry,
  type DomainEventHandler,
} from '../../events/domain-event-handler.registry';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { ALL_PERMISSIONS_WILDCARD } from '../rbac/permissions/permission-registry';
import { UsersService } from '../users/services/users.service';
import { NotificationDispatcher, type Recipient } from './services/notification-dispatcher.service';

/**
 * Turns onboarding events into notifications. A file sent for review tells every platform user who
 * can review; a decision tells the owners of that company. Runs in the worker, after the change
 * that caused the event is safely stored, so a notification problem never affects the review.
 */
@Injectable()
export class OnboardingNotificationHandler implements DomainEventHandler, OnModuleInit {
  readonly name = 'onboarding-notifications';
  readonly eventTypes = ['onboarding.submitted', 'onboarding.approved', 'onboarding.rejected'];
  private readonly logger = new Logger(OnboardingNotificationHandler.name);

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
    const notice = onboardingNotice(event);
    if (!notice) return;
    const recipients = await this.recipientsOf(notice.audience, event);
    if (recipients.length === 0) {
      this.logger.warn({ eventId: event.eventId, audience: notice.audience }, 'Nobody to notify');
      return;
    }
    let failed = 0;
    for (const recipient of recipients) {
      const ok = await this.dispatcher.deliver(recipient, {
        eventId: event.eventId,
        type: notice.type,
        title: notice.title,
        body: notice.body,
        data: notice.data,
      });
      if (!ok) failed += 1;
    }
    // Failed channels are retried with backoff; the ones that worked are not repeated
    if (failed > 0) throw new Error(`${failed} recipient(s) had a channel that failed; will retry`);
  }

  private async recipientsOf(
    audience: 'REVIEWERS' | 'OWNERS',
    event: DomainEventMessage,
  ): Promise<Recipient[]> {
    const roles = await this.roles.findAll();
    const users =
      audience === 'REVIEWERS'
        ? await this.users.findActiveByRoleIds(
            roles
              .filter(
                (role) =>
                  role.permissionKeys.includes(ALL_PERMISSIONS_WILDCARD) ||
                  role.permissionKeys.includes('documents.review'),
              )
              .map((role) => role._id),
          )
        : await this.users.findActiveByRoleIds(
            roles.filter((role) => role.key === 'OPERATOR_ADMIN').map((role) => role._id),
            { operatorId: new Types.ObjectId(String(event.payload.operatorId)) },
          );
    return users
      .filter((user) => audience !== 'REVIEWERS' || user.userType === 'STAFF')
      .map((user) => ({ userId: user._id, email: user.email, phone: user.phone }));
  }
}
