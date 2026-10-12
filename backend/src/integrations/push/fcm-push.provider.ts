import { readFileSync } from 'node:fs';
import { type App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import {
  PushDeliveryError,
  type PushMessage,
  type PushProvider,
  type PushResult,
} from './push-provider.interface';

/** FCM answers these when a device token is permanently gone. */
const GONE_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** FCM accepts at most 500 tokens in one request. */
const BATCH = 500;

/**
 * The service account Firebase gave for this project: either the JSON itself or the path of the
 * file that holds it (`FCM_SERVICE_ACCOUNT_JSON`). It is read once, when the first push is sent.
 */
function readServiceAccount(value: string): Record<string, unknown> {
  const text = value.trim().startsWith('{') ? value : readFileSync(value, 'utf8');
  return JSON.parse(text) as Record<string, unknown>;
}

/** Firebase Cloud Messaging (HTTP v1) through the Firebase Admin SDK. */
export class FcmPushProvider implements PushProvider {
  readonly providerKey = 'fcm';
  private app: App | undefined;

  constructor(private readonly serviceAccount: string) {}

  async send(tokens: readonly string[], message: PushMessage): Promise<PushResult> {
    const messaging = getMessaging(this.firebaseApp());
    const result: PushResult = { sent: 0, invalidTokens: [] };
    for (let start = 0; start < tokens.length; start += BATCH) {
      const batch = tokens.slice(start, start + BATCH);
      let response;
      try {
        response = await messaging.sendEachForMulticast({
          tokens: batch,
          notification: { title: message.title, body: message.body },
          data: message.data,
          // Delivered at once and kept for a day, so a closed browser or a sleeping phone still
          // gets it when it wakes
          webpush: { headers: { Urgency: 'high', TTL: '86400' } },
          android: {
            priority: 'high',
            ttl: 86_400_000,
            notification: { channelId: 'high_priority_channel' },
          },
          apns: { headers: { 'apns-priority': '10' } },
        });
      } catch {
        // Credentials or network: say so without the provider's text
        throw new PushDeliveryError('The push service could not be reached');
      }
      response.responses.forEach((item, index) => {
        if (item.success) {
          result.sent += 1;
        } else if (item.error && GONE_CODES.has(item.error.code)) {
          const token = batch[index];
          if (token) result.invalidTokens.push(token);
        }
      });
    }
    if (result.sent === 0 && result.invalidTokens.length === 0 && tokens.length > 0) {
      throw new PushDeliveryError('The push service refused every message');
    }
    return result;
  }

  private firebaseApp(): App {
    if (this.app) return this.app;
    this.app =
      getApps()[0] ?? initializeApp({ credential: cert(readServiceAccount(this.serviceAccount)) });
    return this.app;
  }
}
