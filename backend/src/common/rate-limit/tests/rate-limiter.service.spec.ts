import { type Redis } from 'ioredis';
import { ApiException } from '../../errors/api-exception';
import { RateLimiterService } from '../rate-limiter.service';
import { configOf } from './in-memory-rate-limiter.fixture';

function limiter(redis: Partial<Record<keyof Redis, jest.Mock>>): RateLimiterService {
  return new RateLimiterService(redis as unknown as Redis, configOf({ REDIS_KEY_PREFIX: 'abra' }));
}

describe('RateLimiterService', () => {
  it('namespaces keys with REDIS_KEY_PREFIX', () => {
    expect(limiter({}).key('otp', 'send', 'x')).toBe('abra:otp:send:x');
  });

  it('allows hits up to the limit and blocks the next one with a retry time', async () => {
    const evalMock = jest.fn().mockResolvedValueOnce([3, 600]).mockResolvedValueOnce([4, 598]);
    const service = limiter({ eval: evalMock });

    await expect(service.hit('k', 3, 900)).resolves.toEqual({
      allowed: true,
      count: 3,
      retryAfterSeconds: 600,
    });
    await expect(service.hit('k', 3, 900)).resolves.toEqual({
      allowed: false,
      count: 4,
      retryAfterSeconds: 598,
    });
    // One atomic script call per hit: key and window are passed, never interpolated
    expect(evalMock).toHaveBeenCalledWith(expect.any(String), 1, 'k', 900);
  });

  it('reports remaining seconds and treats a missing key as 0', async () => {
    const ttl = jest.fn().mockResolvedValueOnce(42).mockResolvedValueOnce(-2);
    const service = limiter({ ttl });
    await expect(service.secondsRemaining('k')).resolves.toBe(42);
    await expect(service.secondsRemaining('k')).resolves.toBe(0);
  });

  it('sets flags with expiry, optionally only if absent', async () => {
    const set = jest.fn().mockResolvedValueOnce('OK').mockResolvedValueOnce(null);
    const service = limiter({ set });
    await expect(service.setFlag('k', 30)).resolves.toBe(true);
    await expect(service.setFlag('k', 30, true)).resolves.toBe(false);
    expect(set).toHaveBeenNthCalledWith(1, 'k', '1', 'EX', 30);
    expect(set).toHaveBeenNthCalledWith(2, 'k', '1', 'EX', 30, 'NX');
  });

  it('fails closed with SERVICE_UNAVAILABLE when Redis cannot be reached', async () => {
    const down = jest.fn().mockRejectedValue(new Error('ECONNREFUSED 10.0.0.5:6379'));
    const service = limiter({ eval: down, ttl: down, set: down, del: down });

    for (const call of [
      () => service.hit('k', 1, 1),
      () => service.secondsRemaining('k'),
      () => service.setFlag('k', 1),
      () => service.clear('k'),
    ]) {
      const error = await call().catch((caught: unknown) => caught);
      expect(error).toBeInstanceOf(ApiException);
      expect((error as ApiException).code).toBe('SERVICE_UNAVAILABLE');
      // Connection details never reach the client
      expect((error as ApiException).message).not.toContain('10.0.0.5');
    }
  });
});
