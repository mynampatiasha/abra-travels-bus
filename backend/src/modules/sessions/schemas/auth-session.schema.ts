import { Schema, type Types } from 'mongoose';

export const AUTH_SESSION_MODEL = 'AuthSession';

export const SESSION_CLIENT_TYPES = ['MOBILE', 'WEB'] as const;
export type SessionClientType = (typeof SESSION_CLIENT_TYPES)[number];

export const SESSION_REVOCATION_REASONS = [
  'LOGOUT',
  'LOGOUT_ALL',
  'REVOKED_BY_USER',
  'REFRESH_TOKEN_REUSE',
  'PASSWORD_CHANGED',
  'MFA_CHANGED',
  'ACCOUNT_DISABLED',
] as const;
export type SessionRevocationReason = (typeof SESSION_REVOCATION_REASONS)[number];

/**
 * One signed-in device. A session is also the refresh-token family: every rotation replaces
 * `refreshTokenHash` and remembers the replaced hashes, so a replaced token that shows up again
 * is recognised as reuse and the whole session is revoked.
 */
export interface AuthSession {
  userId: Types.ObjectId;
  /** SHA-256 of the current refresh-token secret. The raw token is never stored. */
  refreshTokenHash: string;
  /** Hashes of replaced tokens, newest last (bounded). */
  previousRefreshTokenHashes: string[];
  clientType: SessionClientType;
  deviceName?: string;
  ip?: string;
  userAgent?: string;
  /** Second factor verified when the session was created. */
  mfaVerified: boolean;
  /** Session may only finish MFA enrolment (staff accounts when MFA is mandatory). */
  mfaEnrollmentPending: boolean;
  lastUsedAt: Date;
  /** When the refresh token was last rotated. */
  rotatedAt: Date;
  expiresAt: Date;
  revokedAt?: Date | null;
  revokedReason?: SessionRevocationReason | null;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `auth_sessions` (database-architecture.md §1). */
export const authSessionSchema = new Schema<AuthSession>(
  {
    userId: { type: Schema.Types.ObjectId, required: true },
    refreshTokenHash: { type: String, required: true },
    previousRefreshTokenHashes: { type: [String], default: [] },
    clientType: { type: String, enum: SESSION_CLIENT_TYPES, required: true },
    deviceName: { type: String, maxlength: 80 },
    ip: { type: String, maxlength: 64 },
    userAgent: { type: String, maxlength: 256 },
    mfaVerified: { type: Boolean, required: true, default: false },
    mfaEnrollmentPending: { type: Boolean, required: true, default: false },
    lastUsedAt: { type: Date, required: true },
    rotatedAt: { type: Date, required: true },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },
    revokedReason: { type: String, enum: [...SESSION_REVOCATION_REASONS, null], default: null },
  },
  { collection: 'auth_sessions', timestamps: true, versionKey: false },
);

authSessionSchema.index({ userId: 1, revokedAt: 1 });
// MongoDB removes a session once it has expired; an expired refresh token is useless anyway
authSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
