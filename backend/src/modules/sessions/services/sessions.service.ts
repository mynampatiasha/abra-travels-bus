import { Injectable, Logger } from '@nestjs/common';
import { type ClientSession, type Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type UserType } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import {
  AuthSessionRepository,
  type StoredAuthSession,
} from '../repositories/auth-session.repository';
import {
  type SessionClientType,
  type SessionRevocationReason,
} from '../schemas/auth-session.schema';
import {
  formatRefreshToken,
  newRefreshTokenSecret,
  parseRefreshToken,
} from './refresh-token.codec';

/**
 * Two requests that refresh with the same token at the same moment (app resumed on two isolates,
 * retry after a network timeout) are not theft. Within this window the loser of the race gets a
 * plain rejection and can continue with the token the winner received; after it, a replaced
 * token is treated as stolen.
 */
export const REFRESH_REUSE_GRACE_MS = 10_000;

const DAY_MS = 24 * 60 * 60 * 1000;

export interface NewSessionInput {
  userId: Types.ObjectId;
  userType: UserType;
  clientType: SessionClientType;
  deviceName?: string;
  client: ClientRequestInfo;
  mfaVerified: boolean;
  mfaEnrollmentPending: boolean;
}

export interface IssuedSession {
  session: StoredAuthSession;
  /** Raw refresh token. Returned to the client once; only its hash is stored. */
  refreshToken: string;
}

export interface SessionSummary {
  id: string;
  current: boolean;
  clientType: SessionClientType;
  deviceName: string | null;
  ip: string | null;
  userAgent: string | null;
  createdAt: string | null;
  lastUsedAt: string;
  expiresAt: string;
}

function invalidRefreshToken(): ApiException {
  // One answer for every failure: unknown, malformed, expired, revoked or reused
  return new ApiException(
    'UNAUTHENTICATED',
    'The session is no longer valid. Please sign in again.',
  );
}

/** Signed-in devices and their refresh tokens. MongoDB is the source of truth for sessions. */
@Injectable()
export class SessionsService {
  private readonly logger = new Logger(SessionsService.name);

  constructor(
    private readonly repository: AuthSessionRepository,
    private readonly config: AppConfigService,
  ) {}

  /** Customers and drivers stay signed in longer than staff, operator staff and partner users. */
  refreshTokenLifetimeMs(userType: UserType): number {
    const days =
      userType === 'CUSTOMER' || userType === 'DRIVER'
        ? this.config.get('REFRESH_TOKEN_TTL_DAYS')
        : this.config.get('REFRESH_TOKEN_TTL_DAYS_STAFF');
    return days * DAY_MS;
  }

  async create(input: NewSessionInput, dbSession?: ClientSession): Promise<IssuedSession> {
    const now = new Date();
    const { secret, secretHash } = newRefreshTokenSecret();
    const session = await this.repository.insert(
      {
        userId: input.userId,
        refreshTokenHash: secretHash,
        previousRefreshTokenHashes: [],
        clientType: input.clientType,
        ...(input.deviceName ? { deviceName: input.deviceName } : {}),
        ip: input.client.ip,
        ...(input.client.userAgent ? { userAgent: input.client.userAgent } : {}),
        mfaVerified: input.mfaVerified,
        mfaEnrollmentPending: input.mfaEnrollmentPending,
        lastUsedAt: now,
        rotatedAt: now,
        expiresAt: new Date(now.getTime() + this.refreshTokenLifetimeMs(input.userType)),
      },
      dbSession,
    );
    return { session, refreshToken: formatRefreshToken(session._id.toHexString(), secret) };
  }

  /**
   * Exchanges a refresh token for a new one (rotation). The presented token stops working the
   * moment this succeeds. `userTypeOf` lets the caller reject a disabled user before the token is
   * rotated and supplies the lifetime for the new token.
   */
  async rotate(
    refreshToken: unknown,
    client: ClientRequestInfo,
    userTypeOf: (userId: string) => Promise<UserType>,
  ): Promise<IssuedSession> {
    const parsed = parseRefreshToken(refreshToken);
    if (!parsed) throw invalidRefreshToken();

    const existing = await this.repository.findById(parsed.sessionId);
    const now = new Date();
    if (!existing || existing.revokedAt || existing.expiresAt <= now) throw invalidRefreshToken();

    if (existing.refreshTokenHash !== parsed.secretHash) {
      await this.handleNonCurrentToken(existing, parsed.secretHash, now);
      throw invalidRefreshToken();
    }

    const userType = await userTypeOf(existing.userId.toHexString());
    const { secret, secretHash } = newRefreshTokenSecret();
    const rotated = await this.repository.rotate(
      parsed.sessionId,
      parsed.secretHash,
      {
        refreshTokenHash: secretHash,
        expiresAt: new Date(now.getTime() + this.refreshTokenLifetimeMs(userType)),
        ip: client.ip,
        ...(client.userAgent ? { userAgent: client.userAgent } : {}),
      },
      now,
    );
    // Lost a race with a concurrent rotation of the same token (or the session was just revoked)
    if (!rotated) throw invalidRefreshToken();

    return { session: rotated, refreshToken: formatRefreshToken(parsed.sessionId, secret) };
  }

  /** A token that is not the current one: either a replaced token used again, or garbage. */
  private async handleNonCurrentToken(
    session: StoredAuthSession,
    presentedHash: string,
    now: Date,
  ): Promise<void> {
    const replaced = session.previousRefreshTokenHashes;
    if (!replaced.includes(presentedHash)) return; // never issued for this session: just invalid

    const justReplaced = replaced.at(-1) === presentedHash;
    const withinGrace = now.getTime() - session.rotatedAt.getTime() <= REFRESH_REUSE_GRACE_MS;
    if (justReplaced && withinGrace) return; // concurrent refresh, not theft

    const userId = session.userId.toHexString();
    await this.repository.revoke(session._id.toHexString(), userId, 'REFRESH_TOKEN_REUSE', now);
    this.logger.warn(
      { userId, sessionId: session._id.toHexString() },
      'Refresh token reuse detected; session revoked',
    );
  }

  /** The session behind an access token, or null if it is revoked, expired or not this user's. */
  async findActive(sessionId: string, userId: string): Promise<StoredAuthSession | null> {
    const session = await this.repository.findById(sessionId);
    if (!session || session.revokedAt || session.expiresAt <= new Date()) return null;
    return session.userId.toHexString() === userId ? session : null;
  }

  revoke(
    sessionId: string,
    userId: string,
    reason: SessionRevocationReason,
    dbSession?: ClientSession,
  ): Promise<boolean> {
    return this.repository.revoke(sessionId, userId, reason, new Date(), dbSession);
  }

  /** Logout with only a refresh token (the access token may already have expired). Idempotent. */
  async revokeByRefreshToken(refreshToken: unknown): Promise<void> {
    const parsed = parseRefreshToken(refreshToken);
    if (!parsed) return;
    const session = await this.repository.findById(parsed.sessionId);
    // Only the holder of the current token may end the session
    if (!session || session.refreshTokenHash !== parsed.secretHash) return;
    await this.repository.revoke(
      parsed.sessionId,
      session.userId.toHexString(),
      'LOGOUT',
      new Date(),
    );
  }

  revokeAllForUser(
    userId: string,
    reason: SessionRevocationReason,
    options: { exceptSessionId?: string; dbSession?: ClientSession } = {},
  ): Promise<number> {
    return this.repository.revokeAllForUser(userId, reason, new Date(), options);
  }

  clearMfaEnrollmentPending(sessionId: string, userId: string): Promise<void> {
    return this.repository.clearMfaEnrollmentPending(sessionId, userId);
  }

  async listActive(userId: string, currentSessionId: string): Promise<SessionSummary[]> {
    const sessions = await this.repository.listActiveForUser(userId, new Date());
    return sessions.map((session) => ({
      id: session._id.toHexString(),
      current: session._id.toHexString() === currentSessionId,
      clientType: session.clientType,
      deviceName: session.deviceName ?? null,
      ip: session.ip ?? null,
      userAgent: session.userAgent ?? null,
      createdAt: session.createdAt?.toISOString() ?? null,
      lastUsedAt: session.lastUsedAt.toISOString(),
      expiresAt: session.expiresAt.toISOString(),
    }));
  }
}
