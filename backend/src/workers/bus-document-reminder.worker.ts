import {
  type BeforeApplicationShutdown,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
  type OnModuleInit,
} from '@nestjs/common';
import {
  BUS_DOCUMENT_EXPIRING_EVENT,
  BusDocumentsClientManageService,
} from '../modules/buses/bus_documents_client_manage.service';
import { EventRouter, type EventRule } from '../modules/notifications/event_router_core.service';

/** First check shortly after the worker starts, then every few hours. A check is cheap and idempotent. */
const FIRST_CHECK_DELAY_MS = 45_000;
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
  if (payload.stage === 'EXPIRED') return 'Bus document expired';
  if (payload.stage === 'DAY0') return 'Bus document expires today';
  return 'Bus document expiring soon';
}

const bus = (p: Record<string, unknown>): string => text(p.busRegistration) || text(p.busName);

/**
 * Who is told when a bus document is about to expire: the owners and the staff who manage buses, and the
 * people who run that bus (its usual driver and conductor, and the crew of its upcoming trips).
 */
export const BUS_DOCUMENT_EVENT_RULES: readonly EventRule[] = [
  {
    event: BUS_DOCUMENT_EXPIRING_EVENT,
    notices: [
      {
        to: [{ kind: 'operator-owners' }, { kind: 'operator-staff', permission: 'buses.update' }],
        title,
        body: (p) => `Bus ${bus(p)}: ${text(p.documentName)} ${when(p)}.`,
        goTo: '/buses',
      },
      {
        to: [{ kind: 'users', field: 'crewUserIds' }],
        title,
        body: (p) => `Your bus ${bus(p)}: ${text(p.documentName)} ${when(p)}. Please remind your operator.`,
        goTo: '/bus-documents',
      },
    ],
    messages: [
      {
        channels: ['WHATSAPP'],
        kind: 'GENERAL',
        subject: title,
        body: (p) =>
          `Hi ${text(p.driverName)}, the ${text(p.documentName)} of bus ${bus(p)} ${when(p)}. Please remind your operator.`,
        contact: { userField: 'driverId', nameField: 'driverName', phoneField: 'driverPhone' },
        when: (p) => text(p.driverPhone) !== '',
      },
      {
        channels: ['WHATSAPP'],
        kind: 'GENERAL',
        subject: title,
        body: (p) =>
          `Hi ${text(p.conductorName)}, the ${text(p.documentName)} of bus ${bus(p)} ${when(p)}. Please remind your operator.`,
        contact: { userField: 'conductorId', nameField: 'conductorName', phoneField: 'conductorPhone' },
        when: (p) => text(p.conductorPhone) !== '',
      },
    ],
  },
];

/**
 * Checks the expiry dates of bus documents once in a while (worker process only) and records a
 * reminder event for every reminder day, expiry day and expired stage not sent yet.
 */
@Injectable()
export class BusDocumentReminderWorker
  implements OnModuleInit, OnApplicationBootstrap, BeforeApplicationShutdown
{
  private readonly logger = new Logger(BusDocumentReminderWorker.name);
  private first: NodeJS.Timeout | undefined;
  private every: NodeJS.Timeout | undefined;

  constructor(
    private readonly documents: BusDocumentsClientManageService,
    private readonly router: EventRouter,
  ) {}

  onModuleInit(): void {
    this.router.addRules(BUS_DOCUMENT_EVENT_RULES);
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
      if (result.sent > 0) this.logger.log(result, 'Bus document reminders recorded');
    } catch (error) {
      this.logger.error(
        { message: error instanceof Error ? error.message : 'unknown' },
        'Bus document check failed',
      );
    }
  }
}
