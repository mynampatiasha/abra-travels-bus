import { Injectable, Logger } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { SessionsService } from '../../sessions/services/sessions.service';
import { UsersService } from '../../users/services/users.service';
import { LoginThrottleService } from './login-throttle.service';
import { OtpService } from './otp.service';
import { PasswordHasher } from './password-hasher.service';
import { assertPasswordAcceptable } from './password-policy';

/**
 * Setting, changing and resetting passwords. Every change signs out the other devices of the
 * account, so a stolen session does not survive a password change.
 */
@Injectable()
export class PasswordManagementService {
  private readonly logger = new Logger(PasswordManagementService.name);

  constructor(
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly hasher: PasswordHasher,
    private readonly throttle: LoginThrottleService,
    private readonly otp: OtpService,
  ) {}

  /**
   * Sets the first password of an OTP-only account, or changes an existing one. Changing requires
   * the current password; wrong guesses are throttled like sign-in attempts.
   */
  async setOrChange(
    actor: AuthenticatedUserActor,
    input: { currentPassword?: string; newPassword: string },
  ): Promise<{ otherSessionsSignedOut: number }> {
    const user = await this.users.getById(actor.userId);
    assertPasswordAcceptable(input.newPassword, user);

    if (user.passwordHash) {
      const throttleKey = `user:${actor.userId}`;
      await this.throttle.assertNotLocked('password', throttleKey);
      const correct =
        input.currentPassword !== undefined &&
        (await this.hasher.verify(input.currentPassword, user.passwordHash));
      if (!correct) {
        await this.throttle.recordFailure('password', throttleKey);
        throw new ApiException('INVALID_CREDENTIALS', 'The current password is incorrect.');
      }
      await this.throttle.recordSuccess('password', throttleKey);
    }

    await this.users.setPassword(actor.userId, await this.hasher.hash(input.newPassword));
    const otherSessionsSignedOut = await this.sessions.revokeAllForUser(
      actor.userId,
      'PASSWORD_CHANGED',
      { exceptSessionId: actor.sessionId },
    );
    this.logger.log({ userId: actor.userId }, 'Password changed');
    return { otherSessionsSignedOut };
  }

  /** Forgotten password: a PASSWORD_RESET code proves control of the account's phone. */
  async resetWithOtp(input: { phone: string; code: string; newPassword: string }): Promise<void> {
    await this.otp.verify(input.phone, 'PASSWORD_RESET', input.code);

    // A reset code is only ever sent to an existing active account (OtpLoginService.requestCode)
    const user = await this.users.findByPhone(input.phone);
    if (!user || user.status !== 'ACTIVE') {
      throw new ApiException(
        'OTP_INVALID',
        'The verification code is incorrect or has expired. Please request a new code.',
      );
    }
    assertPasswordAcceptable(input.newPassword, user);

    const userId = user._id.toHexString();
    await this.users.setPassword(userId, await this.hasher.hash(input.newPassword));
    await this.sessions.revokeAllForUser(userId, 'PASSWORD_CHANGED');
    // The owner proved control of the account: lift any lockout on its identifiers
    await Promise.all(
      [user.phone, user.email]
        .filter((identifier): identifier is string => typeof identifier === 'string')
        .map((identifier) => this.throttle.clear('password', identifier)),
    );
    this.logger.log({ userId }, 'Password reset with OTP');
  }
}
