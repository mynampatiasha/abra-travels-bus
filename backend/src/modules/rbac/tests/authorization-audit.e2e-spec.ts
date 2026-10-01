import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import {
  type AuditEntry,
  newId,
  seedAndSignIn,
  type SeededUser,
  seedUser,
} from './rbac-e2e.harness';

/**
 * The audit trail of authorization changes, over HTTP against the real application, MongoDB
 * replica set and Redis.
 */
describe('Authorization e2e: audit trail', () => {
  let context: AuthTestContext;
  const operatorA = newId();
  const operatorB = newId();
  let superAdmin: SeededUser & { tokens: Tokens };
  let adminA: SeededUser & { tokens: Tokens };
  let adminB: SeededUser & { tokens: Tokens };

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
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const api = () => client(context);

  async function auditEntries(tokens: Tokens, query = ''): Promise<AuditEntry[]> {
    return dataOf<AuditEntry[]>(
      await api()
        .get(`/api/v1/audit-logs${query}`)
        .set(...bearer(tokens))
        .expect(200),
    );
  }

  describe('audit trail', () => {
    it('records role, override and scope changes with actor, before, after, reason and request data', async () => {
      const target = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const request = async (
        method: 'put' | 'delete',
        path: string,
        body: object,
        requestId: string,
      ): Promise<void> => {
        const call = method === 'put' ? api().put(path) : api().delete(path);
        await call
          .set(...bearer(superAdmin.tokens))
          .set('X-Forwarded-For', '198.51.100.77')
          .set('X-Request-Id', requestId)
          .set('User-Agent', 'AbraAdminApp/1.0')
          .send(body)
          .expect(200);
      };

      await request(
        'put',
        `/api/v1/users/${target.id}/roles`,
        { roleKeys: ['OPERATOR_MANAGER'], reason: 'Promoted to manager' },
        'audit-req-roles-1',
      );
      await request(
        'put',
        `/api/v1/users/${target.id}/permissions/trips.cancel`,
        { effect: 'DENY', reason: 'Not allowed to cancel trips' },
        'audit-req-deny-1',
      );
      await request(
        'put',
        `/api/v1/users/${target.id}/permissions/trips.cancel`,
        { effect: 'ALLOW', reason: 'Allowed again' },
        'audit-req-allow-1',
      );
      await request(
        'delete',
        `/api/v1/users/${target.id}/permissions/trips.cancel`,
        { reason: 'Back to the role' },
        'audit-req-remove-1',
      );
      await request(
        'put',
        `/api/v1/users/${target.id}/data-scope`,
        {
          type: 'SELECTED_OPERATORS',
          operatorIds: [operatorA.toHexString()],
          reason: 'Scope pinned',
        },
        'audit-req-scope-1',
      );

      const entries = (
        await auditEntries(superAdmin.tokens, `?entityId=${target.id}&pageSize=50`)
      ).reverse();
      expect(entries.map((entry) => entry.action)).toEqual([
        'user.roles.changed',
        'user.permission-override.set',
        'user.permission-override.set',
        'user.permission-override.removed',
        'user.data-scope.changed',
      ]);

      expect(entries[0]).toMatchObject({
        actor: { userId: superAdmin.id, userType: 'STAFF', roleKeys: ['SUPER_ADMIN'] },
        entityType: 'user',
        entityId: target.id,
        operatorId: operatorA.toHexString(),
        before: { roleKeys: ['BOOKING_STAFF'] },
        after: { roleKeys: ['OPERATOR_MANAGER'] },
        reason: 'Promoted to manager',
        requestId: 'audit-req-roles-1',
        ip: '198.51.100.77',
        userAgent: 'AbraAdminApp/1.0',
      });
      expect(entries[1]).toMatchObject({
        before: { permissionKey: 'trips.cancel', effect: null },
        after: { permissionKey: 'trips.cancel', effect: 'DENY' },
        reason: 'Not allowed to cancel trips',
      });
      // Modification of an existing override records the previous effect
      expect(entries[2]).toMatchObject({ before: { effect: 'DENY' }, after: { effect: 'ALLOW' } });
      expect(entries[3]).toMatchObject({ before: { effect: 'ALLOW' }, after: { effect: null } });
      expect(entries[4]).toMatchObject({
        before: { dataScope: { type: 'OWN_OPERATOR' } },
        after: {
          dataScope: { type: 'SELECTED_OPERATORS', operatorIds: [operatorA.toHexString()] },
        },
        reason: 'Scope pinned',
      });
    });

    it('a refused change writes no audit entry and changes nothing', async () => {
      const target = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorB,
      });
      await api()
        .put(`/api/v1/users/${target.id}/roles`)
        .set(...bearer(adminA.tokens))
        .send({ roleKeys: ['OPERATOR_ADMIN'] })
        .expect(404);
      await api()
        .put(`/api/v1/users/${target.id}/permissions/settings.update`)
        .set(...bearer(superAdmin.tokens))
        .send({ effect: 'ALLOW', reason: 'invalid' })
        .expect(400);
      expect(await auditEntries(superAdmin.tokens, `?entityId=${target.id}`)).toEqual([]);
    });

    it('audit entries are scoped: an operator administrator sees only their operator', async () => {
      const targetA = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorA,
      });
      const targetB = await seedUser(context, {
        roleKeys: ['BOOKING_STAFF'],
        operatorId: operatorB,
      });
      await api()
        .put(`/api/v1/users/${targetA.id}/roles`)
        .set(...bearer(adminA.tokens))
        .send({ roleKeys: ['ACCOUNT_STAFF'] })
        .expect(200);
      await api()
        .put(`/api/v1/users/${targetB.id}/roles`)
        .set(...bearer(adminB.tokens))
        .send({ roleKeys: ['ACCOUNT_STAFF'] })
        .expect(200);

      const seenByA = await auditEntries(adminA.tokens, '?pageSize=100');
      expect(seenByA.length).toBeGreaterThan(0);
      expect(seenByA.every((entry) => entry.operatorId === operatorA.toHexString())).toBe(true);
      expect(seenByA.map((entry) => entry.entityId)).not.toContain(targetB.id);
      // Filters cannot widen the scope
      expect(await auditEntries(adminA.tokens, `?operatorId=${operatorB.toHexString()}`)).toEqual(
        [],
      );
      expect(await auditEntries(adminA.tokens, `?entityId=${targetB.id}`)).toEqual([]);
      // The platform sees both
      const seenByPlatform = await auditEntries(
        superAdmin.tokens,
        '?action=user.roles.changed&pageSize=100',
      );
      expect(seenByPlatform.map((entry) => entry.entityId)).toEqual(
        expect.arrayContaining([targetA.id, targetB.id]),
      );
    });

    it('never stores or returns credentials, tokens or MFA data', async () => {
      const stored = await context.connection.collection('audit_logs').find().toArray();
      expect(stored.length).toBeGreaterThan(0);
      const serialized =
        JSON.stringify(stored) +
        JSON.stringify(await auditEntries(superAdmin.tokens, '?pageSize=100'));
      expect(serialized).not.toMatch(
        /password|argon2|refreshToken|accessToken|Bearer|secretEncrypted|recoveryCode|otp/i,
      );
      expect(serialized).not.toContain(superAdmin.tokens.accessToken);
      expect(serialized).not.toContain(superAdmin.tokens.refreshToken);
    });
  });
});
