import {
  type BeforeApplicationShutdown,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
  type OnModuleInit,
} from '@nestjs/common';
import {
  CREW_DOCUMENT_EXPIRING_EVENT,
  CrewDocumentsClientManageService,
} from '../modules/operator-staff/crew_documents_client_manage.service';
import { EventRouter, type EventRule } from '../modules/notifications/event_router_core.service';

/** First check shortly after the worker starts, then every few hours. A check is cheap and idempotent. */
const FIRST_CHECK_DELAY_MS = 30_000;
const CHECK_EVERY_MS = 6 * 60 * 60 * 1000;

const text = (value: unknown): string => (typeof value === 'string' ? value : '');

function when(payload: Record<string, unknown>): string {
  const date = text(payload.validTillText);
  const days = typeof payload.daysLeft === 'number' ? payload.daysLeft : 0;
  if (payload.stage === 'EXPIRED') return `expired on ${date}`;
  if (payload.stage === 'DAY0') return 'expires today';
  return `expires on ${date} (${days} day${days === 1 ? '' : 's'} left)`;
}

function title(payload: Record<string, unknown>): string {
  if (payload.stage === 'EXPIRED') return 'Document expired';
  if (payload.stage === 'DAY0') return 'Document expires today';
  return 'Document expiring soon';
}

/** Who is told when a driver's document is about to expire: the owner and the driver. */
export const CREW_DOCUMENT_EVENT_RULES: readonly EventRule[] = [
  {
    event: CREW_DOCUMENT_EXPIRING_EVENT,
    notices: [
      {
        to: [{ kind: 'operator-owners' }],
        title,
        body: (p) => `${text(p.driverName)}: ${text(p.documentName)} ${when(p)}.`,
        goTo: '/crew',
      },
      {
        to: [{ kind: 'user', field: 'driverId' }],
        title,
        body: (p) => `Your ${text(p.documentName)} ${when(p)}. Please give a renewed copy to your operator.`,
        goTo: '/notifications',
      },
    ],
    messages: [
      {
        channels: ['WHATSAPP'],
        kind: 'GENERAL',
        subject: title,
        body: (p) =>
          `Hi ${text(p.driverName)}, your ${text(p.documentName)} ${when(p)}. Please give a renewed copy to your operator.`,
        contact: { userField: 'driverId', nameField: 'driverName', phoneField: 'driverPhone' },
      },
    ],
  },
];

/**
 * Checks the validity dates of drivers' documents once in a while (worker process only) and
 * records a reminder event for every 30-day, 7-day, expiry-day and expired stage not sent yet.
 */
@Injectable()
export class CrewDocumentReminderWorker
  implements OnModuleInit, OnApplicationBootstrap, BeforeApplicationShutdown
{
  private readonly logger = new Logger(CrewDocumentReminderWorker.name);
  private first: NodeJS.Timeout | undefined;
  private every: NodeJS.Timeout | undefined;

  constructor(
    private readonly documents: CrewDocumentsClientManageService,
    private readonly router: EventRouter,
  ) {}

  onModuleInit(): void {
    this.router.addRules(CREW_DOCUMENT_EVENT_RULES);
  }

  onApplicationBootstrap(): void {
    this.first = setTimeout(() => void this.check(), FIRST_CHECK_DELAY_MS);
    this.every = setInterval(() => void this.check(), CHECK_EVERY_MS);
    this.first.unref();
    this.every.unref();
  }

  beforeApplicationShutdown(): void {
    if (this.first) clearTimeout(this.first);
    if (this.every) clearInterval(this.every);
  }

  async check(now = new Date()): Promise<void> {
    try {
      const result = await this.documents.scanExpiries(now);
      if (result.sent > 0) this.logger.log(result, 'Crew document reminders recorded');
    } catch (error) {
      this.logger.error(
        { message: error instanceof Error ? error.message : 'unknown' },
        'Crew document check failed',
      );
    }
  }
}
