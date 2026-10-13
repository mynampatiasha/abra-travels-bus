import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { newId, seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';

interface IntegrationBody {
  key: string;
  status: string;
  missing: string[];
  values: Record<string, { value: unknown; source: string }>;
  secrets: Record<string, { configured: boolean; source: string; lastFour: string | null }>;
}

/** The integration settings over HTTP, against the real application, MongoDB and Redis. */
describe('Integration settings e2e', () => {
  let context: AuthTestContext;
  let superAdmin: SeededUser & { tokens: Tokens };
  let admin: SeededUser & { tokens: Tokens };
  let operator: SeededUser & { tokens: Tokens };
  const SECRET = 'rzp-secret-value-for-the-test-1234';

  const api = () => client(context);

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
    operator = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: newId() });
  }, 90_000);

  afterAll(async () => {
    await context.close();
  }, 60_000);

  it('lists every integration with a status, WhatsApp and email included', async () => {
    const list = dataOf<Array<{ key: string; status: string }>>(
      await api()
        .get('/api/v1/settings/integrations')
        .set(...bearer(superAdmin.tokens))
        .expect(200),
    );
    expect(list.map((item) => item.key)).toEqual([
      'whatsapp',
      'email',
      'razorpay',
      'maps',
      'sms',
      'push',
      'assistant',
    ]);
  });

  it('keeps the fixed WhatsApp and email pages working next to the new :key routes', async () => {
    const whatsapp = dataOf<{ provider: string }>(
      await api()
        .get('/api/v1/settings/integrations/whatsapp')
        .set(...bearer(superAdmin.tokens))
        .expect(200),
    );
    expect(whatsapp).toHaveProperty('provider');
    const email = dataOf<{ provider: string }>(
      await api()
        .get('/api/v1/settings/integrations/email')
        .set(...bearer(superAdmin.tokens))
        .expect(200),
    );
    expect(email).toHaveProperty('provider');
  });

  it('refuses an unknown integration', async () => {
    await api()
      .get('/api/v1/settings/integrations/telegram')
      .set(...bearer(superAdmin.tokens))
      .expect(400);
  });

  it('saves Razorpay settings, returns no secret, and stores the secret encrypted', async () => {
    const saved = dataOf<IntegrationBody>(
      await api()
        .put('/api/v1/settings/integrations/razorpay')
        .set(...bearer(superAdmin.tokens))
        .send({
          values: { keyId: 'rzp_test_abcdef123456', routeEnabled: true },
          secrets: { keySecret: SECRET, webhookSecret: 'whsec-for-the-test' },
          reason: 'first setup',
        })
        .expect(200),
    );
    expect(saved.status).toBe('READY');
    expect(saved.secrets.keySecret).toEqual({
      configured: true,
      source: 'ADMIN',
      lastFour: '1234',
    });
    expect(saved.values.routeEnabled?.value).toBe(true);

    const read = await api()
      .get('/api/v1/settings/integrations/razorpay')
      .set(...bearer(superAdmin.tokens))
      .expect(200);
    expect(JSON.stringify(read.body)).not.toContain(SECRET);

    const row = await context.connection
      .collection<{ secrets: { keySecret: { encrypted: string; lastFour: string } } }>(
        'integration_settings',
      )
      .findOne({ key: 'razorpay' });
    expect(row?.secrets.keySecret.encrypted.startsWith('v1.')).toBe(true);
    expect(JSON.stringify(row)).not.toContain(SECRET);
  });

  it('writes an audit entry for the change without any secret in it', async () => {
    const audit = await api()
      .get('/api/v1/audit-logs?pageSize=20')
      .set(...bearer(superAdmin.tokens))
      .expect(200);
    const entries = dataOf<Array<{ action: string; after: Record<string, unknown> }>>(audit);
    const entry = entries.find((item) => item.action === 'settings.integration.changed');
    expect(entry).toBeDefined();
    expect(entry?.after).toMatchObject({ secretsChanged: ['keySecret', 'webhookSecret'] });
    expect(JSON.stringify(audit.body)).not.toContain(SECRET);
  });

  it('validates input: unknown field, wrong format, wrong choice, no reason, nothing to change', async () => {
    const put = (key: string, body: object) =>
      api()
        .put(`/api/v1/settings/integrations/${key}`)
        .set(...bearer(superAdmin.tokens))
        .send(body);
    await put('razorpay', { values: { nonsense: 'x' }, reason: 'test' }).expect(400);
    await put('razorpay', { values: { keyId: 'bad' }, reason: 'test' }).expect(400);
    await put('maps', { values: { provider: 'bing' }, reason: 'test' }).expect(400);
    await put('maps', { values: { provider: 'google' } }).expect(400);
    await put('maps', { reason: 'test' }).expect(400);
  });

  it('turns an integration off and on again without losing the credentials', async () => {
    const put = async (body: object) =>
      dataOf<IntegrationBody>(
        await api()
          .put('/api/v1/settings/integrations/razorpay')
          .set(...bearer(superAdmin.tokens))
          .send(body)
          .expect(200),
      );
    expect((await put({ enabled: false, reason: 'pause' })).status).toBe('DISABLED');
    const back = await put({ enabled: true, reason: 'resume' });
    expect(back.status).toBe('READY');
    expect(back.secrets.keySecret?.configured).toBe(true);
  });

  it('tests a connection without sending anything to a customer', async () => {
    await api()
      .put('/api/v1/settings/integrations/sms')
      .set(...bearer(superAdmin.tokens))
      .send({
        values: { senderId: 'ABRATV', dltEntityId: '12345678901' },
        secrets: { apiKey: 'sms-api-key-for-test' },
        reason: 'setup',
      })
      .expect(200);
    const result = dataOf<{ ok: boolean; message: string }>(
      await api()
        .post('/api/v1/settings/integrations/sms/test-connection')
        .set(...bearer(superAdmin.tokens))
        .expect(200),
    );
    expect(result.ok).toBe(true);
  });

  it('lets an Admin read but not change, and refuses an operator and anonymous callers', async () => {
    await api()
      .get('/api/v1/settings/integrations/razorpay')
      .set(...bearer(admin.tokens))
      .expect(200);
    await api()
      .put('/api/v1/settings/integrations/razorpay')
      .set(...bearer(admin.tokens))
      .send({ enabled: false, reason: 'try' })
      .expect(403);
    await api()
      .post('/api/v1/settings/integrations/maps/test-connection')
      .set(...bearer(admin.tokens))
      .expect(403);
    await api()
      .get('/api/v1/settings/integrations')
      .set(...bearer(operator.tokens))
      .expect(403);
    await api().get('/api/v1/settings/integrations').expect(401);
  });
});
