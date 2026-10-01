import { PERMISSION_CATALOG, type PermissionKey } from '../permissions/permission-catalog';
import {
  definePermissions,
  PERMISSION_KEY_PATTERN,
  type PermissionDefinition,
  PLATFORM_ONLY,
} from '../permissions/permission-definition';
import {
  ALL_PERMISSIONS_WILDCARD,
  PermissionRegistry,
  validatePermissionDefinitions,
} from '../permissions/permission-registry';

describe('permission registry', () => {
  it('declares every permission with a stable key, name, module, action and description', () => {
    const definitions = PermissionRegistry.all();
    expect(definitions.length).toBeGreaterThan(30);
    for (const definition of definitions) {
      expect(definition.key).toMatch(PERMISSION_KEY_PATTERN);
      expect(definition.key).toBe(`${definition.module}.${definition.action}`);
      expect(definition.name.length).toBeGreaterThan(2);
      expect(definition.description.length).toBeGreaterThan(5);
      expect(definition.grantableTo.length).toBeGreaterThan(0);
    }
  });

  it('has unique keys', () => {
    const keys = PermissionRegistry.keys();
    expect(new Set(keys).size).toBe(keys.length);
    expect(keys).toEqual(Object.keys(PERMISSION_CATALOG));
  });

  it.each([
    'users.read',
    'users.create',
    'users.update',
    'users.delete',
    'bookings.read',
    'bookings.create',
    'bookings.update',
    'bookings.cancel',
    'buses.read',
    'trips.cancel',
    'fares.update',
    'reports.read',
    'settlements.read',
    'customers.update',
    'operators.create',
    'partners.update',
    'notifications.manage',
    'settings.update',
    'audit.read',
    'users.roles.assign',
    'users.permissions.manage',
    'users.data-scope.manage',
  ] satisfies PermissionKey[])('contains %s', (key) => {
    expect(PermissionRegistry.has(key)).toBe(true);
    expect(PermissionRegistry.get(key)?.key).toBe(key);
  });

  it.each([
    'bookings.destroy',
    'unknown.read',
    'bookings',
    'BOOKINGS.READ',
    '',
    ALL_PERMISSIONS_WILDCARD,
    undefined,
    null,
    42,
    { key: 'bookings.read' },
  ])('does not know %p (unknown keys grant nothing)', (key) => {
    expect(PermissionRegistry.has(key)).toBe(false);
  });

  it('knows which kinds of account may hold a permission', () => {
    expect(PermissionRegistry.isGrantableTo('settings.update', 'STAFF')).toBe(true);
    expect(PermissionRegistry.isGrantableTo('settings.update', 'OPERATOR_STAFF')).toBe(false);
    expect(PermissionRegistry.isGrantableTo('settings.update', 'CUSTOMER')).toBe(false);
    expect(PermissionRegistry.isGrantableTo('bookings.create', 'CUSTOMER')).toBe(true);
    expect(PermissionRegistry.isGrantableTo('users.data-scope.manage', 'OPERATOR_STAFF')).toBe(
      false,
    );
    expect(PermissionRegistry.isGrantableTo('unknown.read', 'STAFF')).toBe(false);
  });

  it('groups permissions by module', () => {
    const grouped = PermissionRegistry.byModule();
    expect(grouped.bookings?.map((definition) => definition.action)).toEqual([
      'read',
      'create',
      'update',
      'cancel',
    ]);
    expect(grouped['users.permissions']?.map((definition) => definition.action)).toEqual([
      'read',
      'manage',
    ]);
  });

  describe('definePermissions (how a new module adds its permissions)', () => {
    it('builds keys from module and action', () => {
      const group = definePermissions('seat-layouts', {
        read: {
          name: 'View seat layouts',
          description: 'View layouts.',
          grantableTo: PLATFORM_ONLY,
        },
        publish: {
          name: 'Publish seat layouts',
          description: 'Publish a layout version.',
          grantableTo: PLATFORM_ONLY,
          sensitive: true,
        },
      });
      expect(Object.keys(group)).toEqual(['seat-layouts.read', 'seat-layouts.publish']);
      expect(group['seat-layouts.publish']).toEqual({
        key: 'seat-layouts.publish',
        module: 'seat-layouts',
        action: 'publish',
        name: 'Publish seat layouts',
        description: 'Publish a layout version.',
        grantableTo: PLATFORM_ONLY,
        sensitive: true,
      });
      expect(validatePermissionDefinitions(group)).toHaveLength(2);
    });
  });

  describe('validatePermissionDefinitions (start-up check)', () => {
    const valid: PermissionDefinition = {
      key: 'things.read',
      module: 'things',
      action: 'read',
      name: 'View things',
      description: 'View things.',
      grantableTo: ['STAFF'],
    };

    it('accepts a well-formed catalogue', () => {
      expect(validatePermissionDefinitions({ 'things.read': valid })).toEqual([valid]);
    });

    it.each([
      [
        'a malformed key',
        { 'Things.Read': { ...valid, key: 'Things.Read' } },
        'Invalid permission key',
      ],
      [
        'a key without an action',
        { things: { ...valid, key: 'things' } },
        'Invalid permission key',
      ],
      [
        'a key that differs from module.action',
        { 'things.read': { ...valid, action: 'write' } },
        'does not match',
      ],
      ['a mismatched record key', { 'things.write': valid }, 'does not match'],
      [
        'a permission nobody can hold',
        { 'things.read': { ...valid, grantableTo: [] } },
        'not grantable',
      ],
    ])('rejects %s', (_label, definitions, message) => {
      expect(() =>
        validatePermissionDefinitions(definitions as Record<string, PermissionDefinition>),
      ).toThrow(message);
    });
  });
});
