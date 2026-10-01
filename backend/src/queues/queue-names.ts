/**
 * Every BullMQ queue the platform uses, defined once. Names never contain ':' (BullMQ key
 * separator). Business queues (notifications per channel, partner webhooks, refunds, ...) are
 * added here by the phase that implements them.
 */
export const QUEUE_NAMES = {
  /** Domain events relayed from the transactional outbox (notification-architecture.md). */
  DOMAIN_EVENTS: 'domain-events',
} as const;

export type QueueName = (typeof QUEUE_NAMES)[keyof typeof QUEUE_NAMES];

export const ALL_QUEUE_NAMES: readonly QueueName[] = Object.values(QUEUE_NAMES);
