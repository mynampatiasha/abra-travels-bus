import { Injectable } from '@nestjs/common';
import { sha256Hex } from '../../../common/crypto/secure-hash';
import { ApiException } from '../../../common/errors/api-exception';
import { RateLimiterService } from '../../../common/rate-limit/rate-limiter.service';
import { AppConfigService } from '../../../config/app-config.service';

/** What is being guessed: a password for a sign-in identifier, or a second factor for a user. */
export type ThrottleSubject = 'password' | 'mfa';

/**
 * Temporary lockout after repeated failed sign-in attempts (authentication.md §4), kept in Redis
 * because it is short-lived state, not account data.
 *
 * Failures are counted per identifier as typed — whether or not an account exists for it — so a
 * lockout never reveals that an account exists. LOGIN_MAX_FAILED_ATTEMPTS failures within
 * LOGIN_LOCKOUT_SECONDS lock the identifier for LOGIN_LOCKOUT_SECONDS; the lock expires by
 * itself and a successful sign-in clears the counter. A separate per-IP limit slows down one
 * source trying many identifiers.
 */
@Injectable()
export class LoginThrottleService {
  constructor(
    private readonly rateLimiter: RateLimiterService,
    private readonly config: AppConfigService,
  ) {}

  async assertIpAllowed(ip: string): Promise<void> {
    const decision = await this.rateLimiter.hit(
      this.rateLimiter.key('auth', 'attempts', 'ip', sha256Hex(ip).slice(0, 32)),
      this.config.get('LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW'),
      this.config.get('LOGIN_LOCKOUT_SECONDS'),
    );
    if (!decision.allowed) {
      throw new ApiException('RATE_LIMITED', 'Too many sign-in attempts. Please wait.', {
        retryAfterSeconds: decision.retryAfterSeconds,
      });
    }
  }

  async assertNotLocked(subject: ThrottleSubject, identifier: string): Promise<void> {
    const retryAfterSeconds = await this.rateLimiter.secondsRemaining(
      this.lockKey(subject, identifier),
    );
    if (retryAfterSeconds > 0) {
      throw new ApiException(
        'ACCOUNT_LOCKED',
        'Too many failed attempts. Please try again later.',
        { retryAfterSeconds },
      );
    }
  }

  /** Counts a failure; returns true if this failure triggered the lock. */
  async recordFailure(subject: ThrottleSubject, identifier: string): Promise<boolean> {
    const lockoutSeconds = this.config.get('LOGIN_LOCKOUT_SECONDS');
    const failureKey = this.failureKey(subject, identifier);
    const { count } = await this.rateLimiter.hit(
      failureKey,
      this.config.get('LOGIN_MAX_FAILED_ATTEMPTS'),
      lockoutSeconds,
    );
    if (count < this.config.get('LOGIN_MAX_FAILED_ATTEMPTS')) return false;

    await this.rateLimiter.setFlag(this.lockKey(subject, identifier), lockoutSeconds);
    await this.rateLimiter.clear(failureKey);
    return true;
  }

  async recordSuccess(subject: ThrottleSubject, identifier: string): Promise<void> {
    await this.rateLimiter.clear(this.failureKey(subject, identifier));
  }

  /** Removes counter and lock, e.g. after the owner proved control with a password reset. */
  async clear(subject: ThrottleSubject, identifier: string): Promise<void> {
    await this.rateLimiter.clear(
      this.failureKey(subject, identifier),
      this.lockKey(subject, identifier),
    );
  }

  // Identifiers are hashed so phone numbers and emails are not stored as Redis key names
  private failureKey(subject: ThrottleSubject, identifier: string): string {
    return this.rateLimiter.key('auth', 'failures', subject, sha256Hex(identifier).slice(0, 32));
  }

  private lockKey(subject: ThrottleSubject, identifier: string): string {
    return this.rateLimiter.key('auth', 'lock', subject, sha256Hex(identifier).slice(0, 32));
  }
}
