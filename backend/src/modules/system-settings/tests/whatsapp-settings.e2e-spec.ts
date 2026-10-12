import { FieldEncryptionService } from '../../../common/crypto/field-encryption.service';
import { DevelopmentWhatsAppProvider } from '../../../integrations/whatsapp/development-whatsapp.provider';
import {
  WhatsAppDeliveryError,
  type WhatsAppProvider,
} from '../../../integrations/whatsapp/whatsapp-provider.interface';
import { WhatsAppSettingsStore } from '../../../integrations/whatsapp/whatsapp-settings.store';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  type Tokens,
  uniquePhone,
} from '../../authentication/tests/auth-e2e.harness';
import { type AuditEntry, seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import { type WhatsAppSettingsView } from '../services/whatsapp-settings-admin.service';

const PATH = '/api/v1/settings/integrations/whatsapp';
// Shaped like a Meta token; not a real credential.
const TOKEN = 'EAAtestTokenForAutomatedTestsOnly0000000000WXYZ';

type SignedIn = SeededUser & { tokens: Tokens };

/** Removes the stored settings so suites and tests do not affect each other. */
async function resetSettings(context: AuthTestContext): Promise<void> {
  await context.connection.collection('whatsapp_settings').deleteMany({});
  context.app.get(WhatsAppSettingsStore).invalidate();
}

/** Administration of the WhatsApp settings — real application, MongoDB replica set and Redis. */
describe('System settings e2e: WhatsApp', () => {
  let context: AuthTestContext;
  let superAdmin: SignedIn;
  let admin: SignedIn;
  let customer: SignedIn;

  beforeAll(async () => {
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    admin = await seedAndSignIn(context, { roleKeys: ['ADMIN'] });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'] });
  }, 90_000);

  beforeEach(() => resetSettings(context));

  afterAll(async () => {
    await resetSettings(context);
    await context.close();
  }, 60_000);

  const api = () => client(context);
  const read = async (user: SignedIn) =>
    dataOf<WhatsAppSettingsView>(
      await api()
        .get(PATH)
        .set(...bearer(user.tokens))
        .expect(200),
    );
  const change = (user: SignedIn, body: Record<string, unknown>) =>
    api()
      .put(PATH)
      .set(...bearer(user.tokens))
      .send(body);

  describe('access', () => {
    it('requires sign-in', async () => {
      await api().get(PATH).expect(401);
      await api().put(PATH).send({ enabled: false, reason: 'test' }).expect(401);
    });

    it('a customer can neither read nor change the settings', async () => {
      const readAttempt = await api()
        .get(PATH)
        .set(...bearer(customer.tokens))
        .expect(403);
      expect(errorCodeOf(readAttempt)).toBe('PERMISSION_DENIED');
      await change(customer, { enabled: false, reason: 'not allowed' }).expect(403);
    });

    it('an administrator can read but only a super administrator can change', async () => {
      expect((await read(admin)).enabled).toBe(true);
      const attempt = await change(admin, { enabled: false, reason: 'not allowed' }).expect(403);
      expect(errorCodeOf(attempt)).toBe('PERMISSION_DENIED');
      expect((await read(superAdmin)).enabled).toBe(true);
    });
  });

  it('without stored settings the environment configuration is shown', async () => {
    expect(await read(superAdmin)).toEqual({
      provider: 'development',
      status: 'READY',
      missing: [],
      enabled: true,
      businessAccountId: null,
      phoneDisplay: null,
      webhookVerifyToken: { configured: false },
      phoneNumberId: null,
      accessToken: { configured: false, source: 'NONE', lastFour: null },
      otpTemplateName: null,
      otpTemplateLanguage: null,
      otpFallbackToSms: true,
      notificationTemplateName: null,
      notificationTemplateLanguage: null,
      graphApiVersion: null,
      updatedAt: null,
      updatedByUserId: null,
    });
  });

  describe('credentials', () => {
    const credentials = {
      businessAccountId: '102290129340398',
      phoneNumberId: '106540352242922',
      accessToken: TOKEN,
      otpTemplateName: 'abra_login_code',
      otpTemplateLanguage: 'en_US',
      reason: 'Initial WhatsApp Business setup',
    };

    it('the token is stored encrypted and never returned', async () => {
      const response = await change(superAdmin, credentials).expect(200);
      const view = dataOf<WhatsAppSettingsView>(response);
      expect(view).toMatchObject({
        businessAccountId: '102290129340398',
        phoneNumberId: '106540352242922',
        accessToken: { configured: true, source: 'ADMIN', lastFour: 'WXYZ' },
        otpTemplateName: 'abra_login_code',
        otpTemplateLanguage: 'en_US',
        updatedByUserId: superAdmin.id,
      });
      expect(JSON.stringify(response.body)).not.toContain(TOKEN);
      expect(JSON.stringify(await read(admin))).not.toContain(TOKEN);

      const stored = await context.connection
        .collection<{ accessTokenEncrypted: string }>('whatsapp_settings')
        .findOne({});
      expect(JSON.stringify(stored)).not.toContain(TOKEN);
      expect(stored?.accessTokenEncrypted).toMatch(/^v1\./);
      expect(context.app.get(FieldEncryptionService).decrypt(stored!.accessTokenEncrypted)).toBe(
        TOKEN,
      );
    });

    it('a later change keeps the fields that were not sent', async () => {
      await change(superAdmin, credentials).expect(200);
      const view = dataOf<WhatsAppSettingsView>(
        await change(superAdmin, {
          otpTemplateName: 'abra_login_code_v2',
          reason: 'New approved template',
        }).expect(200),
      );
      expect(view.otpTemplateName).toBe('abra_login_code_v2');
      expect(view.phoneNumberId).toBe('106540352242922');
      expect(view.accessToken).toEqual({ configured: true, source: 'ADMIN', lastFour: 'WXYZ' });
    });

    it('null removes the stored token', async () => {
      await change(superAdmin, credentials).expect(200);
      const view = dataOf<WhatsAppSettingsView>(
        await change(superAdmin, { accessToken: null, reason: 'Token revoked' }).expect(200),
      );
      expect(view.accessToken).toEqual({ configured: false, source: 'NONE', lastFour: null });
    });

    it('every change is audited with the reason and without the token', async () => {
      const reason = `Audited setup ${Date.now()}`;
      await change(superAdmin, { ...credentials, reason }).expect(200);
      const entries = dataOf<AuditEntry[]>(
        await api()
          .get('/api/v1/audit-logs?pageSize=100')
          .set(...bearer(superAdmin.tokens))
          .expect(200),
      ).filter((entry) => entry.reason === reason);

      expect(entries).toHaveLength(1);
      expect(entries[0]).toMatchObject({
        actor: { userId: superAdmin.id },
        action: 'settings.whatsapp.changed',
        entityType: 'whatsapp_settings',
        before: { accessTokenSet: false, phoneNumberId: null },
        after: {
          accessTokenSet: true,
          accessTokenChanged: true,
          phoneNumberId: '106540352242922',
          otpTemplateName: 'abra_login_code',
        },
      });
      expect(JSON.stringify(entries)).not.toContain(TOKEN);
      expect(JSON.stringify(entries)).not.toContain('WXYZ');
    });

    it('a refused change is neither stored nor audited', async () => {
      await change(admin, credentials).expect(403);
      expect(await context.connection.collection('whatsapp_settings').countDocuments()).toBe(0);
    });
  });

  describe('validation', () => {
    it.each([
      ['no reason', { enabled: false }],
      ['nothing to change', { reason: 'no fields' }],
      ['a template name with capitals', { otpTemplateName: 'Abra-OTP', reason: 'bad name' }],
      ['a language that is not a code', { otpTemplateLanguage: 'English', reason: 'bad code' }],
      ['a token with spaces', { accessToken: 'not a token at all, just words', reason: 'bad' }],
      ['an id that is not numeric', { phoneNumberId: 'abc', reason: 'bad id' }],
    ])('rejects %s', async (_name, body) => {
      const response = await change(superAdmin, body).expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
      expect(await context.connection.collection('whatsapp_settings').countDocuments()).toBe(0);
    });
  });

  describe('effect on one-time codes', () => {
    const sendOtp = async (phone: string) =>
      dataOf<{ channel: string }>(
        await api().post('/api/v1/auth/otp/send').send({ phone }).expect(200),
      );
    const whatsAppMessages = (phone: string) =>
      (context.whatsApp as DevelopmentWhatsAppProvider).messagesTo(phone);

    it('turning WhatsApp off sends the next code by SMS; turning it on again restores it', async () => {
      const first = uniquePhone();
      expect((await sendOtp(first)).channel).toBe('WHATSAPP');

      const view = dataOf<WhatsAppSettingsView>(
        await change(superAdmin, { enabled: false, reason: 'Meta outage' }).expect(200),
      );
      expect(view.status).toBe('DISABLED');
      const second = uniquePhone();
      expect((await sendOtp(second)).channel).toBe('SMS');
      expect(whatsAppMessages(second)).toEqual([]);

      await change(superAdmin, { enabled: true, reason: 'Outage over' }).expect(200);
      expect((await sendOtp(uniquePhone())).channel).toBe('WHATSAPP');
    });

    it('the template chosen by an administrator is used for the next code', async () => {
      await change(superAdmin, {
        otpTemplateName: 'abra_login_code_v2',
        otpTemplateLanguage: 'en_US',
        reason: 'New approved template',
      }).expect(200);
      const phone = uniquePhone();
      await sendOtp(phone);
      expect(whatsAppMessages(phone)[0]).toMatchObject({
        templateName: 'abra_login_code_v2',
        languageCode: 'en_US',
      });
    });
  });
});

describe('System settings e2e: WhatsApp unavailable', () => {
  const unavailableWhatsApp: WhatsAppProvider = {
    providerKey: 'meta-cloud',
    sendTemplate: () =>
      Promise.reject(new WhatsAppDeliveryError('WhatsApp rejected the message (HTTP 503)')),
  };
  let context: AuthTestContext;
  let superAdmin: SignedIn;

  beforeAll(async () => {
    context = await createAuthTestApp({}, { whatsApp: unavailableWhatsApp });
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    await resetSettings(context);
  }, 90_000);

  afterAll(async () => {
    await resetSettings(context);
    await context.close();
  }, 60_000);

  it('with the SMS fallback turned off, no SMS is sent and the request fails cleanly', async () => {
    const fallback = uniquePhone();
    const sent = await client(context)
      .post('/api/v1/auth/otp/send')
      .send({ phone: fallback })
      .expect(200);
    expect(dataOf<{ channel: string }>(sent).channel).toBe('SMS');

    await client(context)
      .put(PATH)
      .set(...bearer(superAdmin.tokens))
      .send({ otpFallbackToSms: false, reason: 'SMS contract ended' })
      .expect(200);

    const phone = uniquePhone();
    const response = await client(context)
      .post('/api/v1/auth/otp/send')
      .send({ phone })
      .expect(503);
    expect(errorCodeOf(response)).toBe('SERVICE_UNAVAILABLE');
    expect(JSON.stringify(response.body)).not.toMatch(/meta|HTTP 503|whatsapp rejected/i);
    expect(
      (context.sms as unknown as { messagesTo(phone: string): unknown[] }).messagesTo(phone),
    ).toEqual([]);
  });
});
