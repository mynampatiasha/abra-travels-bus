import { randomUUID } from 'node:crypto';
import { Redis } from 'ioredis';
import { AppConfigService } from '../../config/app-config.service';
import { validateEnvironment } from '../../config/environment-loader';
import { validTestEnvironment } from '../../config/tests/valid-test-environment';

/**
 * Helpers for e2e tests against the real Docker Redis. Every suite uses its own queue prefix so it
 * never touches development queues, and deletes its keys afterwards.
 */
export function uniqueQueuePrefix(): string {
  return `abra-test-${randomUUID().slice(0, 8)}`;
}

export function testConfig(overrides: Record<string, string> = {}): AppConfigService {
  return new AppConfigService(validateEnvironment(validTestEnvironment(overrides)));
}

/** A Redis URL where nothing listens, to simulate an outage without stopping shared Redis. */
export const UNREACHABLE_REDIS_URL = 'redis://127.0.0.1:6390';

export async function deleteQueueKeys(redisUrl: string, prefix: string): Promise<void> {
  const redis = new Redis(redisUrl);
  try {
    let cursor = '0';
    do {
      const [next, keys] = await redis.scan(cursor, 'MATCH', `${prefix}:*`, 'COUNT', 500);
      cursor = next;
      if (keys.length > 0) await redis.del(...keys);
    } while (cursor !== '0');
  } finally {
    redis.disconnect();
  }
}

export async function waitFor(
  condition: () => boolean | Promise<boolean>,
  timeoutMs = 10_000,
  intervalMs = 25,
): Promise<void> {
  const started = Date.now();
  while (!(await condition())) {
    if (Date.now() - started > timeoutMs) throw new Error(`Condition not met in ${timeoutMs} ms`);
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
}
