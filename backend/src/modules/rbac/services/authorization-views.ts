import { type DataScopeType, type UserType } from '../../../common/request-context/request-actor';
import { type StoredUser } from '../../users/repositories/user.repository';
import { PermissionRegistry } from '../permissions/permission-registry';
import { type StoredPermissionOverride } from '../repositories/permission-override.repository';
import { type StoredRole } from '../repositories/role.repository';
import { type OverrideEffect } from '../schemas/permission-override.schema';
import { type EffectivePermissions, type PermissionSource } from './effective-permissions';

export interface RoleSummary {
  key: string;
  name: string;
}

export interface DataScopeView {
  type: DataScopeType;
  operatorIds: string[];
}

/** What a client needs to decide which screens and actions to show. Authorization facts only. */
export interface MyPermissionsView {
  userId: string;
  userType: UserType;
  roles: RoleSummary[];
  /** Changes whenever the user's access changes; clients refetch when it differs. */
  permissionVersion: number;
  dataScope: DataScopeView;
  operatorId: string | null;
  partnerId: string | null;
  /** Effective permission keys, sorted. */
  permissions: string[];
  /** The same permissions grouped by module: `{ bookings: ['cancel', 'create', 'read'] }`. */
  permissionsByModule: Record<string, string[]>;
}

/** A user's authorization as seen by an administrator. */
export interface UserAuthorizationView {
  userId: string;
  userType: UserType;
  operatorId: string | null;
  partnerId: string | null;
  permissionVersion: number;
  roles: RoleSummary[];
  dataScope: DataScopeView;
  overrides: Array<{
    permissionKey: string;
    effect: OverrideEffect;
    reason: string;
    grantedBy: string;
    updatedAt: string | null;
  }>;
  effectivePermissions: Array<{ key: string; source: PermissionSource }>;
  /** Role permissions removed by a DENY override. */
  deniedPermissions: string[];
}

export function dataScopeView(user: StoredUser): DataScopeView {
  return {
    type: user.dataScope.type,
    operatorIds: user.dataScope.operatorIds.map((operatorId) => operatorId.toHexString()),
  };
}

function roleSummaries(
  roles: readonly StoredRole[],
  effective: EffectivePermissions,
): RoleSummary[] {
  return roles
    .filter((role) => effective.roleKeys.includes(role.key))
    .map((role) => ({ key: role.key, name: role.name }));
}

export function toMyPermissionsView(
  user: StoredUser,
  roles: readonly StoredRole[],
  effective: EffectivePermissions,
): MyPermissionsView {
  const permissions = [...effective.permissions].sort();
  const permissionsByModule: Record<string, string[]> = {};
  for (const key of permissions) {
    const definition = PermissionRegistry.get(key);
    if (definition) (permissionsByModule[definition.module] ??= []).push(definition.action);
  }
  return {
    userId: user._id.toHexString(),
    userType: user.userType,
    roles: roleSummaries(roles, effective),
    permissionVersion: user.permissionVersion,
    dataScope: dataScopeView(user),
    operatorId: user.operatorId?.toHexString() ?? null,
    partnerId: user.partnerId?.toHexString() ?? null,
    permissions,
    permissionsByModule,
  };
}

export function toUserAuthorizationView(
  user: StoredUser,
  roles: readonly StoredRole[],
  overrides: readonly StoredPermissionOverride[],
  effective: EffectivePermissions,
): UserAuthorizationView {
  return {
    userId: user._id.toHexString(),
    userType: user.userType,
    operatorId: user.operatorId?.toHexString() ?? null,
    partnerId: user.partnerId?.toHexString() ?? null,
    permissionVersion: user.permissionVersion,
    roles: roleSummaries(roles, effective),
    dataScope: dataScopeView(user),
    overrides: overrides.map((override) => ({
      permissionKey: override.permissionKey,
      effect: override.effect,
      reason: override.reason,
      grantedBy: override.grantedBy.toHexString(),
      updatedAt: override.updatedAt?.toISOString() ?? null,
    })),
    effectivePermissions: [...effective.sources.entries()]
      .map(([key, source]) => ({ key, source }))
      .sort((a, b) => a.key.localeCompare(b.key)),
    deniedPermissions: [...effective.denied].sort(),
  };
}
