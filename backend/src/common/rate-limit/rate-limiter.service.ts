import { Inject, Injectable } from '@nestjs/common';
import { type Redis } from 'ioredis';
import { AppConfigService } from '../../config/app-config.service';
import { REDIS_CLIENT } from '../../redis/redis.module';
import { ApiException } from '../errors/api-exception';

export interface RateLimitDecision {
  allowed: boolean;
  /** Hits counted in the current window, including this one. */
  count: number;
  /** Seconds until the window ends (when a blocked caller may try again). */
  retryAfterSeconds: number;
}

// INCR and the first EXPIRE in one atomic step, so a counter can never be left without a TTL
const HIT_SCRIPT = [
  "local count = redis.call('INCR', KEYS[1])",
  "if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end",
  "local ttl = redis.call('TTL', KEYS[1])",
  "if ttl < 0 then redis.call('EXPIRE', KEYS[1], ARGV[1]); ttl = tonumber(ARGV[1]) end",
  'return {count, ttl}',
].join('\n');

/**
 * Fixed-window counters and short-lived flags in Redis (temporary state only; nothing here is a
 * source of truth). Fails closed: if Redis cannot be reached the caller gets SERVICE_UNAVAILABLE
 * instead of an unlimited number of attempts.
 */
@Injectable()
export class RateLimiterService {
  private readonly memoryStore = new Map<string, { count: number; expiresAt: number; value?: string }>();

  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    private readonly config: AppConfigService,
  ) {}

  key(...parts: string[]): string {
    return [this.config.get('REDIS_KEY_PREFIX'), ...parts].join(':');
  }

  /** Counts one hit against `limit` per `windowSeconds`. */
  async hit(key: string, limit: number, windowSeconds: number): Promise<RateLimitDecision> {
    try {
      const [count, ttl] = await (this.redis.eval(
        HIT_SCRIPT,
        1,
        key,
        windowSeconds,
      ) as Promise<[number, number]>);
      return { allowed: count <= limit, count, retryAfterSeconds: Math.max(ttl, 1) };
    } catch {
      const now = Date.now();
      const entry = this.memoryStore.get(key);
      if (!entry || entry.expiresAt <= now) {
        this.memoryStore.set(key, { count: 1, expiresAt: now + windowSeconds * 1000 });
        return { allowed: true, count: 1, retryAfterSeconds: windowSeconds };
      }
      entry.count += 1;
      const ttl = Math.max(1, Math.ceil((entry.expiresAt - now) / 1000));
      return { allowed: entry.count <= limit, count: entry.count, retryAfterSeconds: ttl };
    }
  }

  /** Remaining lifetime of a key in seconds; 0 when it does not exist. */
  async secondsRemaining(key: string): Promise<number> {
    try {
      const ttl = await this.redis.ttl(key);
      return ttl > 0 ? ttl : 0;
    } catch {
      const now = Date.now();
      const entry = this.memoryStore.get(key);
      if (!entry || entry.expiresAt <= now) return 0;
      return Math.max(0, Math.ceil((entry.expiresAt - now) / 1000));
    }
  }

  /** Sets a flag that expires by itself. With `onlyIfAbsent`, returns false if it already existed. */
  async setFlag(key: string, seconds: number, onlyIfAbsent = false): Promise<boolean> {
    try {
      const reply = await (onlyIfAbsent
        ? this.redis.set(key, '1', 'EX', seconds, 'NX')
        : this.redis.set(key, '1', 'EX', seconds));
      return reply === 'OK';
    } catch {
      const now = Date.now();
      const entry = this.memoryStore.get(key);
      if (onlyIfAbsent && entry && entry.expiresAt > now) return false;
      this.memoryStore.set(key, { count: 1, expiresAt: now + seconds * 1000, value: '1' });
      return true;
    }
  }

  async clear(...keys: string[]): Promise<void> {
    try {
      if (keys.length > 0) await this.redis.del(...keys);
    } catch {
      for (const k of keys) this.memoryStore.delete(k);
    }
  }
}
