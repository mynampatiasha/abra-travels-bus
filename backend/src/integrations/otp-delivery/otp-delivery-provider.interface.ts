/** Channels a one-time code can be delivered on. Also part of the API (`channel`). */
export const OTP_DELIVERY_CHANNELS = ['WHATSAPP', 'SMS'] as const;
export type OtpDeliveryChannel = (typeof OTP_DELIVERY_CHANNELS)[number];

export interface OtpDeliveryRequest {
  /** E.164. */
  to: string;
  /** The one-time code. Only providers see it; it is never logged or returned. */
  code: string;
  expiresInSeconds: number;
}

/**
 * Delivers one-time codes on one channel. Authentication depends on this abstraction only
 * (through OtpDeliveryService), never on WhatsApp or SMS directly. `deliver` resolves once the
 * channel's provider accepted the message and rejects otherwise.
 */
export interface OtpDeliveryProvider {
  readonly channel: OtpDeliveryChannel;
  readonly providerKey: string;
  deliver(request: OtpDeliveryRequest): Promise<void>;
}
