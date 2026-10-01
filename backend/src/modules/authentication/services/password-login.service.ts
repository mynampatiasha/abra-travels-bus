import { Injectable, Logger } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { RateLimiterService } from '../../../common/rate-limit/rate-limiter.service';
import {
  normalizeEmail,
  normalizePhoneNumber,
} from '../../../common/validation/contact-identifiers';
import { UsersService } from '../../users/services/users.service';
import { AccessTokenService } from './access-token.service';
import {
  type AuthenticationResult,
  AuthSessionIssuer,
  type DeviceInfo,
  type MfaRequiredResult,
} from './auth-session-issuer.service';
import { LoginThrottleService } from './login-throttle.service';
import { MfaService, type SecondFactor } from './mfa.service';
import { PasswordHasher } from './password-hasher.service';

/** The same key for every spelling of one identifier, so lockout cannot be dodged by re-typing. */
export function canonicalLoginIdentifier(identifier: string): string {
  if (identifier.includes('@')) return normalizeEmail(identifier);
  return normalizePhoneNumber(identifier) ?? identifier.trim().toLowerCase();
}

function invalidCredentials(): ApiException {
  return new ApiException(
    'INVALID_CREDENTIALS',
    'The email, phone number or password is incorrect.',
  );
}

/**
 * Sign-in with identifier (email or phone) and password, plus the second-factor step for
 * accounts with MFA.
 *
 * Enumeration resistance: an unknown identifier, an account without a password and a wrong
 * password all cost one Argon2id verification, count as a failure for that identifier and answer
 * INVALID_CREDENTIALS. Account status is revealed only after the password was correct.
 */
@Injectable()
export class PasswordLoginService {
  private readonly logger = new Logger(PasswordLoginService.name);

  constructor(
    private readonly users: UsersService,
    private readonly hasher: PasswordHasher,
    private readonly throttle: LoginThrottleService,
    private readonly issuer: AuthSessionIssuer,
    private readonly mfa: MfaService,
    private readonly accessTokens: AccessTokenService,
    private readonly rateLimiter: RateLimiterService,
  ) {}

  async login(
    input: { identifier: string; password: string },
    device: DeviceInfo,
    client: ClientRequestInfo,
  ): Promise<AuthenticationResult | MfaRequiredResult> {
    await this.throttle.assertIpAllowed(client.ip);
    const identifier = canonicalLoginIdentifier(input.identifier);
    await this.throttle.assertNotLocked('password', identifier);

    const user = await this.users.findByLoginIdentifier(input.identifier);
    const passwordCorrect = user?.passwordHash
      ? await this.hasher.verify(input.password, user.passwordHash)
      : await this.hasher.verifyAgainstDummy(input.password);

    if (!user || !passwordCorrect) {
      const locked = await this.throttle.recordFailure('password', identifier);
      if (locked) this.logger.warn({ userId: user?._id.toHexString() }, 'Sign-in locked');
      throw invalidCredentials();
    }
    await this.throttle.recordSuccess('password', identifier);
    this.issuer.assertCanSignIn(user);

    if (user.passwordHash && this.hasher.needsRehash(user.passwordHash)) {
      await this.users.setPassword(user._id.toHexString(), await this.hasher.hash(input.password));
    }

    if (user.mfa.enabled) return this.issuer.mfaChallengeFor(user);
    return this.issuer.issue(user, device, client, { mfaVerified: false });
  }

  /** Second step of a sign-in for an account with MFA: challenge token + TOTP or recovery code. */
  async completeMfa(
    input: { mfaToken: string } & SecondFactor,
    device: DeviceInfo,
    client: ClientRequestInfo,
  ): Promise<AuthenticationResult> {
    await this.throttle.assertIpAllowed(client.ip);
    const challenge = await this.accessTokens.verifyMfaChallenge(input.mfaToken);

    const user = await this.users.findById(challenge.userId);
    if (!user?.mfa.enabled) {
      throw new ApiException(
        'MFA_INVALID',
        'The verification step has expired. Please sign in again.',
      );
    }
    this.issuer.assertCanSignIn(user);
    await this.mfa.assertSecondFactor(user, {
      ...(input.code !== undefined ? { code: input.code } : {}),
      ...(input.recoveryCode !== undefined ? { recoveryCode: input.recoveryCode } : {}),
    });

    // A challenge token completes at most one sign-in
    const firstUse = await this.rateLimiter.setFlag(
      this.rateLimiter.key('auth', 'mfa-challenge-used', challenge.challengeId),
      challenge.expiresInSeconds + 10,
      true,
    );
    if (!firstUse) {
      throw new ApiException(
        'MFA_INVALID',
        'The verification step has expired. Please sign in again.',
      );
    }
    return this.issuer.issue(user, device, client, { mfaVerified: true });
  }
}
