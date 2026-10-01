import { type UserType } from '../../../common/request-context/request-actor';
import { PERMISSION_CATALOG, type PermissionKey } from './permission-catalog';
import { PERMISSION_KEY_PATTERN, type PermissionDefinition } from './permission-definition';

/** Held only by SUPER_ADMIN: every permission, including ones added later. Never an override. */
export const ALL_PERMISSIONS_WILDCARD = '*';

/**
 * Checks a set of definitions once, at start-up: key format, key matches module + action,
 * at least one account kind. A malformed catalogue stops the process instead of producing a
 * permission that can never match.
 */
export function validatePermissionDefinitions(
  definitions: Readonly<Record<string, PermissionDefinition>>,
): PermissionDefinition[] {
  const validated: PermissionDefinition[] = [];
  for (const [key, definition] of Object.entries(definitions)) {
    if (!PERMISSION_KEY_PATTERN.test(key)) {
      throw new Error(`Invalid permission key "${key}"`);
    }
    if (definition.key !== key || key !== `${definition.module}.${definition.action}`) {
      throw new Error(`Permission "${key}" does not match its module and action`);
    }
    if (definition.grantableTo.length === 0) {
      throw new Error(`Permission "${key}" is not grantable to any account kind`);
    }
    validated.push(definition);
  }
  return validated;
}

const DEFINITIONS: readonly PermissionDefinition[] =
  validatePermissionDefinitions(PERMISSION_CATALOG);
const BY_KEY: ReadonlyMap<string, PermissionDefinition> = new Map(
  DEFINITIONS.map((definition) => [definition.key, definition]),
);

/**
 * Read-only view of the permission catalogue. Authorization never works with free-form strings:
 * a key that is not in the registry grants nothing and cannot be granted (fail closed).
 */
export const PermissionRegistry = {
  all(): readonly PermissionDefinition[] {
    return DEFINITIONS;
  },

  keys(): PermissionKey[] {
    return DEFINITIONS.map((definition) => definition.key as PermissionKey);
  },

  has(key: unknown): key is PermissionKey {
    return typeof key === 'string' && BY_KEY.has(key);
  },

  get(key: string): PermissionDefinition | undefined {
    return BY_KEY.get(key);
  },

  /** May an account of this kind hold the permission at all (role or ALLOW override)? */
  isGrantableTo(key: string, userType: UserType): boolean {
    return BY_KEY.get(key)?.grantableTo.includes(userType) ?? false;
  },

  /** Permissions grouped by module, in declaration order. */
  byModule(): Record<string, PermissionDefinition[]> {
    const grouped: Record<string, PermissionDefinition[]> = {};
    for (const definition of DEFINITIONS) {
      (grouped[definition.module] ??= []).push(definition);
    }
    return grouped;
  },
};
