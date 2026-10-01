import { randomUUID } from 'node:crypto';
import { hostname } from 'node:os';
import { Injectable, Logger } from '@nestjs/common';
import { AppConfigService } from '../config/app-config.service';
import { ALL_QUEUE_NAMES, type QueueName } from '../queues/queue-names';
import { QueueRegistry } from '../queues/queue-registry.service';
import { type DomainEventMessage } from './domain-event.types';
import { OutboxRepository, type StoredOutboxEvent } from './outbox.repository';

export type RelayOutcome = 'published' | 'retried' | 'failed' | 'leaseLost';
export type RelayBatchResult = Record<RelayOutcome, number>;

const RETRY_BASE_DELAY_MS = 1_000;
const RETRY_MAX_DELAY_MS = 60_000;

/** Exponential back-off between publish attempts: 1 s, 2 s, 4 s ... capped at 60 s. */
export function outboxRetryDelayMs(attempts: number): number {
  return Math.min(RETRY_BASE_DELAY_MS * 2 ** Math.max(0, attempts - 1), RETRY_MAX_DELAY_MS);
}

function toMessage(event: StoredOutboxEvent): DomainEventMessage {
  return {
    eventId: event.eventId,
    type: event.type,
    aggregateType: event.aggregateType,
    aggregateId: event.aggregateId,
    payload: event.payload,
    occurredAt: event.occurredAt.toISOString(),
    ...(event.requestId ? { requestId: event.requestId } : {}),
  };
}

function isKnownQueue(name: string): name is QueueName {
  return (ALL_QUEUE_NAMES as readonly string[]).includes(name);
}

/**
 * Moves committed outbox events into BullMQ. Delivery is at-least-once and idempotent:
 *
 * 1. claim  — one event at a time, atomically, with a lease (several relays can run safely)
 * 2. enqueue — BullMQ job id = eventId, so re-adding an already-enqueued event is a no-op
 * 3. mark PUBLISHED — only after the enqueue succeeded, and only if the lease is still held
 *
 * If the process dies between 2 and 3 the lease expires, another pass re-claims the event, the
 * enqueue is deduplicated by job id, and the event is marked. Enqueue failures (Redis down) are
 * rescheduled with back-off; after OUTBOX_MAX_PUBLISH_ATTEMPTS the event is parked as FAILED —
 * kept in MongoDB, logged as an error, counted in readiness, and requeueable. Never dropped.
 */
@Injectable()
export class OutboxRelayService {
  private readonly logger = new Logger(OutboxRelayService.name);
  readonly relayId = `${hostname()}:${process.pid}:${randomUUID().slice(0, 8)}`;

  constructor(
    private readonly repository: OutboxRepository,
    private readonly queues: QueueRegistry,
    private readonly config: AppConfigService,
  ) {}

  /** One relay pass: publishes up to OUTBOX_BATCH_SIZE due events. */
  async relayBatch(): Promise<RelayBatchResult> {
    const result: RelayBatchResult = { published: 0, retried: 0, failed: 0, leaseLost: 0 };
    const batchSize = this.config.get('OUTBOX_BATCH_SIZE');
    const leaseMs = this.config.get('OUTBOX_LEASE_MS');

    for (let processed = 0; processed < batchSize; processed++) {
      const event = await this.repository.claimNext(this.relayId, leaseMs, new Date());
      if (!event) break;
      result[await this.publishOne(event)]++;
    }
    return result;
  }

  private async publishOne(event: StoredOutboxEvent): Promise<RelayOutcome> {
    try {
      if (!isKnownQueue(event.queueName)) {
        throw new Error(`Unknown queue "${event.queueName}"`);
      }
      await this.queues
        .get(event.queueName)
        .add(event.type, toMessage(event), { jobId: event.eventId });
    } catch (error) {
      return this.handlePublishFailure(event, error instanceof Error ? error.message : 'unknown');
    }

    const marked = await this.repository.markPublished(event._id, this.relayId, new Date());
    if (!marked) {
      // Another relay reclaimed it after our lease expired; it will dedupe on the job id
      this.logger.warn({ eventId: event.eventId }, 'Outbox lease lost after enqueue');
      return 'leaseLost';
    }
    return 'published';
  }

  private async handlePublishFailure(
    event: StoredOutboxEvent,
    reason: string,
  ): Promise<RelayOutcome> {
    const context = { eventId: event.eventId, type: event.type, attempts: event.attempts, reason };

    if (event.attempts >= this.config.get('OUTBOX_MAX_PUBLISH_ATTEMPTS')) {
      await this.repository.markFailed(event._id, this.relayId, reason);
      this.logger.error(context, 'Outbox event parked as FAILED after max publish attempts');
      return 'failed';
    }

    const retryAt = new Date(Date.now() + outboxRetryDelayMs(event.attempts));
    await this.repository.scheduleRetry(event._id, this.relayId, retryAt, reason);
    this.logger.warn({ ...context, retryAt }, 'Outbox publish failed; retry scheduled');
    return 'retried';
  }
}
