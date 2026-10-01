/** Injection token for the configured SMS provider (SMS_PROVIDER). */
export const SMS_PROVIDER = Symbol('SMS_PROVIDER');

export interface SmsMessage {
  /** E.164. */
  to: string;
  body: string;
  /** What the message is for; real providers map it to a registered (DLT) template. */
  purpose: 'OTP';
}

/**
 * Outbound SMS. Business code depends on this interface only, so a real provider is added as a
 * new class without touching callers (architecture.md rule 8). `send` rejects when the message
 * could not be handed to the provider.
 */
export interface SmsProvider {
  readonly providerKey: string;
  send(message: SmsMessage): Promise<void>;
}
