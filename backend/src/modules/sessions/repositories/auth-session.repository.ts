import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, isValidObjectId, type Model, type Types } from 'mongoose';
import {
  AUTH_SESSION_MODEL,
  type AuthSession,
  type SessionRevocationReason,
} from '../schemas/auth-session.schema';

export type StoredAuthSession = AuthSession & { _id: Types.ObjectId };

/** Replaced refresh-token hashes remembered per session for reuse detection. */
export const REMEMBERED_REPLACED_TOKENS = 20;

/**
 * `auth_sessions`. Looked up while the caller is still being identified, so this is not a
 * ScopedRepository. Every query that acts for a user carries that user's id explicitly, so one
 * user can never read or revoke another user's session.
 */
@Injectable()
export class AuthSessionRepository {
  constructor(@InjectModel(AUTH_SESSION_MODEL) private readonly model: Model<AuthSession>) {}

  async insert(
    session: Partial<AuthSession>,
    dbSession?: ClientSession,
  ): Promise<StoredAuthSession> {
    const [created] = await this.model.create([session], { session: dbSession });
    if (!created) throw new Error('Session insert returned no document');
    return created.toObject();
  }

  findById(id: string): Promise<StoredAuthSession | null> {
    if (!isValidObjectId(id)) return Promise.resolve(null);
    return this.model.findById(id).lean<StoredAuthSession>().exec();
  }

  /**
   * Replaces the refresh token only if `currentHash` is still the session's current token and the
   * session is alive. One atomic update: of two concurrent rotations exactly one succeeds.
   */
  rotate(
    id: string,
    currentHash: string,
    next: { refreshTokenHash: string; expiresAt: Date; ip?: string; userAgent?: string },
    now: Date,
  ): Promise<StoredAuthSession | null> {
    return this.model
      .findOneAndUpdate(
        { _id: id, refreshTokenHash: currentHash, revokedAt: null, expiresAt: { $gt: now } },
        {
          $set: {
            refreshTokenHash: next.refreshTokenHash,
            expiresAt: next.expiresAt,
            rotatedAt: now,
            lastUsedAt: now,
            ...(next.ip ? { ip: next.ip } : {}),
            ...(next.userAgent ? { userAgent: next.userAgent } : {}),
          },
          $push: {
            previousRefreshTokenHashes: {
              $each: [currentHash],
              $slice: -REMEMBERED_REPLACED_TOKENS,
            },
          },
        },
        { returnDocument: 'after' },
      )
      .lean<StoredAuthSession>()
      .exec();
  }

  /** Revokes one session of one user. Returns false if it was not theirs or already revoked. */
  async revoke(
    id: string,
    userId: string,
    reason: SessionRevocationReason,
    now: Date,
    dbSession?: ClientSession,
  ): Promise<boolean> {
    if (!isValidObjectId(id)) return false;
    const result = await this.model.updateOne(
      { _id: id, userId, revokedAt: null },
      { $set: { revokedAt: now, revokedReason: reason } },
      { session: dbSession },
    );
    return result.modifiedCount === 1;
  }

  async revokeAllForUser(
    userId: string,
    reason: SessionRevocationReason,
    now: Date,
    options: { exceptSessionId?: string; dbSession?: ClientSession } = {},
  ): Promise<number> {
    const result = await this.model.updateMany(
      {
        userId,
        revokedAt: null,
        ...(options.exceptSessionId ? { _id: { $ne: options.exceptSessionId } } : {}),
      },
      { $set: { revokedAt: now, revokedReason: reason } },
      { session: options.dbSession },
    );
    return result.modifiedCount;
  }

  listActiveForUser(userId: string, now: Date): Promise<StoredAuthSession[]> {
    return this.model
      .find({ userId, revokedAt: null, expiresAt: { $gt: now } })
      .sort({ lastUsedAt: -1 })
      .lean<StoredAuthSession[]>()
      .exec();
  }

  async clearMfaEnrollmentPending(id: string, userId: string): Promise<void> {
    await this.model.updateOne(
      { _id: id, userId },
      { $set: { mfaEnrollmentPending: false, mfaVerified: true } },
    );
  }
}
