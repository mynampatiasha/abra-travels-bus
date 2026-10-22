/**
 * Endpoint tests. Use ONLY a throw-away database, for example:
 *   MONGODB_URI=mongodb://localhost:27017/abra_payout_test?directConnection=true PORT=4002 \
 *   REDIS_KEY_PREFIX=pay QUEUE_PREFIX=pay
 * Never abra_travels. Never run two e2e runs on the same database at once.
 *
 * Runs the real application: real sign-in, the access matrix (a role with View on the Payout
 * page), the real audit trail and the real operators collection.
 */
import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

interface SlabBody {
  id: string;
  hoursBefore: number;
  refundPct: number;
}

describe('Payout and fees (e2e)', () => {
  let context: AuthTestContext;
  let superAdmin: Caller;
  let viewer: Caller;
  let none: Caller;

  const call = (caller: Caller) => ({
    get: (path: string) =>
      client(context)
        .get(`${API}${path}`)
        .set(...bearer(caller.tokens)),
    put: (path: string, body: object) =>
      client(context)
        .put(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
    post: (path: string, body: object = {}) =>
      client(context)
        .post(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
    delete: (path: string) =>
      client(context)
        .delete(`${API}${path}`)
        .set(...bearer(caller.tokens)),
  });
  const auditActions = async () =>
    (
      await context.connection
        .collection('audit_logs')
        .find({ action: /^payout\./ })
        .sort({ at: 1 })
        .toArray()
    ).map((entry) => String(entry.action));
  const errorMessage = (body: unknown) =>
    (body as { error?: { message?: string } }).error?.message ?? '';

  beforeAll(async () => {
    const uri = process.env.MONGODB_URI;
    if (!uri || !/_test(\?|$)/.test(uri)) {
      throw new Error('Set MONGODB_URI to a throw-away *_test database, never abra_travels');
    }
    context = await createAuthTestApp();
    for (const name of ['payout_settings', 'refund_slabs', 'operators']) {
      await context.connection.collection(name).deleteMany({});
    }
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    // A role with View on the Payout page: payout.read only
    const role = dataOf<{ key: string }>(
      await call(superAdmin)
        .post('/access-matrix/roles', { audience: 'ADMIN', name: `Payout viewer ${Date.now()}` })
        .expect(201),
    );
    await call(superAdmin)
      .put(`/access-matrix/roles/${role.key}/pages/payout`, { level: 'VIEW' })
      .expect(200);
    viewer = await seedAndSignIn(context, { roleKeys: [role.key as never], userType: 'STAFF' });
    // Support has no access to Payout and fees
    none = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
  }, 180_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  const settings = {
    defaultMode: 'MANUAL',
    cycleDays: 7,
    minPayout: 100000,
    holdDays: 2,
    razorpayRoute: true,
    gstPct: 18,
    convenienceFee: 4900,
    couponFunding: 'PLATFORM',
  };

  it('returns null settings before anything is saved (no invented data)', async () => {
    const r = await call(superAdmin).get('/admin/payout/settings').expect(200);
    expect(dataOf<{ settings: unknown }>(r).settings).toBeNull();
  });

  it('saves settings, audits as sensitive, and reads them back', async () => {
    await call(superAdmin).put('/admin/payout/settings', settings).expect(200);
    const r = await call(superAdmin).get('/admin/payout/settings').expect(200);
    const saved = dataOf<{ settings: { gstPct: number; updatedBy: string } }>(r).settings;
    expect(saved.gstPct).toBe(18);
    expect(saved.updatedBy).toEqual(expect.any(String));
    expect(await auditActions()).toContain('payout.settings-changed');
  });

  it('rejects bad values', async () => {
    const bad = (o: object) =>
      call(superAdmin)
        .put('/admin/payout/settings', { ...settings, ...o })
        .expect(400);
    await bad({ gstPct: 29 });
    await bad({ cycleDays: 0 });
    await bad({ minPayout: -1 });
    await bad({ convenienceFee: 49.5 });
    await bad({ defaultMode: 'AUTO' });
    await bad({ gstPct: 5.555 });
  });

  it('refuses to switch Route off while operators are on Automatic', async () => {
    await context.connection.collection('operators').insertMany([
      { companyName: 'Auto One', status: 'ACTIVE', payoutMode: 'AUTO_SPLIT' },
      { companyName: 'Auto Two', status: 'ACTIVE', payoutMode: 'AUTO_SPLIT' },
    ]);
    const r = await call(superAdmin)
      .put('/admin/payout/settings', { ...settings, razorpayRoute: false })
      .expect(409);
    expect(errorMessage(r.body)).toContain('2 operators');
    await context.connection.collection('operators').deleteMany({});
    await call(superAdmin)
      .put('/admin/payout/settings', { ...settings, razorpayRoute: false })
      .expect(200);
  });

  describe('refund slabs', () => {
    let id: string;

    it('creates a slab and blocks a duplicate hour value', async () => {
      const r = await call(superAdmin)
        .post('/admin/payout/refund-slabs', { hoursBefore: 24, refundPct: 75 })
        .expect(201);
      id = dataOf<SlabBody>(r).id;
      await call(superAdmin)
        .post('/admin/payout/refund-slabs', { hoursBefore: 24, refundPct: 50 })
        .expect(409);
      await call(superAdmin)
        .post('/admin/payout/refund-slabs', { hoursBefore: 5, refundPct: 101 })
        .expect(400);
    });

    it('lists, gets, soft deletes and restores', async () => {
      let list = dataOf<SlabBody[]>(
        await call(superAdmin).get('/admin/payout/refund-slabs').expect(200),
      );
      expect(list).toHaveLength(1);
      await call(superAdmin).get(`/admin/payout/refund-slabs/${id}`).expect(200);

      await call(superAdmin).delete(`/admin/payout/refund-slabs/${id}`).expect(200);
      list = dataOf<SlabBody[]>(
        await call(superAdmin).get('/admin/payout/refund-slabs').expect(200),
      );
      expect(list).toHaveLength(0);
      expect((await auditActions()).at(-1)).toBe('payout.slab-removed');

      await call(superAdmin).post(`/admin/payout/refund-slabs/${id}/restore`).expect(200);
      list = dataOf<SlabBody[]>(
        await call(superAdmin).get('/admin/payout/refund-slabs').expect(200),
      );
      expect(list).toHaveLength(1);
      expect((await auditActions()).at(-1)).toBe('payout.slab-restored');
    });

    it('cannot restore when the hours are now used by another slab', async () => {
      await call(superAdmin).delete(`/admin/payout/refund-slabs/${id}`).expect(200);
      await call(superAdmin)
        .post('/admin/payout/refund-slabs', { hoursBefore: 24, refundPct: 60 })
        .expect(201);
      await call(superAdmin).post(`/admin/payout/refund-slabs/${id}/restore`).expect(409);
    });

    it('exports CSV and Excel', async () => {
      const r = await call(superAdmin)
        .get('/admin/payout/refund-slabs/export?format=csv')
        .expect(200);
      expect(r.text).toContain('Refund percent');
      expect(r.text).toContain('24,60');
      await call(superAdmin).get('/admin/payout/refund-slabs/export?format=xlsx').expect(200);
    });

    it('returns 404 for an unknown slab', async () => {
      await call(superAdmin)
        .get(`/admin/payout/refund-slabs/${new Types.ObjectId().toHexString()}`)
        .expect(404);
      await call(superAdmin).get('/admin/payout/refund-slabs/not-an-id').expect(400);
    });
  });

  describe('permissions', () => {
    it('view-only users can read but not change', async () => {
      await call(viewer).get('/admin/payout/settings').expect(200);
      await call(viewer).put('/admin/payout/settings', settings).expect(403);
      await call(viewer)
        .post('/admin/payout/refund-slabs', { hoursBefore: 1, refundPct: 10 })
        .expect(403);
      // Export is a View action in this project (the demo shows Export to every viewer)
      await call(viewer).get('/admin/payout/refund-slabs/export').expect(200);
    });

    it('users without access get nothing', async () => {
      await call(none).get('/admin/payout/settings').expect(403);
      await call(none).get('/admin/payout/refund-slabs').expect(403);
    });
  });
});
