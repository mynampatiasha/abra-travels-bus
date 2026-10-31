import { Inject, Injectable, Logger } from '@nestjs/common';
import { ABRA_LOGO_PNG_BASE64 } from '../tickets/ticket_logo';
import { EMAIL_LOGO_CID, renderEmail, whatsAppFor } from './message_templates';
import { InjectModel } from '@nestjs/mongoose';
import { type QueryFilter, isValidObjectId, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { dayRange, escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { EmailDeliveryError, EmailService } from '../../integrations/email/email.service';
import {
  WHATSAPP_PROVIDER,
  WhatsAppDeliveryError,
  type WhatsAppProvider,
} from '../../integrations/whatsapp/whatsapp-provider.interface';
import { WhatsAppSettingsStore } from '../../integrations/whatsapp/whatsapp-settings.store';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';

// ===== 0. SCHEMA ====================================================================
// `messages`: a copy of every WhatsApp message and email sent to a person (master plan,
// Appendix A). It sits here, in the file the service needs it from, so the files do not import
// each other in a circle. The customer feature reads the same collection.

export const MESSAGE_MODEL = 'Message';

export const MESSAGE_CHANNELS = ['WHATSAPP', 'EMAIL'] as const;
export type MessageChannel = (typeof MESSAGE_CHANNELS)[number];

export const MESSAGE_KINDS = [
  'BOOKING_CONFIRMED',
  'BOOKING_CANCELLED',
  'REFUND_PAID',
  'PAYMENT_FAILED',
  'TRIP_DELAYED',
  'BOARDING_STARTED',
  'ANNOUNCEMENT',
  'GENERAL',
  'TRIP_REMINDER',
  'FEEDBACK_REQUEST',
  'SUPPORT_REPLY',
] as const;
export type MessageKind = (typeof MESSAGE_KINDS)[number];

/** QUEUED: stored, not tried yet. SENT. SKIPPED: the channel is not set up. FAILED: refused. */
export const MESSAGE_STATUSES = ['QUEUED', 'SENT', 'SKIPPED', 'FAILED'] as const;
export type MessageStatus = (typeof MESSAGE_STATUSES)[number];

export interface Message {
  channel: MessageChannel;
  kind: MessageKind;
  /** The account the message belongs to; absent for a guest booking. */
  userId?: Types.ObjectId;
  recipientName: string;
  /** E.164 phone number for WhatsApp, email address for email. */
  address: string;
  subject: string;
  body: string;
  bookingId?: Types.ObjectId;
  /** The domain event behind the message; with channel and address it makes sending safe to repeat. */
  eventId?: string;
  status: MessageStatus;
  /** Why it was not sent, in words for people. */
  detail?: string | null;
  attempts: number;
  lastAttemptAt?: Date;
  sentAt?: Date;
  /** Set on a message that was created by resending another one. */
  resendOf?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

export const messageSchema = new Schema<Message>(
  {
    channel: { type: String, enum: MESSAGE_CHANNELS, required: true },
    kind: { type: String, enum: MESSAGE_KINDS, required: true },
    userId: { type: Schema.Types.ObjectId },
    recipientName: { type: String, required: true, maxlength: 120 },
    address: { type: String, required: true, maxlength: 254 },
    subject: { type: String, required: true, maxlength: 200 },
    body: { type: String, required: true, maxlength: 4000 },
    bookingId: { type: Schema.Types.ObjectId },
    eventId: { type: String, maxlength: 120 },
    status: { type: String, enum: MESSAGE_STATUSES, required: true, default: 'QUEUED' },
    detail: { type: String, maxlength: 300, default: null },
    attempts: { type: Number, required: true, default: 0, min: 0 },
    lastAttemptAt: { type: Date },
    sentAt: { type: Date },
    resendOf: { type: Schema.Types.ObjectId },
  },
  { collection: 'messages', timestamps: true, versionKey: false },
);

messageSchema.index({ createdAt: -1 });
messageSchema.index({ userId: 1, createdAt: -1 });
messageSchema.index({ bookingId: 1 });
messageSchema.index(
  { eventId: 1, channel: 1, address: 1 },
  { unique: true, partialFilterExpression: { eventId: { $type: 'string' } } },
);

// ===== 1. VIEWS =====================================================================

export interface MessageView {
  id: string;
  at: string;
  channel: MessageChannel;
  kind: MessageKind;
  toName: string;
  address: string;
  subject: string;
  body: string;
  status: MessageStatus;
  /** Why it was not sent, in words for people. Empty when it was sent. */
  detail: string | null;
  attempts: number;
  bookingId: string | null;
  sentAt: string | null;
  resendOfId: string | null;
}

type StoredMessage = Message & { _id: Types.ObjectId; createdAt: Date };

export function toMessageView(message: StoredMessage): MessageView {
  return {
    id: message._id.toHexString(),
    at: message.createdAt.toISOString(),
    channel: message.channel,
    kind: message.kind,
    toName: message.recipientName,
    address: message.address,
    subject: message.subject,
    body: message.body,
    status: message.status,
    detail: message.detail ?? null,
    attempts: message.attempts,
    bookingId: message.bookingId ? message.bookingId.toHexString() : null,
    sentAt: message.sentAt ? message.sentAt.toISOString() : null,
    resendOfId: message.resendOf ? message.resendOf.toHexString() : null,
  };
}

// ===== 2. SENDING (used by every feature that tells a customer something) ============

export interface SendMessageInput {
  channel: MessageChannel;
  kind: MessageKind;
  /** The account the message belongs to, so the person sees it in "Messages sent to me". */
  userId?: Types.ObjectId | undefined;
  recipientName: string;
  /** E.164 phone number for WhatsApp, email address for email. */
  address: string;
  subject: string;
  body: string;
  bookingId?: Types.ObjectId | undefined;
  /** The domain event that caused this message: sending it twice for one event does nothing. */
  eventId?: string | undefined;
  /**
   * The values behind the message (PNR, route, amount ...). With them, a kind that has a template
   * (message_templates.ts) goes out as its branded email and its approved WhatsApp template; without
   * them the plain subject and body are sent, as before.
   */
  variables?: Readonly<Record<string, string | undefined>> | undefined;
  /** The ticket PDF, sent with the email and as the WhatsApp header. Not stored with the message. */
  attachment?: { filename: string; content: Buffer; contentType: string } | undefined;
}

/** What is only needed while the message is being delivered. */
interface DeliveryExtras {
  variables?: SendMessageInput['variables'];
  attachment?: SendMessageInput['attachment'];
}

const escapeHtml = (text: string): string =>
  text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/** WhatsApp template parameters cannot hold line breaks, tabs or long runs of spaces. */
const forTemplate = (text: string): string => text.replace(/\s+/g, ' ').trim().slice(0, 900);

/**
 * Sends one WhatsApp message or email and keeps a copy in the `messages` log, whatever the
 * outcome: SENT, SKIPPED (the channel is not set up) or FAILED (the provider refused it). A
 * provider being down never throws to the caller, so a booking is never lost because a message
 * could not be sent. The log is what the customer reads in "Messages sent to me" and what an
 * administrator resends from.
 */
@Injectable()
export class MessageSenderService {
  private readonly logger = new Logger(MessageSenderService.name);

  constructor(
    @InjectModel(MESSAGE_MODEL) private readonly model: Model<Message>,
    private readonly email: EmailService,
    private readonly whatsAppSettings: WhatsAppSettingsStore,
    @Inject(WHATSAPP_PROVIDER) private readonly whatsApp: WhatsAppProvider,
  ) {}

  async send(input: SendMessageInput): Promise<MessageView> {
    const existing = input.eventId
      ? await this.model
          .findOne({ eventId: input.eventId, channel: input.channel, address: input.address })
          .lean<StoredMessage>()
          .exec()
      : null;
    // The same event again: leave what was delivered alone, retry only what failed
    if (existing && existing.status !== 'FAILED') return toMessageView(existing);

    const record =
      existing ??
      ((
        await this.model.create({
          channel: input.channel,
          kind: input.kind,
          ...(input.userId ? { userId: input.userId } : {}),
          recipientName: input.recipientName,
          address: input.address,
          subject: input.subject,
          body: input.body,
          ...(input.bookingId ? { bookingId: input.bookingId } : {}),
          ...(input.eventId ? { eventId: input.eventId } : {}),
          status: 'QUEUED',
          attempts: 0,
        })
      ).toObject() as StoredMessage);
    return this.attempt(record, { variables: input.variables, attachment: input.attachment });
  }

  /** Tries the channel once more for an existing record and stores the outcome. */
  async attempt(record: StoredMessage, extras: DeliveryExtras = {}): Promise<MessageView> {
    const outcome = await this.deliver(record, extras);
    const now = new Date();
    const updated = await this.model
      .findByIdAndUpdate(
        record._id,
        {
          $set: {
            status: outcome.status,
            detail: outcome.detail ?? null,
            lastAttemptAt: now,
            ...(outcome.status === 'SENT' ? { sentAt: now } : {}),
          },
          $inc: { attempts: 1 },
        },
        { new: true },
      )
      .lean<StoredMessage>()
      .exec();
    return toMessageView(updated ?? { ...record, status: outcome.status });
  }

  private async deliver(
    record: StoredMessage,
    extras: DeliveryExtras,
  ): Promise<{ status: Exclude<MessageStatus, 'QUEUED'>; detail?: string }> {
    try {
      if (record.channel === 'EMAIL') {
        const branded = extras.variables ? renderEmail(record.kind, extras.variables) : null;
        await this.email.send({
          to: record.address,
          subject: branded?.subject ?? record.subject,
          text: branded?.text ?? record.body,
          html:
            branded?.html ??
            `<p><strong>${escapeHtml(record.subject)}</strong></p><p>${escapeHtml(record.body).replaceAll('\n', '<br>')}</p>`,
          attachments: [
            ...(branded
              ? [{ filename: 'abra-logo.png', content: Buffer.from(ABRA_LOGO_PNG_BASE64, 'base64'), contentType: 'image/png', cid: EMAIL_LOGO_CID }]
              : []),
            ...(extras.attachment ? [extras.attachment] : []),
          ],
        });
        return { status: 'SENT' };
      }
      const templated = extras.variables ? whatsAppFor(record.kind, extras.variables) : null;
      if (templated) {
        // The approved template of this kind: its name and blanks are fixed in message_templates.ts
        const own = await this.whatsAppSettings.effective();
        if (!own.enabled) return { status: 'SKIPPED', detail: 'WhatsApp is not set up.' };
        await this.whatsApp.sendTemplate({
          to: record.address,
          templateName: templated.template.name,
          languageCode: templated.template.language,
          bodyParameters: templated.parameters,
          purpose: 'NOTIFICATION',
          ...(templated.template.withDocument && extras.attachment ? { documentHeader: extras.attachment } : {}),
        });
        return { status: 'SENT' };
      }
      const settings = await this.whatsAppSettings.effective();
      if (
        !settings.enabled ||
        !settings.notificationTemplateName ||
        !settings.notificationTemplateLanguage
      ) {
        return { status: 'SKIPPED', detail: 'No WhatsApp notification template is set up.' };
      }
      await this.whatsApp.sendTemplate({
        to: record.address,
        templateName: settings.notificationTemplateName,
        languageCode: settings.notificationTemplateLanguage,
        bodyParameters: [forTemplate(record.subject), forTemplate(record.body)],
        purpose: 'NOTIFICATION',
      });
      return { status: 'SENT' };
    } catch (error) {
      if (
        error instanceof EmailDeliveryError &&
        (error.code === 'NOT_CONFIGURED' || error.code === 'DISABLED')
      ) {
        return { status: 'SKIPPED', detail: error.message };
      }
      // Only text written for people is kept, never a provider's raw answer
      const detail =
        error instanceof EmailDeliveryError || error instanceof WhatsAppDeliveryError
          ? error.message
          : 'The channel could not be used.';
      this.logger.warn({ channel: record.channel, messageId: record._id.toHexString() }, detail);
      return { status: 'FAILED', detail };
    }
  }
}

// ===== 3. ADMIN: LIST, READ, RESEND ==================================================

export interface MessageListQuery {
  q?: string | undefined;
  channel?: MessageChannel | undefined;
  kind?: MessageKind | undefined;
  status?: MessageStatus | undefined;
  from?: string | undefined;
  to?: string | undefined;
  bookingId?: string | undefined;
  page: number;
  pageSize: number;
}

/** The admin "Messages sent" page: every WhatsApp message and email, newest first. */
@Injectable()
export class MessagesAdminManageService {
  constructor(
    @InjectModel(MESSAGE_MODEL) private readonly model: Model<Message>,
    private readonly sender: MessageSenderService,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(query: MessageListQuery): Promise<PaginatedResult<MessageView>> {
    const filter: QueryFilter<Message> = {};
    if (query.channel) filter.channel = query.channel;
    if (query.kind) filter.kind = query.kind;
    if (query.status) filter.status = query.status;
    const range = dayRange(query);
    if (range) filter.createdAt = range;
    if (query.bookingId && isValidObjectId(query.bookingId)) {
      filter.bookingId = new Types.ObjectId(query.bookingId);
    }
    if (query.q) {
      const pattern = new RegExp(escapeRegExp(query.q.trim()), 'i');
      filter.$or = [{ recipientName: pattern }, { address: pattern }, { subject: pattern }];
    }
    const [items, total] = await Promise.all([
      this.model
        .find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredMessage[]>()
        .exec(),
      this.model.countDocuments(filter).exec(),
    ]);
    return new PaginatedResult(items.map(toMessageView), query.page, query.pageSize, total);
  }

  async get(id: string): Promise<MessageView> {
    return toMessageView(await this.find(id));
  }

  /** Sends the same message again and writes who did it to the audit trail. */
  async resend(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<MessageView> {
    const message = await this.find(id);
    // The channel is tried first, outside any database transaction; the audit entry follows
    const result = await this.sender.attempt(message);
    await this.changes.run<StoredMessage>({
      actor,
      client,
      action: 'message.resent',
      entityType: 'message',
      before: { status: message.status, attempts: message.attempts },
      apply: () => Promise.resolve(message),
      describe: () => ({ status: result.status, attempts: result.attempts }),
    });
    return result;
  }

  private async find(id: string): Promise<StoredMessage> {
    const message = isValidObjectId(id)
      ? await this.model.findById(id).lean<StoredMessage>().exec()
      : null;
    if (!message) throw new ApiException('RESOURCE_NOT_FOUND', 'That message was not found');
    return message;
  }
}
