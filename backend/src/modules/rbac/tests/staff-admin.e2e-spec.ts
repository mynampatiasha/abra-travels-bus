import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  uniqueEmail,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from './rbac-e2e.harness';

describe('Staff admin manage e2e', () => {
  let context: AuthTestContext;
  let superAdminTokens: { accessToken: string };
  let superAdminId: string;

  beforeAll(async () => {
    context = await createAuthTestApp();
    const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    superAdminTokens = superAdmin.tokens;
    superAdminId = superAdmin.id;
  }, 60_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const api = () => client(context);

  describe('GET /api/v1/admin/staff', () => {
    it('requires authentication', async () => {
      await api().get('/api/v1/admin/staff').expect(401);
    });

    it('returns staff list for super admin', async () => {
      const res = await api()
        .get('/api/v1/admin/staff')
        .set(...bearer(superAdminTokens))
        .expect(200);

      const data = dataOf<Array<{ id: string; email: string; role: string }>>(res);
      expect(Array.isArray(data)).toBe(true);
      expect(data.some((u) => u.id === superAdminId)).toBe(true);
    });
  });

  describe('POST /api/v1/admin/staff & invitation flow', () => {
    const inviteEmail = uniqueEmail();
    let inviteToken: string;
    let staffId: string;

    it('invites a new staff member', async () => {
      const res = await api()
        .post('/api/v1/admin/staff')
        .set(...bearer(superAdminTokens))
        .send({
          name: 'Priya Sharma',
          email: inviteEmail,
          role: 'SUPPORT',
        })
        .expect(201);

      const staff = dataOf<{ id: string; email: string; status: string; inviteUrl?: string }>(res);
      expect(staff.email).toBe(inviteEmail);
      expect(staff.status).toBe('INVITED');
      staffId = staff.id;

      // Extract token from inviteUrl
      expect(staff.inviteUrl).toBeDefined();
      const url = new URL(staff.inviteUrl!);
      inviteToken = url.searchParams.get('token')!;
      expect(inviteToken).toBeTruthy();
    });

    it('refuses to invite with existing email', async () => {
      await api()
        .post('/api/v1/admin/staff')
        .set(...bearer(superAdminTokens))
        .send({
          name: 'Another Person',
          email: inviteEmail,
          role: 'ADMIN',
        })
        .expect(409);
    });

    it('inspects invitation link publicly', async () => {
      const res = await api()
        .post('/api/v1/staff-invitations/inspect')
        .send({ token: inviteToken })
        .expect(200);

      const preview = dataOf<{ name: string; email: string; roleKey: string }>(res);
      expect(preview.name).toBe('Priya Sharma');
      expect(preview.email).toBe(inviteEmail);
      expect(preview.roleKey).toBe('SUPPORT');
    });

    it('refuses to inspect invalid token', async () => {
      await api()
        .post('/api/v1/staff-invitations/inspect')
        .send({ token: 'invalid-non-existent-token' })
        .expect(404);
    });

    it('accepts invitation and sets password', async () => {
      const res = await api()
        .post('/api/v1/staff-invitations/accept')
        .send({
          token: inviteToken,
          password: 'CorrectHorseBatteryStaple99!',
        })
        .expect(200);

      const result = dataOf<{ email: string }>(res);
      expect(result.email).toBe(inviteEmail);

      // Now staff member should be ACTIVE
      const staffRes = await api()
        .get(`/api/v1/admin/staff/${staffId}`)
        .set(...bearer(superAdminTokens))
        .expect(200);

      const staff = dataOf<{ status: string }>(staffRes);
      expect(staff.status).toBe('ACTIVE');
    });

    it('updates staff member details', async () => {
      const res = await api()
        .patch(`/api/v1/admin/staff/${staffId}`)
        .set(...bearer(superAdminTokens))
        .send({
          name: 'Priya Sharma Updated',
          role: 'ADMIN',
        })
        .expect(200);

      const updated = dataOf<{ name: string; role: string }>(res);
      expect(updated.name).toBe('Priya Sharma Updated');
      expect(updated.role).toBe('ADMIN');
    });

    it('refuses when admin attempts to change own role', async () => {
      await api()
        .patch(`/api/v1/admin/staff/${superAdminId}`)
        .set(...bearer(superAdminTokens))
        .send({ role: 'SUPPORT' })
        .expect(403);
    });

    it('deactivates staff member', async () => {
      const res = await api()
        .post(`/api/v1/admin/staff/${staffId}/deactivate`)
        .set(...bearer(superAdminTokens))
        .send({ reason: 'Left company' })
        .expect(200);

      const staff = dataOf<{ status: string }>(res);
      expect(staff.status).toBe('DEACTIVATED');
    });

    it('refuses to deactivate own account', async () => {
      await api()
        .post(`/api/v1/admin/staff/${superAdminId}/deactivate`)
        .set(...bearer(superAdminTokens))
        .send({})
        .expect(403);
    });

    it('activates staff member again', async () => {
      const res = await api()
        .post(`/api/v1/admin/staff/${staffId}/activate`)
        .set(...bearer(superAdminTokens))
        .send({})
        .expect(200);

      const staff = dataOf<{ status: string }>(res);
      expect(staff.status).toBe('ACTIVE');
    });
  });
});
