import request from 'supertest';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  signInWithOtp,
  uniquePhone,
} from '../../authentication/tests/auth-e2e.harness';
import { findSystemRole, SYSTEM_ROLE_KEYS } from '../roles/system-roles';
import { type MyPermissions, newId, seedAndSignIn } from './rbac-e2e.harness';

/**
 * Authorization over HTTP against the real application, MongoDB replica set and Redis:
 * permission guard (401 / 403 / 200), role permissions, /me/permissions, catalogues.
 */
describe('Authorization e2e: permission guard, roles, /me/permissions', () => {
  let context: AuthTestContext;
  const operatorA = newId();

  beforeAll(async () => {
    context = await createAuthTestApp();
  }, 60_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const api = () => client(context);

  describe('start-up', () => {
    it('synchronised the twelve system roles into MongoDB', async () => {
      const roles = await context.connection.collection('roles').find().toArray();
      expect(roles.map((role) => role.key as string).sort()).toEqual([...SYSTEM_ROLE_KEYS].sort());
      expect(roles.every((role) => role.isSystemRole === true)).toBe(true);
    });

    it('created no users', async () => {
      // Roles are seeded; accounts never are
      expect(await context.users.countDocuments({ userType: { $ne: 'CUSTOMER' } })).toBe(0);
    });
  });

  describe('401 / 403 / 200', () => {
    it('public endpoints stay reachable without a token', async () => {
      await request(context.server).get('/health/live').expect(200);
      await api()
        .post('/api/v1/auth/login')
        .send({ identifier: 'x@example.test', password: 'wrong' })
        .expect(401);
    });

    it.each([
      '/api/v1/users',
      '/api/v1/me/permissions',
      '/api/v1/permissions',
      '/api/v1/roles',
      '/api/v1/audit-logs',
    ])('unauthenticated GET %s → 401', async (path) => {
      const response = await api().get(path).expect(401);
      expect(errorCodeOf(response)).toBe('UNAUTHENTICATED');
    });

    it('authenticated with the permission → 200', async () => {
      const admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
      await api()
        .get('/api/v1/users')
        .set(...bearer(admin.tokens))
        .expect(200);
      await api()
        .get('/api/v1/permissions')
        .set(...bearer(admin.tokens))
        .expect(200);
      await api()
        .get('/api/v1/audit-logs')
        .set(...bearer(admin.tokens))
        .expect(200);
    });

    it('authenticated without the permission → 403 PERMISSION_DENIED', async () => {
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      for (const path of ['/api/v1/users', '/api/v1/permissions', '/api/v1/audit-logs']) {
        const response = await api()
          .get(path)
          .set(...bearer(staff.tokens))
          .expect(403);
        expect(errorCodeOf(response)).toBe('PERMISSION_DENIED');
      }
    });

    it('a staff account without any role can do nothing that needs a permission', async () => {
      const noRole = await seedAndSignIn(context, { roleKeys: [], userType: 'STAFF' });
      await api()
        .get('/api/v1/users')
        .set(...bearer(noRole.tokens))
        .expect(403);
      const mine = dataOf<MyPermissions>(
        await api()
          .get('/api/v1/me/permissions')
          .set(...bearer(noRole.tokens))
          .expect(200),
      );
      expect(mine.permissions).toEqual([]);
      expect(mine.roles).toEqual([]);
    });

    it('a customer cannot reach administration endpoints', async () => {
      const customer = await signInWithOtp(context, uniquePhone());
      for (const path of ['/api/v1/users', '/api/v1/roles', '/api/v1/audit-logs']) {
        await api()
          .get(path)
          .set(...bearer(customer))
          .expect(403);
      }
    });
  });

  describe('GET /me/permissions', () => {
    it('returns the role permissions and data scope of the caller', async () => {
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const mine = dataOf<MyPermissions>(
        await api()
          .get('/api/v1/me/permissions')
          .set(...bearer(staff.tokens))
          .expect(200),
      );

      expect(mine).toMatchObject({
        userId: staff.id,
        userType: 'OPERATOR_STAFF',
        roles: [{ key: 'BOOKING_STAFF', name: 'Booking staff' }],
        permissionVersion: 1,
        dataScope: { type: 'OWN_OPERATOR', operatorIds: [operatorA.toHexString()] },
        operatorId: operatorA.toHexString(),
        partnerId: null,
      });
      expect(mine.permissions).toEqual(
        [...(findSystemRole('BOOKING_STAFF')?.permissionKeys ?? [])].sort(),
      );
      expect(mine.permissionsByModule.bookings).toEqual(['cancel', 'create', 'read', 'update']);
    });

    it('a customer holds the CUSTOMER role implicitly, scoped to their own records', async () => {
      const customer = await signInWithOtp(context, uniquePhone());
      const mine = dataOf<MyPermissions>(
        await api()
          .get('/api/v1/me/permissions')
          .set(...bearer(customer))
          .expect(200),
      );
      expect(mine.roles).toEqual([{ key: 'CUSTOMER', name: 'Customer' }]);
      expect(mine.dataScope).toEqual({ type: 'OWN_RECORDS', operatorIds: [] });
      expect(mine.permissions).toEqual([
        'bookings.cancel',
        'bookings.create',
        'bookings.read',
        'fares.read',
        'trips.read',
      ]);
    });

    it('a super administrator holds every permission', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const mine = dataOf<MyPermissions>(
        await api()
          .get('/api/v1/me/permissions')
          .set(...bearer(superAdmin.tokens))
          .expect(200),
      );
      expect(mine.permissions).toEqual(
        expect.arrayContaining(['settings.update', 'users.delete', 'audit.read']),
      );
      expect(mine.dataScope.type).toBe('ALL');
    });

    it('exposes only authorization facts — no credentials, tokens or MFA data', async () => {
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const response = await api()
        .get('/api/v1/me/permissions')
        .set(...bearer(staff.tokens))
        .expect(200);
      const body = JSON.stringify(response.body);
      expect(body).not.toMatch(/password|argon2|refreshToken|accessToken|secret|recovery|mfa/i);
      expect(body).not.toContain(staff.email);
    });

    it('is always about the caller: another user cannot be requested', async () => {
      const victim = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
      const staff = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });

      // Parameters naming someone else are ignored
      const mine = dataOf<MyPermissions>(
        await api()
          .get(`/api/v1/me/permissions?userId=${victim.id}`)
          .set(...bearer(staff.tokens))
          .expect(200),
      );
      expect(mine.userId).toBe(staff.id);
      // The administration endpoint needs a permission the caller does not have
      const response = await api()
        .get(`/api/v1/users/${victim.id}/permissions`)
        .set(...bearer(staff.tokens))
        .expect(403);
      expect(errorCodeOf(response)).toBe('PERMISSION_DENIED');
    });
  });

  describe('catalogues', () => {
    it('lists the permission catalogue with metadata', async () => {
      const admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
      const permissions = dataOf<
        Array<{ key: string; module: string; name: string; description: string }>
      >(
        await api()
          .get('/api/v1/permissions')
          .set(...bearer(admin.tokens))
          .expect(200),
      );
      expect(permissions).toContainEqual(
        expect.objectContaining({
          key: 'bookings.cancel',
          module: 'bookings',
          action: 'cancel',
          name: 'Cancel bookings',
        }),
      );
    });

    it('shows a caller only the roles they could assign', async () => {
      const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const operatorAdmin = await seedAndSignIn(context, {
        roleKeys: ['OPERATOR_ADMIN'],
        operatorId: operatorA,
      });
      const keysFor = async (tokens: { accessToken: string }) =>
        dataOf<Array<{ key: string }>>(
          await api()
            .get('/api/v1/roles')
            .set(...bearer(tokens))
            .expect(200),
        ).map((role) => role.key);

      expect((await keysFor(superAdmin.tokens)).sort()).toEqual([...SYSTEM_ROLE_KEYS].sort());
      const visible = await keysFor(operatorAdmin.tokens);
      expect(visible).toEqual(
        expect.arrayContaining(['OPERATOR_ADMIN', 'BOOKING_STAFF', 'DRIVER']),
      );
      expect(visible).not.toContain('SUPER_ADMIN');
      expect(visible).not.toContain('ADMIN');
    });
  });

  describe('OpenAPI', () => {
    it('documents the authorization endpoints with their required permissions', async () => {
      const docs = await createAuthTestApp({ API_DOCS_ENABLED: 'true' });
      try {
        const document = (await request(docs.server).get('/api/docs-json').expect(200)).body as {
          paths: Record<
            string,
            Record<
              string,
              { description?: string; security?: unknown[]; responses: Record<string, unknown> }
            >
          >;
        };
        expect(Object.keys(document.paths)).toEqual(
          expect.arrayContaining([
            '/api/v1/me/permissions',
            '/api/v1/permissions',
            '/api/v1/roles',
            '/api/v1/users',
            '/api/v1/users/{userId}/permissions',
            '/api/v1/users/{userId}/roles',
            '/api/v1/users/{userId}/permissions/{permissionKey}',
            '/api/v1/users/{userId}/data-scope',
            '/api/v1/audit-logs',
          ]),
        );
        const assign = document.paths['/api/v1/users/{userId}/roles']?.put;
        expect(assign?.description).toContain('users.roles.assign');
        expect(assign?.security).toEqual([{ 'access-token': [] }]);
        expect(Object.keys(assign?.responses ?? {})).toEqual(
          expect.arrayContaining(['401', '403']),
        );
      } finally {
        await docs.app.close();
      }
    });
  });
});
