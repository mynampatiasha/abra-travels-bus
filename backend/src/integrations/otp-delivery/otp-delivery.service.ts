import { Injectable, Logger } from '@nestjs/common';
import { maskPhoneNumber } from '../../common/validation/contact-identifiers';
import { AppConfigService } from '../../config/app-config.service';
import {
  type OtpDeliveryChannel,
  type OtpDeliveryProvider,
  type OtpDeliveryRequest,
} from './otp-delivery-provider.interface';
import { SmsOtpDeliveryProvider } from './sms-otp-delivery.provider';
import { WhatsAppOtpDeliveryProvider } from './whatsapp-otp-delivery.provider';

/** No configured channel accepted the code. The message never contains the code. */
export class OtpDeliveryFailedError extends Error {
  constructor(readonly attemptedChannels: readonly OtpDeliveryChannel[]) {
    super(`OTP could not be delivered on ${attemptedChannels.join(', ')}`);
    this.name = 'OtpDeliveryFailedError';
  }
}

/**
 * Chooses the channel for a one-time code (OTP_DELIVERY_CHANNELS, e.g. `whatsapp,sms`):
 * channels are tried in order and the first one whose provider accepts the message wins; a later
 * channel is used only when the earlier ones failed. Exactly one message is sent per request —
 * never one on every channel.
 *
 * Note: a provider that times out may still have delivered; the fallback then sends a second
 * message with the same code. That is accepted over leaving the customer without a code.
 */
@Injectable()
export class OtpDeliveryService {
  private readonly logger = new Logger(OtpDeliveryService.name);
  private readonly providers: Record<OtpDeliveryChannel, OtpDeliveryProvider>;

  constructor(
    private readonly config: AppConfigService,
    whatsApp: WhatsAppOtpDeliveryProvider,
    sms: SmsOtpDeliveryProvider,
  ) {
    this.providers = { WHATSAPP: whatsApp, SMS: sms };
  }

  /** Configured channels, in the order they are tried. */
  get channels(): OtpDeliveryChannel[] {
    return this.config
      .get('OTP_DELIVERY_CHANNELS')
      .map((channel) => (channel === 'whatsapp' ? 'WHATSAPP' : 'SMS'));
  }

  /** The channel a successful delivery normally uses. */
  get primaryChannel(): OtpDeliveryChannel {
    const [first] = this.channels;
    if (!first) throw new Error('OTP_DELIVERY_CHANNELS is empty');
    return first;
  }

  /** Delivers on the first channel that accepts the message and returns that channel. */
  async deliver(request: OtpDeliveryRequest): Promise<OtpDeliveryChannel> {
    const attempted: OtpDeliveryChannel[] = [];
    for (const channel of this.channels) {
      const provider = this.providers[channel];
      attempted.push(channel);
      try {
        await provider.deliver(request);
        if (attempted.length > 1) {
          this.logger.warn(
            { phone: maskPhoneNumber(request.to), channel, failed: attempted.slice(0, -1) },
            'OTP delivered on a fallback channel',
          );
        }
        return channel;
      } catch (error) {
        this.logger.warn(
          {
            phone: maskPhoneNumber(request.to),
            channel,
            provider: provider.providerKey,
            reason: error instanceof Error ? error.message : 'unknown',
          },
          'OTP delivery failed on channel',
        );
      }
    }
    throw new OtpDeliveryFailedError(attempted);
  }
}
