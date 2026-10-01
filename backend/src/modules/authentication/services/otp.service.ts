import { randomInt } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { Types } from 'mongoose';
import { hmacSha256Hex, safeEqualHex, sha256Hex } from '../../../common/crypto/secure-hash';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { RateLimiterService } from '../../../common/rate-limit/rate-limiter.service';
import { maskPhoneNumber } from '../../../common/validation/contact-identifiers';
import { AppConfigService } from '../../../config/app-config.service';
import { SMS_PROVIDER, type SmsProvider } from '../../../integrations/sms/sms-provider.interface';
import { OtpChallengeRepository } from '../repositories/otp-challenge.repository';
import { type OtpPurpose } from '../schemas/otp-challenge.schema';

export interface OtpRequestResult {
  expiresInSeconds: number;
  /** Earliest time another code can be requested for this number. */
  resendAfterSeconds: number;
}

/** Uniformly random numeric code of `length` digits, from the OS CSPRNG. */
export function generateOtpCode(length: number): string {
  return randomInt(0, 10 ** length)
    .toString()
    .padStart(length, '0');
}

function rateLimited(retryAfterSeconds: number): ApiException {
  return new ApiException('RATE_LIMITED', 'Too many verification code requests. Please wait.', {
    retryAfterSeconds,
  });
}

function otpInvalid(): ApiException {
  // One message for wrong, expired, already used, replaced and out-of-attempts
  return new ApiException(
    'OTP_INVALID',
    'The verification code is incorrect or has expired. Please request a new code.',
  );
}

/**
 * One-time codes sent by SMS (authentication.md §3).
 *
 * - The code exists in plain form only in memory and in the SMS; MongoDB holds a keyed hash.
 * - Limits: cooldown between sends, sends per number and per IP per window (Redis counters),
 *   verification attempts per code (atomic counter on the challenge in MongoDB).
 * - A code is single-use, purpose-bound, and replaced by any newer code for the same number.
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private readonly challenges: OtpChallengeRepository,
    private readonly rateLimiter: RateLimiterService,
    private readonly config: AppConfigService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  /**
   * Applies the send limits and, when `deliver` is true, creates a challenge and sends the code.
   * `deliver: false` answers exactly like a real send without sending anything (used when the
   * caller must not learn whether the number has an account).
   */
  async request(
    phone: string,
    purpose: OtpPurpose,
    client: ClientRequestInfo,
    options: { deliver: boolean } = { deliver: true },
  ): Promise<OtpRequestResult> {
    await this.enforceSendLimits(phone, purpose, client.ip);

    const ttlSeconds = this.config.get('OTP_TTL_SECONDS');
    const result: OtpRequestResult = {
      expiresInSeconds: ttlSeconds,
      resendAfterSeconds: this.config.get('OTP_RESEND_COOLDOWN_SECONDS'),
    };
    if (!options.deliver) return result;

    const now = new Date();
    const id = new Types.ObjectId();
    const code = generateOtpCode(this.config.get('OTP_LENGTH'));

    await this.challenges.supersedeActive(phone, purpose, now);
    await this.challenges.insert({
      _id: id,
      target: phone,
      purpose,
      codeHash: this.hashCode(id, code),
      attempts: 0,
      expiresAt: new Date(now.getTime() + ttlSeconds * 1000),
      consumedAt: null,
      requestIp: client.ip,
    });

    try {
      await this.sms.send({ to: phone, purpose: 'OTP', body: this.messageBody(code, ttlSeconds) });
    } catch (error) {
      await this.challenges.consume(id, new Date());
      this.logger.error(
        {
          phone: maskPhoneNumber(phone),
          provider: this.sms.providerKey,
          message: error instanceof Error ? error.message : 'unknown',
        },
        'OTP message could not be sent',
      );
      throw new ApiException(
        'SERVICE_UNAVAILABLE',
        'The verification code could not be sent. Please try again shortly.',
      );
    }
    return result;
  }

  /** Resolves when `code` is the current code for this number and purpose; consumes it. */
  async verify(phone: string, purpose: OtpPurpose, code: string): Promise<void> {
    const now = new Date();
    const challenge = await this.challenges.registerAttempt(
      phone,
      purpose,
      this.config.get('OTP_MAX_VERIFY_ATTEMPTS'),
      now,
    );
    if (!challenge) throw otpInvalid();

    if (!safeEqualHex(challenge.codeHash, this.hashCode(challenge._id, code))) throw otpInvalid();

    // Two requests with the same correct code: exactly one consumes it
    if (!(await this.challenges.consume(challenge._id, now))) throw otpInvalid();
  }

  private async enforceSendLimits(phone: string, purpose: OtpPurpose, ip: string): Promise<void> {
    const windowSeconds = this.config.get('OTP_SEND_WINDOW_SECONDS');
    const phoneKey = sha256Hex(phone).slice(0, 32);

    const perIp = await this.rateLimiter.hit(
      this.rateLimiter.key('otp', 'send', 'ip', sha256Hex(ip).slice(0, 32)),
      this.config.get('OTP_MAX_SENDS_PER_IP_PER_WINDOW'),
      windowSeconds,
    );
    if (!perIp.allowed) throw rateLimited(perIp.retryAfterSeconds);

    const cooldownKey = this.rateLimiter.key('otp', 'cooldown', purpose, phoneKey);
    const cooldownRemaining = await this.rateLimiter.secondsRemaining(cooldownKey);
    if (cooldownRemaining > 0) throw rateLimited(cooldownRemaining);

    const perPhone = await this.rateLimiter.hit(
      this.rateLimiter.key('otp', 'send', 'phone', phoneKey),
      this.config.get('OTP_MAX_SENDS_PER_WINDOW'),
      windowSeconds,
    );
    if (!perPhone.allowed) throw rateLimited(perPhone.retryAfterSeconds);

    await this.rateLimiter.setFlag(cooldownKey, this.config.get('OTP_RESEND_COOLDOWN_SECONDS'));
  }

  private hashCode(challengeId: Types.ObjectId, code: string): string {
    return hmacSha256Hex(
      this.config.get('OTP_HASH_SECRET'),
      `${challengeId.toHexString()}:${code}`,
    );
  }

  private messageBody(code: string, ttlSeconds: number): string {
    const minutes = Math.max(1, Math.round(ttlSeconds / 60));
    return (
      `${code} is your Abra Travels verification code. It expires in ${minutes} minutes. ` +
      'Do not share it with anyone.'
    );
  }
}
