import { Inject, Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Redis } from 'ioredis';
import { ConnectionStates, type Connection } from 'mongoose';
import { AppConfigService } from '../../../config/app-config.service';
import { OutboxRepository, type OutboxStats } from '../../../events/outbox.repository';
import { QueueHealthService, type QueueStatus } from '../../../queues/queue-health.service';
import { type QueueName } from '../../../queues/queue-names';
import { REDIS_CLIENT } from '../../../redis/redis.module';

export type DependencyStatus = 'up' | 'down';

export interface DependencyCheck<TDetails = undefined> {
  status: DependencyStatus;
  latencyMs: number;
  /** Short failure reason. Never contains connection strings or credentials. */
  reason?: string;
  details?: TDetails;
}

export type OutboxHealth = OutboxStats & { lagging: boolean };

export interface ReadinessReport {
  ready: boolean;
  checks: {
    mongodb: DependencyCheck;
    redis: DependencyCheck;
    queues: DependencyCheck<Record<QueueName, QueueStatus>>;
    outbox: DependencyCheck<OutboxHealth>;
  };
  /** Conditions to act on that do not stop this API instance from serving traffic. */
  warnings: string[];
}

const CHECK_TIMEOUT_MS = 2_000;

async function timed<T>(check: () => Promise<T>): Promise<DependencyCheck<T>> {
  const startedAt = performance.now();
  let timer: NodeJS.Timeout | undefined;
  try {
    const details = await Promise.race([
      check(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('timed out')), CHECK_TIMEOUT_MS);
      }),
    ]);
    const latencyMs = Math.round(performance.now() - startedAt);
    return details === undefined
      ? { status: 'up', latencyMs }
      : { status: 'up', latencyMs, details };
  } catch (error) {
    return {
      status: 'down',
      latencyMs: Math.round(performance.now() - startedAt),
      reason: error instanceof Error ? error.message.slice(0, 120) : 'unknown error',
    };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Readiness = this API instance can serve traffic: MongoDB primary reachable, Redis answering,
 * queues readable (so events can be enqueued) and the outbox readable. Any of these down → 503.
 *
 * Worker-side problems (no worker connected, queue or outbox lag, events parked as FAILED) are
 * reported as `warnings` but do not fail readiness: taking the API out of the load balancer would
 * not fix a worker problem. Liveness (/health/live) never touches dependencies.
 */
@Injectable()
export class ReadinessCheckService {
  constructor(
    @InjectConnection() private readonly mongoConnection: Connection,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    private readonly queueHealth: QueueHealthService,
    private readonly outbox: OutboxRepository,
    private readonly config: AppConfigService,
  ) {}

  async check(): Promise<ReadinessReport> {
    const now = Date.now();
    const [mongodb, redis, queues, outbox] = await Promise.all([
      timed(() => this.pingMongo()),
      timed(() => this.pingRedis()),
      timed(() => this.queueHealth.status(now)),
      timed(() => this.outboxHealth(now)),
    ]);
    const checks = { mongodb, redis, queues, outbox };
    return {
      ready: Object.values(checks).every((check) => check.status === 'up'),
      checks,
      warnings: this.warningsFor(queues.details, outbox.details),
    };
  }

  private async outboxHealth(now: number): Promise<OutboxHealth> {
    const stats = await this.outbox.stats(new Date(now));
    return { ...stats, lagging: stats.oldestPendingAgeMs > this.config.get('QUEUE_LAG_ALERT_MS') };
  }

  private warningsFor(
    queues: Record<string, QueueStatus> | undefined,
    outbox: OutboxHealth | undefined,
  ): string[] {
    const warnings: string[] = [];
    for (const [name, queue] of Object.entries(queues ?? {})) {
      if (queue.workers === 0) warnings.push(`queue ${name}: no worker connected`);
      if (queue.lagging) warnings.push(`queue ${name}: oldest waiting job exceeds lag threshold`);
      if (queue.failed > 0) warnings.push(`queue ${name}: ${queue.failed} failed job(s)`);
    }
    if (outbox?.lagging) warnings.push('outbox: oldest unpublished event exceeds lag threshold');
    if (outbox && outbox.failed > 0) warnings.push(`outbox: ${outbox.failed} FAILED event(s)`);
    return warnings;
  }

  private async pingMongo(): Promise<undefined> {
    const database = this.mongoConnection.db;
    if (this.mongoConnection.readyState !== ConnectionStates.connected || !database) {
      throw new Error('not connected');
    }
    await database.command({ ping: 1 });
    return undefined;
  }

  private async pingRedis(): Promise<undefined> {
    const reply = await this.redis.ping();
    if (reply !== 'PONG') throw new Error('unexpected ping reply');
    return undefined;
  }
}
