import { Inject, Injectable, Logger } from '@nestjs/common';
import { type Types } from 'mongoose';
import { EmailDeliveryError, EmailService } from '../../../integrations/email/email.service';
import {
  PUSH_PROVIDER,
  PushDeliveryError,
  type PushProvider,
} from '../../../integrations/push/push-provider.interface';
import {
  WHATSAPP_PROVIDER,
  WhatsAppDeliveryError,
  type WhatsAppProvider,
} from '../../../integrations/whatsapp/whatsapp-provider.interface';
import { WhatsAppSettingsStore } from '../../../integrations/whatsapp/whatsapp-settings.store';
import {
  NotificationRepository,
  PushTokenRepository,
} from '../repositories/notification.repository';
import {
  DELIVERY_CHANNELS,
  type DeliveryChannel,
  type NotificationDelivery,
} from '../schemas/notification.schema';
import { RealtimeEmitter } from '../realtime/realtime';

export interface Recipient {
  userId: Types.ObjectId;
  email?: string | undefined;
  /** E.164. */
  phone?: string | undefined;
}

export interface NotificationContent {
  /** The domain event; with the person it makes delivery safe to repeat. */
  eventId: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, string>;
}

const escapeHtml = (text: string): string =>
  text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/** WhatsApp template parameters cannot hold line breaks, tabs or long runs of spaces. */
const forTemplate = (text: string): string => text.replace(/\s+/g, ' ').trim().slice(0, 900);

/**
 * Delivers one notification to one person: stores it (the in-app list is the record), then tells
 * them through every channel — instantly if the app is open, push when it is closed, email and
 * WhatsApp as the guaranteed fallbacks. Each channel is tried on its own, so one provider being
 * down never blocks the others, and a repeat of the same event only retries what failed.
 */
@Injectable()
export class NotificationDispatcher {
  private readonly logger = new Logger(NotificationDispatcher.name);

  constructor(
    private readonly notifications: NotificationRepository,
    private readonly pushTokens: PushTokenRepository,
    private readonly realtime: RealtimeEmitter,
    private readonly email: EmailService,
    private readonly whatsAppSettings: WhatsAppSettingsStore,
    @Inject(PUSH_PROVIDER) private readonly push: PushProvider,
    @Inject(WHATSAPP_PROVIDER) private readonly whatsApp: WhatsAppProvider,
  ) {}

  /** @returns false when a channel failed and the event should be tried again later. */
  async deliver(
    recipient: Recipient,
    content: NotificationContent,
    options: { off?: ReadonlySet<DeliveryChannel> } = {},
  ): Promise<boolean> {
    const { notification } = await this.notifications.insertOnce({
      userId: recipient.userId,
      eventId: content.eventId,
      type: content.type,
      title: content.title,
      body: content.body,
      data: content.data,
    });
    const settled = new Set(
      notification.deliveries
        .filter((item) => item.status !== 'FAILED')
        .map((item) => item.channel),
    );
    const results: NotificationDelivery[] = [];
    for (const channel of DELIVERY_CHANNELS) {
      if (settled.has(channel)) continue;
      if (options.off?.has(channel)) {
        // The customer turned this channel off for this kind of message
        results.push({
          channel,
          at: new Date(),
          status: 'SKIPPED',
          detail: 'The customer turned this off.',
        });
        continue;
      }
      results.push(await this.attempt(channel, recipient, content, notification._id.toHexString()));
    }
    if (results.length > 0) await this.notifications.recordDeliveries(notification._id, results);
    return results.every((item) => item.status !== 'FAILED');
  }

  private async attempt(
    channel: DeliveryChannel,
    recipient: Recipient,
    content: NotificationContent,
    notificationId: string,
  ): Promise<NotificationDelivery> {
    const at = new Date();
    try {
      const outcome = await this.send(channel, recipient, content, notificationId);
      return { channel, at, ...outcome };
    } catch (error) {
      // Only text written for people is kept; never a provider's raw answer
      const detail =
        error instanceof EmailDeliveryError ||
        error instanceof PushDeliveryError ||
        error instanceof WhatsAppDeliveryError
          ? error.message
          : 'The channel could not be used.';
      this.logger.warn(
        { channel, userId: recipient.userId.toHexString() },
        `Delivery failed: ${detail}`,
      );
      return { channel, at, status: 'FAILED', detail };
    }
  }

  private async send(
    channel: DeliveryChannel,
    recipient: Recipient,
    content: NotificationContent,
    notificationId: string,
  ): Promise<Pick<NotificationDelivery, 'status' | 'detail'>> {
    switch (channel) {
      case 'REALTIME':
        this.realtime.emitToUser(recipient.userId.toHexString(), {
          id: notificationId,
          type: content.type,
          title: content.title,
          body: content.body,
          data: content.data,
        });
        return { status: 'SENT' };

      case 'PUSH': {
        const tokens = await this.pushTokens.tokensOf(recipient.userId);
        if (tokens.length === 0) return { status: 'SKIPPED', detail: 'No device registered.' };
        const result = await this.push.send(tokens, {
          title: content.title,
          body: content.body,
          data: content.data,
        });
        await this.pushTokens.removeMany(result.invalidTokens);
        if (result.sent > 0) return { status: 'SENT' };
        return { status: 'SKIPPED', detail: 'No device could receive it.' };
      }

      case 'EMAIL': {
        if (!recipient.email) return { status: 'SKIPPED', detail: 'No email address.' };
        try {
          await this.email.send({
            to: recipient.email,
            subject: content.title,
            text: content.body,
            html: `<p><strong>${escapeHtml(content.title)}</strong></p><p>${escapeHtml(content.body)}</p>`,
          });
        } catch (error) {
          // An administrator has not set email up (or turned it off): nothing to retry
          if (
            error instanceof EmailDeliveryError &&
            (error.code === 'NOT_CONFIGURED' || error.code === 'DISABLED')
          ) {
            return { status: 'SKIPPED', detail: error.message };
          }
          throw error;
        }
        return { status: 'SENT' };
      }

      case 'WHATSAPP': {
        if (!recipient.phone) return { status: 'SKIPPED', detail: 'No phone number.' };
        const settings = await this.whatsAppSettings.effective();
        if (
          !settings.enabled ||
          !settings.notificationTemplateName ||
          !settings.notificationTemplateLanguage
        ) {
          return { status: 'SKIPPED', detail: 'No WhatsApp notification template is set up.' };
        }
        await this.whatsApp.sendTemplate({
          to: recipient.phone,
          templateName: settings.notificationTemplateName,
          languageCode: settings.notificationTemplateLanguage,
          bodyParameters: [forTemplate(content.title), forTemplate(content.body)],
          purpose: 'NOTIFICATION',
        });
        return { status: 'SENT' };
      }
    }
  }
}
