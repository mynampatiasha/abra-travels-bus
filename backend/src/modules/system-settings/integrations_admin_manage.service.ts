import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, Schema, Types } from 'mongoose';
import { FieldEncryptionService } from '../../common/crypto/field-encryption.service';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AppConfigService } from '../../config/app-config.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import {
  EmailSettingsAdminService,
  type SettingsTestResult,
} from './services/email-settings-admin.service';
import { WhatsAppSettingsAdminService } from './services/whatsapp-settings-admin.service';

// ===== 0. SCHEMA ====================================================================
// `integration_settings`: one document per integration (Razorpay, Maps, SMS, Push, Assistant).
// WhatsApp and email keep their own documents and endpoints. Secrets are stored encrypted
// (FieldEncryptionService) with only their last four characters readable. The schema sits in
// this file, the one that needs it, so the two feature files never import each other in a circle.

export const INTEGRATION_SETTINGS_MODEL = 'IntegrationSettings';

export const INTEGRATION_KEYS = ['razorpay', 'maps', 'sms', 'push', 'assistant'] as const;
export type IntegrationKey = (typeof INTEGRATION_KEYS)[number];

export interface StoredSecret {
  encrypted: string;
  lastFour: string;
}

export interface IntegrationSettings {
  key: IntegrationKey;
  /** False turns the integration off without removing its credentials. */
  enabled?: boolean;
  /** Plain settings by field name. `null` clears a field back to the environment value. */
  values: Record<string, string | null>;
  secrets: Record<string, StoredSecret | null>;
  updatedByUserId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

export const integrationSettingsSchema = new Schema<IntegrationSettings>(
  {
    key: { type: String, required: true, enum: INTEGRATION_KEYS },
    enabled: { type: Boolean },
    values: { type: Schema.Types.Mixed, default: {} },
    secrets: { type: Schema.Types.Mixed, default: {} },
    updatedByUserId: { type: Schema.Types.ObjectId },
  },
  { collection: 'integration_settings', timestamps: true, versionKey: false, minimize: false },
);
integrationSettingsSchema.index({ key: 1 }, { unique: true });

type StoredIntegration = IntegrationSettings & { _id: Types.ObjectId };

// ===== 1. THE FIVE INTEGRATIONS =====================================================

export interface FieldDefinition {
  name: string;
  label: string;
  /** A secret is write-only: it goes in, only "is set" and its last four characters come out. */
  secret?: boolean;
  /** Name of the environment variable used when nothing is saved here. */
  env?: string;
  /** The values allowed, for a choice. */
  options?: readonly string[];
  /** A value that is not text but true or false. */
  boolean?: boolean;
  pattern?: RegExp;
  patternMessage?: string;
  minLength?: number;
  maxLength?: number;
}

export interface IntegrationDefinition {
  key: IntegrationKey;
  title: string;
  description: string;
  fields: readonly FieldDefinition[];
  /** Names of the fields that must have a value before the integration can work. */
  required: (values: Readonly<Record<string, string | undefined>>) => string[];
}

const missing = (values: Readonly<Record<string, string | undefined>>, names: string[]) =>
  names.filter((name) => !values[name]);

export const INTEGRATIONS: Readonly<Record<IntegrationKey, IntegrationDefinition>> = {
  razorpay: {
    key: 'razorpay',
    title: 'Razorpay',
    description:
      'Online payments, refunds and the automatic split with Razorpay Route. In the Razorpay dashboard, ' +
      'point the webhook to https://<your server>/api/v1/webhooks/payments/razorpay and use the same webhook secret here.',
    fields: [
      {
        name: 'keyId',
        label: 'Key id',
        env: 'RAZORPAY_KEY_ID',
        pattern: /^rzp_(test|live)_[A-Za-z0-9]{6,40}$/,
        patternMessage: 'must look like rzp_test_xxxxxxxx or rzp_live_xxxxxxxx',
      },
      {
        name: 'keySecret',
        label: 'Key secret',
        secret: true,
        env: 'RAZORPAY_KEY_SECRET',
        minLength: 12,
        maxLength: 128,
      },
      {
        name: 'webhookSecret',
        label: 'Webhook secret',
        secret: true,
        env: 'RAZORPAY_WEBHOOK_SECRET',
        minLength: 8,
        maxLength: 128,
      },
      {
        name: 'routeEnabled',
        label: 'Automatic split (Route) is enabled on the account',
        boolean: true,
      },
    ],
    required: (values) => missing(values, ['keyId', 'keySecret', 'webhookSecret']),
  },
  maps: {
    key: 'maps',
    title: 'Maps',
    description: 'Maps, place search and the bus position on the tracking screens.',
    fields: [
      {
        name: 'provider',
        label: 'Provider',
        env: 'MAPS_PROVIDER',
        options: ['google', 'osm', 'development'],
      },
      {
        name: 'apiKey',
        label: 'API key',
        secret: true,
        env: 'MAPS_API_KEY',
        minLength: 20,
        maxLength: 256,
      },
    ],
    required: (values) => (values.provider === 'google' ? missing(values, ['apiKey']) : []),
  },
  sms: {
    key: 'sms',
    title: 'SMS',
    description: 'Text messages for codes and alerts. Needs a provider with DLT registration.',
    fields: [
      {
        name: 'apiKey',
        label: 'API key',
        secret: true,
        env: 'SMS_API_KEY',
        minLength: 8,
        maxLength: 256,
      },
      {
        name: 'senderId',
        label: 'Sender id',
        env: 'SMS_SENDER_ID',
        pattern: /^[A-Za-z0-9]{3,11}$/,
        patternMessage: '3 to 11 letters or digits',
      },
      {
        name: 'dltEntityId',
        label: 'DLT entity id',
        env: 'SMS_DLT_ENTITY_ID',
        pattern: /^\d{8,30}$/,
        patternMessage: 'digits only',
      },
    ],
    required: (values) => missing(values, ['apiKey', 'senderId', 'dltEntityId']),
  },
  push: {
    key: 'push',
    title: 'Push notifications (Firebase)',
    description: 'Push messages to the apps through Firebase Cloud Messaging.',
    fields: [
      {
        name: 'projectId',
        label: 'Firebase project id',
        env: 'FIREBASE_PROJECT_ID',
        pattern: /^[a-z][a-z0-9-]{4,29}$/,
        patternMessage: 'lowercase letters, digits and hyphens',
      },
      {
        name: 'serviceAccountJson',
        label: 'Service account (JSON)',
        secret: true,
        env: 'FCM_SERVICE_ACCOUNT_JSON',
        minLength: 50,
        maxLength: 20_000,
      },
    ],
    required: (values) => missing(values, ['projectId', 'serviceAccountJson']),
  },
  assistant: {
    key: 'assistant',
    title: 'AI assistant (Groq)',
    description:
      'The assistant in every app. It runs on the backend and answers only from data the person may see.',
    fields: [
      { name: 'provider', label: 'Provider', env: 'AI_PROVIDER', options: ['groq', 'development'] },
      {
        name: 'apiKey',
        label: 'API key',
        secret: true,
        env: 'GROQ_API_KEY',
        minLength: 20,
        maxLength: 256,
      },
      {
        name: 'model',
        label: 'Model',
        env: 'AI_MODEL',
        pattern: /^[A-Za-z0-9._:/-]{3,80}$/,
        patternMessage: 'a model name such as llama-3.3-70b-versatile',
      },
      {
        name: 'allowActions',
        label: 'The assistant may propose actions (each one still needs a confirmation)',
        boolean: true,
      },
    ],
    required: (values) => (values.provider === 'groq' ? missing(values, ['apiKey', 'model']) : []),
  },
};

export function isIntegrationKey(value: string): value is IntegrationKey {
  return (INTEGRATION_KEYS as readonly string[]).includes(value);
}

// ===== 2. STORE: what is saved, and what is in use ===================================

export type SettingSource = 'ADMIN' | 'ENVIRONMENT' | 'NONE';

export interface EffectiveIntegration {
  enabled: boolean;
  /** Plain values in use. Secrets are decrypted here for the code that needs them, in memory only. */
  values: Record<string, string | undefined>;
  sources: Record<string, SettingSource>;
}

const CACHE_MS = 15_000;

/**
 * Reads and writes the saved settings of the five integrations and works out what is in use:
 * administrator settings over the environment, field by field. Other modules (payments, maps,
 * assistant) call `effective` to get the credentials; nothing here is ever returned by an API.
 */
@Injectable()
export class IntegrationSettingsStore {
  private readonly cache = new Map<IntegrationKey, { value: EffectiveIntegration; at: number }>();

  constructor(
    @InjectModel(INTEGRATION_SETTINGS_MODEL) private readonly model: Model<IntegrationSettings>,
    private readonly encryption: FieldEncryptionService,
    private readonly config: AppConfigService,
  ) {}

  stored(key: IntegrationKey, session?: ClientSession): Promise<StoredIntegration | null> {
    return this.model
      .findOne({ key })
      .session(session ?? null)
      .lean<StoredIntegration>()
      .exec();
  }

  async save(
    key: IntegrationKey,
    change: {
      enabled?: boolean | undefined;
      values?: Record<string, string | null>;
      secrets?: Record<string, string | null>;
    },
    updatedByUserId: Types.ObjectId,
    session: ClientSession,
  ): Promise<StoredIntegration> {
    const set: Record<string, unknown> = { updatedByUserId };
    if (change.enabled !== undefined) set.enabled = change.enabled;
    for (const [name, value] of Object.entries(change.values ?? {})) set[`values.${name}`] = value;
    for (const [name, secret] of Object.entries(change.secrets ?? {})) {
      set[`secrets.${name}`] =
        secret === null
          ? null
          : { encrypted: this.encryption.encrypt(secret), lastFour: secret.slice(-4) };
    }
    const saved = await this.model
      .findOneAndUpdate(
        { key },
        { $set: set, $setOnInsert: { key } },
        { upsert: true, returnDocument: 'after', session },
      )
      .lean<StoredIntegration>()
      .exec();
    if (!saved) throw new Error(`Integration settings "${key}" could not be saved`);
    return saved;
  }

  invalidate(key: IntegrationKey): void {
    this.cache.delete(key);
  }

  async effective(key: IntegrationKey): Promise<EffectiveIntegration> {
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.at < CACHE_MS) return cached.value;
    const value = this.resolve(key, await this.stored(key));
    this.cache.set(key, { value, at: Date.now() });
    return value;
  }

  resolve(key: IntegrationKey, stored: IntegrationSettings | null): EffectiveIntegration {
    const values: Record<string, string | undefined> = {};
    const sources: Record<string, SettingSource> = {};
    for (const field of INTEGRATIONS[key].fields) {
      const own = field.secret ? stored?.secrets?.[field.name] : stored?.values?.[field.name];
      const fromAdmin =
        own === undefined || own === null
          ? undefined
          : typeof own === 'string'
            ? own
            : this.encryption.decrypt(own.encrypted);
      const fromEnvironment = field.env ? this.environmentValue(field.env) : undefined;
      values[field.name] = fromAdmin ?? fromEnvironment;
      sources[field.name] =
        fromAdmin !== undefined ? 'ADMIN' : fromEnvironment ? 'ENVIRONMENT' : 'NONE';
    }
    return { enabled: stored?.enabled ?? true, values, sources };
  }

  private environmentValue(name: string): string | undefined {
    const value = (this.config as unknown as { get(key: string): unknown }).get(name);
    return typeof value === 'string' && value.length > 0 ? value : undefined;
  }
}

// ===== 3. CONNECTION TESTS ==========================================================
// A test asks the provider a harmless question and never sends anything to a customer. A failed
// test is a normal answer (ok: false) with the reason in words for people.

type FetchFunction = typeof fetch;
const TIMEOUT_MS = 10_000;

async function ask(fetchFn: FetchFunction, url: string, headers: Record<string, string>) {
  try {
    return await fetchFn(url, { headers, signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch {
    return undefined;
  }
}

export async function testRazorpay(
  values: Record<string, string | undefined>,
  fetchFn: FetchFunction = fetch,
): Promise<SettingsTestResult> {
  if (!values.keyId || !values.keySecret) {
    return { ok: false, message: 'Save the key id and the key secret first.' };
  }
  const basic = Buffer.from(`${values.keyId}:${values.keySecret}`).toString('base64');
  const response = await ask(fetchFn, 'https://api.razorpay.com/v1/orders?count=1', {
    Authorization: `Basic ${basic}`,
  });
  if (!response)
    return {
      ok: false,
      message: 'Razorpay could not be reached. Check the internet connection and try again.',
    };
  if (response.status === 401)
    return { ok: false, message: 'Razorpay rejected the key id or the key secret.' };
  if (!response.ok)
    return { ok: false, message: `Razorpay refused the request (HTTP ${response.status}).` };
  const mode = values.keyId.startsWith('rzp_live_') ? 'live' : 'test';
  // The keys alone are not enough to confirm a payment made after the app is closed: that needs the webhook secret
  const webhook = values.webhookSecret
    ? ''
    : ' The webhook secret is not saved yet: without it, a payment made after the customer closes the app cannot confirm the booking.';
  return { ok: true, message: `Connected to Razorpay in ${mode} mode.${webhook}` };
}

export async function testMaps(
  values: Record<string, string | undefined>,
  fetchFn: FetchFunction = fetch,
): Promise<SettingsTestResult> {
  if (values.provider === 'osm')
    return { ok: true, message: 'OpenStreetMap needs no key. Nothing to test.' };
  if (values.provider !== 'google')
    return { ok: false, message: 'Choose a provider and save first.' };
  if (!values.apiKey) return { ok: false, message: 'Save the API key first.' };
  const url = `https://maps.googleapis.com/maps/api/geocode/json?address=Hyderabad&key=${encodeURIComponent(values.apiKey)}`;
  const response = await ask(fetchFn, url, {});
  if (!response)
    return {
      ok: false,
      message: 'Google could not be reached. Check the internet connection and try again.',
    };
  const body = (await response.json().catch(() => ({}))) as { status?: string };
  if (body.status === 'OK')
    return { ok: true, message: 'Google accepted the key (place search works).' };
  if (body.status === 'REQUEST_DENIED') {
    return {
      ok: false,
      message:
        'Google refused the key. Check that the Geocoding API is turned on, billing is attached and the key has no wrong restriction.',
    };
  }
  return { ok: false, message: `Google answered ${body.status ?? 'with an error'}.` };
}

export function testSms(values: Record<string, string | undefined>): SettingsTestResult {
  const absent = INTEGRATIONS.sms.required(values);
  if (absent.length > 0) return { ok: false, message: `Still missing: ${absent.join(', ')}.` };
  return {
    ok: true,
    message:
      'The settings are complete. This server uses the development SMS adapter, so no message is sent to test them.',
  };
}

export function testPush(values: Record<string, string | undefined>): SettingsTestResult {
  if (!values.serviceAccountJson)
    return { ok: false, message: 'Save the service account JSON first.' };
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(values.serviceAccountJson) as Record<string, unknown>;
  } catch {
    return {
      ok: false,
      message:
        'The service account is not valid JSON. Paste the whole file downloaded from Firebase.',
    };
  }
  if (
    parsed.type !== 'service_account' ||
    typeof parsed.client_email !== 'string' ||
    typeof parsed.private_key !== 'string'
  ) {
    return {
      ok: false,
      message:
        'This is not a Firebase service account file (client_email or private_key is missing).',
    };
  }
  if (values.projectId && parsed.project_id !== values.projectId) {
    return {
      ok: false,
      message: 'The project id does not match the project in the service account file.',
    };
  }
  return {
    ok: true,
    message: `The service account for project ${String(parsed.project_id)} is complete.`,
  };
}

export async function testAssistant(
  values: Record<string, string | undefined>,
  fetchFn: FetchFunction = fetch,
): Promise<SettingsTestResult> {
  if (values.provider !== 'groq')
    return { ok: false, message: 'Choose Groq as the provider and save first.' };
  if (!values.apiKey) return { ok: false, message: 'Save the API key first.' };
  const response = await ask(fetchFn, 'https://api.groq.com/openai/v1/models', {
    Authorization: `Bearer ${values.apiKey}`,
  });
  if (!response)
    return {
      ok: false,
      message: 'Groq could not be reached. Check the internet connection and try again.',
    };
  if (response.status === 401) return { ok: false, message: 'Groq rejected the API key.' };
  if (!response.ok)
    return { ok: false, message: `Groq refused the request (HTTP ${response.status}).` };
  const body = (await response.json().catch(() => ({}))) as { data?: Array<{ id?: string }> };
  const known = (body.data ?? []).map((model) => model.id);
  if (values.model && known.length > 0 && !known.includes(values.model)) {
    return {
      ok: false,
      message: `Groq accepted the key, but it has no model called "${values.model}".`,
    };
  }
  return {
    ok: true,
    message: `Groq accepted the key${values.model ? ` and the model ${values.model}` : ''}.`,
  };
}

// ===== 4. VIEWS =====================================================================

export type IntegrationStatus = 'READY' | 'DISABLED' | 'INCOMPLETE';

export interface IntegrationView {
  key: IntegrationKey;
  title: string;
  description: string;
  status: IntegrationStatus;
  /** Fields that are missing when status is INCOMPLETE. */
  missing: string[];
  enabled: boolean;
  values: Record<string, { value: string | boolean | null; source: SettingSource }>;
  /** Secrets are never returned: only whether one is set, where it comes from and its last four characters. */
  secrets: Record<string, { configured: boolean; source: SettingSource; lastFour: string | null }>;
  updatedAt: string | null;
  updatedByUserId: string | null;
}

export interface IntegrationSummary {
  key: string;
  title: string;
  status: IntegrationStatus;
  missing: string[];
}

// ===== 5. THE ADMIN SERVICE =========================================================

export interface IntegrationChange {
  enabled?: boolean | undefined;
  values?: Record<string, string | boolean | null> | undefined;
  secrets?: Record<string, string | null> | undefined;
  reason: string;
}

function invalid(path: string, message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path, code: 'custom', message }],
  });
}

/**
 * The admin "Settings and integrations" page for Razorpay, Maps, SMS, Push and the assistant
 * (WhatsApp and email have their own endpoints and appear here only as summaries). Credentials go
 * in and never come out; every change is audited without any secret.
 */
@Injectable()
export class IntegrationsAdminManageService {
  constructor(
    private readonly store: IntegrationSettingsStore,
    private readonly changes: AuditedChangeRunner,
    private readonly whatsApp: WhatsAppSettingsAdminService,
    private readonly email: EmailSettingsAdminService,
  ) {}

  /** One line per integration for the cards on the Settings page. */
  async list(): Promise<IntegrationSummary[]> {
    const [whatsApp, email] = await Promise.all([this.whatsApp.describe(), this.email.describe()]);
    const own = await Promise.all(INTEGRATION_KEYS.map((key) => this.describe(key)));
    return [
      {
        key: 'whatsapp',
        title: 'WhatsApp Business',
        status: whatsApp.status,
        missing: whatsApp.missing,
      },
      { key: 'email', title: 'Email (SMTP)', status: email.status, missing: email.missing },
      ...own.map((view) => ({
        key: view.key,
        title: view.title,
        status: view.status,
        missing: view.missing,
      })),
    ];
  }

  async describe(key: IntegrationKey): Promise<IntegrationView> {
    return this.view(key, await this.store.stored(key));
  }

  async testConnection(key: IntegrationKey): Promise<SettingsTestResult> {
    const { values } = await this.store.effective(key);
    switch (key) {
      case 'razorpay':
        return testRazorpay(values);
      case 'maps':
        return testMaps(values);
      case 'sms':
        return testSms(values);
      case 'push':
        return testPush(values);
      case 'assistant':
        return testAssistant(values);
    }
  }

  async update(
    actor: AuthenticatedUserActor,
    key: IntegrationKey,
    input: IntegrationChange,
    client: ClientRequestInfo,
  ): Promise<IntegrationView> {
    const { reason, enabled, values: rawValues, secrets } = input;
    const definition = INTEGRATIONS[key];
    const values: Record<string, string | null> = {};
    for (const [name, value] of Object.entries(rawValues ?? {})) {
      const field = definition.fields.find(
        (candidate) => candidate.name === name && !candidate.secret,
      );
      if (!field) throw invalid(`values.${name}`, 'is not a setting of this integration');
      values[name] = this.checkedValue(field, value, `values.${name}`);
    }
    for (const [name, secret] of Object.entries(secrets ?? {})) {
      const field = definition.fields.find(
        (candidate) => candidate.name === name && candidate.secret,
      );
      if (!field) throw invalid(`secrets.${name}`, 'is not a secret of this integration');
      if (secret !== null) this.checkedValue(field, secret, `secrets.${name}`);
    }
    if (
      enabled === undefined &&
      Object.keys(values).length === 0 &&
      Object.keys(secrets ?? {}).length === 0
    ) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }

    const before = await this.store.stored(key);
    const saved = await this.changes.run<StoredIntegration>({
      actor,
      client,
      action: 'settings.integration.changed',
      entityType: `integration_settings:${key}`,
      before: this.auditState(before),
      reason,
      apply: (session) =>
        this.store.save(
          key,
          { enabled, values, ...(secrets ? { secrets } : {}) },
          new Types.ObjectId(actor.userId),
          session,
        ),
      describe: (record) => ({
        ...this.auditState(record),
        // Says that a secret was replaced or removed, never what it is
        ...(secrets && Object.keys(secrets).length > 0
          ? { secretsChanged: Object.keys(secrets) }
          : {}),
      }),
    });
    this.store.invalidate(key);
    return this.view(key, saved);
  }

  private checkedValue(
    field: FieldDefinition,
    value: string | boolean | null,
    path: string,
  ): string | null {
    if (value === null) return null;
    if (field.boolean) {
      if (typeof value !== 'boolean') throw invalid(path, 'must be true or false');
      return value ? 'true' : 'false';
    }
    if (typeof value !== 'string') throw invalid(path, 'must be text');
    const text = field.secret ? value : value.trim();
    if (field.options && !field.options.includes(text))
      throw invalid(path, `must be one of: ${field.options.join(', ')}`);
    if (field.minLength !== undefined && text.length < field.minLength)
      throw invalid(path, `is too short (at least ${field.minLength} characters)`);
    if (field.maxLength !== undefined && text.length > field.maxLength)
      throw invalid(path, `is too long (at most ${field.maxLength} characters)`);
    if (field.pattern && !field.pattern.test(text))
      throw invalid(path, field.patternMessage ?? 'has the wrong format');
    return text;
  }

  private view(key: IntegrationKey, stored: IntegrationSettings | null): IntegrationView {
    const definition = INTEGRATIONS[key];
    const effective = this.store.resolve(key, stored);
    const absent = definition.required(effective.values);
    const values: IntegrationView['values'] = {};
    const secrets: IntegrationView['secrets'] = {};
    for (const field of definition.fields) {
      const source = effective.sources[field.name] ?? 'NONE';
      if (field.secret) {
        const own = stored?.secrets?.[field.name];
        secrets[field.name] = {
          configured: effective.values[field.name] !== undefined,
          source,
          lastFour: source === 'ADMIN' ? (own?.lastFour ?? null) : null,
        };
      } else {
        const raw = effective.values[field.name];
        values[field.name] = {
          value: raw === undefined ? null : field.boolean ? raw === 'true' : raw,
          source,
        };
      }
    }
    return {
      key,
      title: definition.title,
      description: definition.description,
      status: !effective.enabled ? 'DISABLED' : absent.length > 0 ? 'INCOMPLETE' : 'READY',
      missing: absent,
      enabled: effective.enabled,
      values,
      secrets,
      updatedAt: stored?.updatedAt?.toISOString() ?? null,
      updatedByUserId: stored?.updatedByUserId?.toHexString() ?? null,
    };
  }

  /** What is written to the audit trail: settings and which secrets are set, never a secret. */
  private auditState(stored: IntegrationSettings | null): Record<string, unknown> {
    return {
      enabled: stored?.enabled ?? null,
      values: stored?.values ?? {},
      secretsSet: Object.entries(stored?.secrets ?? {})
        .filter(([, secret]) => secret !== null)
        .map(([name]) => name),
    };
  }
}
