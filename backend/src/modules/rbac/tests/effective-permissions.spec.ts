import { ALL_PERMISSIONS_WILDCARD, PermissionRegistry } from '../permissions/permission-registry';
import { findSystemRole } from '../roles/system-roles';
import {
  type OverrideGrant,
  resolveEffectivePermissions,
  type RoleGrant,
} from '../services/effective-permissions';

function systemRole(key: string): RoleGrant {
  const role = findSystemRole(key);
  if (!role) throw new Error(`role ${key} missing`);
  return role;
}

const BOOKING_STAFF = systemRole('BOOKING_STAFF');
const allow = (permissionKey: string): OverrideGrant => ({ permissionKey, effect: 'ALLOW' });
const deny = (permissionKey: string): OverrideGrant => ({ permissionKey, effect: 'DENY' });

describe('resolveEffectivePermissions: (roles ∪ ALLOW) − DENY', () => {
  it('a role grants exactly its permissions', () => {
    const effective = resolveEffectivePermissions('OPERATOR_STAFF', [BOOKING_STAFF], []);
    expect([...effective.permissions].sort()).toEqual([...BOOKING_STAFF.permissionKeys].sort());
    expect(effective.roleKeys).toEqual(['BOOKING_STAFF']);
    expect(effective.hasWildcard).toBe(false);
    expect(effective.sources.get('bookings.read')).toBe('ROLE');
    expect(effective.denied.size).toBe(0);
  });

  it('several roles add up', () => {
    const effective = resolveEffectivePermissions(
      'OPERATOR_STAFF',
      [BOOKING_STAFF, systemRole('ACCOUNT_STAFF')],
      [],
    );
    expect(effective.permissions.has('bookings.cancel')).toBe(true);
    expect(effective.permissions.has('settlements.read')).toBe(true);
    expect(effective.roleKeys).toEqual(['BOOKING_STAFF', 'ACCOUNT_STAFF']);
  });

  it('ALLOW override adds a permission the role does not have', () => {
    const effective = resolveEffectivePermissions(
      'OPERATOR_STAFF',
      [BOOKING_STAFF],
      [allow('reports.read')],
    );
    expect(effective.permissions.has('reports.read')).toBe(true);
    expect(effective.sources.get('reports.read')).toBe('ALLOW_OVERRIDE');
    expect(effective.sources.get('bookings.read')).toBe('ROLE');
  });

  it('DENY override removes a permission inherited from the role', () => {
    const effective = resolveEffectivePermissions(
      'OPERATOR_STAFF',
      [BOOKING_STAFF],
      [deny('bookings.cancel')],
    );
    expect(effective.permissions.has('bookings.cancel')).toBe(false);
    expect(effective.permissions.has('bookings.read')).toBe(true);
    expect([...effective.denied]).toEqual(['bookings.cancel']);
  });

  it('DENY wins over ALLOW in whatever order they are stored', () => {
    for (const overrides of [
      [allow('reports.read'), deny('reports.read')],
      [deny('reports.read'), allow('reports.read')],
    ]) {
      const effective = resolveEffectivePermissions('OPERATOR_STAFF', [BOOKING_STAFF], overrides);
      expect(effective.permissions.has('reports.read')).toBe(false);
    }
  });

  it('DENY wins over the SUPER_ADMIN wildcard', () => {
    const effective = resolveEffectivePermissions(
      'STAFF',
      [systemRole('SUPER_ADMIN')],
      [deny('settings.update')],
    );
    expect(effective.hasWildcard).toBe(true);
    expect(effective.permissions.has('settings.update')).toBe(false);
    expect(effective.permissions.has('settings.read')).toBe(true);
  });

  it('the wildcard grants every permission in the catalogue', () => {
    const effective = resolveEffectivePermissions('STAFF', [systemRole('SUPER_ADMIN')], []);
    expect([...effective.permissions].sort()).toEqual([...PermissionRegistry.keys()].sort());
  });

  it('a DENY for a permission the user never had changes nothing', () => {
    const effective = resolveEffectivePermissions(
      'OPERATOR_STAFF',
      [BOOKING_STAFF],
      [deny('settlements.read')],
    );
    expect(effective.denied.size).toBe(0);
    expect([...effective.permissions].sort()).toEqual([...BOOKING_STAFF.permissionKeys].sort());
  });

  describe('fail closed', () => {
    it('no roles and no overrides → no permissions', () => {
      const effective = resolveEffectivePermissions('OPERATOR_STAFF', [], []);
      expect(effective.permissions.size).toBe(0);
      expect(effective.roleKeys).toEqual([]);
    });

    it('an unknown permission key grants nothing — from a role or from ALLOW', () => {
      const role: RoleGrant = {
        key: 'CUSTOM',
        userType: 'OPERATOR_STAFF',
        permissionKeys: ['bookings.read', 'bookings.destroy', 'made.up'],
      };
      const effective = resolveEffectivePermissions(
        'OPERATOR_STAFF',
        [role],
        [allow('made.up'), allow('')],
      );
      expect([...effective.permissions]).toEqual(['bookings.read']);
    });

    it('the wildcard cannot be granted by an override', () => {
      const effective = resolveEffectivePermissions(
        'OPERATOR_STAFF',
        [BOOKING_STAFF],
        [allow(ALL_PERMISSIONS_WILDCARD)],
      );
      expect(effective.hasWildcard).toBe(false);
      expect(effective.permissions.has('settings.update')).toBe(false);
    });

    it('a role made for another kind of account contributes nothing', () => {
      // A customer account that somehow references the SUPER_ADMIN role gets nothing from it
      const effective = resolveEffectivePermissions('CUSTOMER', [systemRole('SUPER_ADMIN')], []);
      expect(effective.permissions.size).toBe(0);
      expect(effective.hasWildcard).toBe(false);
      expect(effective.roleKeys).toEqual([]);
    });

    it('ALLOW cannot give a permission the account kind may not hold', () => {
      const customer = resolveEffectivePermissions(
        'CUSTOMER',
        [systemRole('CUSTOMER')],
        [allow('settings.update'), allow('users.read'), allow('bookings.update')],
      );
      expect(customer.permissions.has('settings.update')).toBe(false);
      expect(customer.permissions.has('users.read')).toBe(false);
      expect(customer.permissions.has('bookings.update')).toBe(false);
      expect(customer.permissions.has('bookings.read')).toBe(true);
    });

    it('a role cannot give a permission its account kind may not hold, even if stored', () => {
      const tampered: RoleGrant = {
        key: 'BOOKING_STAFF',
        userType: 'OPERATOR_STAFF',
        permissionKeys: ['bookings.read', 'settings.update', 'users.data-scope.manage'],
      };
      const effective = resolveEffectivePermissions('OPERATOR_STAFF', [tampered], []);
      expect([...effective.permissions]).toEqual(['bookings.read']);
    });

    it('a wildcard role on a non-platform account is limited to what that account may hold', () => {
      const tampered: RoleGrant = {
        key: 'X',
        userType: 'OPERATOR_STAFF',
        permissionKeys: [ALL_PERMISSIONS_WILDCARD],
      };
      const effective = resolveEffectivePermissions('OPERATOR_STAFF', [tampered], []);
      expect(effective.permissions.has('buses.read')).toBe(true);
      expect(effective.permissions.has('settings.update')).toBe(false);
      expect(effective.permissions.has('users.data-scope.manage')).toBe(false);
    });
  });
});
