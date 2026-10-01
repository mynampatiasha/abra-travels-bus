import { type UserType } from '../../../common/request-context/request-actor';

/**
 * One permission as declared by the module that owns the protected capability.
 * `grantableTo` lists the kinds of account that may ever hold it — through a role or through a
 * user-level ALLOW override. A platform-only permission can therefore never be handed to a
 * customer, driver or partner account, whatever an administrator sends.
 */
export interface PermissionDeclaration {
  /** Human-readable name for administration screens. */
  readonly name: string;
  readonly description: string;
  readonly grantableTo: readonly UserType[];
  /** Changing who holds it needs a reason and is highlighted in the audit trail. */
  readonly sensitive?: boolean;
}

export interface PermissionDefinition extends PermissionDeclaration {
  /** Stable machine-readable key: `<module>.<action>` (`users.permissions.manage`). */
  readonly key: string;
  /** Domain the permission belongs to: the part of the key before the action. */
  readonly module: string;
  readonly action: string;
}

/** `bookings.read`, `users.permissions.manage`: lower-case segments joined by dots. */
export const PERMISSION_KEY_PATTERN = /^[a-z][a-z-]*(\.[a-z][a-z-]*)+$/;

/** Account kinds, for readable `grantableTo` lists. */
export const PLATFORM_ONLY = ['STAFF'] as const satisfies readonly UserType[];
export const PLATFORM_AND_OPERATOR = [
  'STAFF',
  'OPERATOR_STAFF',
] as const satisfies readonly UserType[];
export const EVERY_ACCOUNT_KIND = [
  'STAFF',
  'OPERATOR_STAFF',
  'DRIVER',
  'PARTNER_USER',
  'CUSTOMER',
] as const satisfies readonly UserType[];

/**
 * Declares the permissions of one module. A module adds its permissions by exporting such a
 * group and listing it in permission-registry.ts; keys are checked at start-up (format,
 * uniqueness), and `PermissionKey` — the union of all declared keys — makes every
 * `@RequirePermission('...')` and role definition type-checked.
 *
 *   export const BUS_PERMISSIONS = definePermissions('buses', {
 *     read: { name: 'View buses', description: '...', grantableTo: PLATFORM_AND_OPERATOR },
 *   });
 */
export function definePermissions<
  const Module extends string,
  const Actions extends Record<string, PermissionDeclaration>,
>(
  module: Module,
  actions: Actions,
): { readonly [Action in keyof Actions & string as `${Module}.${Action}`]: PermissionDefinition } {
  const entries = Object.entries(actions).map(([action, declaration]) => {
    const key = `${module}.${action}`;
    return [key, { ...declaration, key, module, action }] as const;
  });
  return Object.fromEntries(entries) as unknown as {
    readonly [Action in keyof Actions & string as `${Module}.${Action}`]: PermissionDefinition;
  };
}
