import {
  definePermissions,
  EVERY_ACCOUNT_KIND,
  PLATFORM_AND_OPERATOR,
  PLATFORM_ONLY,
} from './permission-definition';

const WITH_PARTNERS = ['STAFF', 'OPERATOR_STAFF', 'PARTNER_USER'] as const;
const WITH_FIELD_STAFF = ['STAFF', 'OPERATOR_STAFF', 'DRIVER', 'PARTNER_USER', 'CUSTOMER'] as const;
const BOOKING_CHANNELS = ['STAFF', 'OPERATOR_STAFF', 'PARTNER_USER', 'CUSTOMER'] as const;

/**
 * Permission groups, one per module. Only capabilities that exist or are needed by the
 * authorization foundation are declared; each business module adds its own group here when it is
 * built (documentation/authorization.md §2).
 */

export const USER_PERMISSIONS = definePermissions('users', {
  read: {
    name: 'View users',
    description: 'List and view user accounts within the data scope.',
    grantableTo: WITH_PARTNERS,
  },
  create: {
    name: 'Create users',
    description: 'Create user accounts within the data scope.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  update: {
    name: 'Edit users',
    description: 'Change user account details and status.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  delete: {
    name: 'Delete users',
    description: 'Deactivate or remove user accounts.',
    grantableTo: PLATFORM_ONLY,
    sensitive: true,
  },
});

export const USER_ROLE_PERMISSIONS = definePermissions('users.roles', {
  assign: {
    name: 'Assign roles',
    description: 'Change the roles of another user.',
    grantableTo: PLATFORM_AND_OPERATOR,
    sensitive: true,
  },
});

export const USER_PERMISSION_PERMISSIONS = definePermissions('users.permissions', {
  read: {
    name: 'View user permissions',
    description: 'View the roles, overrides and effective permissions of another user.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  manage: {
    name: 'Manage user permissions',
    description: 'Grant or deny individual permissions for another user.',
    grantableTo: PLATFORM_AND_OPERATOR,
    sensitive: true,
  },
});

export const USER_DATA_SCOPE_PERMISSIONS = definePermissions('users.data-scope', {
  manage: {
    name: 'Manage data scope',
    description: 'Change which operators or records another user can reach.',
    grantableTo: PLATFORM_ONLY,
    sensitive: true,
  },
});

export const ROLE_PERMISSIONS = definePermissions('roles', {
  read: {
    name: 'View roles and permissions',
    description: 'View the role catalogue and the permission catalogue.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
});

export const BOOKING_PERMISSIONS = definePermissions('bookings', {
  read: {
    name: 'View bookings',
    description: 'View bookings within the data scope.',
    grantableTo: WITH_FIELD_STAFF,
  },
  create: {
    name: 'Create bookings',
    description: 'Create bookings.',
    grantableTo: BOOKING_CHANNELS,
  },
  update: {
    name: 'Edit bookings',
    description: 'Change passenger or contact details of a booking.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  cancel: {
    name: 'Cancel bookings',
    description: 'Cancel bookings or individual seats.',
    grantableTo: BOOKING_CHANNELS,
  },
});

export const BUS_PERMISSIONS = definePermissions('buses', {
  read: { name: 'View buses', description: 'View buses.', grantableTo: PLATFORM_AND_OPERATOR },
  create: { name: 'Add buses', description: 'Add buses.', grantableTo: PLATFORM_AND_OPERATOR },
  update: { name: 'Edit buses', description: 'Edit buses.', grantableTo: PLATFORM_AND_OPERATOR },
  delete: {
    name: 'Remove buses',
    description: 'Remove buses.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
});

export const TRIP_PERMISSIONS = definePermissions('trips', {
  read: { name: 'View trips', description: 'View trips.', grantableTo: EVERY_ACCOUNT_KIND },
  create: {
    name: 'Create trips',
    description: 'Create trips.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  update: {
    name: 'Edit trips',
    description: 'Edit trips and update their status.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  cancel: {
    name: 'Cancel trips',
    description: 'Cancel a trip and refund its bookings.',
    grantableTo: PLATFORM_AND_OPERATOR,
    sensitive: true,
  },
});

export const FARE_PERMISSIONS = definePermissions('fares', {
  read: {
    name: 'View fares',
    description: 'View fare rules.',
    grantableTo: BOOKING_CHANNELS,
  },
  create: {
    name: 'Create fares',
    description: 'Create fare rules.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  update: {
    name: 'Edit fares',
    description: 'Change fare rules.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
});

export const REPORT_PERMISSIONS = definePermissions('reports', {
  read: { name: 'View reports', description: 'View reports.', grantableTo: WITH_PARTNERS },
});

export const SETTLEMENT_PERMISSIONS = definePermissions('settlements', {
  read: {
    name: 'View settlements',
    description: 'View settlement statements.',
    grantableTo: WITH_PARTNERS,
  },
});

export const CUSTOMER_PERMISSIONS = definePermissions('customers', {
  read: {
    name: 'View customers',
    description: 'View customer profiles.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  update: {
    name: 'Edit customers',
    description: 'Edit customer profiles.',
    grantableTo: PLATFORM_ONLY,
  },
});

export const OPERATOR_PERMISSIONS = definePermissions('operators', {
  read: {
    name: 'View operators',
    description: 'View operator profiles.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  create: {
    name: 'Create operators',
    description: 'Register operators.',
    grantableTo: PLATFORM_ONLY,
  },
  update: {
    name: 'Edit operators',
    description: 'Edit operator profiles.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
});

export const PARTNER_PERMISSIONS = definePermissions('partners', {
  read: { name: 'View partners', description: 'View partners.', grantableTo: WITH_PARTNERS },
  create: { name: 'Create partners', description: 'Onboard partners.', grantableTo: PLATFORM_ONLY },
  update: { name: 'Edit partners', description: 'Edit partners.', grantableTo: PLATFORM_ONLY },
});

export const NOTIFICATION_PERMISSIONS = definePermissions('notifications', {
  read: {
    name: 'View notifications',
    description: 'View sent notifications and their delivery status.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
  manage: {
    name: 'Manage notifications',
    description: 'Manage templates and resend notifications.',
    grantableTo: PLATFORM_ONLY,
  },
});

export const SETTING_PERMISSIONS = definePermissions('settings', {
  read: { name: 'View settings', description: 'View system settings.', grantableTo: PLATFORM_ONLY },
  update: {
    name: 'Change settings',
    description: 'Change system settings.',
    grantableTo: PLATFORM_ONLY,
    sensitive: true,
  },
});

export const AUDIT_PERMISSIONS = definePermissions('audit', {
  read: {
    name: 'View audit log',
    description: 'View the audit trail within the data scope.',
    grantableTo: PLATFORM_AND_OPERATOR,
  },
});

/** Every permission of the platform. A new module's group is added to this object. */
export const PERMISSION_CATALOG = {
  ...USER_PERMISSIONS,
  ...USER_ROLE_PERMISSIONS,
  ...USER_PERMISSION_PERMISSIONS,
  ...USER_DATA_SCOPE_PERMISSIONS,
  ...ROLE_PERMISSIONS,
  ...BOOKING_PERMISSIONS,
  ...BUS_PERMISSIONS,
  ...TRIP_PERMISSIONS,
  ...FARE_PERMISSIONS,
  ...REPORT_PERMISSIONS,
  ...SETTLEMENT_PERMISSIONS,
  ...CUSTOMER_PERMISSIONS,
  ...OPERATOR_PERMISSIONS,
  ...PARTNER_PERMISSIONS,
  ...NOTIFICATION_PERMISSIONS,
  ...SETTING_PERMISSIONS,
  ...AUDIT_PERMISSIONS,
} as const;

/** Union of every declared permission key; the only values `@RequirePermission` accepts. */
export type PermissionKey = keyof typeof PERMISSION_CATALOG;
