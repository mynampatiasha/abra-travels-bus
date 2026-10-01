/**
 * A fact that happened in the domain (`booking.confirmed`, `trip.delayed`, ...). Recorded in the
 * outbox inside the same transaction as the state change (architecture.md §7), then relayed to
 * the `domain-events` queue. Payloads carry ids and snapshot values, never secrets.
 */
export interface DomainEvent<TPayload extends Record<string, unknown> = Record<string, unknown>> {
  /** `<aggregate>.<past-tense-verb>`, lowercase, dash-separated words: `seat-lock.expired`. */
  readonly type: string;
  readonly aggregateType: string;
  readonly aggregateId: string;
  readonly payload: TPayload;
}

/** What consumers receive: the event plus its identity and trace data. */
export interface DomainEventMessage<
  TPayload extends Record<string, unknown> = Record<string, unknown>,
> extends DomainEvent<TPayload> {
  /** UUID; also the BullMQ job id, so a re-published event is not enqueued twice. */
  readonly eventId: string;
  /** ISO-8601 UTC. */
  readonly occurredAt: string;
  readonly requestId?: string;
}

export const DOMAIN_EVENT_TYPE_PATTERN = /^[a-z][a-z-]*(\.[a-z][a-z-]*)+$/;

export function isDomainEventMessage(value: unknown): value is DomainEventMessage {
  if (typeof value !== 'object' || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.eventId === 'string' &&
    typeof candidate.type === 'string' &&
    DOMAIN_EVENT_TYPE_PATTERN.test(candidate.type) &&
    typeof candidate.aggregateType === 'string' &&
    typeof candidate.aggregateId === 'string' &&
    typeof candidate.occurredAt === 'string' &&
    typeof candidate.payload === 'object' &&
    candidate.payload !== null
  );
}
