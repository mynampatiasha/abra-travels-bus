import { Schema } from 'mongoose';
import { type DataScopeType, type UserType } from '../../../common/request-context/request-actor';
import { DATA_SCOPE_TYPES, USER_TYPES } from '../../users/schemas/user.schema';

export const ROLE_MODEL = 'Role';

export interface Role {
  /** Stable key, e.g. `OPERATOR_ADMIN`. */
  key: string;
  name: string;
  description: string;
  /** Kind of account the role can be assigned to. */
  userType: UserType;
  dataScopeType: DataScopeType;
  /** Permission keys, or the single wildcard `*`. Unknown keys grant nothing. */
  permissionKeys: string[];
  /** Mirrored from code at start-up; cannot be changed through the API. */
  isSystemRole: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `roles` (database-architecture.md §1). */
export const roleSchema = new Schema<Role>(
  {
    key: { type: String, required: true, maxlength: 64 },
    name: { type: String, required: true, maxlength: 80 },
    description: { type: String, required: true, maxlength: 300 },
    userType: { type: String, enum: USER_TYPES, required: true },
    dataScopeType: { type: String, enum: DATA_SCOPE_TYPES, required: true },
    permissionKeys: { type: [String], default: [] },
    isSystemRole: { type: Boolean, required: true, default: false },
  },
  { collection: 'roles', timestamps: true, versionKey: false },
);

roleSchema.index({ key: 1 }, { unique: true });
