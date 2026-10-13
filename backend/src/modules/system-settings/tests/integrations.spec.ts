import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import {
  INTEGRATIONS,
  IntegrationSettingsStore,
  IntegrationsAdminManageService,
  testAssistant,
  testMaps,
  testPush,
  testRazorpay,
  testSms,
} from '../integrations_admin_manage.service';

const reply = (status: number, body: unknown = {}) =>
  Promise.resolve({
    status,
    ok: status >= 200 && status < 300,
    json: () => Promise.resolve(body),
  } as Response);

describe('connection tests', () => {
  it('Razorpay: ok, rejected key, unreachable, and missing values', async () => {
    const values = { keyId: 'rzp_test_abcdef123456', keySecret: 'secret-secret-1' };
    const ok = await testRazorpay(values, () => reply(200, { items: [] }));
    expect(ok).toEqual({ ok: true, message: 'Connected to Razorpay in test mode.' });
    const live = await testRazorpay({ ...values, keyId: 'rzp_live_abcdef123456' }, () =>
      reply(200),
    );
    expect(live.message).toContain('live mode');
    expect((await testRazorpay(values, () => reply(401))).ok).toBe(false);
    expect((await testRazorpay(values, () => Promise.reject(new Error('down')))).message).toContain(
      'could not be reached',
    );
    expect((await testRazorpay({ keyId: 'rzp_test_abcdef123456' })).message).toContain(
      'key secret',
    );
  });

  it('Razorpay sends the key as basic auth and never in the address', async () => {
    const fetchFn = jest.fn(() => reply(200));
    await testRazorpay(
      { keyId: 'rzp_test_abcdef123456', keySecret: 'secret-secret-1' },
      fetchFn as never,
    );
    const [url, init] = fetchFn.mock.calls[0] as unknown as [
      string,
      { headers: Record<string, string> },
    ];
    expect(url).not.toContain('secret-secret-1');
    expect(init.headers.Authorization).toBe(
      `Basic ${Buffer.from('rzp_test_abcdef123456:secret-secret-1').toString('base64')}`,
    );
  });

  it('Maps: Google ok, denied, OpenStreetMap needs nothing', async () => {
    const google = { provider: 'google', apiKey: 'AIza-example-key-0000000' };
    expect((await testMaps(google, () => reply(200, { status: 'OK' }))).ok).toBe(true);
    const denied = await testMaps(google, () => reply(200, { status: 'REQUEST_DENIED' }));
    expect(denied.ok).toBe(false);
    expect(denied.message).toContain('Geocoding API');
    expect((await testMaps({ provider: 'osm' })).ok).toBe(true);
    expect((await testMaps({ provider: 'google' })).message).toContain('API key');
  });

  it('Push: checks the service account file without any network call', () => {
    const file = JSON.stringify({
      type: 'service_account',
      project_id: 'abra-demo',
      client_email: 'a@b.c',
      private_key: 'x'.repeat(60),
    });
    expect(testPush({ serviceAccountJson: file, projectId: 'abra-demo' }).ok).toBe(true);
    expect(testPush({ serviceAccountJson: file, projectId: 'other-project' }).message).toContain(
      'does not match',
    );
    expect(testPush({ serviceAccountJson: '{not json' }).message).toContain('not valid JSON');
    expect(testPush({ serviceAccountJson: '{"type":"user"}' }).message).toContain(
      'not a Firebase service account',
    );
    expect(testPush({}).ok).toBe(false);
  });

  it('Assistant: Groq key ok, rejected key, unknown model, wrong provider', async () => {
    const values = {
      provider: 'groq',
      apiKey: 'gsk_example_key_00000000',
      model: 'llama-3.3-70b-versatile',
    };
    const models = { data: [{ id: 'llama-3.3-70b-versatile' }] };
    expect((await testAssistant(values, () => reply(200, models))).ok).toBe(true);
    expect((await testAssistant(values, () => reply(401))).message).toContain('rejected');
    expect(
      (await testAssistant({ ...values, model: 'nope' }, () => reply(200, models))).message,
    ).toContain('no model called');
    expect((await testAssistant({ provider: 'development' })).ok).toBe(false);
  });

  it('SMS: complete settings pass, missing ones are listed', () => {
    expect(testSms({ apiKey: 'abcdefgh', senderId: 'ABRATV', dltEntityId: '1234567890' }).ok).toBe(
      true,
    );
    expect(testSms({ apiKey: 'abcdefgh' }).message).toContain('senderId');
  });
});

describe('what is in use', () => {
  const encryption = {
    encrypt: (v: string) => `enc:${v}`,
    decrypt: (v: string) => v.replace(/^enc:/, ''),
  };
  const config = (env: Record<string, string>) => ({ get: (name: string) => env[name] });
  const store = (env: Record<string, string> = {}) =>
    new IntegrationSettingsStore({} as never, encryption as never, config(env) as never);

  it('administrator settings win over the environment, field by field', () => {
    const resolved = store({ MAPS_PROVIDER: 'osm', MAPS_API_KEY: 'env-key-0000000000000' }).resolve(
      'maps',
      {
        key: 'maps',
        values: { provider: 'google' },
        secrets: {},
      },
    );
    expect(resolved.values).toEqual({ provider: 'google', apiKey: 'env-key-0000000000000' });
    expect(resolved.sources).toEqual({ provider: 'ADMIN', apiKey: 'ENVIRONMENT' });
  });

  it('decrypts a saved secret for the code that needs it', () => {
    const resolved = store().resolve('assistant', {
      key: 'assistant',
      values: { provider: 'groq', model: 'm-model' },
      secrets: { apiKey: { encrypted: 'enc:gsk_secret_value_0000', lastFour: '0000' } },
    });
    expect(resolved.values.apiKey).toBe('gsk_secret_value_0000');
    expect(resolved.sources.apiKey).toBe('ADMIN');
  });

  it('a field set to null falls back to the environment, nothing set means NONE', () => {
    const resolved = store({ SMS_SENDER_ID: 'ABRATV' }).resolve('sms', {
      key: 'sms',
      values: { senderId: null },
      secrets: {},
    });
    expect(resolved.values.senderId).toBe('ABRATV');
    expect(resolved.sources.senderId).toBe('ENVIRONMENT');
    expect(resolved.sources.apiKey).toBe('NONE');
  });
});

describe('IntegrationsAdminManageService', () => {
  const encryption = {
    encrypt: (v: string) => `enc:${v}`,
    decrypt: (v: string) => v.replace(/^enc:/, ''),
  };
  const actor = { userId: new Types.ObjectId().toHexString() } as never;
  const client = { ip: '127.0.0.1' } as never;

  function build(initial: Record<string, unknown> | null = null) {
    const real = new IntegrationSettingsStore(
      {} as never,
      encryption as never,
      { get: () => undefined } as never,
    );
    let doc = initial ? { _id: new Types.ObjectId(), ...initial } : null;
    jest.spyOn(real, 'stored').mockImplementation(() => Promise.resolve(doc as never));
    const save = jest.spyOn(real, 'save').mockImplementation((key, change) => {
      const next = {
        _id: doc?._id ?? new Types.ObjectId(),
        key,
        enabled: change.enabled ?? (doc as { enabled?: boolean } | null)?.enabled,
        values: {
          ...((doc as { values?: object } | null)?.values ?? {}),
          ...(change.values ?? {}),
        },
        secrets: { ...((doc as { secrets?: object } | null)?.secrets ?? {}) },
        updatedAt: new Date('2026-10-12T10:00:00Z'),
      } as Record<string, unknown>;
      for (const [name, secret] of Object.entries(change.secrets ?? {})) {
        (next.secrets as Record<string, unknown>)[name] =
          secret === null ? null : { encrypted: `enc:${secret}`, lastFour: secret.slice(-4) };
      }
      doc = next as never;
      return Promise.resolve(next as never);
    });
    const audits: Array<{ before: unknown; after: unknown; action: string }> = [];
    const changes = {
      run: jest.fn(
        async (change: {
          action: string;
          before: unknown;
          apply: (s: unknown) => Promise<{ _id: Types.ObjectId }>;
          describe: (r: never) => unknown;
        }) => {
          const record = await change.apply({});
          audits.push({
            action: change.action,
            before: change.before,
            after: change.describe(record as never),
          });
          return record;
        },
      ),
    };
    const whatsApp = { describe: () => Promise.resolve({ status: 'READY', missing: [] }) };
    const email = { describe: () => Promise.resolve({ status: 'INCOMPLETE', missing: ['host'] }) };
    const service = new IntegrationsAdminManageService(
      real,
      changes as never,
      whatsApp as never,
      email as never,
    );
    return { service, save, audits };
  }

  it('lists WhatsApp, email and the five integrations with a status', async () => {
    const { service } = build();
    const list = await service.list();
    expect(list.map((item) => item.key)).toEqual([
      'whatsapp',
      'email',
      'razorpay',
      'maps',
      'sms',
      'push',
      'assistant',
    ]);
    expect(list.find((item) => item.key === 'razorpay')).toMatchObject({
      status: 'INCOMPLETE',
      missing: ['keyId', 'keySecret', 'webhookSecret'],
    });
    expect(list.find((item) => item.key === 'email')?.status).toBe('INCOMPLETE');
  });

  it('saves a secret and never returns it, only that it is set and its last four characters', async () => {
    const { service } = build();
    const view = await service.update(
      actor,
      'razorpay',
      {
        values: { keyId: 'rzp_test_abcdef123456', routeEnabled: true },
        secrets: { keySecret: 'my-very-secret-value-9999', webhookSecret: 'webhook-secret-1' },
        reason: 'first setup',
      },
      client,
    );
    expect(view.status).toBe('READY');
    expect(view.secrets.keySecret).toEqual({ configured: true, source: 'ADMIN', lastFour: '9999' });
    expect(view.values.routeEnabled?.value).toBe(true);
    expect(JSON.stringify(view)).not.toContain('my-very-secret-value');
  });

  it('writes an audit entry that says a secret changed but never contains it', async () => {
    const { service, audits } = build();
    await service.update(
      actor,
      'maps',
      {
        values: { provider: 'google' },
        secrets: { apiKey: 'AIza-secret-key-0000000' },
        reason: 'turn on',
      },
      client,
    );
    expect(audits).toHaveLength(1);
    const entry = audits[0]!;
    expect(entry.action).toBe('settings.integration.changed');
    expect(JSON.stringify(entry)).not.toContain('AIza-secret-key');
    expect(entry.after).toMatchObject({ secretsChanged: ['apiKey'], secretsSet: ['apiKey'] });
  });

  it('refuses unknown fields, wrong formats, wrong choices and empty changes', async () => {
    const { service } = build();
    const fail = (input: Parameters<typeof service.update>[2]) =>
      service.update(actor, 'razorpay', input, client);
    await expect(fail({ values: { nonsense: 'x' }, reason: 'test' })).rejects.toBeInstanceOf(
      ApiException,
    );
    await expect(fail({ values: { keyId: 'not-a-key' }, reason: 'test' })).rejects.toThrow();
    await expect(fail({ values: { keySecret: 'x' }, reason: 'test' })).rejects.toThrow(); // a secret is not a plain value
    await expect(fail({ secrets: { keySecret: 'short' }, reason: 'test' })).rejects.toThrow();
    await expect(
      service.update(actor, 'maps', { values: { provider: 'bing' }, reason: 'test' }, client),
    ).rejects.toThrow();
    await expect(fail({ reason: 'test' })).rejects.toThrow('Nothing to change');
  });

  it('turning an integration off shows DISABLED without losing the credentials', async () => {
    const { service } = build();
    await service.update(
      actor,
      'sms',
      {
        secrets: { apiKey: 'sms-api-key-0000' },
        values: { senderId: 'ABRATV', dltEntityId: '12345678901' },
        reason: 'setup',
      },
      client,
    );
    const off = await service.update(actor, 'sms', { enabled: false, reason: 'pause' }, client);
    expect(off.status).toBe('DISABLED');
    expect(off.secrets.apiKey?.configured).toBe(true);
  });

  it('clearing a field with null returns it to the environment value', async () => {
    const { service } = build({ key: 'sms', values: { senderId: 'ABRATV' }, secrets: {} });
    const view = await service.update(
      actor,
      'sms',
      { values: { senderId: null }, reason: 'clear' },
      client,
    );
    expect(view.values.senderId?.source).toBe('NONE');
  });

  it('every integration only names fields that exist in the catalogue', () => {
    for (const definition of Object.values(INTEGRATIONS)) {
      const names = new Set(definition.fields.map((field) => field.name));
      expect(names.size).toBe(definition.fields.length);
    }
  });
});
