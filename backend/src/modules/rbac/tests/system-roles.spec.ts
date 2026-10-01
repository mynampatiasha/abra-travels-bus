import { ALL_PERMISSIONS_WILDCARD, PermissionRegistry } from '../permissions/permission-registry';
import {
  ALLOWED_SCOPE_TYPES_BY_USER_TYPE,
  findSystemRole,
  IMPLICIT_ROLE_BY_USER_TYPE,
  type RoleDefinition,
  SYSTEM_ROLE_KEYS,
  SYSTEM_ROLES,
  validateRoleDefinitions,
} from '../roles/system-roles';

function role(key: string): RoleDefinition {
  const found = findSystemRole(key);
  if (!found) throw new Error(`role ${key} missing`);
  return found;
}

describe('system roles', () => {
  it('defines exactly the twelve roles of the platform specification', () => {
    expect(SYSTEM_ROLES.map((definition) => definition.key).sort()).toEqual(
      [
        'SUPER_ADMIN',
        'ADMIN',
        'OPERATOR_ADMIN',
        'OPERATOR_MANAGER',
        'BOOKING_STAFF',
        'ACCOUNT_STAFF',
        'OPERATIONS_STAFF',
        'DRIVER',
        'CONDUCTOR',
        'SUPPORT',
        'PARTNER',
        'CUSTOMER',
      ].sort(),
    );
    expect(SYSTEM_ROLE_KEYS).toHaveLength(12);
  });

  it('passes its own start-up validation', () => {
    expect(() => validateRoleDefinitions(SYSTEM_ROLES)).not.toThrow();
  });

  it('gives every role a name, a description, an account kind and a data scope', () => {
    for (const definition of SYSTEM_ROLES) {
      expect(definition.name.length).toBeGreaterThan(2);
      expect(definition.description.length).toBeGreaterThan(10);
      expect(ALLOWED_SCOPE_TYPES_BY_USER_TYPE[definition.userType]).toContain(
        definition.dataScopeType,
      );
    }
  });

  it('only references permissions that exist and that the account kind may hold', () => {
    for (const definition of SYSTEM_ROLES) {
      for (const key of definition.permissionKeys) {
        if (key === ALL_PERMISSIONS_WILDCARD) continue;
        expect(PermissionRegistry.has(key)).toBe(true);
        expect(PermissionRegistry.isGrantableTo(key, definition.userType)).toBe(true);
      }
    }
  });

  it('only SUPER_ADMIN holds the wildcard', () => {
    const holders = SYSTEM_ROLES.filter((definition) =>
      definition.permissionKeys.includes(ALL_PERMISSIONS_WILDCARD),
    );
    expect(holders.map((definition) => definition.key)).toEqual(['SUPER_ADMIN']);
  });

  it('ADMIN has broad access but not the most dangerous permissions', () => {
    const admin = role('ADMIN').permissionKeys;
    expect(admin).toEqual(expect.arrayContaining(['users.roles.assign', 'audit.read']));
    expect(admin).not.toContain('users.delete');
    expect(admin).not.toContain('settings.update');
    expect(admin).not.toContain(ALL_PERMISSIONS_WILDCARD);
  });

  it.each([
    ['SUPER_ADMIN', 'STAFF', 'ALL'],
    ['ADMIN', 'STAFF', 'ALL'],
    ['SUPPORT', 'STAFF', 'ALL'],
    ['OPERATOR_ADMIN', 'OPERATOR_STAFF', 'OWN_OPERATOR'],
    ['OPERATOR_MANAGER', 'OPERATOR_STAFF', 'OWN_OPERATOR'],
    ['BOOKING_STAFF', 'OPERATOR_STAFF', 'OWN_OPERATOR'],
    ['ACCOUNT_STAFF', 'OPERATOR_STAFF', 'OWN_OPERATOR'],
    ['OPERATIONS_STAFF', 'OPERATOR_STAFF', 'OWN_OPERATOR'],
    ['DRIVER', 'DRIVER', 'ASSIGNED_RECORDS'],
    ['CONDUCTOR', 'DRIVER', 'ASSIGNED_RECORDS'],
    ['PARTNER', 'PARTNER_USER', 'OWN_PARTNER'],
    ['CUSTOMER', 'CUSTOMER', 'OWN_RECORDS'],
  ])('%s is for %s accounts with scope %s', (key, userType, scope) => {
    expect(role(key)).toMatchObject({ userType, dataScopeType: scope });
  });

  it('role permissions match the responsibilities of the role', () => {
    expect(role('BOOKING_STAFF').permissionKeys).toEqual(
      expect.arrayContaining(['bookings.read', 'bookings.create', 'bookings.cancel']),
    );
    expect(role('BOOKING_STAFF').permissionKeys).not.toContain('settlements.read');
    expect(role('ACCOUNT_STAFF').permissionKeys).toContain('settlements.read');
    expect(role('ACCOUNT_STAFF').permissionKeys).not.toContain('bookings.cancel');
    expect(role('SUPPORT').permissionKeys).not.toContain('bookings.cancel');
    expect(role('OPERATOR_ADMIN').permissionKeys).not.toContain('users.data-scope.manage');
    expect(role('CUSTOMER').permissionKeys).not.toContain('users.read');
    expect(role('DRIVER').permissionKeys).toEqual(['trips.read', 'bookings.read']);
  });

  it('only customers get an implicit role; every other account starts with nothing', () => {
    expect(IMPLICIT_ROLE_BY_USER_TYPE).toEqual({ CUSTOMER: 'CUSTOMER' });
  });

  it('unknown roles are not found', () => {
    expect(findSystemRole('ROOT')).toBeUndefined();
    expect(findSystemRole('super_admin')).toBeUndefined();
  });

  describe('validateRoleDefinitions', () => {
    const base = role('BOOKING_STAFF');

    it('rejects duplicate role keys', () => {
      expect(() => validateRoleDefinitions([base, base])).toThrow('Duplicate role');
    });

    it('rejects a data scope the account kind cannot use', () => {
      expect(() => validateRoleDefinitions([{ ...base, dataScopeType: 'ALL' }])).toThrow(
        'data scope',
      );
    });

    it('rejects a permission the account kind cannot hold', () => {
      expect(() =>
        validateRoleDefinitions([{ ...base, permissionKeys: ['settings.update'] }]),
      ).toThrow('cannot hold');
    });

    it('rejects a permission that does not exist', () => {
      expect(() =>
        validateRoleDefinitions([{ ...base, permissionKeys: ['bookings.destroy' as never] }]),
      ).toThrow('cannot hold');
    });
  });
});
