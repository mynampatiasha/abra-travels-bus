import { ApiException } from '../../../common/errors/api-exception';
import {
  configOf,
  InMemoryRateLimiter,
} from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { LoginThrottleService } from '../services/login-throttle.service';

function setup(overrides: Record<string, number> = {}) {
  const limiter = new InMemoryRateLimiter();
  const throttle = new LoginThrottleService(
    limiter.asService(),
    configOf({
      LOGIN_MAX_FAILED_ATTEMPTS: 5,
      LOGIN_LOCKOUT_SECONDS: 900,
      LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW: 50,
      ...overrides,
    }),
  );
  return { limiter, throttle };
}

async function codeOf(work: Promise<unknown>): Promise<ApiException | undefined> {
  return work.then(
    () => undefined,
    (caught: unknown) => caught as ApiException,
  );
}

describe('LoginThrottleService', () => {
  it('does not lock after a single mistake, or after four', async () => {
    const { throttle } = setup();
    for (let attempt = 1; attempt <= 4; attempt++) {
      expect(await throttle.recordFailure('password', 'asha@example.com')).toBe(false);
      await expect(
        throttle.assertNotLocked('password', 'asha@example.com'),
      ).resolves.toBeUndefined();
    }
  });

  it('locks on the fifth failure and reports when to retry', async () => {
    const { throttle } = setup();
    for (let attempt = 1; attempt <= 4; attempt++) await throttle.recordFailure('password', 'id');
    expect(await throttle.recordFailure('password', 'id')).toBe(true);

    const error = await codeOf(throttle.assertNotLocked('password', 'id'));
    expect(error?.code).toBe('ACCOUNT_LOCKED');
    expect(error?.details).toEqual({ retryAfterSeconds: 900 });
  });

  it('the lock expires by itself — never permanent', async () => {
    const { throttle, limiter } = setup();
    for (let attempt = 1; attempt <= 5; attempt++) await throttle.recordFailure('password', 'id');
    limiter.advanceSeconds(899);
    expect((await codeOf(throttle.assertNotLocked('password', 'id')))?.code).toBe('ACCOUNT_LOCKED');
    limiter.advanceSeconds(2);
    await expect(throttle.assertNotLocked('password', 'id')).resolves.toBeUndefined();
    // A fresh budget after the lock: one mistake does not lock again
    expect(await throttle.recordFailure('password', 'id')).toBe(false);
  });

  it('a successful sign-in resets the failure counter', async () => {
    const { throttle } = setup();
    for (let attempt = 1; attempt <= 4; attempt++) await throttle.recordFailure('password', 'id');
    await throttle.recordSuccess('password', 'id');
    for (let attempt = 1; attempt <= 4; attempt++) {
      expect(await throttle.recordFailure('password', 'id')).toBe(false);
    }
  });

  it('old failures fall out of the window', async () => {
    const { throttle, limiter } = setup();
    for (let attempt = 1; attempt <= 4; attempt++) await throttle.recordFailure('password', 'id');
    limiter.advanceSeconds(901);
    expect(await throttle.recordFailure('password', 'id')).toBe(false);
  });

  it('counts identifiers and subjects separately', async () => {
    const { throttle } = setup();
    for (let attempt = 1; attempt <= 5; attempt++)
      await throttle.recordFailure('password', 'victim');
    await expect(throttle.assertNotLocked('password', 'someone-else')).resolves.toBeUndefined();
    await expect(throttle.assertNotLocked('mfa', 'victim')).resolves.toBeUndefined();
  });

  it('clear removes counter and lock', async () => {
    const { throttle } = setup();
    for (let attempt = 1; attempt <= 5; attempt++) await throttle.recordFailure('password', 'id');
    await throttle.clear('password', 'id');
    await expect(throttle.assertNotLocked('password', 'id')).resolves.toBeUndefined();
  });

  it('limits attempts per IP across identifiers', async () => {
    const { throttle } = setup({ LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW: 3 });
    for (let attempt = 1; attempt <= 3; attempt++) {
      await expect(throttle.assertIpAllowed('198.51.100.9')).resolves.toBeUndefined();
    }
    const error = await codeOf(throttle.assertIpAllowed('198.51.100.9'));
    expect(error?.code).toBe('RATE_LIMITED');
    expect(error?.details).toMatchObject({ retryAfterSeconds: expect.any(Number) as unknown });
    await expect(throttle.assertIpAllowed('198.51.100.10')).resolves.toBeUndefined();
  });

  it('does not put identifiers into Redis key names', async () => {
    const limiter = new InMemoryRateLimiter();
    const hit = jest.spyOn(limiter, 'hit');
    const throttle = new LoginThrottleService(
      limiter.asService(),
      configOf({ LOGIN_MAX_FAILED_ATTEMPTS: 5, LOGIN_LOCKOUT_SECONDS: 900 }),
    );
    await throttle.recordFailure('password', '+919876543210');
    expect(hit.mock.calls[0]?.[0]).not.toContain('9876543210');
  });
});
