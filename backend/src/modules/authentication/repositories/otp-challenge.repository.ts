import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, type Types } from 'mongoose';
import {
  OTP_CHALLENGE_MODEL,
  type OtpChallenge,
  type OtpPurpose,
} from '../schemas/otp-challenge.schema';

export type StoredOtpChallenge = OtpChallenge & { _id: Types.ObjectId };

/** `otp_challenges`. Platform-internal (pre-authentication), so not a ScopedRepository. */
@Injectable()
export class OtpChallengeRepository {
  constructor(@InjectModel(OTP_CHALLENGE_MODEL) private readonly model: Model<OtpChallenge>) {}

  async insert(challenge: OtpChallenge & { _id: Types.ObjectId }): Promise<void> {
    await this.model.create([challenge]);
  }

  /** A new code replaces every earlier unused code for the same number and purpose. */
  async supersedeActive(target: string, purpose: OtpPurpose, now: Date): Promise<void> {
    await this.model.updateMany(
      { target, purpose, consumedAt: null },
      { $set: { consumedAt: now } },
    );
  }

  /**
   * Counts one verification attempt against the newest usable challenge and returns it. Atomic:
   * the attempt limit holds even when many guesses arrive at once. Null when there is no usable
   * challenge (none requested, expired, used, replaced, or out of attempts).
   */
  registerAttempt(
    target: string,
    purpose: OtpPurpose,
    maxAttempts: number,
    now: Date,
  ): Promise<StoredOtpChallenge | null> {
    return this.model
      .findOneAndUpdate(
        {
          target,
          purpose,
          consumedAt: null,
          expiresAt: { $gt: now },
          attempts: { $lt: maxAttempts },
        },
        { $inc: { attempts: 1 } },
        { sort: { createdAt: -1 }, returnDocument: 'after' },
      )
      .lean<StoredOtpChallenge>()
      .exec();
  }

  /** Marks the challenge used. False if it was already used, so a code works exactly once. */
  async consume(id: Types.ObjectId, now: Date): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, consumedAt: null },
      { $set: { consumedAt: now } },
    );
    return result.modifiedCount === 1;
  }
}
