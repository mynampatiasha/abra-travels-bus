import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import {
  type OverrideEffect,
  PERMISSION_OVERRIDE_MODEL,
  type PermissionOverride,
} from '../schemas/permission-override.schema';

export type StoredPermissionOverride = PermissionOverride & { _id: Types.ObjectId };

/**
 * `permission_overrides`. Only AuthorizationAdministrationService writes here, after it has
 * verified that the acting administrator may change the target user; reads are for evaluating a
 * user's effective permissions.
 */
@Injectable()
export class PermissionOverrideRepository {
  constructor(
    @InjectModel(PERMISSION_OVERRIDE_MODEL) private readonly model: Model<PermissionOverride>,
  ) {}

  findForUser(
    userId: Types.ObjectId | string,
    session?: ClientSession,
  ): Promise<StoredPermissionOverride[]> {
    return this.model
      .find({ userId }, null, { session })
      .sort({ permissionKey: 1 })
      .lean<StoredPermissionOverride[]>()
      .exec();
  }

  findOne(
    userId: string,
    permissionKey: string,
    session: ClientSession,
  ): Promise<StoredPermissionOverride | null> {
    return this.model
      .findOne({ userId, permissionKey }, null, { session })
      .lean<StoredPermissionOverride>()
      .exec();
  }

  /** Creates the override or replaces its effect and reason. */
  async set(
    override: {
      userId: Types.ObjectId;
      permissionKey: string;
      effect: OverrideEffect;
      reason: string;
      grantedBy: Types.ObjectId;
    },
    session: ClientSession,
  ): Promise<void> {
    await this.model.updateOne(
      { userId: override.userId, permissionKey: override.permissionKey },
      { $set: override },
      { upsert: true, session, runValidators: true },
    );
  }

  async remove(userId: string, permissionKey: string, session: ClientSession): Promise<boolean> {
    const result = await this.model.deleteOne({ userId, permissionKey }, { session });
    return result.deletedCount === 1;
  }
}
