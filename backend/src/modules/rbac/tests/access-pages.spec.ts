import {
  ACCESS_PAGES,
  findPage,
  inferLevel,
  keysForPageLevel,
  managedKeys,
  pagesFor,
  permissionKeysFromLevels,
  audienceOfUserType,
  type AccessLevel,
} from '../permissions/access-pages';
import { PermissionRegistry } from '../permissions/permission-registry';

const trips = findPage('ADMIN', 'trips')!;

describe('access pages', () => {
  it('has the 38 admin pages and the 20 operator pages of the demos, with unique ids', () => {
    expect(pagesFor('ADMIN')).toHaveLength(38);
    expect(pagesFor('OPERATOR')).toHaveLength(20);
    for (const audience of ['ADMIN', 'OPERATOR'] as const) {
      const ids = pagesFor(audience).map((page) => page.id);
      expect(new Set(ids).size).toBe(ids.length);
    }
  });

  it('never gives the roles module to a page: only the Super Admin edits the matrix', () => {
    expect(ACCESS_PAGES.some((page) => page.modules.some((m) => m === 'roles'))).toBe(false);
    expect(managedKeys('ADMIN').has('roles.manage')).toBe(false);
  });

  it('maps the audiences to account kinds', () => {
    expect(audienceOfUserType('STAFF')).toBe('ADMIN');
    expect(audienceOfUserType('OPERATOR_STAFF')).toBe('OPERATOR');
    expect(audienceOfUserType('CUSTOMER')).toBeUndefined();
  });
});

describe('keysForPageLevel', () => {
  it('None grants nothing', () => {
    expect(keysForPageLevel(trips, 'NONE')).toEqual([]);
  });

  it('View grants only reading', () => {
    const keys = keysForPageLevel(trips, 'VIEW');
    expect(keys).toContain('trips.read');
    expect(keys.every((key) => key.endsWith('.read'))).toBe(true);
  });

  it('Edit grants changes but not deletion or sensitive actions; Edit and delete grants all', () => {
    const edit = keysForPageLevel(trips, 'EDIT');
    const full = keysForPageLevel(trips, 'FULL');
    expect(edit).toEqual(expect.arrayContaining(['trips.read', 'trips.create', 'trips.update']));
    expect(edit.some((key) => key.endsWith('.delete'))).toBe(false);
    for (const key of edit) expect(full).toContain(key);
    const sensitive = PermissionRegistry.all().filter(
      (d) => d.module === 'trips' && d.sensitive === true,
    );
    for (const definition of sensitive) {
      expect(edit).not.toContain(definition.key);
      expect(full).toContain(definition.key);
    }
  });

  it('grants nothing for a module that has no permissions yet (fail closed)', () => {
    const payments = findPage('ADMIN', 'payments')!;
    expect(keysForPageLevel(payments, 'FULL')).toEqual([]);
  });

  it('every granted key exists in the permission registry', () => {
    for (const page of ACCESS_PAGES) {
      for (const level of ['VIEW', 'EDIT', 'FULL'] as const) {
        for (const key of keysForPageLevel(page, level))
          expect(PermissionRegistry.has(key)).toBe(true);
      }
    }
  });
});

describe('permissionKeysFromLevels', () => {
  it('keeps keys the matrix does not own and replaces the ones it owns', () => {
    const keys = permissionKeysFromLevels('ADMIN', { trips: 'VIEW' }, [
      'users.permissions.manage',
      'trips.create',
      'trips.read',
    ]);
    expect(keys).toContain('users.permissions.manage');
    expect(keys).toContain('trips.read');
    expect(keys).not.toContain('trips.create');
  });

  it('is stable and sorted', () => {
    const levels: Record<string, AccessLevel> = { trips: 'EDIT', buses: 'FULL' };
    const a = permissionKeysFromLevels('ADMIN', levels, []);
    expect(a).toEqual([...a].sort());
    expect(permissionKeysFromLevels('ADMIN', levels, [])).toEqual(a);
  });

  it('a page left out of the levels grants nothing', () => {
    expect(permissionKeysFromLevels('ADMIN', {}, ['trips.read'])).toEqual([]);
  });
});

describe('inferLevel', () => {
  it('reads each level back from the keys it produces', () => {
    for (const level of ['NONE', 'VIEW', 'EDIT', 'FULL'] as const) {
      const keys = new Set(keysForPageLevel(trips, level));
      expect(inferLevel(trips, keys, false)).toEqual({ level, exact: true });
    }
  });

  it('the wildcard is full access everywhere', () => {
    expect(inferLevel(trips, new Set(), true)).toEqual({ level: 'FULL', exact: true });
  });

  it('flags keys that match no level exactly', () => {
    const keys = new Set([...keysForPageLevel(trips, 'VIEW'), 'trips.cancel']);
    const result = inferLevel(trips, keys, false);
    expect(result.exact).toBe(false);
    expect(result.level).toBe('VIEW');
  });
});
