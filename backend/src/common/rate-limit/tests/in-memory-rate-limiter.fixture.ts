import { type RateLimitDecision, type RateLimiterService } from '../rate-limiter.service';

/**
 * In-memory stand-in for RateLimiterService in unit tests, with a controllable clock. Mirrors the
 * Redis semantics: fixed windows that start at the first hit, flags that expire by themselves.
 */
export class InMemoryRateLimiter {
  nowMs = 1_000_000;
  private readonly entries = new Map<string, { count: number; expiresAtMs: number }>();

  advanceSeconds(seconds: number): void {
    this.nowMs += seconds * 1000;
  }

  key(...parts: string[]): string {
    return ['test', ...parts].join(':');
  }

  private live(key: string): { count: number; expiresAtMs: number } | undefined {
    const entry = this.entries.get(key);
    if (entry && entry.expiresAtMs <= this.nowMs) {
      this.entries.delete(key);
      return undefined;
    }
    return entry;
  }

  hit(key: string, limit: number, windowSeconds: number): Promise<RateLimitDecision> {
    const entry = this.live(key) ?? { count: 0, expiresAtMs: this.nowMs + windowSeconds * 1000 };
    entry.count += 1;
    this.entries.set(key, entry);
    return Promise.resolve({
      allowed: entry.count <= limit,
      count: entry.count,
      retryAfterSeconds: Math.max(1, Math.ceil((entry.expiresAtMs - this.nowMs) / 1000)),
    });
  }

  secondsRemaining(key: string): Promise<number> {
    const entry = this.live(key);
    return Promise.resolve(entry ? Math.ceil((entry.expiresAtMs - this.nowMs) / 1000) : 0);
  }

  setFlag(key: string, seconds: number, onlyIfAbsent = false): Promise<boolean> {
    if (onlyIfAbsent && this.live(key)) return Promise.resolve(false);
    this.entries.set(key, { count: 1, expiresAtMs: this.nowMs + seconds * 1000 });
    return Promise.resolve(true);
  }

  clear(...keys: string[]): Promise<void> {
    for (const key of keys) this.entries.delete(key);
    return Promise.resolve();
  }

  asService(): RateLimiterService {
    return this as unknown as RateLimiterService;
  }
}

/** Minimal AppConfigService stand-in backed by a plain object. */
export function configOf<T extends Record<string, unknown>>(values: T) {
  return {
    get: (key: string) => values[key],
    isProduction: values.NODE_ENV === 'production',
  } as unknown as import('../../../config/app-config.service').AppConfigService;
}
