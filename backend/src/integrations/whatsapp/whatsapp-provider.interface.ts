/** Injection token for the configured WhatsApp provider (WHATSAPP_PROVIDER). */
export const WHATSAPP_PROVIDER = Symbol('WHATSAPP_PROVIDER');

/**
 * A message built from an approved WhatsApp template (business-initiated messages must use one).
 * Parameters are substituted into the template by WhatsApp; nothing here is free text.
 */
export interface WhatsAppTemplateMessage {
  /** E.164. */
  to: string;
  templateName: string;
  /** Template language code, e.g. `en` or `en_US`. */
  languageCode: string;
  /** Values for the body placeholders {{1}}, {{2}}, ... in order. */
  bodyParameters: string[];
  /**
   * Value for the first URL button. Authentication templates use it for the "copy code" button,
   * which must receive the same one-time code as the body.
   */
  urlButtonParameter?: string;
  /** What the message is for (logs, metrics). */
  purpose: 'OTP';
}

/**
 * Outbound WhatsApp messages (documentation/whatsapp-architecture.md). Business code depends on
 * this interface only; credentials stay inside the provider and never leave the backend.
 * `sendTemplate` resolves once the provider has accepted the message and rejects otherwise. Only
 * what OTP delivery needs exists so far; conversational messages arrive with the WhatsApp bots.
 */
export interface WhatsAppProvider {
  readonly providerKey: string;
  sendTemplate(message: WhatsAppTemplateMessage): Promise<void>;
}

/** The provider did not accept a message. The text never contains the message content. */
export class WhatsAppDeliveryError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'WhatsAppDeliveryError';
  }
}
