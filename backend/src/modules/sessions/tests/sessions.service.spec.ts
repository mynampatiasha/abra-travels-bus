import { Logger } from '@nestjs/common';
import { Types } from 'mongoose';
import { sha256Hex } from '../../../common/crypto/secure-hash';
import { ApiException } from '../../../common/errors/api-exception';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { parseRefreshToken } from '../services/refresh-token.codec';
import {
  type NewSessionInput,
  REFRESH_REUSE_GRACE_MS,
  SessionsService,
} from '../services/sessions.service';
import { InMemoryAuthSessionRepository } from './in-memory-auth-session.repository';

const DAY_MS = 86_400_000;
const CLIENT = { ip: '203.0.113.7', userAgent: 'AbraTravels/1.0 (Android 15)' };
const customerType = (): Promise<'CUSTOMER'> => Promise.resolve('CUSTOMER');

function setup() {
  const repository = new InMemoryAuthSessionRepository();
  const service = new SessionsService(
    repository.asRepository(),
    configOf({ REFRESH_TOKEN_TTL_DAYS: 30, REFRESH_TOKEN_TTL_DAYS_STAFF: 7 }),
  );
  const userId = new Types.ObjectId();
  const input = (overrides: Partial<NewSessionInput> = {}): NewSessionInput => ({
    userId,
    userType: 'CUSTOMER',
    clientType: 'MOBILE',
    deviceName: 'Pixel 9',
    client: CLIENT,
    mfaVerified: false,
    mfaEnrollmentPending: false,
    ...overrides,
  });
  return { repository, service, userId, input };
}

async function rejection(work: Promise<unknown>): Promise<ApiException> {
  const error: unknown = await work.then(
    () => undefined,
    (caught: unknown) => caught,
  );
  expect(error).toBeInstanceOf(ApiException);
  return error as ApiException;
}

describe('SessionsService', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });
  afterEach(() => jest.useRealTimers());

  it('creates a session and stores only the hash of the refresh token', async () => {
    const { service, repository, input } = setup();
    const { session, refreshToken } = await service.create(input());

    const [sessionId, secret] = refreshToken.split('.');
    expect(sessionId).toBe(session._id.toHexString());
    expect(secret).toMatch(/^[A-Za-z0-9_-]{43}$/); // 256 bits
    const stored = repository.sessions.get(sessionId ?? '');
    expect(stored?.refreshTokenHash).toBe(sha256Hex(secret ?? ''));
    expect(JSON.stringify(stored)).not.toContain(secret);
    expect(stored).toMatchObject({ deviceName: 'Pixel 9', ip: CLIENT.ip, clientType: 'MOBILE' });
  });

  it('gives customers 30 days and staff 7 days', async () => {
    const { service, input } = setup();
    const customer = await service.create(input());
    const staff = await service.create(input({ userType: 'STAFF' }));
    const lifetime = (expiresAt: Date): number =>
      Math.round((expiresAt.getTime() - Date.now()) / DAY_MS);
    expect(lifetime(customer.session.expiresAt)).toBe(30);
    expect(lifetime(staff.session.expiresAt)).toBe(7);
    expect(service.refreshTokenLifetimeMs('DRIVER')).toBe(30 * DAY_MS);
    expect(service.refreshTokenLifetimeMs('PARTNER_USER')).toBe(7 * DAY_MS);
  });

  it('rotation returns a new token and the old one stops working', async () => {
    const { service, input } = setup();
    const first = await service.create(input());
    const second = await service.rotate(first.refreshToken, CLIENT, customerType);

    expect(second.refreshToken).not.toBe(first.refreshToken);
    expect(second.session._id.toHexString()).toBe(first.session._id.toHexString());
    // The new token works; the chain continues
    const third = await service.rotate(second.refreshToken, CLIENT, customerType);
    expect(third.refreshToken).not.toBe(second.refreshToken);
  });

  it('reuse of a replaced token after the grace window revokes the whole session', async () => {
    const { service, repository, input } = setup();
    const first = await service.create(input());
    const second = await service.rotate(first.refreshToken, CLIENT, customerType);

    jest.useFakeTimers({ now: Date.now() + REFRESH_REUSE_GRACE_MS + 1000 });
    expect((await rejection(service.rotate(first.refreshToken, CLIENT, customerType))).code).toBe(
      'UNAUTHENTICATED',
    );
    const stored = repository.sessions.get(first.session._id.toHexString());
    expect(stored?.revokedReason).toBe('REFRESH_TOKEN_REUSE');
    // The legitimate holder's current token is dead too: both sides must sign in again
    await rejection(service.rotate(second.refreshToken, CLIENT, customerType));
  });

  it('reuse of an older replaced token revokes the session even inside the grace window', async () => {
    const { service, repository, input } = setup();
    const first = await service.create(input());
    const second = await service.rotate(first.refreshToken, CLIENT, customerType);
    await service.rotate(second.refreshToken, CLIENT, customerType);

    await rejection(service.rotate(first.refreshToken, CLIENT, customerType));
    expect(repository.sessions.get(first.session._id.toHexString())?.revokedReason).toBe(
      'REFRESH_TOKEN_REUSE',
    );
  });

  it('a concurrent double refresh is rejected without revoking the session', async () => {
    const { service, repository, input } = setup();
    const first = await service.create(input());
    const winner = await service.rotate(first.refreshToken, CLIENT, customerType);

    // Same token again a moment later (retry / second isolate): refused, session stays alive
    await rejection(service.rotate(first.refreshToken, CLIENT, customerType));
    expect(repository.sessions.get(first.session._id.toHexString())?.revokedAt).toBeNull();
    await expect(service.rotate(winner.refreshToken, CLIENT, customerType)).resolves.toBeDefined();
  });

  it('a made-up secret for a real session is rejected and does not revoke it', async () => {
    const { service, repository, input } = setup();
    const { session, refreshToken } = await service.create(input());
    const forged = `${session._id.toHexString()}.${'A'.repeat(43)}`;
    await rejection(service.rotate(forged, CLIENT, customerType));
    expect(repository.sessions.get(session._id.toHexString())?.revokedAt).toBeNull();
    await expect(service.rotate(refreshToken, CLIENT, customerType)).resolves.toBeDefined();
  });

  it.each([undefined, null, 42, '', 'no-dot', 'a.b.c', 'not-an-id.' + 'A'.repeat(43)])(
    'rejects malformed refresh token %p',
    async (token) => {
      const { service } = setup();
      expect((await rejection(service.rotate(token, CLIENT, customerType))).code).toBe(
        'UNAUTHENTICATED',
      );
      expect(parseRefreshToken(token)).toBeUndefined();
    },
  );

  it('rejects expired and revoked sessions', async () => {
    const { service, repository, input, userId } = setup();
    const expired = await service.create(input());
    const stored = repository.sessions.get(expired.session._id.toHexString());
    if (stored) stored.expiresAt = new Date(Date.now() - 1000);
    await rejection(service.rotate(expired.refreshToken, CLIENT, customerType));

    const revoked = await service.create(input());
    await service.revoke(revoked.session._id.toHexString(), userId.toHexString(), 'LOGOUT');
    await rejection(service.rotate(revoked.refreshToken, CLIENT, customerType));
    expect(
      await service.findActive(revoked.session._id.toHexString(), userId.toHexString()),
    ).toBeNull();
  });

  it('does not rotate when the user may no longer sign in', async () => {
    const { service, input } = setup();
    const { refreshToken } = await service.create(input());
    const disabled = (): Promise<never> =>
      Promise.reject(new ApiException('UNAUTHENTICATED', 'disabled'));
    await rejection(service.rotate(refreshToken, CLIENT, disabled));
    // The token was not consumed by the failed attempt
    await expect(service.rotate(refreshToken, CLIENT, customerType)).resolves.toBeDefined();
  });

  it('revokes only sessions of the given user', async () => {
    const { service, input, userId } = setup();
    const mine = await service.create(input());
    const someoneElse = new Types.ObjectId().toHexString();

    expect(
      await service.revoke(mine.session._id.toHexString(), someoneElse, 'REVOKED_BY_USER'),
    ).toBe(false);
    expect(await service.findActive(mine.session._id.toHexString(), someoneElse)).toBeNull();
    expect(
      await service.findActive(mine.session._id.toHexString(), userId.toHexString()),
    ).not.toBeNull();
    expect(
      await service.revoke(mine.session._id.toHexString(), userId.toHexString(), 'REVOKED_BY_USER'),
    ).toBe(true);
    // Already revoked: nothing to do
    expect(
      await service.revoke(mine.session._id.toHexString(), userId.toHexString(), 'REVOKED_BY_USER'),
    ).toBe(false);
  });

  it('logout by refresh token needs the current token and is silent otherwise', async () => {
    const { service, repository, input } = setup();
    const first = await service.create(input());
    const second = await service.rotate(first.refreshToken, CLIENT, customerType);
    const id = first.session._id.toHexString();

    await service.revokeByRefreshToken(first.refreshToken); // replaced token: ignored
    await service.revokeByRefreshToken('garbage');
    expect(repository.sessions.get(id)?.revokedAt).toBeNull();

    await service.revokeByRefreshToken(second.refreshToken);
    expect(repository.sessions.get(id)?.revokedReason).toBe('LOGOUT');
  });

  it('revokes all sessions of a user, optionally keeping the current one', async () => {
    const { service, input, userId } = setup();
    const [a, b, c] = await Promise.all([
      service.create(input()),
      service.create(input()),
      service.create(input()),
    ]);
    const keep = a.session._id.toHexString();

    expect(
      await service.revokeAllForUser(userId.toHexString(), 'PASSWORD_CHANGED', {
        exceptSessionId: keep,
      }),
    ).toBe(2);
    const active = await service.listActive(userId.toHexString(), keep);
    expect(active).toHaveLength(1);
    expect(active[0]).toMatchObject({ id: keep, current: true, deviceName: 'Pixel 9' });
    expect(JSON.stringify(active)).not.toMatch(/refreshToken|Hash/);
    await rejection(service.rotate(b.refreshToken, CLIENT, customerType));
    await rejection(service.rotate(c.refreshToken, CLIENT, customerType));
  });
});
