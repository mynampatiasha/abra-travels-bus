import { Schema } from 'mongoose';

export const OTP_CHALLENGE_MODEL = 'OtpChallenge';

/**
 * SIGN_IN: sign in, or create the customer account on first use.
 * PASSWORD_RESET: prove ownership of the phone before setting a new password.
 * A code issued for one purpose is not accepted for the other.
 */
export const OTP_PURPOSES = ['SIGN_IN', 'PASSWORD_RESET'] as const;
export type OtpPurpose = (typeof OTP_PURPOSES)[number];

export interface OtpChallenge {
  /** E.164 phone number the code was sent to. */
  target: string;
  purpose: OtpPurpose;
  /** HMAC-SHA256(OTP_HASH_SECRET, challengeId + ':' + code). The code itself is never stored. */
  codeHash: string;
  /** Verification attempts made against this challenge. */
  attempts: number;
  expiresAt: Date;
  /** Set when the code was used, replaced by a newer one, or could not be delivered. */
  consumedAt?: Date | null;
  requestIp?: string;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `otp_challenges` (database-architecture.md §1). */
export const otpChallengeSchema = new Schema<OtpChallenge>(
  {
    target: { type: String, required: true },
    purpose: { type: String, enum: OTP_PURPOSES, required: true },
    codeHash: { type: String, required: true },
    attempts: { type: Number, required: true, default: 0, min: 0 },
    expiresAt: { type: Date, required: true },
    consumedAt: { type: Date, default: null },
    requestIp: { type: String, maxlength: 64 },
  },
  { collection: 'otp_challenges', timestamps: true, versionKey: false },
);

otpChallengeSchema.index({ target: 1, purpose: 1, createdAt: -1 });
// Expired challenges are removed by MongoDB shortly after they stop being usable
otpChallengeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
