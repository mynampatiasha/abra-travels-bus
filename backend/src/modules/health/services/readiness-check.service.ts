import { Inject, Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Redis } from 'ioredis';
import { ConnectionStates, type Connection } from 'mongoose';
import { REDIS_CLIENT } from '../../../redis/redis.module';

export type DependencyStatus = 'up' | 'down';

export interface DependencyCheck {
  status: DependencyStatus;
  latencyMs: number;
  /** Short failure reason. Never contains connection strings or credentials. */
  reason?: string;
}

export interface ReadinessReport {
  ready: boolean;
  checks: { mongodb: DependencyCheck; redis: DependencyCheck };
}

const CHECK_TIMEOUT_MS = 2_000;

async function timed(check: () => Promise<void>): Promise<DependencyCheck> {
  const startedAt = performance.now();
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      check(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('timed out')), CHECK_TIMEOUT_MS);
      }),
    ]);
    return { status: 'up', latencyMs: Math.round(performance.now() - startedAt) };
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
 * Readiness = the API can serve traffic: MongoDB primary reachable and Redis answering.
 * Queue lag is added when BullMQ is configured (Phase 2 step 6).
 */
@Injectable()
export class ReadinessCheckService {
  constructor(
    @InjectConnection() private readonly mongoConnection: Connection,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  async check(): Promise<ReadinessReport> {
    const [mongodb, redis] = await Promise.all([
      timed(() => this.pingMongo()),
      timed(() => this.pingRedis()),
    ]);
    return { ready: mongodb.status === 'up' && redis.status === 'up', checks: { mongodb, redis } };
  }

  private async pingMongo(): Promise<void> {
    const database = this.mongoConnection.db;
    if (this.mongoConnection.readyState !== ConnectionStates.connected || !database) {
      throw new Error('not connected');
    }
    await database.command({ ping: 1 });
  }

  private async pingRedis(): Promise<void> {
    const reply = await this.redis.ping();
    if (reply !== 'PONG') throw new Error('unexpected ping reply');
  }
}
