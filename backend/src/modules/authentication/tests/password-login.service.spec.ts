import { Logger } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import {
  configOf,
  InMemoryRateLimiter,
} from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { SessionsService } from '../../sessions/services/sessions.service';
import { InMemoryAuthSessionRepository } from '../../sessions/tests/in-memory-auth-session.repository';
import { type StoredUser } from '../../users/repositories/user.repository';
import { AccessTokenService } from '../services/access-token.service';
import {
  type AuthenticationResult,
  AuthSessionIssuer,
  type MfaRequiredResult,
} from '../services/auth-session-issuer.service';
import { LoginThrottleService } from '../services/login-throttle.service';
import { MfaService } from '../services/mfa.service';
import { PasswordHasher } from '../services/password-hasher.service';
import { canonicalLoginIdentifier, PasswordLoginService } from '../services/password-login.service';
import { totpAt } from '../services/totp';
import { failureOf, InMemoryUsers, testEncryption, testUser } from './authentication-test.fixtures';

const CLIENT = { ip: '203.0.113.7' };
const DEVICE = { clientType: 'MOBILE' as const, deviceName: 'Pixel 9' };
const PASSWORD = 'violet-river-lantern';

async function setup(userOverrides: Partial<StoredUser> = {}) {
  const config = configOf({
    JWT_ACCESS_SECRET: randomBytes(64).toString('base64'),
    JWT_ACCESS_TTL_SECONDS: 900,
    JWT_ISSUER: 'abra-travels',
    JWT_AUDIENCE: 'abra-travels-apps',
    MFA_CHALLENGE_TTL_SECONDS: 300,
    MFA_TOTP_ISSUER: 'Abra Travels',
    MFA_REQUIRED_FOR_STAFF: false,
    LOGIN_MAX_FAILED_ATTEMPTS: 5,
    LOGIN_LOCKOUT_SECONDS: 900,
    LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW: 50,
    REFRESH_TOKEN_TTL_DAYS: 30,
    REFRESH_TOKEN_TTL_DAYS_STAFF: 7,
  });
  const hasher = new PasswordHasher();
  const users = new InMemoryUsers();
  const user = users.add(
    testUser({
      email: 'asha@example.com',
      passwordHash: await hasher.hash(PASSWORD),
      ...userOverrides,
    }),
  );
  const sessionRepository = new InMemoryAuthSessionRepository();
  const sessions = new SessionsService(sessionRepository.asRepository(), config);
  const limiter = new InMemoryRateLimiter();
  const throttle = new LoginThrottleService(limiter.asService(), config);
  const accessTokens = new AccessTokenService(config);
  const mfa = new MfaService(users.asService(), sessions, testEncryption(), throttle, config);
  const issuer = new AuthSessionIssuer(sessions, accessTokens, users.asService(), mfa);
  const service = new PasswordLoginService(
    users.asService(),
    hasher,
    throttle,
    issuer,
    mfa,
    accessTokens,
    limiter.asService(),
  );
  const login = (identifier: string, password: string) =>
    service.login({ identifier, password }, DEVICE, CLIENT);
  return {
    service,
    login,
    user,
    users,
    hasher,
    limiter,
    sessionRepository,
    accessTokens,
    mfa,
    sessions,
  };
}

describe('canonicalLoginIdentifier', () => {
  it('maps every spelling of an identifier to one key', () => {
    expect(canonicalLoginIdentifier(' Asha@Example.com ')).toBe('asha@example.com');
    expect(canonicalLoginIdentifier('98765 43210')).toBe('+919876543210');
    expect(canonicalLoginIdentifier('+91-9876543210')).toBe('+919876543210');
    expect(canonicalLoginIdentifier('  SomeName ')).toBe('somename');
  });
});

describe('PasswordLoginService', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('signs in with email or phone and returns tokens without credentials', async () => {
    const { login, user, sessionRepository } = await setup();
    for (const identifier of ['asha@example.com', 'ASHA@example.com', '9876543210']) {
      const result = (await login(identifier, PASSWORD)) as AuthenticationResult;
      expect(result).toMatchObject({
        tokenType: 'Bearer',
        accessTokenExpiresInSeconds: 900,
        mfaEnrollmentRequired: false,
        user: { id: user._id.toHexString(), userType: 'CUSTOMER', hasPassword: true },
      });
      expect(JSON.stringify(result)).not.toMatch(/passwordHash|argon2|secretEncrypted/);
    }
    expect(sessionRepository.sessions.size).toBe(3);
    expect(user.lastLoginAt).toBeInstanceOf(Date);
  });

  it('gives the same answer for a wrong password, an unknown account and an OTP-only account', async () => {
    const { login, users, hasher } = await setup();
    users.add(testUser({ phone: '+919000000001', email: 'otp-only@example.com' }));
    const dummy = jest.spyOn(hasher, 'verifyAgainstDummy');

    const wrongPassword = await failureOf(login('asha@example.com', 'not-the-password'));
    const unknown = await failureOf(login('nobody@example.com', PASSWORD));
    const otpOnly = await failureOf(login('otp-only@example.com', PASSWORD));

    for (const error of [wrongPassword, unknown, otpOnly]) {
      expect(error.code).toBe('INVALID_CREDENTIALS');
      expect(error.message).toBe(wrongPassword.message);
      expect(error.details).toBeUndefined();
    }
    // Unknown and password-less accounts still cost a real hash verification (timing)
    expect(dummy).toHaveBeenCalledTimes(2);
  });

  it('locks an identifier after 5 failures — also when no such account exists', async () => {
    const { login } = await setup();
    for (const identifier of ['asha@example.com', 'nobody@example.com']) {
      for (let attempt = 1; attempt <= 5; attempt++) {
        expect((await failureOf(login(identifier, 'wrong-password'))).code).toBe(
          'INVALID_CREDENTIALS',
        );
      }
      const locked = await failureOf(login(identifier, PASSWORD));
      expect(locked.code).toBe('ACCOUNT_LOCKED');
      expect(locked.details).toEqual({ retryAfterSeconds: 900 });
    }
  });

  it('a locked identifier unlocks after the lockout time and the right password works again', async () => {
    const { login, limiter } = await setup();
    for (let attempt = 1; attempt <= 5; attempt++)
      await failureOf(login('asha@example.com', 'wrong'));
    expect((await failureOf(login('asha@example.com', PASSWORD))).code).toBe('ACCOUNT_LOCKED');
    limiter.advanceSeconds(901);
    await expect(login('asha@example.com', PASSWORD)).resolves.toMatchObject({
      tokenType: 'Bearer',
    });
  });

  it('re-typing the identifier differently does not dodge the lockout', async () => {
    const { login } = await setup();
    const spellings = [
      '9876543210',
      '+919876543210',
      '98765 43210',
      '+91 98765-43210',
      '9876543210',
    ];
    for (const spelling of spellings) await failureOf(login(spelling, 'wrong-password'));
    expect((await failureOf(login('+919876543210', PASSWORD))).code).toBe('ACCOUNT_LOCKED');
  });

  it('a successful sign-in resets the failure count', async () => {
    const { login } = await setup();
    for (let attempt = 1; attempt <= 4; attempt++)
      await failureOf(login('asha@example.com', 'wrong'));
    await login('asha@example.com', PASSWORD);
    for (let attempt = 1; attempt <= 4; attempt++) {
      expect((await failureOf(login('asha@example.com', 'wrong'))).code).toBe(
        'INVALID_CREDENTIALS',
      );
    }
  });

  it.each(['SUSPENDED', 'DEACTIVATED', 'INVITED'] as const)(
    'reveals a %s account only after the correct password',
    async (status) => {
      const { login } = await setup({ status });
      expect((await failureOf(login('asha@example.com', 'wrong-password'))).code).toBe(
        'INVALID_CREDENTIALS',
      );
      expect((await failureOf(login('asha@example.com', PASSWORD))).code).toBe('ACCOUNT_DISABLED');
    },
  );

  it('upgrades a hash made with older parameters on successful sign-in', async () => {
    const { login, user, hasher } = await setup();
    jest.spyOn(hasher, 'needsRehash').mockReturnValueOnce(true);
    const before = user.passwordHash;
    await login('asha@example.com', PASSWORD);
    expect(user.passwordHash).not.toBe(before);
    await expect(hasher.verify(PASSWORD, user.passwordHash ?? '')).resolves.toBe(true);
  });

  describe('with MFA enabled', () => {
    async function withMfa() {
      const context = await setup();
      const actor = {
        actorType: 'USER' as const,
        userId: context.user._id.toHexString(),
        dataScope: { type: 'OWN_RECORDS' as const, operatorIds: [] },
        userType: 'CUSTOMER' as const,
        sessionId: (
          await context.sessions.create({
            userId: context.user._id,
            userType: 'CUSTOMER',
            clientType: 'MOBILE',
            client: CLIENT,
            mfaVerified: false,
            mfaEnrollmentPending: false,
          })
        ).session._id.toHexString(),
        permissionVersion: 1,
        roleIds: [],
        mfaEnrollmentPending: false,
      };
      const { secret } = await context.mfa.startEnrollment(actor.userId);
      const { recoveryCodes } = await context.mfa.activate(actor, totpAt(secret, Date.now()));
      return { ...context, secret, recoveryCodes };
    }

    it('the password alone yields a challenge, not tokens or a session', async () => {
      const { login, sessionRepository } = await withMfa();
      const before = sessionRepository.sessions.size;
      const result = (await login('asha@example.com', PASSWORD)) as MfaRequiredResult;
      expect(result).toEqual({
        mfaRequired: true,
        mfaToken: expect.any(String) as unknown,
        mfaTokenExpiresInSeconds: 300,
      });
      expect(result).not.toHaveProperty('accessToken');
      expect(sessionRepository.sessions.size).toBe(before);
    });

    it('challenge + valid code completes the sign-in with an MFA-verified session', async () => {
      const { login, service, secret, sessionRepository } = await withMfa();
      const { mfaToken } = (await login('asha@example.com', PASSWORD)) as MfaRequiredResult;
      const result = await service.completeMfa(
        { mfaToken, code: totpAt(secret, Date.now() + 30_000) },
        DEVICE,
        CLIENT,
      );
      expect(result.tokenType).toBe('Bearer');
      expect(sessionRepository.sessions.get(result.sessionId)?.mfaVerified).toBe(true);
    });

    it('a challenge token completes only one sign-in', async () => {
      const { login, service, recoveryCodes } = await withMfa();
      const { mfaToken } = (await login('asha@example.com', PASSWORD)) as MfaRequiredResult;
      await service.completeMfa({ mfaToken, recoveryCode: recoveryCodes[0] }, DEVICE, CLIENT);
      const second = await failureOf(
        service.completeMfa({ mfaToken, recoveryCode: recoveryCodes[1] }, DEVICE, CLIENT),
      );
      expect(second.code).toBe('MFA_INVALID');
    });

    it('rejects a wrong code, a forged challenge and an access token used as a challenge', async () => {
      const { login, service, accessTokens, user } = await withMfa();
      const { mfaToken } = (await login('asha@example.com', PASSWORD)) as MfaRequiredResult;
      expect(
        (await failureOf(service.completeMfa({ mfaToken, code: '000000' }, DEVICE, CLIENT))).code,
      ).toBe('MFA_INVALID');
      expect(
        (
          await failureOf(
            service.completeMfa(
              { mfaToken: 'forged.challenge.token-aaaa', code: '000000' },
              DEVICE,
              CLIENT,
            ),
          )
        ).code,
      ).toBe('MFA_INVALID');
      const access = await accessTokens.issue({
        userId: user._id.toHexString(),
        userType: 'CUSTOMER',
        sessionId: 'x',
        permissionVersion: 1,
      });
      expect(
        (
          await failureOf(
            service.completeMfa({ mfaToken: access.token, code: '000000' }, DEVICE, CLIENT),
          )
        ).code,
      ).toBe('MFA_INVALID');
    });
  });
});
