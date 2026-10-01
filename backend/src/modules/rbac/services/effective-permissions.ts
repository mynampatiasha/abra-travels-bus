import { type UserType } from '../../../common/request-context/request-actor';
import { type PermissionKey } from '../permissions/permission-catalog';
import { ALL_PERMISSIONS_WILDCARD, PermissionRegistry } from '../permissions/permission-registry';
import { type OverrideEffect } from '../schemas/permission-override.schema';

/** Where an effective permission comes from, for administration screens. */
export type PermissionSource = 'ROLE' | 'ALLOW_OVERRIDE';

export interface RoleGrant {
  readonly key: string;
  readonly userType: UserType;
  readonly permissionKeys: readonly string[];
}

export interface OverrideGrant {
  readonly permissionKey: string;
  readonly effect: OverrideEffect;
}

export interface EffectivePermissions {
  /** Keys of the roles that actually contributed (assigned and valid for the account kind). */
  readonly roleKeys: readonly string[];
  /** Holds the SUPER_ADMIN wildcard: may administer other wildcard holders. */
  readonly hasWildcard: boolean;
  readonly permissions: ReadonlySet<PermissionKey>;
  readonly sources: ReadonlyMap<PermissionKey, PermissionSource>;
  /** Permissions removed by a DENY override that a role would otherwise grant. */
  readonly denied: ReadonlySet<PermissionKey>;
}

export const NO_PERMISSIONS: EffectivePermissions = Object.freeze({
  roleKeys: [],
  hasWildcard: false,
  permissions: new Set<PermissionKey>(),
  sources: new Map<PermissionKey, PermissionSource>(),
  denied: new Set<PermissionKey>(),
});

/**
 * The precedence rule of the whole authorization system, as a pure function
 * (documentation/authorization.md §1):
 *
 *   effective = (permissions of the user's roles ∪ ALLOW overrides) − DENY overrides
 *
 * Fail closed at every step:
 * - a role made for another kind of account contributes nothing;
 * - a key that is not in the registry contributes nothing, from a role or from an override;
 * - a permission the account kind may not hold is never granted, even by ALLOW or the wildcard;
 * - DENY always wins, including over the wildcard.
 */
export function resolveEffectivePermissions(
  userType: UserType,
  roles: readonly RoleGrant[],
  overrides: readonly OverrideGrant[],
): EffectivePermissions {
  const sources = new Map<PermissionKey, PermissionSource>();
  const roleKeys: string[] = [];
  let hasWildcard = false;

  for (const role of roles) {
    if (role.userType !== userType) continue;
    roleKeys.push(role.key);
    for (const key of role.permissionKeys) {
      if (key === ALL_PERMISSIONS_WILDCARD) {
        hasWildcard = true;
        for (const every of PermissionRegistry.keys()) {
          if (PermissionRegistry.isGrantableTo(every, userType)) sources.set(every, 'ROLE');
        }
      } else if (PermissionRegistry.has(key) && PermissionRegistry.isGrantableTo(key, userType)) {
        sources.set(key, 'ROLE');
      }
    }
  }

  for (const override of overrides) {
    const key = override.permissionKey;
    if (override.effect !== 'ALLOW' || !PermissionRegistry.has(key)) continue;
    if (!PermissionRegistry.isGrantableTo(key, userType)) continue;
    if (!sources.has(key)) sources.set(key, 'ALLOW_OVERRIDE');
  }

  const denied = new Set<PermissionKey>();
  for (const override of overrides) {
    const key = override.permissionKey;
    if (override.effect !== 'DENY' || !PermissionRegistry.has(key)) continue;
    if (sources.delete(key)) denied.add(key);
  }

  return {
    roleKeys,
    hasWildcard,
    permissions: new Set(sources.keys()),
    sources,
    denied,
  };
}
