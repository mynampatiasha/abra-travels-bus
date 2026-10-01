import { Injectable } from '@nestjs/common';
import { type ClientSession } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type StoredAuthSession } from '../../sessions/repositories/auth-session.repository';
import { type SessionClientType } from '../../sessions/schemas/auth-session.schema';
import { SessionsService } from '../../sessions/services/sessions.service';
import { type StoredUser } from '../../users/repositories/user.repository';
import { toUserProfile, type UserProfile, UsersService } from '../../users/services/users.service';
import { AccessTokenService } from './access-token.service';
import { MfaService } from './mfa.service';

export interface DeviceInfo {
  clientType: SessionClientType;
  deviceName?: string;
}

/** What a client receives after a completed sign-in or a token refresh. */
export interface AuthenticationResult {
  tokenType: 'Bearer';
  accessToken: string;
  accessTokenExpiresInSeconds: number;
  /** Opaque; store in the platform keystore. Web clients receive it as an HttpOnly cookie instead. */
  refreshToken: string;
  refreshTokenExpiresAt: string;
  sessionId: string;
  /** The session can only complete MFA enrolment until MFA is enabled. */
  mfaEnrollmentRequired: boolean;
  user: UserProfile;
}

/** Password was correct but a second factor is still required. No session exists yet. */
export interface MfaRequiredResult {
  mfaRequired: true;
  mfaToken: string;
  mfaTokenExpiresInSeconds: number;
}

/**
 * The single place that turns an identified user into a session and tokens, so every sign-in
 * method (password, OTP, MFA, registration) applies the same account checks.
 */
@Injectable()
export class AuthSessionIssuer {
  constructor(
    private readonly sessions: SessionsService,
    private readonly accessTokens: AccessTokenService,
    private readonly users: UsersService,
    private readonly mfa: MfaService,
  ) {}

  /** Only ACTIVE accounts may sign in or keep a session. */
  assertCanSignIn(user: StoredUser): void {
    if (user.status !== 'ACTIVE') {
      throw new ApiException('ACCOUNT_DISABLED', 'This account is not active. Contact support.');
    }
  }

  async mfaChallengeFor(user: StoredUser): Promise<MfaRequiredResult> {
    const challenge = await this.accessTokens.issueMfaChallenge(user._id.toHexString());
    return {
      mfaRequired: true,
      mfaToken: challenge.token,
      mfaTokenExpiresInSeconds: challenge.expiresInSeconds,
    };
  }

  async issue(
    user: StoredUser,
    device: DeviceInfo,
    client: ClientRequestInfo,
    options: { mfaVerified: boolean; dbSession?: ClientSession },
  ): Promise<AuthenticationResult> {
    this.assertCanSignIn(user);
    const { session, refreshToken } = await this.sessions.create(
      {
        userId: user._id,
        userType: user.userType,
        clientType: device.clientType,
        ...(device.deviceName ? { deviceName: device.deviceName } : {}),
        client,
        mfaVerified: options.mfaVerified,
        mfaEnrollmentPending: this.mfa.isRequiredFor(user) && !user.mfa.enabled,
      },
      options.dbSession,
    );
    await this.users.recordLogin(user._id.toHexString(), options.dbSession);
    return this.result(user, session, refreshToken);
  }

  /** Tokens for a session whose refresh token was just rotated. */
  async result(
    user: StoredUser,
    session: StoredAuthSession,
    refreshToken: string,
  ): Promise<AuthenticationResult> {
    const access = await this.accessTokens.issue({
      userId: user._id.toHexString(),
      userType: user.userType,
      sessionId: session._id.toHexString(),
      permissionVersion: user.permissionVersion,
      ...(user.operatorId ? { operatorId: user.operatorId.toHexString() } : {}),
    });
    return {
      tokenType: 'Bearer',
      accessToken: access.token,
      accessTokenExpiresInSeconds: access.expiresInSeconds,
      refreshToken,
      refreshTokenExpiresAt: session.expiresAt.toISOString(),
      sessionId: session._id.toHexString(),
      mfaEnrollmentRequired: session.mfaEnrollmentPending,
      user: toUserProfile(user),
    };
  }
}
