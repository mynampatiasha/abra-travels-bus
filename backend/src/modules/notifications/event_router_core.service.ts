import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { Types } from 'mongoose';
import {
  DomainEventHandlerRegistry,
  type DomainEventHandler,
} from '../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../events/domain-event.types';
import {
  MessageSenderService,
  type MessageChannel,
  type MessageKind,
} from '../messages/messages_admin_manage.service';
import { LivePublisher } from '../realtime/live_updates_channel.service';
import { ALL_PERMISSIONS_WILDCARD } from '../rbac/permissions/permission-registry';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { TicketsCustomerService } from '../tickets/tickets_customer.service';
import { UsersService } from '../users/services/users.service';
import { NotificationDispatcher, type Recipient } from './services/notification-dispatcher.service';

/*
 * The event router: the one place that turns a business event (`trip.cancelled`, `refund.updated`)
 * into what people see: a notification in the app (and push, email, WhatsApp as fallbacks), a live
 * update for screens that are open, and a WhatsApp or email message with a copy in the messages
 * log. A feature never notifies anybody itself: it records its event in the outbox, and a rule
 * here (or one the feature registers) says who is told what (plan Appendix B).
 *
 * Rules are data. Runs in the worker, after the change is safely stored, so a notification
 * problem never affects the business action. Delivery is at-least-once: every send is keyed by the
 * event id, so a retry only repeats what failed.
 */

// ===== 1. RULE TYPES =====

/** Text from the event: `{route}` is replaced by `payload.route`; a function can decide by itself. */
export type EventText = string | ((payload: Record<string, unknown>) => string);

/** Who is told. Ids and names come from the event payload (ids as text). */
export type AudienceSpec =
  /** Platform staff whose role holds the permission (or everything). */
  | { kind: 'staff'; permission: string }
  /** The owners (administrators) of `payload.operatorId`. */
  | { kind: 'operator-owners' }
  /** Staff of `payload.operatorId` whose role holds the permission. */
  | { kind: 'operator-staff'; permission: string }
  /** The account whose id is in `payload[field]`. */
  | { kind: 'user'; field: string }
  /** The accounts whose ids are in the list `payload[field]`. */
  | { kind: 'users'; field: string };

export interface NoticeRule {
  to: readonly AudienceSpec[];
  title: EventText;
  body: EventText;
  /** The page or screen the notification opens. */
  goTo: EventText;
  /** Skip this notice for events where it does not apply. */
  when?: (payload: Record<string, unknown>) => boolean;
}

/** Where a live update goes. */
export type LiveTarget =
  | 'staff'
  | 'operator'
  | { user: string }
  | { topic: string; idField: string };

export interface LiveRule {
  /** `kind.event`, lowercase (appendix B.3). */
  type: string;
  to: readonly LiveTarget[];
  /** Payload fields copied into the live message: ids and state only, never records. */
  data: readonly string[];
  when?: (payload: Record<string, unknown>) => boolean;
}

export interface MessageRule {
  channels: readonly MessageChannel[];
  kind: MessageKind;
  subject: EventText;
  body: EventText;
  /** The payload fields that say who gets it: the booking's contact, not only the account. */
  contact: {
    userField?: string;
    nameField: string;
    phoneField?: string;
    emailField?: string;
    bookingField?: string;
  };
  when?: (payload: Record<string, unknown>) => boolean;
  /** The ticket PDF of the booking travels with the message (email attachment, WhatsApp header). */
  attachTicketPdf?: boolean;
}

export interface EventRule {
  /** Event type, `<aggregate>.<past-tense-verb>`. */
  event: string;
  notices?: readonly NoticeRule[];
  live?: readonly LiveRule[];
  messages?: readonly MessageRule[];
}

// ===== 2. WORDS =====

const textOf = (value: unknown): string =>
  typeof value === 'string' ? value : typeof value === 'number' ? String(value) : '';

/** The text of a rule for one event: `{field}` placeholders filled from the payload. */
export function renderText(text: EventText, payload: Record<string, unknown>): string {
  if (typeof text === 'function') return text(payload).trim();
  return text
    .replace(/\{([A-Za-z][A-Za-z0-9]*)\}/g, (_match, field: string) => textOf(payload[field]))
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Small string values for the app to open the right screen: the ids the event carries, plus the
 * place to go. Never the whole payload.
 */
export function noticeData(payload: Record<string, unknown>, goTo: string): Record<string, string> {
  const data: Record<string, string> = { route: goTo };
  for (const [key, value] of Object.entries(payload)) {
    if (/Id$/.test(key) && typeof value === 'string' && value.length <= 40) data[key] = value;
    if (Object.keys(data).length >= 9) break;
  }
  return data;
}

// ===== 3. THE ROUTER =====

@Injectable()
export class EventRouter implements DomainEventHandler, OnModuleInit {
  readonly name = 'event-router';
  private readonly logger = new Logger(EventRouter.name);
  private readonly rules = new Map<string, EventRule>();

  constructor(
    private readonly registry: DomainEventHandlerRegistry,
    private readonly dispatcher: NotificationDispatcher,
    private readonly live: LivePublisher,
    private readonly messages: MessageSenderService,
    private readonly roles: RoleRepository,
    private readonly users: UsersService,
    private readonly tickets: TicketsCustomerService,
  ) {}

  /** The events that have a rule; read when an event arrives, so late registrations count. */
  get eventTypes(): readonly string[] {
    return [...this.rules.keys()];
  }

  onModuleInit(): void {
    this.registry.register(this);
  }

  /** A feature adds the rules of its own events. One rule per event. */
  addRules(rules: readonly EventRule[]): void {
    for (const rule of rules) {
      if (this.rules.has(rule.event)) {
        throw new Error(`The event router already has a rule for "${rule.event}"`);
      }
      this.rules.set(rule.event, rule);
    }
  }

  ruleFor(event: string): EventRule | undefined {
    return this.rules.get(event);
  }

  async handle(event: DomainEventMessage): Promise<void> {
    const rule = this.rules.get(event.type);
    if (!rule) return;
    const payload = event.payload;
    let failures = 0;

    // Live updates first: they cost nothing and a screen that is open should not wait
    for (const live of rule.live ?? []) {
      if (live.when && !live.when(payload)) continue;
      try {
        this.publish(live, payload);
      } catch (error) {
        failures += 1;
        this.logger.warn({ eventId: event.eventId, type: live.type }, `Live update failed: ${String(error)}`);
      }
    }

    // One notification per person: the first notice that names them wins
    const told = new Map<string, { recipient: Recipient; notice: NoticeRule }>();
    for (const notice of rule.notices ?? []) {
      if (notice.when && !notice.when(payload)) continue;
      for (const recipient of await this.recipientsOf(notice.to, payload)) {
        const key = recipient.userId.toHexString();
        if (!told.has(key)) told.set(key, { recipient, notice });
      }
    }
    for (const { recipient, notice } of told.values()) {
      const goTo = renderText(notice.goTo, payload);
      const ok = await this.dispatcher.deliver(recipient, {
        eventId: event.eventId,
        type: event.type,
        title: renderText(notice.title, payload),
        body: renderText(notice.body, payload),
        data: noticeData(payload, goTo),
      });
      if (!ok) failures += 1;
    }
    if (told.size === 0 && (rule.notices?.length ?? 0) > 0) {
      this.logger.warn({ eventId: event.eventId, type: event.type }, 'Nobody to notify');
    }

    for (const message of rule.messages ?? []) {
      if (message.when && !message.when(payload)) continue;
      failures += await this.sendMessages(message, event);
    }

    // Failed channels are retried with backoff; what already worked is not repeated
    if (failures > 0) throw new Error(`${failures} delivery(ies) failed for ${event.type}; will retry`);
  }

  // ----- live -----

  private publish(rule: LiveRule, payload: Record<string, unknown>): void {
    const data: Record<string, unknown> = {};
    for (const field of rule.data) if (payload[field] !== undefined) data[field] = payload[field];
    for (const target of rule.to) {
      if (target === 'staff') this.live.toStaff(rule.type, data);
      else if (target === 'operator') {
        const operatorId = textOf(payload.operatorId);
        if (operatorId) this.live.toOperator(operatorId, rule.type, data);
      } else if ('user' in target) {
        const userId = textOf(payload[target.user]);
        if (userId) this.live.toUser(userId, rule.type, data);
      } else {
        const id = textOf(payload[target.idField]);
        if (id) this.live.toTopic(target.topic, id, rule.type, data);
      }
    }
  }

  // ----- messages -----

  /** Sends one message rule; returns how many sends failed. A channel that is off counts as done. */
  private async sendMessages(rule: MessageRule, event: DomainEventMessage): Promise<number> {
    const payload = event.payload;
    const contact = rule.contact;
    const name = textOf(payload[contact.nameField]) || 'Customer';
    const userId = contact.userField ? textOf(payload[contact.userField]) : '';
    const bookingId = contact.bookingField ? textOf(payload[contact.bookingField]) : '';
    // The values behind the words, so the message goes out as its branded email and approved template
    const variables: Record<string, string> = {};
    for (const [key, value] of Object.entries(payload)) {
      if (typeof value === 'string' || typeof value === 'number') variables[key] = String(value);
    }
    let attachment: { filename: string; content: Buffer; contentType: string } | undefined;
    if (rule.attachTicketPdf && bookingId) {
      try {
        const file = await this.tickets.pdfForBooking(bookingId);
        attachment = { filename: file.fileName, content: file.body, contentType: 'application/pdf' };
      } catch (error) {
        // The message still goes out; only the file is missing
        this.logger.warn(
          { bookingId, message: error instanceof Error ? error.message : 'unknown' },
          'The ticket PDF could not be made for a message',
        );
      }
    }
    let failed = 0;
    for (const channel of rule.channels) {
      const address = textOf(
        payload[(channel === 'WHATSAPP' ? contact.phoneField : contact.emailField) ?? ''],
      );
      if (!address) continue;
      const sent = await this.messages.send({
        channel,
        kind: rule.kind,
        ...(userId && Types.ObjectId.isValid(userId) ? { userId: new Types.ObjectId(userId) } : {}),
        recipientName: name,
        address,
        subject: renderText(rule.subject, payload),
        body: renderText(rule.body, payload),
        ...(bookingId && Types.ObjectId.isValid(bookingId)
          ? { bookingId: new Types.ObjectId(bookingId) }
          : {}),
        eventId: event.eventId,
        variables,
        ...(attachment ? { attachment } : {}),
      });
      if (sent.status === 'FAILED') failed += 1;
    }
    return failed;
  }

  // ----- who -----

  async recipientsOf(
    audiences: readonly AudienceSpec[],
    payload: Record<string, unknown>,
  ): Promise<Recipient[]> {
    const found = new Map<string, Recipient>();
    const add = (list: ReadonlyArray<{ _id: Types.ObjectId; email?: string; phone?: string }>) => {
      for (const user of list) {
        found.set(user._id.toHexString(), {
          userId: user._id,
          email: user.email,
          phone: user.phone,
        });
      }
    };
    const operatorId = textOf(payload.operatorId);
    const operator = Types.ObjectId.isValid(operatorId) ? new Types.ObjectId(operatorId) : undefined;

    for (const audience of audiences) {
      switch (audience.kind) {
        case 'staff': {
          const roleIds = await this.roleIdsHolding(audience.permission);
          const users = await this.users.findActiveByRoleIds(roleIds);
          add(users.filter((user) => user.userType === 'STAFF'));
          break;
        }
        case 'operator-owners': {
          if (!operator) break;
          const owners = (await this.roles.findAll()).filter((role) => role.key === 'OPERATOR_ADMIN');
          add(
            await this.users.findActiveByRoleIds(
              owners.map((role) => role._id),
              { operatorId: operator },
            ),
          );
          break;
        }
        case 'operator-staff': {
          if (!operator) break;
          const roleIds = await this.roleIdsHolding(audience.permission);
          add(await this.users.findActiveByRoleIds(roleIds, { operatorId: operator }));
          break;
        }
        case 'user':
        case 'users': {
          const raw =
            audience.kind === 'user'
              ? [payload[audience.field]]
              : Array.isArray(payload[audience.field])
                ? (payload[audience.field] as unknown[])
                : [];
          const ids = raw
            .map(textOf)
            .filter((id) => Types.ObjectId.isValid(id))
            .map((id) => new Types.ObjectId(id));
          add(await this.users.findContacts(ids));
          break;
        }
      }
    }
    return [...found.values()];
  }

  private async roleIdsHolding(permission: string): Promise<Types.ObjectId[]> {
    return (await this.roles.findAll())
      .filter(
        (role) =>
          role.permissionKeys.includes(ALL_PERMISSIONS_WILDCARD) ||
          role.permissionKeys.includes(permission),
      )
      .map((role) => role._id);
  }
}
