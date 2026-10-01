import { Schema, type Types } from 'mongoose';

export const PERMISSION_OVERRIDE_MODEL = 'PermissionOverride';

export const OVERRIDE_EFFECTS = ['ALLOW', 'DENY'] as const;
export type OverrideEffect = (typeof OVERRIDE_EFFECTS)[number];

/**
 * A per-user exception to the permissions of the user's roles: ALLOW adds one permission, DENY
 * removes one. At most one override per user and permission.
 */
export interface PermissionOverride {
  userId: Types.ObjectId;
  permissionKey: string;
  effect: OverrideEffect;
  reason: string;
  /** The administrator who set it. */
  grantedBy: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `permission_overrides` (database-architecture.md §1). */
export const permissionOverrideSchema = new Schema<PermissionOverride>(
  {
    userId: { type: Schema.Types.ObjectId, required: true },
    permissionKey: { type: String, required: true, maxlength: 80 },
    effect: { type: String, enum: OVERRIDE_EFFECTS, required: true },
    reason: { type: String, required: true, maxlength: 300 },
    grantedBy: { type: Schema.Types.ObjectId, required: true },
  },
  { collection: 'permission_overrides', timestamps: true, versionKey: false },
);

permissionOverrideSchema.index({ userId: 1, permissionKey: 1 }, { unique: true });
