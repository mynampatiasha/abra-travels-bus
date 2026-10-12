import { type AddressInfo } from 'node:net';
import { SMTPServer } from 'smtp-server';
import { EmailSettingsStore } from '../../../integrations/email/email-settings.store';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { type AuditEntry, seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  type EmailSettingsView,
  type SettingsTestResult,
} from '../services/email-settings-admin.service';

const PATH = '/api/v1/settings/integrations/email';
const PASSWORD = 'correct horse battery staple 7';

interface Received {
  to: string[];
  data: string;
}

/** Email settings and tests — real application, MongoDB and Redis, plus a real SMTP server. */
describe('System settings e2e: email', () => {
  let context: AuthTestContext;
  /** Only the Super Admin changes settings. */
  let admin: { tokens: Tokens };
  let plainAdmin: { tokens: Tokens };
  let support: { tokens: Tokens };
  let customer: { tokens: Tokens };
  let smtp: SMTPServer;
  let port: number;
  const received: Received[] = [];

  beforeAll(async () => {
    smtp = new SMTPServer({
      authOptional: false,
      allowInsecureAuth: true,
      disabledCommands: ['STARTTLS'],
      onAuth(auth, _session, callback) {
        if (auth.username === 'mailer' && auth.password === PASSWORD) {
          callback(null, { user: 'mailer' });
        } else {
          callback(new Error('Invalid login'));
        }
      },
      onData(stream, session, callback) {
        const chunks: Buffer[] = [];
        stream.on('data', (chunk: Buffer) => chunks.push(chunk));
        stream.on('end', () => {
          received.push({
            to: session.envelope.rcptTo.map((address) => address.address),
            data: Buffer.concat(chunks).toString('utf8'),
          });
          callback();
        });
      },
    });
    await new Promise<void>((resolve) => smtp.listen(0, '127.0.0.1', resolve));
    port = (smtp.server.address() as AddressInfo).port;

    context = await createAuthTestApp();
    admin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    plainAdmin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
    support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
  }, 120_000);

  beforeEach(async () => {
    received.length = 0;
    await context.connection.collection('email_settings').deleteMany({});
    context.app.get(EmailSettingsStore).invalidate();
  });

  afterAll(async () => {
    await context.connection.collection('email_settings').deleteMany({});
    await context.close();
    await new Promise<void>((resolve) => smtp.close(() => resolve()));
  }, 60_000);

  const as = (user: { tokens: Tokens }) => ({
    get: (path = '') =>
      client(context)
        .get(`${PATH}${path}`)
        .set(...bearer(user.tokens)),
    put: (body: object) =>
      client(context)
        .put(PATH)
        .set(...bearer(user.tokens))
        .send(body),
    post: (path: string, body: object = {}) =>
      client(context)
        .post(`${PATH}${path}`)
        .set(...bearer(user.tokens))
        .send(body),
  });

  const settings = (overrides: object = {}) => ({
    host: '127.0.0.1',
    port,
    security: 'NONE',
    username: 'mailer',
    password: PASSWORD,
    fromName: 'Abra Travels',
    fromAddress: 'no-reply@abratravels.test',
    reason: 'Initial setup',
    ...overrides,
  });

  it('is closed to people without the settings permissions', async () => {
    await client(context).get(PATH).expect(401);
    await as(support).get().expect(403);
    await as(customer).put(settings()).expect(403);
    await as(customer).post('/test-connection').expect(403);
    await as(customer).post('/test-email', { to: 'a@b.test' }).expect(403);
  });

  it('a regular administrator can look but not change or test', async () => {
    await as(plainAdmin).get().expect(200);
    await as(plainAdmin).put(settings()).expect(403);
    await as(plainAdmin).post('/test-connection').expect(403);
    await as(plainAdmin).post('/test-email', { to: 'a@b.test' }).expect(403);
  });

  it('starts incomplete, and never shows the password once saved', async () => {
    const before = dataOf<EmailSettingsView>(await as(admin).get().expect(200));
    expect(before.status).toBe('INCOMPLETE');
    expect(before.missing).toEqual(expect.arrayContaining(['host', 'port']));

    const saved = dataOf<EmailSettingsView>(await as(admin).put(settings()).expect(200));
    expect(saved).toMatchObject({
      status: 'READY',
      host: '127.0.0.1',
      port,
      security: 'NONE',
      username: 'mailer',
      password: { configured: true },
      fromAddress: 'no-reply@abratravels.test',
      fromName: 'Abra Travels',
    });
    const raw = await context.connection.collection('email_settings').findOne({});
    expect(JSON.stringify(saved)).not.toContain(PASSWORD);
    // stored encrypted, not as typed
    expect(raw?.passwordEncrypted).toMatch(/^v1\./);
    expect(JSON.stringify(raw)).not.toContain(PASSWORD);
  });

  it('a username without a password is reported as missing', async () => {
    const saved = dataOf<EmailSettingsView>(
      await as(admin)
        .put(settings({ password: null }))
        .expect(200),
    );
    expect(saved.status).toBe('INCOMPLETE');
    expect(saved.missing).toContain('password');
  });

  it('refuses changes that are invalid or empty', async () => {
    await as(admin).put({ reason: 'Nothing' }).expect(400);
    await as(admin)
      .put(settings({ host: 'bad host!' }))
      .expect(400);
    await as(admin)
      .put(settings({ port: 70000 }))
      .expect(400);
    await as(admin)
      .put(settings({ fromAddress: 'not-an-address' }))
      .expect(400);
    await as(admin)
      .put(settings({ security: 'MAYBE' }))
      .expect(400);
    await as(admin)
      .put(settings({ reason: '' }))
      .expect(400);
  });

  it('every change is audited with the reason and without the password', async () => {
    const reason = `Audited setup ${Date.now()}`;
    await as(admin).put(settings({ reason })).expect(200);
    const entries = dataOf<AuditEntry[]>(
      await client(context)
        .get('/api/v1/audit-logs?pageSize=100')
        .set(...bearer(admin.tokens))
        .expect(200),
    );
    const entry = entries.find((item) => item.reason === reason);
    expect(entry?.action).toBe('settings.email.changed');
    expect(entry?.after).toMatchObject({ passwordSet: true, passwordChanged: true });
    expect(JSON.stringify(entry)).not.toContain(PASSWORD);
  });

  describe('tests', () => {
    it('asks for the settings first when nothing is saved', async () => {
      const result = dataOf<SettingsTestResult>(
        await as(admin).post('/test-connection').expect(200),
      );
      expect(result.ok).toBe(false);
      expect(result.message).toMatch(/host and the port/);
    });

    it('signs in to the saved mail server', async () => {
      await as(admin).put(settings()).expect(200);
      const result = dataOf<SettingsTestResult>(
        await as(admin).post('/test-connection').expect(200),
      );
      expect(result).toMatchObject({ ok: true });
      expect(result.message).toContain(`127.0.0.1:${port}`);
    });

    it('says when the password is wrong', async () => {
      await as(admin)
        .put(settings({ password: 'wrong password' }))
        .expect(200);
      const result = dataOf<SettingsTestResult>(
        await as(admin).post('/test-connection').expect(200),
      );
      expect(result.ok).toBe(false);
      expect(result.message).toMatch(/username or password/);
      expect(result.message).not.toContain('wrong password');
    });

    it('says when nothing answers at the address', async () => {
      await as(admin)
        .put(settings({ port: 1 }))
        .expect(200);
      const result = dataOf<SettingsTestResult>(
        await as(admin).post('/test-connection').expect(200),
      );
      expect(result.ok).toBe(false);
      expect(result.message).toMatch(/127\.0\.0\.1:1|connect/);
    });

    it('sends a real test email through the saved settings', async () => {
      await as(admin).put(settings()).expect(200);
      const result = dataOf<SettingsTestResult>(
        await as(admin).post('/test-email', { to: 'owner@client.test' }).expect(200),
      );
      expect(result.ok).toBe(true);
      expect(received).toHaveLength(1);
      expect(received[0]?.to).toEqual(['owner@client.test']);
      expect(received[0]?.data).toContain('Subject: Abra Travels test email');
      expect(received[0]?.data).toContain('From: Abra Travels <no-reply@abratravels.test>');
    });

    it('refuses a bad recipient address', async () => {
      await as(admin).post('/test-email', { to: 'nope' }).expect(400);
    });

    it('a turned-off settings record changes the status but keeps the values', async () => {
      await as(admin).put(settings()).expect(200);
      const off = dataOf<EmailSettingsView>(
        await as(admin).put({ enabled: false, reason: 'Pause email' }).expect(200),
      );
      expect(off).toMatchObject({ status: 'DISABLED', host: '127.0.0.1' });
    });
  });

  describe('WhatsApp connection test', () => {
    it('is closed to people without permission, and explains the development adapter', async () => {
      const path = '/api/v1/settings/integrations/whatsapp/test-connection';
      await client(context).post(path).expect(401);
      await client(context)
        .post(path)
        .set(...bearer(support.tokens))
        .expect(403);
      const result = dataOf<SettingsTestResult>(
        await client(context)
          .post(path)
          .set(...bearer(admin.tokens))
          .expect(200),
      );
      expect(result.ok).toBe(false);
      expect(result.message).toMatch(/development WhatsApp adapter/);
    });
  });
});
