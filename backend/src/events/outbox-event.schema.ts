import { Schema } from 'mongoose';

export const OUTBOX_EVENT_MODEL = 'OutboxEvent';

/**
 * PENDING    → waiting to be published (new, or retry scheduled at `availableAt`)
 * PUBLISHING → claimed by one relay until `lockedUntil`; reclaimable after the lease expires
 * PUBLISHED  → enqueued in BullMQ (terminal)
 * FAILED     → gave up after OUTBOX_MAX_PUBLISH_ATTEMPTS; kept, logged, can be requeued
 */
export const OUTBOX_STATUSES = ['PENDING', 'PUBLISHING', 'PUBLISHED', 'FAILED'] as const;
export type OutboxStatus = (typeof OUTBOX_STATUSES)[number];

export interface OutboxEvent {
  eventId: string;
  type: string;
  aggregateType: string;
  aggregateId: string;
  payload: Record<string, unknown>;
  occurredAt: Date;
  requestId?: string;
  queueName: string;
  status: OutboxStatus;
  /** Publish attempts so far (incremented when a relay claims the event). */
  attempts: number;
  /** Earliest time the event may be (re)published. */
  availableAt: Date;
  lockedBy?: string | null;
  lockedUntil?: Date | null;
  lastError?: string | null;
  publishedAt?: Date | null;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `outbox_events` (database-architecture.md §10). */
export const outboxEventSchema = new Schema<OutboxEvent>(
  {
    eventId: { type: String, required: true },
    type: { type: String, required: true },
    aggregateType: { type: String, required: true },
    aggregateId: { type: String, required: true },
    payload: { type: Schema.Types.Mixed, required: true },
    occurredAt: { type: Date, required: true },
    requestId: { type: String },
    queueName: { type: String, required: true },
    status: { type: String, enum: OUTBOX_STATUSES, required: true, default: 'PENDING' },
    attempts: { type: Number, required: true, default: 0, min: 0 },
    availableAt: { type: Date, required: true },
    lockedBy: { type: String, default: null },
    lockedUntil: { type: Date, default: null },
    lastError: { type: String, default: null },
    publishedAt: { type: Date, default: null },
  },
  { collection: 'outbox_events', timestamps: true, minimize: false, versionKey: false },
);

outboxEventSchema.index({ eventId: 1 }, { unique: true });
// Relay claim queries: due PENDING events, and PUBLISHING events whose lease expired
outboxEventSchema.index({ status: 1, availableAt: 1 });
outboxEventSchema.index({ status: 1, lockedUntil: 1 });
