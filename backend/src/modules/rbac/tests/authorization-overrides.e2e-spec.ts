import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
} from '../../authentication/tests/auth-e2e.harness';
import {
  type MyPermissions,
  newId,
  refresh,
  seedAndSignIn,
  type UserAuthorization,
} from './rbac-e2e.harness';

/**
 * User-level ALLOW / DENY overrides over HTTP against the real application, MongoDB replica
 * set and Redis.
 */
describe('Authorization e2e: user-level overrides', () => {
  let context: AuthTestContext;
  const operatorA = newId();

  beforeAll(async () => {
    context = await createAuthTestApp();
  }, 60_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const api = () => client(context);

  describe('user-level overrides', () => {
    it('DENY removes a permission the role grants — enforced on the next request', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const operatorAdmin = await seedAndSignIn(context, {
        roleKeys: ['OPERATOR_ADMIN'],
        operatorId: operatorA,
      });
      await api()
        .get('/api/v1/users')
        .set(...bearer(operatorAdmin.tokens))
        .expect(200);

      const after = dataOf<UserAuthorization>(
        await api()
          .put(`/api/v1/users/${operatorAdmin.id}/permissions/users.read`)
          .set(...bearer(superAdmin.tokens))
          .send({ effect: 'DENY', reason: 'User directory access withdrawn' })
          .expect(200),
      );
      expect(after.deniedPermissions).toEqual(['users.read']);
      expect(after.effectivePermissions.map((entry) => entry.key)).not.toContain('users.read');
      expect(after.permissionVersion).toBe(2);

      // The access token issued before the change is refused; the client refreshes
      const stale = await api()
        .get('/api/v1/users')
        .set(...bearer(operatorAdmin.tokens))
        .expect(401);
      expect(errorCodeOf(stale)).toBe('PERMISSIONS_CHANGED');
      const fresh = await refresh(context, operatorAdmin.tokens);

      const denied = await api()
        .get('/api/v1/users')
        .set(...bearer(fresh))
        .expect(403);
      expect(errorCodeOf(denied)).toBe('PERMISSION_DENIED');
      const mine = dataOf<MyPermissions>(
        await api()
          .get('/api/v1/me/permissions')
          .set(...bearer(fresh))
          .expect(200),
      );
      expect(mine.permissions).not.toContain('users.read');
      expect(mine.permissions).toContain('buses.read'); // the rest of the role is untouched
      expect(mine.permissionVersion).toBe(2);
    });

    it('ALLOW grants a permission the role does not have; removing it takes it away again', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      await api()
        .get('/api/v1/users')
        .set(...bearer(staff.tokens))
        .expect(403);

      const granted = dataOf<UserAuthorization>(
        await api()
          .put(`/api/v1/users/${staff.id}/permissions/users.read`)
          .set(...bearer(superAdmin.tokens))
          .send({ effect: 'ALLOW', reason: 'Front desk needs the staff list' })
          .expect(200),
      );
      expect(granted.effectivePermissions).toContainEqual({
        key: 'users.read',
        source: 'ALLOW_OVERRIDE',
      });
      expect(granted.effectivePermissions).toContainEqual({ key: 'bookings.read', source: 'ROLE' });
      expect(granted.overrides).toEqual([
        expect.objectContaining({
          permissionKey: 'users.read',
          effect: 'ALLOW',
          reason: 'Front desk needs the staff list',
          grantedBy: superAdmin.id,
        }),
      ]);

      let tokens = await refresh(context, staff.tokens);
      await api()
        .get('/api/v1/users')
        .set(...bearer(tokens))
        .expect(200);

      const removed = dataOf<UserAuthorization>(
        await api()
          .delete(`/api/v1/users/${staff.id}/permissions/users.read`)
          .set(...bearer(superAdmin.tokens))
          .send({ reason: 'No longer needed' })
          .expect(200),
      );
      expect(removed.overrides).toEqual([]);
      tokens = await refresh(context, tokens);
      await api()
        .get('/api/v1/users')
        .set(...bearer(tokens))
        .expect(403);
    });

    it('changing an override replaces it: ALLOW then DENY leaves the permission denied', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const path = `/api/v1/users/${staff.id}/permissions/bookings.cancel`;

      await api()
        .put(path)
        .set(...bearer(superAdmin.tokens))
        .send({ effect: 'ALLOW', reason: 'explicit allow' })
        .expect(200);
      const denied = dataOf<UserAuthorization>(
        await api()
          .put(path)
          .set(...bearer(superAdmin.tokens))
          .send({ effect: 'DENY', reason: 'now denied' })
          .expect(200),
      );
      expect(denied.overrides).toHaveLength(1);
      expect(denied.overrides[0]).toMatchObject({ effect: 'DENY' });
      expect(denied.deniedPermissions).toEqual(['bookings.cancel']);
      expect(
        await context.connection
          .collection('permission_overrides')
          .countDocuments({ permissionKey: 'bookings.cancel' }),
      ).toBeGreaterThanOrEqual(1);
    });

    it('rejects an unknown permission and one the account kind may not hold', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const set = (key: string, body: object) =>
        api()
          .put(`/api/v1/users/${staff.id}/permissions/${key}`)
          .set(...bearer(superAdmin.tokens))
          .send(body);

      expect(
        errorCodeOf(await set('bookings.destroy', { effect: 'ALLOW', reason: 'typo' }).expect(400)),
      ).toBe('VALIDATION_FAILED');
      // Platform-only permission cannot be given to operator staff, even by a super administrator
      expect(
        errorCodeOf(
          await set('settings.update', { effect: 'ALLOW', reason: 'not allowed' }).expect(400),
        ),
      ).toBe('VALIDATION_FAILED');
      // The wildcard is not a permission key
      await set('*', { effect: 'ALLOW', reason: 'wildcard' }).expect(400);
      // A reason is mandatory, and client-supplied extra fields are refused
      await set('reports.read', { effect: 'ALLOW' }).expect(400);
      await set('reports.read', {
        effect: 'ALLOW',
        reason: 'ok reason',
        grantedBy: staff.id,
      }).expect(400);
      await set('reports.read', { effect: 'MAYBE', reason: 'ok reason' }).expect(400);

      const unchanged = dataOf<UserAuthorization>(
        await api()
          .get(`/api/v1/users/${staff.id}/permissions`)
          .set(...bearer(superAdmin.tokens))
          .expect(200),
      );
      expect(unchanged.overrides).toEqual([]);
      expect(unchanged.permissionVersion).toBe(1);
    });

    it('removing an override that does not exist → 404', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const response = await api()
        .delete(`/api/v1/users/${staff.id}/permissions/reports.read`)
        .set(...bearer(superAdmin.tokens))
        .send({})
        .expect(404);
      expect(errorCodeOf(response)).toBe('RESOURCE_NOT_FOUND');
    });
  });
});
