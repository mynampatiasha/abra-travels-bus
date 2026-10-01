import { type DefaultJobOptions, type RedisOptions } from 'bullmq';
import { type AppConfigService } from '../config/app-config.service';

export type BullmqConnectionRole = 'producer' | 'worker';

/**
 * Redis connection options for BullMQ, built from REDIS_URL (the same Redis as the rest of the
 * backend; BullMQ opens its own connections).
 *
 * - producer (Queue.add, counts): a command waits for at most one reconnect attempt and then
 *   fails (about 1 s while Redis is unreachable), so the outbox relay records the failure and
 *   retries later instead of hanging. The offline queue stays enabled on purpose: BullMQ sends an
 *   INFO version check the moment a Queue is constructed, and with `enableOfflineQueue: false`
 *   that check fails before the socket is open, leaving the queue permanently unusable.
 *   A queue whose initialisation still fails (Redis down at creation) is recreated by
 *   QueueRegistry.
 * - worker: `maxRetriesPerRequest: null` is required by BullMQ for its blocking commands; the
 *   worker waits and reconnects on its own when Redis comes back.
 */
export function bullmqConnectionOptions(
  redisUrl: string,
  role: BullmqConnectionRole,
): RedisOptions {
  const connectionName = `abra-travels-bullmq-${role}`;
  return role === 'producer'
    ? { url: redisUrl, connectionName, maxRetriesPerRequest: 1 }
    : { url: redisUrl, connectionName, maxRetriesPerRequest: null };
}

/**
 * Defaults for every job: retries with exponential back-off (QUEUE_DEFAULT_ATTEMPTS,
 * QUEUE_BACKOFF_DELAY_MS). Completed jobs are kept for a day, so a re-published outbox event
 * (same jobId) is recognised as a duplicate; failed jobs are kept for a week for inspection.
 */
export function defaultJobOptions(config: AppConfigService): DefaultJobOptions {
  return {
    attempts: config.get('QUEUE_DEFAULT_ATTEMPTS'),
    backoff: { type: 'exponential', delay: config.get('QUEUE_BACKOFF_DELAY_MS') },
    removeOnComplete: { age: 24 * 60 * 60, count: 10_000 },
    removeOnFail: { age: 7 * 24 * 60 * 60 },
  };
}
