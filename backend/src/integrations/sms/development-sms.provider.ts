import { Logger } from '@nestjs/common';
import { type SmsMessage, type SmsProvider } from './sms-provider.interface';

const INBOX_SIZE = 50;

/**
 * DEVELOPMENT / TEST ONLY — sends nothing. Messages are kept in a small in-memory inbox (read by
 * automated tests) and, when NODE_ENV=development, written to the server log so a developer can
 * read the OTP (authentication.md §3). Configuration validation refuses SMS_PROVIDER=development
 * in production, and the factory in SmsModule refuses to construct this class there.
 */
export class DevelopmentSmsProvider implements SmsProvider {
  readonly providerKey = 'development';
  private readonly logger = new Logger('DevelopmentSms');
  private readonly inbox: SmsMessage[] = [];

  constructor(private readonly logMessages: boolean) {}

  send(message: SmsMessage): Promise<void> {
    this.inbox.push(message);
    if (this.inbox.length > INBOX_SIZE) this.inbox.shift();
    if (this.logMessages) {
      this.logger.log(`DEVELOPMENT SMS (not sent) to ${message.to}: ${message.body}`);
    }
    return Promise.resolve();
  }

  /** Most recent message to a number, newest first. */
  lastMessageTo(phone: string): SmsMessage | undefined {
    return this.inbox.findLast((message) => message.to === phone);
  }

  messagesTo(phone: string): SmsMessage[] {
    return this.inbox.filter((message) => message.to === phone);
  }
}
