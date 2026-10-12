import { Logger } from '@nestjs/common';
import { type PushMessage, type PushProvider, type PushResult } from './push-provider.interface';

/** Records push messages instead of sending them. Development and tests only. */
export class DevelopmentPushProvider implements PushProvider {
  readonly providerKey = 'development';
  private readonly logger = new Logger(DevelopmentPushProvider.name);

  /** Everything "sent", newest last, for tests and local debugging. */
  readonly sent: Array<{ tokens: string[]; message: PushMessage }> = [];

  send(tokens: readonly string[], message: PushMessage): Promise<PushResult> {
    this.sent.push({ tokens: [...tokens], message });
    this.logger.log({ devices: tokens.length, title: message.title }, 'Push recorded, not sent');
    return Promise.resolve({ sent: tokens.length, invalidTokens: [] });
  }
}
