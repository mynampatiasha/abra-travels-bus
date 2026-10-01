import { Injectable, Logger, type OnApplicationShutdown } from '@nestjs/common';
import { Queue } from 'bullmq';
import { AppConfigService } from '../config/app-config.service';
import { bullmqConnectionOptions, defaultJobOptions } from './bullmq-connection.factory';
import { ALL_QUEUE_NAMES, type QueueName } from './queue-names';

/** Minimum time between two recreations of the same queue while Redis stays unreachable. */
export const QUEUE_RECREATE_INTERVAL_MS = 1_000;
/** Upper bound for closing one queue; a queue that never connected must not block shutdown. */
const QUEUE_CLOSE_TIMEOUT_MS = 5_000;

interface QueueEntry {
  queue: Queue;
  createdAt: number;
  /** BullMQ initialisation (connection + version check) failed; the instance is unusable. */
  initFailed: boolean;
}

/**
 * The single place that creates BullMQ Queue (producer) instances: one instance per queue name,
 * created on first use with the configured prefix and default job options, closed on shutdown.
 * Redis only carries jobs; every job is derived from state already committed to MongoDB.
 *
 * Recovery: BullMQ never retries a failed initialisation, so a Queue constructed while Redis is
 * down stays broken even after Redis returns. The registry watches each instance's
 * initialisation; once it has failed, the next `get()` closes that instance and creates a fresh
 * one (at most once per QUEUE_RECREATE_INTERVAL_MS, so a long outage does not churn
 * connections). A queue that initialised successfully reconnects by itself after an outage.
 */
@Injectable()
export class QueueRegistry implements OnApplicationShutdown {
  private readonly logger = new Logger(QueueRegistry.name);
  private readonly entries = new Map<QueueName, QueueEntry>();
  private createdCount = 0;
  private closing = false;

  constructor(private readonly config: AppConfigService) {}

  get prefix(): string {
    return this.config.get('QUEUE_PREFIX');
  }

  /** Queue instances created since start (recreations included). For diagnostics and tests. */
  get instancesCreated(): number {
    return this.createdCount;
  }

  /** Live instances held by the registry; never more than one per queue name. */
  get size(): number {
    return this.entries.size;
  }

  get(name: QueueName): Queue {
    if (this.closing) throw new Error('QueueRegistry is shut down');

    const existing = this.entries.get(name);
    if (existing && !this.shouldRecreate(existing)) return existing.queue;

    if (existing) {
      this.entries.delete(name);
      this.logger.warn({ queue: name }, 'Recreating queue after failed initialisation');
      void this.closeQuietly(existing.queue);
    }
    return this.create(name).queue;
  }

  all(): Array<{ name: QueueName; queue: Queue }> {
    return ALL_QUEUE_NAMES.map((name) => ({ name, queue: this.get(name) }));
  }

  async onApplicationShutdown(): Promise<void> {
    this.closing = true;
    const queues = [...this.entries.values()].map((entry) => entry.queue);
    this.entries.clear();
    await Promise.all(queues.map((queue) => this.closeQuietly(queue)));
  }

  private shouldRecreate(entry: QueueEntry): boolean {
    return entry.initFailed && Date.now() - entry.createdAt >= QUEUE_RECREATE_INTERVAL_MS;
  }

  private create(name: QueueName): QueueEntry {
    const queue = new Queue(name, {
      connection: bullmqConnectionOptions(this.config.get('REDIS_URL'), 'producer'),
      prefix: this.prefix,
      defaultJobOptions: defaultJobOptions(this.config),
      // Callers get an error while Redis is down (and retry) instead of waiting for it
      skipWaitingForReady: true,
    });
    const entry: QueueEntry = { queue, createdAt: Date.now(), initFailed: false };
    this.createdCount++;

    // Without a listener an 'error' event would crash the process
    queue.on('error', (error: Error) =>
      this.logger.warn({ queue: name, message: error.message }, 'Queue connection error'),
    );
    queue.waitUntilReady().catch((error: unknown) => {
      entry.initFailed = true;
      this.logger.warn(
        { queue: name, message: error instanceof Error ? error.message : 'unknown' },
        'Queue initialisation failed; it will be recreated on next use',
      );
    });

    this.entries.set(name, entry);
    return entry;
  }

  private async closeQuietly(queue: Queue): Promise<void> {
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        queue.close(),
        new Promise<void>((resolve) => {
          timer = setTimeout(resolve, QUEUE_CLOSE_TIMEOUT_MS);
        }),
      ]);
    } catch (error) {
      this.logger.warn(
        { queue: queue.name, message: error instanceof Error ? error.message : 'unknown' },
        'Queue close failed',
      );
    } finally {
      // The 'error' listener stays attached: a connection that did not close in time may still
      // emit, and an unhandled 'error' event would crash the process
      clearTimeout(timer);
    }
  }
}
