import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import {
  newId,
  refresh,
  seedAndSignIn,
  type SeededUser,
  seedUser,
  type UserAuthorization,
} from './rbac-e2e.harness';

/**
 * Self-escalation and privilege escalation through the administration endpoints, and how
 * fast a change takes effect — over HTTP against the real application, MongoDB and Redis.
 */
describe('Authorization e2e: privilege-escalation prevention', () => {
  let context: AuthTestContext;
  const operatorA = newId();
  const operatorB = newId();
  let superAdmin: SeededUser & { tokens: Tokens };
  let adminA: SeededUser & { tokens: Tokens };
  let staffA: SeededUser;

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    adminA = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: operatorA,
    });
    staffA = await seedUser(context, { roleKeys: ['BOOKING_STAFF'], operatorId: operatorA });
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const api = () => client(context);

  describe('self-escalation and privilege escalation', () => {
    it('nobody can change their own roles, overrides or scope — not even a super administrator', async () => {
      for (const actor of [adminA, superAdmin]) {
        const attempts = [
          () => api().put(`/api/v1/users/${actor.id}/roles`).send({ roleKeys: [] }),
          () =>
            api()
              .put(`/api/v1/users/${actor.id}/permissions/settlements.read`)
              .send({ effect: 'ALLOW', reason: 'for myself' }),
          () => api().delete(`/api/v1/users/${actor.id}/permissions/settlements.read`).send({}),
        ];
        for (const attempt of attempts) {
          expect(
            errorCodeOf(
              await attempt()
                .set(...bearer(actor.tokens))
                .expect(403),
            ),
          ).toBe('PERMISSION_DENIED');
        }
      }
      expect(
        errorCodeOf(
          await api()
            .put(`/api/v1/users/${superAdmin.id}/data-scope`)
            .set(...bearer(superAdmin.tokens))
            .send({ type: 'ALL', operatorIds: [], reason: 'for myself' })
            .expect(403),
        ),
      ).toBe('PERMISSION_DENIED');
    });

    it('a user without the administration permissions is refused', async () => {
      const staffTokens = dataOf<Tokens>(
        await api()
          .post('/api/v1/auth/login')
          .send({ identifier: staffA.email, password: staffA.password })
          .expect(200),
      );
      const colleague = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const attempts = [
        () =>
          api()
            .put(`/api/v1/users/${colleague.id}/roles`)
            .send({ roleKeys: ['OPERATOR_ADMIN'] }),
        () =>
          api()
            .put(`/api/v1/users/${colleague.id}/permissions/reports.read`)
            .send({ effect: 'ALLOW', reason: 'no right' }),
        () =>
          api()
            .put(`/api/v1/users/${colleague.id}/data-scope`)
            .send({
              type: 'OWN_OPERATOR',
              operatorIds: [operatorA.toHexString()],
              reason: 'no right',
            }),
        () => api().get(`/api/v1/users/${colleague.id}/permissions`),
      ];
      for (const attempt of attempts) {
        expect(
          errorCodeOf(
            await attempt()
              .set(...bearer(staffTokens))
              .expect(403),
          ),
        ).toBe('PERMISSION_DENIED');
      }
    });

    it('roles and scope sent by the client in other requests are ignored or refused', async () => {
      // Sign-in and profile endpoints accept no role, permission or scope fields
      await api()
        .post('/api/v1/auth/login')
        .send({ identifier: staffA.email, password: staffA.password, roleKeys: ['SUPER_ADMIN'] })
        .expect(400);
      const tokens = dataOf<Tokens>(
        await api()
          .post('/api/v1/auth/login')
          .send({ identifier: staffA.email, password: staffA.password })
          .expect(200),
      );
      // Headers claiming a role change nothing
      await api()
        .get('/api/v1/users')
        .set(...bearer(tokens))
        .set('X-Role', 'SUPER_ADMIN')
        .set('X-Permissions', 'users.read')
        .expect(403);
    });

    it('an operator administrator cannot hand out platform roles', async () => {
      const target = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      for (const roleKey of ['ADMIN', 'SUPER_ADMIN', 'SUPPORT']) {
        const response = await api()
          .put(`/api/v1/users/${target.id}/roles`)
          .set(...bearer(adminA.tokens))
          .send({ roleKeys: [roleKey] });
        expect([400, 403]).toContain(response.status);
      }
      await api()
        .put(`/api/v1/users/${target.id}/roles`)
        .set(...bearer(adminA.tokens))
        .send({ roleKeys: ['NOT_A_ROLE'] })
        .expect(400);
    });

    it('an administrator cannot grant a permission they do not hold', async () => {
      const manager = await seedUser(context, {
        roleKeys: ['OPERATOR_MANAGER'],
        operatorId: operatorA,
      });
      const target = await seedUser(context, {
        roleKeys: ['OPERATIONS_STAFF'],
        operatorId: operatorA,
      });
      // The manager is allowed to manage overrides, but holds no settlements.read
      await api()
        .put(`/api/v1/users/${manager.id}/permissions/users.permissions.manage`)
        .set(...bearer(superAdmin.tokens))
        .send({ effect: 'ALLOW', reason: 'Delegated override management' })
        .expect(200);
      const managerTokens = dataOf<Tokens>(
        await api()
          .post('/api/v1/auth/login')
          .send({ identifier: manager.email, password: manager.password })
          .expect(200),
      );

      const escalation = await api()
        .put(`/api/v1/users/${target.id}/permissions/settlements.read`)
        .set(...bearer(managerTokens))
        .send({ effect: 'ALLOW', reason: 'not mine to give' })
        .expect(403);
      expect(errorCodeOf(escalation)).toBe('PERMISSION_DENIED');
      // What the manager does hold can be passed on
      await api()
        .put(`/api/v1/users/${target.id}/permissions/reports.read`)
        .set(...bearer(managerTokens))
        .send({ effect: 'ALLOW', reason: 'needs reports' })
        .expect(200);
      // And the manager cannot touch someone with more access (the operator administrator)
      await api()
        .put(`/api/v1/users/${adminA.id}/permissions/bookings.read`)
        .set(...bearer(managerTokens))
        .send({ effect: 'DENY', reason: 'attack upwards' })
        .expect(403);
    });

    it('only a super administrator can create or change a super administrator', async () => {
      const admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
      const staff = await seedUser(context, { roleKeys: ['SUPPORT'] });

      expect(
        errorCodeOf(
          await api()
            .put(`/api/v1/users/${staff.id}/roles`)
            .set(...bearer(admin.tokens))
            .send({ roleKeys: ['SUPER_ADMIN'] })
            .expect(403),
        ),
      ).toBe('PERMISSION_DENIED');
      expect(
        errorCodeOf(
          await api()
            .put(`/api/v1/users/${superAdmin.id}/permissions/settings.update`)
            .set(...bearer(admin.tokens))
            .send({ effect: 'DENY', reason: 'attack upwards' })
            .expect(403),
        ),
      ).toBe('PERMISSION_DENIED');
      // ADMIN lacks settings.update, so it cannot grant it either
      await api()
        .put(`/api/v1/users/${staff.id}/permissions/settings.update`)
        .set(...bearer(admin.tokens))
        .send({ effect: 'ALLOW', reason: 'not mine to give' })
        .expect(403);

      await api()
        .put(`/api/v1/users/${staff.id}/roles`)
        .set(...bearer(superAdmin.tokens))
        .send({ roleKeys: ['SUPER_ADMIN'], reason: 'New platform owner' })
        .expect(200);
    });

    it('data scope cannot be widened beyond what suits the account or the caller', async () => {
      const target = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const scope = (tokens: Tokens, userId: string, body: object) =>
        api()
          .put(`/api/v1/users/${userId}/data-scope`)
          .set(...bearer(tokens))
          .send(body);

      // Operator administrators do not hold users.data-scope.manage
      await scope(adminA.tokens, target.id, {
        type: 'SELECTED_OPERATORS',
        operatorIds: [operatorA.toHexString(), operatorB.toHexString()],
        reason: 'grab B',
      }).expect(403);
      // Operator staff can never be given platform-wide reach
      await scope(superAdmin.tokens, target.id, {
        type: 'ALL',
        operatorIds: [],
        reason: 'too wide',
      }).expect(400);
      // OWN_OPERATOR must be the user's own operator
      await scope(superAdmin.tokens, target.id, {
        type: 'OWN_OPERATOR',
        operatorIds: [operatorB.toHexString()],
        reason: 'wrong operator',
      }).expect(400);

      const widened = dataOf<UserAuthorization>(
        await scope(superAdmin.tokens, target.id, {
          type: 'SELECTED_OPERATORS',
          operatorIds: [operatorA.toHexString(), operatorB.toHexString()],
          reason: 'Covers both depots',
        }).expect(200),
      );
      expect(widened.dataScope).toEqual({
        type: 'SELECTED_OPERATORS',
        operatorIds: [operatorA.toHexString(), operatorB.toHexString()],
      });
    });
  });

  describe('changes take effect immediately', () => {
    it('a role change invalidates the old access token and the new one carries the new access', async () => {
      const user = await seedAndSignIn(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      await api()
        .get('/api/v1/users')
        .set(...bearer(user.tokens))
        .expect(403);

      await api()
        .put(`/api/v1/users/${user.id}/roles`)
        .set(...bearer(superAdmin.tokens))
        .send({ roleKeys: ['OPERATOR_ADMIN'] })
        .expect(200);
      expect(
        errorCodeOf(
          await api()
            .get('/api/v1/users')
            .set(...bearer(user.tokens))
            .expect(401),
        ),
      ).toBe('PERMISSIONS_CHANGED');

      const fresh = await refresh(context, user.tokens);
      await api()
        .get('/api/v1/users')
        .set(...bearer(fresh))
        .expect(200);

      // Removing every role removes every permission
      await api()
        .put(`/api/v1/users/${user.id}/roles`)
        .set(...bearer(superAdmin.tokens))
        .send({ roleKeys: [] })
        .expect(200);
      const stripped = await refresh(context, fresh);
      await api()
        .get('/api/v1/users')
        .set(...bearer(stripped))
        .expect(403);
    });

    it('a signed-out or deactivated administrator can no longer change anything', async () => {
      const admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
      const target = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      await context.users.updateOne({ _id: admin.id }, { $set: { status: 'SUSPENDED' } });
      await api()
        .put(`/api/v1/users/${target.id}/roles`)
        .set(...bearer(admin.tokens))
        .send({ roleKeys: ['OPERATOR_MANAGER'] })
        .expect(401);
    });
  });
});
