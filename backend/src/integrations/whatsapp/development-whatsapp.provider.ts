import { Logger } from '@nestjs/common';
import { type WhatsAppProvider, type WhatsAppTemplateMessage } from './whatsapp-provider.interface';

const INBOX_SIZE = 50;

/**
 * DEVELOPMENT / TEST ONLY — sends nothing. Messages are kept in a small in-memory inbox (read by
 * automated tests) and, when NODE_ENV=development, written to the server log so a developer can
 * read the one-time code, exactly like the development SMS adapter. Configuration validation
 * refuses WHATSAPP_PROVIDER=development in production, and the factory in WhatsAppModule refuses
 * to construct this class there.
 */
export class DevelopmentWhatsAppProvider implements WhatsAppProvider {
  readonly providerKey = 'development';
  private readonly logger = new Logger('DevelopmentWhatsApp');
  private readonly inbox: WhatsAppTemplateMessage[] = [];

  constructor(private readonly logMessages: boolean) {}

  sendTemplate(message: WhatsAppTemplateMessage): Promise<void> {
    this.inbox.push(message);
    if (this.inbox.length > INBOX_SIZE) this.inbox.shift();
    if (this.logMessages) {
      this.logger.log(
        `DEVELOPMENT WHATSAPP (not sent) to ${message.to}: template ${message.templateName} ` +
          `[${message.bodyParameters.join(', ')}]`,
      );
    }
    return Promise.resolve();
  }

  /** Most recent message to a number. */
  lastMessageTo(phone: string): WhatsAppTemplateMessage | undefined {
    return this.inbox.findLast((message) => message.to === phone);
  }

  messagesTo(phone: string): WhatsAppTemplateMessage[] {
    return this.inbox.filter((message) => message.to === phone);
  }
}
