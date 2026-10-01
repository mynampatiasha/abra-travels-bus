import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { type ClientSession } from 'mongoose';
import { RequestContextService } from '../common/request-context/request-context.service';
import { QUEUE_NAMES } from '../queues/queue-names';
import { DOMAIN_EVENT_TYPE_PATTERN, type DomainEvent } from './domain-event.types';
import { OutboxRepository } from './outbox.repository';

/**
 * Records domain events in the transactional outbox (architecture.md §7). An event is written in
 * the same MongoDB transaction as the state change it describes, so it exists if and only if the
 * change committed. Publishing to BullMQ happens later, in the worker's outbox relay.
 */
@Injectable()
export class OutboxService {
  constructor(private readonly repository: OutboxRepository) {}

  /**
   * @param session the TransactionRunner session of the state change; required and must be in a
   *   transaction — an event recorded outside the state change's transaction could be sent for a
   *   change that rolled back, or lost for one that committed.
   * @returns the generated eventId
   */
  async record(event: DomainEvent, session: ClientSession): Promise<string> {
    if (!session.inTransaction()) {
      throw new Error('Outbox events must be recorded inside the transaction of the state change');
    }
    if (!DOMAIN_EVENT_TYPE_PATTERN.test(event.type)) {
      throw new Error(
        `Invalid domain event type "${event.type}" (expected e.g. "booking.confirmed")`,
      );
    }
    if (event.aggregateType.trim() === '' || event.aggregateId.trim() === '') {
      throw new Error('Domain events need an aggregateType and aggregateId');
    }

    const now = new Date();
    const eventId = randomUUID();
    const requestId = RequestContextService.requestId();
    await this.repository.insert(
      {
        eventId,
        type: event.type,
        aggregateType: event.aggregateType,
        aggregateId: event.aggregateId,
        payload: event.payload,
        occurredAt: now,
        ...(requestId ? { requestId } : {}),
        queueName: QUEUE_NAMES.DOMAIN_EVENTS,
        status: 'PENDING',
        attempts: 0,
        availableAt: now,
      },
      session,
    );
    return eventId;
  }
}
