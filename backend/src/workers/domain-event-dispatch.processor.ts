import { Injectable } from '@nestjs/common';
import { type Job, UnrecoverableError } from 'bullmq';
import { DomainEventHandlerRegistry } from '../events/domain-event-handler.registry';
import { isDomainEventMessage } from '../events/domain-event.types';

export interface DomainEventDispatchResult {
  eventId: string;
  handledBy: string[];
}

/**
 * Processor of the `domain-events` queue: hands each event to every handler registered for its
 * type. An event with no handlers completes normally (nothing subscribes to it yet).
 * A handler error fails the job so BullMQ retries it with back-off; all handlers of the event run
 * again on retry, which is why handlers must be idempotent. A malformed job is not retried.
 */
@Injectable()
export class DomainEventDispatchProcessor {
  constructor(private readonly registry: DomainEventHandlerRegistry) {}

  async process(job: Job): Promise<DomainEventDispatchResult> {
    const event: unknown = job.data;
    if (!isDomainEventMessage(event)) {
      throw new UnrecoverableError(`Job ${job.id ?? '?'} is not a valid domain event`);
    }

    const handlers = this.registry.handlersFor(event.type);
    for (const handler of handlers) {
      await handler.handle(event);
    }
    return { eventId: event.eventId, handledBy: handlers.map((handler) => handler.name) };
  }
}
