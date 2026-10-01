import { Types } from 'mongoose';
import {
  type AuthSessionRepository,
  REMEMBERED_REPLACED_TOKENS,
  type StoredAuthSession,
} from '../repositories/auth-session.repository';
import { type AuthSession, type SessionRevocationReason } from '../schemas/auth-session.schema';

/**
 * Copy of a stored session as the real repository returns it (`lean()` / `toObject()`): a new
 * object whose mutable array is copied, while ObjectId and Date values stay real instances.
 * (structuredClone would turn ObjectIds into plain objects without `toHexString()`.)
 */
function snapshot(session: StoredAuthSession): StoredAuthSession {
  return { ...session, previousRefreshTokenHashes: [...session.previousRefreshTokenHashes] };
}

/**
 * Unit-test stand-in for AuthSessionRepository with the same conditional-update semantics as the
 * MongoDB queries. The real queries are exercised by the e2e suite.
 */
export class InMemoryAuthSessionRepository {
  readonly sessions = new Map<string, StoredAuthSession>();

  insert(session: Partial<AuthSession>): Promise<StoredAuthSession> {
    const stored = {
      revokedAt: null,
      revokedReason: null,
      createdAt: new Date(),
      ...session,
      _id: new Types.ObjectId(),
    } as StoredAuthSession;
    this.sessions.set(stored._id.toHexString(), stored);
    return Promise.resolve(snapshot(stored));
  }

  findById(id: string): Promise<StoredAuthSession | null> {
    const found = this.sessions.get(id);
    return Promise.resolve(found ? snapshot(found) : null);
  }

  rotate(
    id: string,
    currentHash: string,
    next: { refreshTokenHash: string; expiresAt: Date; ip?: string; userAgent?: string },
    now: Date,
  ): Promise<StoredAuthSession | null> {
    const session = this.sessions.get(id);
    if (
      !session ||
      session.refreshTokenHash !== currentHash ||
      session.revokedAt ||
      session.expiresAt <= now
    ) {
      return Promise.resolve(null);
    }
    session.previousRefreshTokenHashes = [...session.previousRefreshTokenHashes, currentHash].slice(
      -REMEMBERED_REPLACED_TOKENS,
    );
    Object.assign(session, {
      refreshTokenHash: next.refreshTokenHash,
      expiresAt: next.expiresAt,
      rotatedAt: now,
      lastUsedAt: now,
    });
    return Promise.resolve(snapshot(session));
  }

  revoke(id: string, userId: string, reason: SessionRevocationReason, now: Date): Promise<boolean> {
    const session = this.sessions.get(id);
    if (!session || session.userId.toHexString() !== userId || session.revokedAt) {
      return Promise.resolve(false);
    }
    session.revokedAt = now;
    session.revokedReason = reason;
    return Promise.resolve(true);
  }

  revokeAllForUser(
    userId: string,
    reason: SessionRevocationReason,
    now: Date,
    options: { exceptSessionId?: string } = {},
  ): Promise<number> {
    let revoked = 0;
    for (const [id, session] of this.sessions) {
      if (session.userId.toHexString() !== userId || session.revokedAt) continue;
      if (id === options.exceptSessionId) continue;
      session.revokedAt = now;
      session.revokedReason = reason;
      revoked++;
    }
    return Promise.resolve(revoked);
  }

  listActiveForUser(userId: string, now: Date): Promise<StoredAuthSession[]> {
    return Promise.resolve(
      [...this.sessions.values()]
        .filter(
          (session) =>
            session.userId.toHexString() === userId &&
            !session.revokedAt &&
            session.expiresAt > now,
        )
        .sort((a, b) => b.lastUsedAt.getTime() - a.lastUsedAt.getTime())
        .map(snapshot),
    );
  }

  clearMfaEnrollmentPending(id: string, userId: string): Promise<void> {
    const session = this.sessions.get(id);
    if (session?.userId.toHexString() === userId) {
      session.mfaEnrollmentPending = false;
      session.mfaVerified = true;
    }
    return Promise.resolve();
  }

  asRepository(): AuthSessionRepository {
    return this as unknown as AuthSessionRepository;
  }
}
