/// Keys of the thirteen system roles
/// (`backend/src/modules/rbac/roles/system-roles.ts`).
///
/// Prefer permission checks: a role only says which permissions a user
/// starts with, and overrides can change them. Role keys are for display
/// and for the few places where the UI differs by role.
abstract final class RoleKeys {
  static const superAdmin = 'SUPER_ADMIN';
  static const admin = 'ADMIN';
  static const support = 'SUPPORT';
  static const accounts = 'ACCOUNTS';
  static const operatorAdmin = 'OPERATOR_ADMIN';
  static const operatorManager = 'OPERATOR_MANAGER';
  static const bookingStaff = 'BOOKING_STAFF';
  static const accountStaff = 'ACCOUNT_STAFF';
  static const operationsStaff = 'OPERATIONS_STAFF';
  static const driver = 'DRIVER';
  static const conductor = 'CONDUCTOR';
  static const partner = 'PARTNER';
  static const customer = 'CUSTOMER';

  static const Set<String> all = <String>{
    superAdmin,
    admin,
    support,
    accounts,
    operatorAdmin,
    operatorManager,
    bookingStaff,
    accountStaff,
    operationsStaff,
    driver,
    conductor,
    partner,
    customer,
  };
}
