import { Logger } from '@nestjs/common';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import {
  configOf,
  InMemoryRateLimiter,
} from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { SessionsService } from '../../sessions/services/sessions.service';
import { InMemoryAuthSessionRepository } from '../../sessions/tests/in-memory-auth-session.repository';
import { type StoredUser } from '../../users/repositories/user.repository';
import { LoginThrottleService } from '../services/login-throttle.service';
import { MfaService, RECOVERY_CODE_COUNT } from '../services/mfa.service';
import { totpAt } from '../services/totp';
import { failureOf, InMemoryUsers, testEncryption, testUser } from './authentication-test.fixtures';

const CLIENT = { ip: '203.0.113.7' };

async function setup(options: { staffMfaRequired?: boolean; user?: Partial<StoredUser> } = {}) {
  const config = configOf({
    MFA_TOTP_ISSUER: 'Abra Travels',
    MFA_REQUIRED_FOR_STAFF: options.staffMfaRequired ?? false,
    LOGIN_MAX_FAILED_ATTEMPTS: 5,
    LOGIN_LOCKOUT_SECONDS: 900,
    REFRESH_TOKEN_TTL_DAYS: 30,
    REFRESH_TOKEN_TTL_DAYS_STAFF: 7,
  });
  const users = new InMemoryUsers();
  const user = users.add(testUser({ email: 'asha@example.com', ...options.user }));
  const sessionRepository = new InMemoryAuthSessionRepository();
  const sessions = new SessionsService(sessionRepository.asRepository(), config);
  const limiter = new InMemoryRateLimiter();
  const encryption = testEncryption();
  const mfa = new MfaService(
    users.asService(),
    sessions,
    encryption,
    new LoginThrottleService(limiter.asService(), config),
    config,
  );

  const newSession = async () =>
    (
      await sessions.create({
        userId: user._id,
        userType: user.userType,
        clientType: 'MOBILE',
        client: CLIENT,
        mfaVerified: false,
        mfaEnrollmentPending: false,
      })
    ).session._id.toHexString();
  const sessionId = await newSession();
  const actor: AuthenticatedUserActor = {
    actorType: 'USER',
    userId: user._id.toHexString(),
    dataScope: { type: 'OWN_RECORDS', operatorIds: [] },
    userType: user.userType,
    sessionId,
    permissionVersion: 1,
    roleIds: [],
    mfaEnrollmentPending: false,
  };
  return { mfa, users, user, actor, sessions, sessionRepository, limiter, newSession, encryption };
}

/** Enrols and activates MFA; returns the secret and recovery codes. */
async function enable(context: Awaited<ReturnType<typeof setup>>) {
  const { secret } = await context.mfa.startEnrollment(context.actor.userId);
  const { recoveryCodes } = await context.mfa.activate(context.actor, totpAt(secret, Date.now()));
  return { secret, recoveryCodes };
}

describe('MfaService (TOTP)', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('enrolment returns a secret and otpauth URI, stores it encrypted, and changes nothing yet', async () => {
    const context = await setup();
    const enrollment = await context.mfa.startEnrollment(context.actor.userId);

    expect(enrollment.secret).toMatch(/^[A-Z2-7]{32}$/);
    expect(enrollment.keyUri).toContain('otpauth://totp/Abra%20Travels:asha%40example.com');
    expect(enrollment.keyUri).toContain(`secret=${enrollment.secret}`);
    expect(context.user.mfa.enabled).toBe(false);
    const stored = context.user.mfa.pendingSecretEncrypted ?? '';
    expect(stored).not.toContain(enrollment.secret);
    expect(context.encryption.decrypt(stored)).toBe(enrollment.secret);
  });

  it('a wrong code does not activate MFA', async () => {
    const context = await setup();
    const { secret } = await context.mfa.startEnrollment(context.actor.userId);
    const right = totpAt(secret, Date.now());
    const wrong = right === '000000' ? '000001' : '000000';
    expect((await failureOf(context.mfa.activate(context.actor, wrong))).code).toBe('MFA_INVALID');
    expect(context.user.mfa.enabled).toBe(false);
  });

  it('activation turns MFA on, returns one-time recovery codes and signs out other devices', async () => {
    const context = await setup();
    const otherDevice = await context.newSession();
    const { recoveryCodes } = await enable(context);

    expect(context.user.mfa.enabled).toBe(true);
    expect(recoveryCodes).toHaveLength(RECOVERY_CODE_COUNT);
    expect(new Set(recoveryCodes).size).toBe(RECOVERY_CODE_COUNT);
    for (const code of recoveryCodes) expect(code).toMatch(/^[A-Z2-7]{5}-[A-Z2-7]{5}$/);
    // Only hashes are stored
    expect(context.user.mfa.recoveryCodeHashes).toHaveLength(RECOVERY_CODE_COUNT);
    expect(JSON.stringify(context.user.mfa)).not.toContain(recoveryCodes[0]);

    expect(context.sessionRepository.sessions.get(otherDevice)?.revokedReason).toBe('MFA_CHANGED');
    expect(context.sessionRepository.sessions.get(context.actor.sessionId)?.revokedAt).toBeNull();
    await expect(context.mfa.status(context.actor.userId)).resolves.toEqual({
      enabled: true,
      required: false,
      recoveryCodesRemaining: RECOVERY_CODE_COUNT,
    });
  });

  it('cannot enrol or activate twice', async () => {
    const context = await setup();
    const { secret } = await enable(context);
    expect((await failureOf(context.mfa.startEnrollment(context.actor.userId))).code).toBe(
      'INVALID_STATE_TRANSITION',
    );
    expect(
      (await failureOf(context.mfa.activate(context.actor, totpAt(secret, Date.now())))).code,
    ).toBe('INVALID_STATE_TRANSITION');
  });

  it('accepts a valid TOTP code once and rejects its replay', async () => {
    const context = await setup();
    const { secret } = await enable(context);
    // Activation used the current step; the next step is the first fresh code
    const next = totpAt(secret, Date.now() + 30_000);

    await expect(
      context.mfa.assertSecondFactor(context.user, { code: next }),
    ).resolves.toBeUndefined();
    expect(
      (await failureOf(context.mfa.assertSecondFactor(context.user, { code: next }))).code,
    ).toBe('MFA_INVALID');
    // The code that activated MFA cannot be replayed either
    expect(
      (
        await failureOf(
          context.mfa.assertSecondFactor(context.user, { code: totpAt(secret, Date.now()) }),
        )
      ).code,
    ).toBe('MFA_INVALID');
  });

  it('a recovery code works once, in any spelling', async () => {
    const context = await setup();
    const { recoveryCodes } = await enable(context);
    const code = recoveryCodes[0] ?? '';

    await expect(
      context.mfa.assertSecondFactor(context.user, {
        recoveryCode: code.toLowerCase().replace('-', ' '),
      }),
    ).resolves.toBeUndefined();
    expect(
      (await failureOf(context.mfa.assertSecondFactor(context.user, { recoveryCode: code }))).code,
    ).toBe('MFA_INVALID');
    expect((await context.mfa.status(context.actor.userId)).recoveryCodesRemaining).toBe(
      RECOVERY_CODE_COUNT - 1,
    );
  });

  it('requires exactly one of code / recoveryCode', async () => {
    const context = await setup();
    await enable(context);
    expect((await failureOf(context.mfa.assertSecondFactor(context.user, {}))).code).toBe(
      'VALIDATION_FAILED',
    );
    expect(
      (
        await failureOf(
          context.mfa.assertSecondFactor(context.user, {
            code: '123456',
            recoveryCode: 'ABCDE-FGHIJ',
          }),
        )
      ).code,
    ).toBe('VALIDATION_FAILED');
  });

  it('locks the second factor after 5 wrong codes, then recovers by itself', async () => {
    const context = await setup();
    const { secret, recoveryCodes } = await enable(context);
    for (let attempt = 1; attempt <= 5; attempt++) {
      expect(
        (await failureOf(context.mfa.assertSecondFactor(context.user, { code: '000000' }))).code,
      ).toBe('MFA_INVALID');
    }
    // Locked: even a valid recovery code is refused, and it is not consumed
    const locked = await failureOf(
      context.mfa.assertSecondFactor(context.user, { recoveryCode: recoveryCodes[0] ?? '' }),
    );
    expect(locked.code).toBe('ACCOUNT_LOCKED');
    expect(context.user.mfa.recoveryCodeHashes).toHaveLength(RECOVERY_CODE_COUNT);

    context.limiter.advanceSeconds(901);
    await expect(
      context.mfa.assertSecondFactor(context.user, { code: totpAt(secret, Date.now() + 30_000) }),
    ).resolves.toBeUndefined();
  });

  it('disable needs a valid second factor and signs out other devices', async () => {
    const context = await setup();
    const { recoveryCodes } = await enable(context);
    const otherDevice = await context.newSession();

    expect((await failureOf(context.mfa.disable(context.actor, { code: '000000' }))).code).toBe(
      'MFA_INVALID',
    );
    expect(context.user.mfa.enabled).toBe(true);

    await context.mfa.disable(context.actor, { recoveryCode: recoveryCodes[1] ?? '' });
    expect(context.user.mfa).toEqual({ enabled: false, recoveryCodeHashes: [] });
    expect(context.sessionRepository.sessions.get(otherDevice)?.revokedReason).toBe('MFA_CHANGED');
    expect((await failureOf(context.mfa.disable(context.actor, { code: '000000' }))).code).toBe(
      'INVALID_STATE_TRANSITION',
    );
  });

  it('is mandatory for STAFF when configured: reported as required and cannot be disabled', async () => {
    const context = await setup({ staffMfaRequired: true, user: { userType: 'STAFF' } });
    const { recoveryCodes } = await enable(context);
    expect(context.mfa.isRequiredFor(context.user)).toBe(true);
    expect((await context.mfa.status(context.actor.userId)).required).toBe(true);
    expect(
      (
        await failureOf(
          context.mfa.disable(context.actor, { recoveryCode: recoveryCodes[0] ?? '' }),
        )
      ).code,
    ).toBe('PERMISSION_DENIED');
    expect(context.user.mfa.enabled).toBe(true);
  });

  it('is optional for customers even when staff MFA is mandatory', async () => {
    const context = await setup({ staffMfaRequired: true });
    expect(context.mfa.isRequiredFor(context.user)).toBe(false);
  });

  it('activation lifts the MFA-enrolment restriction of the session', async () => {
    const context = await setup();
    const stored = context.sessionRepository.sessions.get(context.actor.sessionId);
    if (stored) stored.mfaEnrollmentPending = true;
    await enable(context);
    expect(stored).toMatchObject({ mfaEnrollmentPending: false, mfaVerified: true });
  });
});
