import { type DataScopeType, type UserType } from '../../../common/request-context/request-actor';
import { type PermissionKey } from '../permissions/permission-catalog';
import { ALL_PERMISSIONS_WILDCARD, PermissionRegistry } from '../permissions/permission-registry';

export const SYSTEM_ROLE_KEYS = [
  'SUPER_ADMIN',
  'ADMIN',
  'SUPPORT',
  'OPERATOR_ADMIN',
  'OPERATOR_MANAGER',
  'BOOKING_STAFF',
  'ACCOUNT_STAFF',
  'OPERATIONS_STAFF',
  'DRIVER',
  'CONDUCTOR',
  'PARTNER',
  'CUSTOMER',
] as const;
export type SystemRoleKey = (typeof SYSTEM_ROLE_KEYS)[number];

export interface RoleDefinition {
  readonly key: SystemRoleKey;
  readonly name: string;
  readonly description: string;
  /** The kind of account this role can be assigned to. */
  readonly userType: UserType;
  /** Which records holders of the role can reach (database/data-scope.policy.ts). */
  readonly dataScopeType: DataScopeType;
  readonly permissionKeys: readonly (PermissionKey | typeof ALL_PERMISSIONS_WILDCARD)[];
}

/** ADMIN runs the platform but cannot delete accounts or change system settings. */
const ADMIN_EXCLUDED: readonly PermissionKey[] = ['users.delete', 'settings.update'];

/**
 * The twelve roles of the platform specification (documentation/authorization.md §3). These
 * definitions are the source of truth for system roles; SystemRolesSynchronizer mirrors them into
 * the `roles` collection at start-up so users can reference them by id. Business code never
 * checks a role name — only permission keys and data scope.
 */
export const SYSTEM_ROLES: readonly RoleDefinition[] = [
  {
    key: 'SUPER_ADMIN',
    name: 'Super administrator',
    description: 'Full control of the platform, including other administrators.',
    userType: 'STAFF',
    dataScopeType: 'ALL',
    permissionKeys: [ALL_PERMISSIONS_WILDCARD],
  },
  {
    key: 'ADMIN',
    name: 'Administrator',
    description: 'Runs the platform day to day across all operators.',
    userType: 'STAFF',
    dataScopeType: 'ALL',
    permissionKeys: PermissionRegistry.keys().filter((key) => !ADMIN_EXCLUDED.includes(key)),
  },
  {
    key: 'SUPPORT',
    name: 'Support agent',
    description: 'Looks up customers, bookings and trips to resolve support requests.',
    userType: 'STAFF',
    dataScopeType: 'ALL',
    permissionKeys: [
      'customers.read',
      'bookings.read',
      'trips.read',
      'buses.read',
      'operators.read',
      'notifications.read',
    ],
  },
  {
    key: 'OPERATOR_ADMIN',
    name: 'Operator administrator',
    description: 'Manages one bus operator: its staff, fleet, trips, fares and bookings.',
    userType: 'OPERATOR_STAFF',
    dataScopeType: 'OWN_OPERATOR',
    permissionKeys: [
      'users.read',
      'users.create',
      'users.update',
      'users.roles.assign',
      'users.permissions.read',
      'users.permissions.manage',
      'roles.read',
      'buses.read',
      'buses.create',
      'buses.update',
      'buses.delete',
      'trips.read',
      'trips.create',
      'trips.update',
      'trips.cancel',
      'fares.read',
      'fares.create',
      'fares.update',
      'bookings.read',
      'bookings.create',
      'bookings.update',
      'bookings.cancel',
      'customers.read',
      'reports.read',
      'settlements.read',
      'operators.read',
      'operators.update',
      'notifications.read',
      'audit.read',
    ],
  },
  {
    key: 'OPERATOR_MANAGER',
    name: 'Operator manager',
    description: 'Plans fleet, trips and fares and oversees bookings for one operator.',
    userType: 'OPERATOR_STAFF',
    dataScopeType: 'OWN_OPERATOR',
    permissionKeys: [
      'buses.read',
      'buses.create',
      'buses.update',
      'trips.read',
      'trips.create',
      'trips.update',
      'trips.cancel',
      'fares.read',
      'fares.create',
      'fares.update',
      'bookings.read',
      'bookings.create',
      'bookings.update',
      'customers.read',
      'reports.read',
    ],
  },
  {
    key: 'BOOKING_STAFF',
    name: 'Booking staff',
    description: 'Creates and manages bookings at the operator counter.',
    userType: 'OPERATOR_STAFF',
    dataScopeType: 'OWN_OPERATOR',
    permissionKeys: [
      'bookings.read',
      'bookings.create',
      'bookings.update',
      'bookings.cancel',
      'customers.read',
      'trips.read',
      'buses.read',
      'fares.read',
    ],
  },
  {
    key: 'ACCOUNT_STAFF',
    name: 'Accounts staff',
    description: 'Reviews bookings, settlements and reports for one operator.',
    userType: 'OPERATOR_STAFF',
    dataScopeType: 'OWN_OPERATOR',
    permissionKeys: ['bookings.read', 'fares.read', 'settlements.read', 'reports.read'],
  },
  {
    key: 'OPERATIONS_STAFF',
    name: 'Operations staff',
    description: 'Runs the trips of the day: status, delays, passenger lists.',
    userType: 'OPERATOR_STAFF',
    dataScopeType: 'OWN_OPERATOR',
    permissionKeys: ['trips.read', 'trips.update', 'buses.read', 'bookings.read'],
  },
  {
    key: 'DRIVER',
    name: 'Driver',
    description: 'Sees the trips assigned to them and their passengers.',
    userType: 'DRIVER',
    dataScopeType: 'ASSIGNED_RECORDS',
    permissionKeys: ['trips.read', 'bookings.read'],
  },
  {
    key: 'CONDUCTOR',
    name: 'Conductor',
    description: 'Sees the trips assigned to them and their passengers.',
    userType: 'DRIVER',
    dataScopeType: 'ASSIGNED_RECORDS',
    permissionKeys: ['trips.read', 'bookings.read'],
  },
  {
    key: 'PARTNER',
    name: 'Partner user',
    description: 'Works with the bookings, reports and settlements of one partner.',
    userType: 'PARTNER_USER',
    dataScopeType: 'OWN_PARTNER',
    permissionKeys: [
      'trips.read',
      'fares.read',
      'bookings.read',
      'bookings.create',
      'bookings.cancel',
      'reports.read',
      'settlements.read',
    ],
  },
  {
    key: 'CUSTOMER',
    name: 'Customer',
    description: 'Books and manages their own travel.',
    userType: 'CUSTOMER',
    dataScopeType: 'OWN_RECORDS',
    permissionKeys: [
      'trips.read',
      'fares.read',
      'bookings.read',
      'bookings.create',
      'bookings.cancel',
    ],
  },
];

/**
 * Customer accounts are created by sign-up without stored roles; they hold the CUSTOMER role
 * implicitly. Every other kind of account has no permissions until a role is assigned.
 */
export const IMPLICIT_ROLE_BY_USER_TYPE: Partial<Record<UserType, SystemRoleKey>> = {
  CUSTOMER: 'CUSTOMER',
};

/**
 * Data-scope types an account of each kind may have. A customer can never be given operator-wide
 * or platform-wide reach, whatever an administrator sends.
 */
export const ALLOWED_SCOPE_TYPES_BY_USER_TYPE: Record<UserType, readonly DataScopeType[]> = {
  STAFF: ['ALL', 'SELECTED_OPERATORS'],
  OPERATOR_STAFF: ['OWN_OPERATOR', 'SELECTED_OPERATORS'],
  DRIVER: ['ASSIGNED_RECORDS'],
  PARTNER_USER: ['OWN_PARTNER'],
  CUSTOMER: ['OWN_RECORDS'],
};

export function findSystemRole(key: string): RoleDefinition | undefined {
  return SYSTEM_ROLES.find((role) => role.key === key);
}

/**
 * Checks the role definitions once at start-up: unique keys, every permission exists and may be
 * held by the role's account kind, and the scope suits that account kind.
 */
export function validateRoleDefinitions(roles: readonly RoleDefinition[]): void {
  const seen = new Set<string>();
  for (const role of roles) {
    if (seen.has(role.key)) throw new Error(`Duplicate role "${role.key}"`);
    seen.add(role.key);
    if (!ALLOWED_SCOPE_TYPES_BY_USER_TYPE[role.userType].includes(role.dataScopeType)) {
      throw new Error(`Role "${role.key}" has a data scope its account kind cannot use`);
    }
    for (const key of role.permissionKeys) {
      if (key === ALL_PERMISSIONS_WILDCARD) continue;
      if (!PermissionRegistry.isGrantableTo(key, role.userType)) {
        throw new Error(`Role "${role.key}" holds "${key}", which ${role.userType} cannot hold`);
      }
    }
  }
}
