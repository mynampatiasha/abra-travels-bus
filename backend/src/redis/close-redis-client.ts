import { type Redis } from 'ioredis';

const QUIT_TIMEOUT_MS = 2_000;

/**
 * Closes an ioredis client so it can never reconnect afterwards.
 *
 * `quit()` alone is not enough: it is a Redis command, so while the client is reconnecting (for
 * example shutdown right after a Redis outage) it is rejected — `enableOfflineQueue: false` — and
 * the client keeps its reconnect timer, connects again later and keeps the process alive.
 * `disconnect()` cancels the reconnect timer and marks the close as intentional.
 *
 * Connected → graceful QUIT (bounded); otherwise, or if QUIT fails or times out → disconnect().
 */
export async function closeRedisClient(
  client: Pick<Redis, 'status' | 'quit' | 'disconnect'>,
  quitTimeoutMs: number = QUIT_TIMEOUT_MS,
): Promise<void> {
  // Read live: quit() changes the status, which a narrowed `client.status` would not reflect
  const isClosed = (): boolean => client.status === 'end';
  if (isClosed()) return;

  if (client.status === 'ready') {
    let timer: NodeJS.Timeout | undefined;
    try {
      await Promise.race([
        client.quit(),
        new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new Error('QUIT timed out')), quitTimeoutMs);
        }),
      ]);
    } catch {
      // Fall through to disconnect()
    } finally {
      clearTimeout(timer);
    }
  }

  if (!isClosed()) client.disconnect();
}
