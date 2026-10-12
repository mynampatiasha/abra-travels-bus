import { Types } from 'mongoose';
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
  type DirectoryUser,
  newId,
  seedAndSignIn,
  type SeededUser,
  seedUser,
  type UserAuthorization,
} from './rbac-e2e.harness';

/**
 * Tenant isolation over HTTP against the real application, MongoDB replica set and Redis:
 * an operator or partner user never reads or changes another tenant, whatever they send.
 */
describe('Authorization e2e: operator and partner isolation', () => {
  let context: AuthTestContext;
  const operatorA = newId();
  const operatorB = newId();
  const partnerA = newId();
  const partnerB = newId();
  let superAdmin: SeededUser & { tokens: Tokens };
  let adminA: SeededUser & { tokens: Tokens };
  let adminB: SeededUser & { tokens: Tokens };
  let staffA: SeededUser;
  let staffB: SeededUser;

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    adminA = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: operatorA,
    });
    adminB = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: operatorB,
    });
    staffA = await seedUser(context, { roleKeys: ['BOOKING_STAFF'], operatorId: operatorA });
    staffB = await seedUser(context, { roleKeys: ['BOOKING_STAFF'], operatorId: operatorB });
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const api = () => client(context);

  async function listUsers(tokens: Tokens, query = ''): Promise<DirectoryUser[]> {
    return dataOf<DirectoryUser[]>(
      await api()
        .get(`/api/v1/users${query}`)
        .set(...bearer(tokens))
        .expect(200),
    );
  }

  describe('operator isolation', () => {
    it('customer directory filters methods and search without exposing credentials or widening scope', async () => {
      const customer = await seedUser(context, { roleKeys: ['CUSTOMER'] });
      await context.users.updateOne(
        { _id: new Types.ObjectId(customer.id) },
        {
          $set: {
            name: 'Customer [sample]',
            googleFirebaseUid: 'directory-google-test',
            appleFirebaseUid: 'directory-apple-test',
            phoneVerifiedAt: new Date(),
            lastLoginAt: new Date(),
          },
        },
      );
      const response = await api()
        .get('/api/v1/users')
        .query({ userType: 'CUSTOMER', search: '[sample]', loginMethod: 'google' })
        .set(...bearer(superAdmin.tokens))
        .expect(200);
      const users =
        dataOf<Array<DirectoryUser & { loginMethods: string[]; lastLoginAt: string }>>(response);
      expect(users).toHaveLength(1);
      expect(users[0]).toMatchObject({
        id: customer.id,
        loginMethods: ['Google', 'Apple', 'WhatsApp OTP', 'Email / phone and password'],
      });
      expect(users[0]?.lastLoginAt).toEqual(expect.any(String));
      expect(JSON.stringify(response.body)).not.toMatch(
        /passwordHash|FirebaseUid|secretEncrypted|recoveryCodeHashes/,
      );
      // The current client KYC gate denies this unapproved operator before the directory runs.
      await api()
        .get('/api/v1/users?userType=CUSTOMER&search=sample&loginMethod=google')
        .set(...bearer(adminA.tokens))
        .expect(403);
      for (const loginMethod of ['apple', 'whatsapp', 'password']) {
        const filtered = await api()
          .get('/api/v1/users')
          .query({ userType: 'CUSTOMER', search: '[sample]', loginMethod })
          .set(...bearer(superAdmin.tokens))
          .expect(200);
        expect(dataOf<DirectoryUser[]>(filtered).map((u) => u.id)).toEqual([customer.id]);
      }
      await api()
        .get('/api/v1/users?loginMethod=unknown')
        .set(...bearer(superAdmin.tokens))
        .expect(400);
      await context.users.deleteOne({ _id: new Types.ObjectId(customer.id) });
    });
    it('an operator administrator lists only users of their own operator', async () => {
      const usersOfA = await listUsers(adminA.tokens, '?pageSize=100');
      expect(usersOfA.map((user) => user.id).sort()).toEqual([adminA.id, staffA.id].sort());
      expect(usersOfA.every((user) => user.operatorId === operatorA.toHexString())).toBe(true);

      const usersOfB = await listUsers(adminB.tokens, '?pageSize=100');
      expect(usersOfB.map((user) => user.id).sort()).toEqual([adminB.id, staffB.id].sort());
    });

    it('query filters cannot escape the data scope', async () => {
      // Asking for Operator B by filter returns nothing, not Operator B's users
      expect(await listUsers(adminA.tokens, `?operatorId=${operatorB.toHexString()}`)).toEqual([]);
      // Filters that match everything still return only Operator A
      const all = await listUsers(
        adminA.tokens,
        '?userType=OPERATOR_STAFF&status=ACTIVE&pageSize=100',
      );
      expect(all.every((user) => user.operatorId === operatorA.toHexString())).toBe(true);
      // Operator injection through the filter is rejected by validation
      await api()
        .get('/api/v1/users?operatorId[$ne]=x')
        .set(...bearer(adminA.tokens))
        .expect(400);
      await api()
        .get('/api/v1/users?scope=ALL')
        .set(...bearer(adminA.tokens))
        .expect(400);
    });

    it('a user of another operator looks like it does not exist (404, not 403)', async () => {
      const read = await api()
        .get(`/api/v1/users/${staffB.id}/permissions`)
        .set(...bearer(adminA.tokens))
        .expect(404);
      expect(errorCodeOf(read)).toBe('RESOURCE_NOT_FOUND');
      // Exactly the same answer as for an id that does not exist at all
      const missing = await api()
        .get(`/api/v1/users/${newId().toHexString()}/permissions`)
        .set(...bearer(adminA.tokens))
        .expect(404);
      expect(missing.body).toMatchObject({
        error: {
          code: 'RESOURCE_NOT_FOUND',
          message: (read.body as { error: { message: string } }).error.message,
        },
      });
    });

    it('an operator administrator cannot change users of another operator', async () => {
      const attempts = [
        () =>
          api()
            .put(`/api/v1/users/${staffB.id}/roles`)
            .send({ roleKeys: ['OPERATOR_MANAGER'] }),
        () =>
          api()
            .put(`/api/v1/users/${staffB.id}/permissions/reports.read`)
            .send({ effect: 'ALLOW', reason: 'cross-operator' }),
        () =>
          api()
            .put(`/api/v1/users/${staffB.id}/permissions/bookings.read`)
            .send({ effect: 'DENY', reason: 'cross-operator' }),
        () => api().delete(`/api/v1/users/${staffB.id}/permissions/bookings.read`).send({}),
      ];
      for (const attempt of attempts) {
        expect(
          errorCodeOf(
            await attempt()
              .set(...bearer(adminA.tokens))
              .expect(404),
          ),
        ).toBe('RESOURCE_NOT_FOUND');
      }
      const untouched = dataOf<UserAuthorization>(
        await api()
          .get(`/api/v1/users/${staffB.id}/permissions`)
          .set(...bearer(superAdmin.tokens))
          .expect(200),
      );
      expect(untouched).toMatchObject({
        permissionVersion: 1,
        overrides: [],
        roles: [{ key: 'BOOKING_STAFF' }],
      });
    });

    it('an operator administrator manages their own staff', async () => {
      const target = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const changed = dataOf<UserAuthorization>(
        await api()
          .put(`/api/v1/users/${target.id}/roles`)
          .set(...bearer(adminA.tokens))
          .send({ roleKeys: ['OPERATOR_MANAGER'], reason: 'Promoted' })
          .expect(200),
      );
      expect(changed.roles).toEqual([expect.objectContaining({ key: 'OPERATOR_MANAGER' })]);
      expect(changed.dataScope).toEqual({
        type: 'OWN_OPERATOR',
        operatorIds: [operatorA.toHexString()],
      });
    });

    it('platform staff limited to selected operators see only those operators', async () => {
      const regional = await seedAndSignIn(context, {
        roleKeys: ['ADMIN'],
        dataScope: { type: 'SELECTED_OPERATORS', operatorIds: [operatorA] },
      });
      const visible = await listUsers(regional.tokens, '?pageSize=100');
      expect(visible.length).toBeGreaterThan(0);
      expect(visible.every((user) => user.operatorId === operatorA.toHexString())).toBe(true);
      await api()
        .get(`/api/v1/users/${staffB.id}/permissions`)
        .set(...bearer(regional.tokens))
        .expect(404);
    });
  });

  describe('partner isolation', () => {
    it('a partner user reaches only users of their own partner', async () => {
      const partnerUserA = await seedUser(context, { roleKeys: ['PARTNER'], partnerId: partnerA });
      const colleagueA = await seedUser(context, { roleKeys: ['PARTNER'], partnerId: partnerA });
      const partnerUserB = await seedUser(context, { roleKeys: ['PARTNER'], partnerId: partnerB });

      // The PARTNER role has no user directory access until it is granted explicitly
      await api()
        .put(`/api/v1/users/${partnerUserA.id}/permissions/users.read`)
        .set(...bearer(superAdmin.tokens))
        .send({ effect: 'ALLOW', reason: 'Partner team lead' })
        .expect(200);
      const tokens = await (async () => {
        const response = await api()
          .post('/api/v1/auth/login')
          .send({ identifier: partnerUserA.email, password: partnerUserA.password })
          .expect(200);
        return dataOf<Tokens>(response);
      })();

      const visible = await listUsers(tokens, '?pageSize=100');
      expect(visible.map((user) => user.id).sort()).toEqual(
        [partnerUserA.id, colleagueA.id].sort(),
      );
      expect(visible.every((user) => user.partnerId === partnerA.toHexString())).toBe(true);
      // Naming Partner B in the filter returns nothing
      expect(await listUsers(tokens, `?partnerId=${partnerB.toHexString()}`)).toEqual([]);
      expect(visible.map((user) => user.id)).not.toContain(partnerUserB.id);
    });
  });
});
