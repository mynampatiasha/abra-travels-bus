import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { newId, seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';

type Person = SeededUser & { tokens: Tokens };
interface FlagBody {
  key: string;
  on: boolean;
}
interface MaintenanceBody {
  scopes: Record<string, boolean>;
  message: string;
  from: string | null;
  to: string | null;
  activeNow: Record<string, boolean>;
}

/**
 * Feature flags and maintenance over HTTP, against the real application, MongoDB and Redis:
 * who may change them, and what every request experiences while an app is in maintenance.
 */
describe('Feature flags and maintenance e2e', () => {
  let context: AuthTestContext;
  let superAdmin: Person;
  let admin: Person;
  let support: Person;
  let customer: Person;
  let operator: Person;

  const api = () => client(context);
  const as = (who: Person) => bearer(who.tokens);
  const putMaintenance = (body: object) =>
    api()
      .put('/api/v1/admin/maintenance')
      .set(...as(superAdmin))
      .send(body);
  const customerCall = () =>
    api()
      .get('/api/v1/customer/messages')
      .set(...as(customer));

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
    support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
    operator = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: newId() });
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  describe('feature flags', () => {
    it('starts with the nine switches of the demo, at their demo defaults', async () => {
      const flags = dataOf<FlagBody[]>(
        await api()
          .get('/api/v1/admin/feature-flags')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(flags.map((flag) => flag.key)).toEqual([
        'live_tracking',
        'whatsapp_chatbot',
        'ai_support',
        'women_safety',
        'partner_api',
        'dynamic_pricing',
        'mobile_app',
        'driver_app',
        'advanced_analytics',
      ]);
      expect(flags.find((flag) => flag.key === 'live_tracking')?.on).toBe(true);
      expect(flags.find((flag) => flag.key === 'partner_api')?.on).toBe(false);
    });

    it('is public as a plain map, so an app can hide what is off', async () => {
      const map = dataOf<Record<string, boolean>>(await api().get('/api/v1/features').expect(200));
      expect(map).toMatchObject({ live_tracking: true, partner_api: false });
    });

    it('turns a feature off and on, audits it, and the public map follows at once', async () => {
      const off = dataOf<FlagBody>(
        await api()
          .put('/api/v1/admin/feature-flags/live_tracking')
          .set(...as(superAdmin))
          .send({ on: false, reason: 'testing' })
          .expect(200),
      );
      expect(off.on).toBe(false);
      expect(
        dataOf<Record<string, boolean>>(await api().get('/api/v1/features').expect(200))
          .live_tracking,
      ).toBe(false);
      const audit = dataOf<Array<{ action: string; after: { on: boolean } }>>(
        await api()
          .get('/api/v1/audit-logs?pageSize=20')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(audit.find((entry) => entry.action === 'feature-flag.changed')?.after).toEqual({
        on: false,
      });
      await api()
        .put('/api/v1/admin/feature-flags/live_tracking')
        .set(...as(superAdmin))
        .send({ on: true, reason: 'back on' })
        .expect(200);
      expect(
        dataOf<Record<string, boolean>>(await api().get('/api/v1/features').expect(200))
          .live_tracking,
      ).toBe(true);
    });

    it('checks the request: unknown feature, no reason, wrong type', async () => {
      const put = (key: string, body: object) =>
        api()
          .put(`/api/v1/admin/feature-flags/${key}`)
          .set(...as(superAdmin))
          .send(body);
      await put('time_travel', { on: true, reason: 'test' }).expect(400);
      await put('live_tracking', { on: true }).expect(400);
      await put('live_tracking', { on: 'yes', reason: 'test' }).expect(400);
    });

    it('lets an Admin read but not change, and refuses an operator and anonymous callers', async () => {
      await api()
        .get('/api/v1/admin/feature-flags')
        .set(...as(admin))
        .expect(200);
      await api()
        .put('/api/v1/admin/feature-flags/live_tracking')
        .set(...as(admin))
        .send({ on: false, reason: 'try' })
        .expect(403);
      await api()
        .get('/api/v1/admin/feature-flags')
        .set(...as(operator))
        .expect(403);
      await api().get('/api/v1/admin/feature-flags').expect(401);
    });
  });

  describe('maintenance', () => {
    afterEach(async () => {
      await putMaintenance({
        scopes: { global: false, customer: false, operator: false, partner: false, admin: false },
        from: null,
        to: null,
        reason: 'reset',
      }).expect(200);
    });

    it('starts switched off, with the demo message', async () => {
      const m = dataOf<MaintenanceBody>(
        await api()
          .get('/api/v1/admin/maintenance')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(m.message).toBe('We are improving Abra Travels. Back soon.');
      expect(Object.values(m.scopes).every((on) => !on)).toBe(true);
    });

    it('stops the customer app only, with the message, while staff and operators carry on', async () => {
      await putMaintenance({
        scopes: { customer: true },
        message: 'Back at 6 pm.',
        reason: 'release',
      }).expect(200);
      const blocked = await customerCall().expect(503);
      expect(blocked.body).toMatchObject({
        success: false,
        error: { code: 'MAINTENANCE_MODE', message: 'Back at 6 pm.' },
      });
      await api()
        .get('/api/v1/admin/maintenance')
        .set(...as(superAdmin))
        .expect(200);
      await api()
        .get('/api/v1/admin/feature-flags')
        .set(...as(admin))
        .expect(200);
      await api()
        .get('/api/v1/notifications/unread-count')
        .set(...as(operator))
        .expect(200);
    });

    it('also stops requests without a token that say they come from the customer app', async () => {
      await putMaintenance({ scopes: { customer: true }, reason: 'release' }).expect(200);
      await api().get('/api/v1/banners').set('X-Abra-App', 'customer').expect(503);
      await api().get('/api/v1/banners').set('X-Abra-App', 'operator').expect(200);
      await api().get('/api/v1/banners').expect(200);
    });

    it('keeps health, status, features and sign-in working', async () => {
      await putMaintenance({
        scopes: { global: true },
        message: 'Back soon.',
        reason: 'release',
      }).expect(200);
      await api().get('/health/live').set('X-Abra-App', 'customer').expect(200);
      await api().get('/api/v1/features').set('X-Abra-App', 'customer').expect(200);
      const status = dataOf<{ active: boolean; message: string }>(
        await api().get('/api/v1/maintenance/status?app=customer').expect(200),
      );
      expect(status.active).toBe(true);
      expect(status.message).toContain('Back soon');
      await api()
        .post('/api/v1/auth/login')
        .set('X-Abra-App', 'admin')
        .send({ identifier: 'nobody@example.com', password: 'wrong password here' })
        .expect(401);
    });

    it('global stops the customer and operator apps but never the admin portal', async () => {
      await putMaintenance({ scopes: { global: true }, reason: 'big release' }).expect(200);
      await customerCall().expect(503);
      await api()
        .get('/api/v1/notifications/unread-count')
        .set(...as(operator))
        .expect(503);
      await api()
        .get('/api/v1/admin/maintenance')
        .set(...as(superAdmin))
        .expect(200);
      await api()
        .get('/api/v1/audit-logs')
        .set(...as(support))
        .expect(403); // not blocked: refused for permission, not maintenance
    });

    it('admin maintenance stops staff without the bypass permission, never the Super Admin or Admin', async () => {
      await putMaintenance({ scopes: { admin: true }, reason: 'admin work' }).expect(200);
      const blocked = await api()
        .get('/api/v1/admin/messages')
        .set(...as(support))
        .expect(503);
      expect(JSON.stringify(blocked.body)).toContain('MAINTENANCE_MODE');
      await api()
        .get('/api/v1/admin/maintenance')
        .set(...as(superAdmin))
        .expect(200);
      await api()
        .get('/api/v1/admin/feature-flags')
        .set(...as(admin))
        .expect(200);
      await customerCall().expect(200); // the customer app is not affected
    });

    it('a window decides when a switch counts: not yet, now, and ended', async () => {
      const hours = (n: number) => new Date(Date.now() + n * 3_600_000).toISOString();
      await putMaintenance({
        scopes: { customer: true },
        from: hours(1),
        to: hours(2),
        reason: 'planned',
      }).expect(200);
      await customerCall().expect(200); // starts in an hour
      let m = dataOf<MaintenanceBody>(
        await api()
          .get('/api/v1/admin/maintenance')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(m.activeNow.customer).toBe(false);
      await putMaintenance({ from: hours(-1), to: hours(1), reason: 'started' }).expect(200);
      await customerCall().expect(503);
      m = dataOf<MaintenanceBody>(
        await api()
          .get('/api/v1/admin/maintenance')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(m.activeNow.customer).toBe(true);
      await putMaintenance({ from: hours(-3), to: hours(-2), reason: 'ended' }).expect(200);
      await customerCall().expect(200); // over, though the switch is still on
    });

    it('checks the request: end before start, nothing to change, no reason, bad scope', async () => {
      const t = (n: number) => new Date(Date.now() + n * 3_600_000).toISOString();
      await putMaintenance({ from: t(2), to: t(1), reason: 'test' }).expect(400);
      await putMaintenance({ reason: 'nothing' }).expect(400);
      await putMaintenance({ scopes: { customer: true } }).expect(400);
      await putMaintenance({ scopes: { moon: true }, reason: 'test' }).expect(400);
      await putMaintenance({ message: 'x', reason: 'test' }).expect(400);
      await putMaintenance({ from: 'not a date', reason: 'test' }).expect(400);
    });

    it('audits every change with who and why', async () => {
      await putMaintenance({ scopes: { partner: true }, reason: 'audit me' }).expect(200);
      const audit = dataOf<Array<{ action: string; reason: string | null }>>(
        await api()
          .get('/api/v1/audit-logs?pageSize=20')
          .set(...as(superAdmin))
          .expect(200),
      );
      expect(
        audit.some(
          (entry) => entry.action === 'maintenance.changed' && entry.reason === 'audit me',
        ),
      ).toBe(true);
    });

    it('lets an Admin read but not change it, and refuses operators and anonymous callers', async () => {
      await api()
        .get('/api/v1/admin/maintenance')
        .set(...as(admin))
        .expect(200);
      await api()
        .put('/api/v1/admin/maintenance')
        .set(...as(admin))
        .send({ scopes: { global: true }, reason: 'try' })
        .expect(403);
      await api()
        .get('/api/v1/admin/maintenance')
        .set(...as(operator))
        .expect(403);
      await api().get('/api/v1/admin/maintenance').expect(401);
    });
  });
});
