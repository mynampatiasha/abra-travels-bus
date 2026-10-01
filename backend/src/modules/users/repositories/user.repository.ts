import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, isValidObjectId, type Model, type Types } from 'mongoose';
import { USER_MODEL, type User } from '../schemas/user.schema';

export type StoredUser = User & { _id: Types.ObjectId };

interface WriteOptions {
  session?: ClientSession;
}

/**
 * Identity lookups and credential updates for authentication. These run before an actor exists
 * (the caller is being identified), so this is deliberately not a ScopedRepository; it is used
 * only by UsersService. User administration by other users (Phase 2 step 8) goes through scoped
 * access and permissions.
 */
@Injectable()
export class UserRepository {
  constructor(@InjectModel(USER_MODEL) private readonly model: Model<User>) {}

  findById(id: string, options: WriteOptions = {}): Promise<StoredUser | null> {
    if (!isValidObjectId(id)) return Promise.resolve(null);
    return this.model.findById(id, null, { session: options.session }).lean<StoredUser>().exec();
  }

  findByEmail(email: string): Promise<StoredUser | null> {
    return this.model.findOne({ email }).lean<StoredUser>().exec();
  }

  findByPhone(phone: string, options: WriteOptions = {}): Promise<StoredUser | null> {
    return this.model
      .findOne({ phone }, null, { session: options.session })
      .lean<StoredUser>()
      .exec();
  }

  async insert(user: Partial<User>, options: WriteOptions = {}): Promise<StoredUser> {
    const [created] = await this.model.create([user], { session: options.session });
    if (!created) throw new Error('User insert returned no document');
    return created.toObject();
  }

  async setFields(
    id: Types.ObjectId | string,
    fields: Partial<User>,
    options: WriteOptions = {},
  ): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id },
      { $set: fields },
      { session: options.session, runValidators: true },
    );
    return result.matchedCount === 1;
  }

  /**
   * Changes roles and/or data scope and bumps `permissionVersion` in one update, so access tokens
   * issued before the change stop working (PERMISSIONS_CHANGED) and the user picks up the new
   * permissions on refresh.
   */
  async applyAuthorizationChange(
    id: Types.ObjectId,
    change: { roleIds?: Types.ObjectId[]; dataScope?: User['dataScope'] },
    session: ClientSession,
  ): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id },
      {
        ...(Object.keys(change).length > 0 ? { $set: change } : {}),
        $inc: { permissionVersion: 1 },
      },
      { session, runValidators: true },
    );
    return result.matchedCount === 1;
  }

  /** Stores a new MFA secret awaiting confirmation; refused when MFA is already enabled. */
  async setPendingMfaSecret(id: string, pendingSecretEncrypted: string): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, 'mfa.enabled': false },
      { $set: { 'mfa.pendingSecretEncrypted': pendingSecretEncrypted } },
    );
    return result.modifiedCount === 1;
  }

  /** Promotes the pending secret to the active one. Conditional, so it happens exactly once. */
  async activateMfa(
    id: string,
    pendingSecretEncrypted: string,
    recoveryCodeHashes: string[],
    timeStep: number,
    now: Date,
  ): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, 'mfa.enabled': false, 'mfa.pendingSecretEncrypted': pendingSecretEncrypted },
      {
        $set: {
          'mfa.enabled': true,
          'mfa.secretEncrypted': pendingSecretEncrypted,
          'mfa.pendingSecretEncrypted': null,
          'mfa.recoveryCodeHashes': recoveryCodeHashes,
          'mfa.lastUsedTimeStep': timeStep,
          'mfa.enabledAt': now,
        },
        $inc: { permissionVersion: 1 },
      },
    );
    return result.modifiedCount === 1;
  }

  async disableMfa(id: string): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, 'mfa.enabled': true },
      {
        $set: {
          'mfa.enabled': false,
          'mfa.secretEncrypted': null,
          'mfa.pendingSecretEncrypted': null,
          'mfa.recoveryCodeHashes': [],
          'mfa.lastUsedTimeStep': null,
          'mfa.enabledAt': null,
        },
        $inc: { permissionVersion: 1 },
      },
    );
    return result.modifiedCount === 1;
  }

  /**
   * Records a TOTP time step as used. Returns false when the same or a later step was already
   * accepted, which makes a captured code useless a second time (replay protection).
   */
  async consumeTotpTimeStep(id: string, timeStep: number): Promise<boolean> {
    const result = await this.model.updateOne(
      {
        _id: id,
        'mfa.enabled': true,
        $or: [{ 'mfa.lastUsedTimeStep': null }, { 'mfa.lastUsedTimeStep': { $lt: timeStep } }],
      },
      { $set: { 'mfa.lastUsedTimeStep': timeStep } },
    );
    return result.modifiedCount === 1;
  }

  /** Removes one recovery code. Returns false if it was not there (wrong or already used). */
  async consumeRecoveryCode(id: string, recoveryCodeHash: string): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, 'mfa.enabled': true, 'mfa.recoveryCodeHashes': recoveryCodeHash },
      { $pull: { 'mfa.recoveryCodeHashes': recoveryCodeHash } },
    );
    return result.modifiedCount === 1;
  }
}
