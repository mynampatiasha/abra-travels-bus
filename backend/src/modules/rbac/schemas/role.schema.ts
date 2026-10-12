import { Schema, type Types } from 'mongoose';
import { type DataScopeType, type UserType } from '../../../common/request-context/request-actor';
import { DATA_SCOPE_TYPES, USER_TYPES } from '../../users/schemas/user.schema';

export const ROLE_MODEL = 'Role';

/** None, View, Edit, Edit and delete: one level per portal page (access-pages.ts). */
export type RoleAccessLevel = 'NONE' | 'VIEW' | 'EDIT' | 'FULL';

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
  /** Mirrored from code at start-up; its definition cannot be deleted through the API. */
  isSystemRole: boolean;
  /**
   * Level per portal page, set when the role is edited in the access matrix. When present, the
   * permission keys the matrix owns come from these levels (permissionKeys is kept in step), and
   * the start-up synchroniser leaves them alone.
   */
  pageLevels?: Record<string, RoleAccessLevel>;
  /** Set for a custom role that belongs to one operator; absent for platform roles. */
  operatorId?: Types.ObjectId;
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
    pageLevels: { type: Schema.Types.Mixed },
    operatorId: { type: Schema.Types.ObjectId },
  },
  { collection: 'roles', timestamps: true, versionKey: false },
);

roleSchema.index({ key: 1 }, { unique: true });
