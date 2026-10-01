import { Injectable } from '@nestjs/common';
import { type DomainEventMessage } from './domain-event.types';

/**
 * A consumer of domain events, run by the worker process. Delivery is at-least-once (a job can be
 * retried, an event can be re-published after a relay crash), so `handle` must be idempotent —
 * e.g. by keying its own writes on `eventId` (notifications: unique eventId + channel).
 */
export interface DomainEventHandler {
  /** Stable name for logs and job results. */
  readonly name: string;
  readonly eventTypes: readonly string[];
  handle(event: DomainEventMessage): Promise<void>;
}

/**
 * Modules register their handlers in `onModuleInit`. No business handlers exist yet; they are
 * added by the phases that own each event (notifications, partner webhooks, analytics, ...).
 */
@Injectable()
export class DomainEventHandlerRegistry {
  private readonly handlers: DomainEventHandler[] = [];

  register(handler: DomainEventHandler): void {
    if (this.handlers.some((existing) => existing.name === handler.name)) {
      throw new Error(`Domain event handler "${handler.name}" is already registered`);
    }
    this.handlers.push(handler);
  }

  unregister(name: string): void {
    const index = this.handlers.findIndex((handler) => handler.name === name);
    if (index >= 0) this.handlers.splice(index, 1);
  }

  handlersFor(eventType: string): readonly DomainEventHandler[] {
    return this.handlers.filter((handler) => handler.eventTypes.includes(eventType));
  }
}
