import { Injectable } from '@nestjs/common';
import { type Queue } from 'bullmq';
import { AppConfigService } from '../config/app-config.service';
import { type QueueName } from './queue-names';
import { QueueRegistry } from './queue-registry.service';

export interface QueueStatus {
  waiting: number;
  active: number;
  delayed: number;
  failed: number;
  /** Age of the oldest job waiting to be picked up; 0 when nothing waits. */
  oldestWaitingAgeMs: number;
  /** Oldest waiting job older than QUEUE_LAG_ALERT_MS. */
  lagging: boolean;
  /** Connected BullMQ workers; 0 means jobs accumulate until a worker starts. */
  workers: number;
}

/**
 * Queue depth, lag and worker presence for readiness. Throws when Redis cannot be reached, which
 * the readiness check turns into a failed dependency.
 */
@Injectable()
export class QueueHealthService {
  constructor(
    private readonly registry: QueueRegistry,
    private readonly config: AppConfigService,
  ) {}

  async status(now: number = Date.now()): Promise<Record<QueueName, QueueStatus>> {
    const entries = await Promise.all(
      this.registry
        .all()
        .map(async ({ name, queue }) => [name, await this.queueStatus(queue, now)]),
    );
    return Object.fromEntries(entries) as Record<QueueName, QueueStatus>;
  }

  private async queueStatus(queue: Queue, now: number): Promise<QueueStatus> {
    const [counts, oldestWaiting, workers] = await Promise.all([
      queue.getJobCounts('waiting', 'active', 'delayed', 'failed'),
      queue.getWaiting(0, 0),
      queue.getWorkersCount(),
    ]);
    const oldestTimestamp = oldestWaiting[0]?.timestamp;
    const oldestWaitingAgeMs = oldestTimestamp ? Math.max(0, now - oldestTimestamp) : 0;

    return {
      waiting: counts.waiting ?? 0,
      active: counts.active ?? 0,
      delayed: counts.delayed ?? 0,
      failed: counts.failed ?? 0,
      oldestWaitingAgeMs,
      lagging: oldestWaitingAgeMs > this.config.get('QUEUE_LAG_ALERT_MS'),
      workers,
    };
  }
}
