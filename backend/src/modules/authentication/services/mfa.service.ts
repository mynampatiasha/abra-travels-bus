import { randomBytes } from 'node:crypto';
import { Injectable, Logger } from '@nestjs/common';
import { FieldEncryptionService } from '../../../common/crypto/field-encryption.service';
import { sha256Hex } from '../../../common/crypto/secure-hash';
import { ApiException } from '../../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import { SessionsService } from '../../sessions/services/sessions.service';
import { type StoredUser } from '../../users/repositories/user.repository';
import { UsersService } from '../../users/services/users.service';
import { LoginThrottleService } from './login-throttle.service';
import { base32Encode, generateTotpSecret, totpKeyUri, verifyTotp } from './totp';

export const RECOVERY_CODE_COUNT = 10;

export interface SecondFactor {
  /** 6-digit code from the authenticator app. */
  code?: string;
  /** One of the single-use recovery codes issued at enrolment. */
  recoveryCode?: string;
}

export interface MfaEnrollment {
  /** Base32 secret for manual entry. Shown once; never returned again. */
  secret: string;
  /** otpauth:// URI to render as a QR code. */
  keyUri: string;
}

export interface MfaStatus {
  enabled: boolean;
  /** Mandatory for this account (it cannot be disabled). */
  required: boolean;
  recoveryCodesRemaining: number;
}

function normalizeRecoveryCode(code: string): string {
  return code.toUpperCase().replace(/[\s-]/g, '');
}

/** 10 characters of base32 (50 bits), displayed as XXXXX-XXXXX. */
function generateRecoveryCode(): string {
  const raw = base32Encode(randomBytes(7)).slice(0, 10);
  return `${raw.slice(0, 5)}-${raw.slice(5)}`;
}

function mfaInvalid(): ApiException {
  return new ApiException('MFA_INVALID', 'The verification code is incorrect.');
}

/**
 * TOTP second factor. The secret is generated on the server, stored encrypted
 * (FieldEncryptionService) and shown to the user exactly once during enrolment. A used time step
 * is remembered, so an intercepted code cannot be replayed. Recovery codes are stored as hashes
 * and work once each. Wrong codes count towards the same temporary lockout as passwords.
 */
@Injectable()
export class MfaService {
  private readonly logger = new Logger(MfaService.name);

  constructor(
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly encryption: FieldEncryptionService,
    private readonly throttle: LoginThrottleService,
    private readonly config: AppConfigService,
  ) {}

  /** STAFF accounts must use MFA when MFA_REQUIRED_FOR_STAFF is on (always on in production). */
  isRequiredFor(user: Pick<StoredUser, 'userType'>): boolean {
    return user.userType === 'STAFF' && this.config.get('MFA_REQUIRED_FOR_STAFF');
  }

  async status(userId: string): Promise<MfaStatus> {
    const user = await this.users.getById(userId);
    return {
      enabled: user.mfa.enabled,
      required: this.isRequiredFor(user),
      recoveryCodesRemaining: user.mfa.recoveryCodeHashes.length,
    };
  }

  /** Step 1: create a secret. Nothing changes for sign-in until `activate` confirms a code. */
  async startEnrollment(userId: string): Promise<MfaEnrollment> {
    const user = await this.users.getById(userId);
    if (user.mfa.enabled) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Two-step verification is already on');
    }
    const secret = generateTotpSecret();
    await this.users.setPendingMfaSecret(userId, this.encryption.encrypt(secret));
    const accountName = user.email ?? user.phone ?? userId;
    return { secret, keyUri: totpKeyUri(this.config.get('MFA_TOTP_ISSUER'), accountName, secret) };
  }

  /**
   * Step 2: prove the authenticator app works. Turns MFA on, returns the recovery codes (shown
   * once) and signs out every other device.
   */
  async activate(
    actor: AuthenticatedUserActor,
    code: string,
  ): Promise<{ recoveryCodes: string[] }> {
    const user = await this.users.getById(actor.userId);
    const pending = user.mfa.pendingSecretEncrypted;
    if (user.mfa.enabled || !pending) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Start two-step verification setup before confirming a code',
      );
    }
    await this.throttle.assertNotLocked('mfa', actor.userId);

    const timeStep = verifyTotp(this.encryption.decrypt(pending), code, Date.now());
    if (timeStep === undefined) {
      await this.throttle.recordFailure('mfa', actor.userId);
      throw mfaInvalid();
    }

    const recoveryCodes = Array.from({ length: RECOVERY_CODE_COUNT }, generateRecoveryCode);
    const activated = await this.users.activateMfa(
      actor.userId,
      pending,
      recoveryCodes.map((recoveryCode) => sha256Hex(normalizeRecoveryCode(recoveryCode))),
      timeStep,
    );
    if (!activated) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Two-step verification setup changed');
    }

    await this.throttle.recordSuccess('mfa', actor.userId);
    await this.sessions.clearMfaEnrollmentPending(actor.sessionId, actor.userId);
    await this.sessions.revokeAllForUser(actor.userId, 'MFA_CHANGED', {
      exceptSessionId: actor.sessionId,
    });
    this.logger.log({ userId: actor.userId }, 'MFA enabled');
    return { recoveryCodes };
  }

  /** Turns MFA off after a valid second factor. Refused where MFA is mandatory. */
  async disable(actor: AuthenticatedUserActor, factor: SecondFactor): Promise<void> {
    const user = await this.users.getById(actor.userId);
    if (!user.mfa.enabled) {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Two-step verification is not on');
    }
    if (this.isRequiredFor(user)) {
      throw new ApiException(
        'PERMISSION_DENIED',
        'Two-step verification is mandatory for this account',
      );
    }
    await this.assertSecondFactor(user, factor);
    await this.users.disableMfa(actor.userId);
    await this.sessions.revokeAllForUser(actor.userId, 'MFA_CHANGED', {
      exceptSessionId: actor.sessionId,
    });
    this.logger.log({ userId: actor.userId }, 'MFA disabled');
  }

  /**
   * Verifies a TOTP code or a recovery code for a user with MFA enabled; throws MFA_INVALID or
   * ACCOUNT_LOCKED. Exactly one of `code` / `recoveryCode` must be given.
   */
  async assertSecondFactor(user: StoredUser, factor: SecondFactor): Promise<void> {
    const userId = user._id.toHexString();
    const hasCode = typeof factor.code === 'string';
    const hasRecoveryCode = typeof factor.recoveryCode === 'string';
    if (hasCode === hasRecoveryCode) {
      throw new ApiException('VALIDATION_FAILED', 'Request validation failed', {
        location: 'body',
        issues: [{ path: 'code', code: 'custom', message: 'provide either code or recoveryCode' }],
      });
    }
    await this.throttle.assertNotLocked('mfa', userId);

    const accepted = hasCode
      ? await this.acceptTotp(user, factor.code ?? '')
      : await this.acceptRecoveryCode(userId, factor.recoveryCode ?? '');
    if (!accepted) {
      await this.throttle.recordFailure('mfa', userId);
      throw mfaInvalid();
    }
    await this.throttle.recordSuccess('mfa', userId);
  }

  private async acceptTotp(user: StoredUser, code: string): Promise<boolean> {
    const stored = user.mfa.secretEncrypted;
    if (!user.mfa.enabled || !stored) return false;
    const timeStep = verifyTotp(this.encryption.decrypt(stored), code, Date.now());
    if (timeStep === undefined) return false;
    // False when this step (or a later one) was already used: the code is a replay
    return this.users.consumeTotpTimeStep(user._id.toHexString(), timeStep);
  }

  private async acceptRecoveryCode(userId: string, recoveryCode: string): Promise<boolean> {
    const normalized = normalizeRecoveryCode(recoveryCode);
    if (!/^[A-Z2-7]{10}$/.test(normalized)) return false;
    const consumed = await this.users.consumeRecoveryCode(userId, sha256Hex(normalized));
    if (consumed) this.logger.warn({ userId }, 'MFA recovery code used');
    return consumed;
  }
}
