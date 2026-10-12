/** Injection token of the configured push provider (`PUSH_PROVIDER`). */
export const PUSH_PROVIDER = Symbol('PUSH_PROVIDER');

export interface PushMessage {
  title: string;
  body: string;
  /** Small string values the app uses to open the right screen. Never secrets. */
  data: Record<string, string>;
}

export interface PushResult {
  /** Devices the provider accepted the message for. */
  sent: number;
  /** Tokens the provider says no longer exist (app uninstalled, permission withdrawn). */
  invalidTokens: string[];
}

/**
 * Push notifications to a user's browsers and phones, also when the app is closed. Business code
 * depends on this interface only; credentials stay inside the provider.
 */
export interface PushProvider {
  readonly providerKey: string;
  send(tokens: readonly string[], message: PushMessage): Promise<PushResult>;
}

/** The provider could not be reached or refused the request. Safe to show; no message content. */
export class PushDeliveryError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'PushDeliveryError';
  }
}
