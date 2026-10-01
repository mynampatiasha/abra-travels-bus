import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  EnvironmentValidationError,
  loadEnvironment,
  validateEnvironment,
} from '../environment-loader';
import { validTestEnvironment } from './valid-test-environment';

function problemsOf(raw: Record<string, string | undefined>): string[] {
  try {
    validateEnvironment(raw);
  } catch (error) {
    if (error instanceof EnvironmentValidationError) return [...error.problems];
    throw error;
  }
  return [];
}

/** Production settings with real providers selected and their credentials present. */
function validProductionEnvironment(): Record<string, string | undefined> {
  return validTestEnvironment({
    NODE_ENV: 'production',
    MFA_REQUIRED_FOR_STAFF: 'true',
    JWT_ACCESS_SECRET: undefined,
    JWT_ACCESS_PRIVATE_KEY: 'pem-private',
    JWT_ACCESS_PUBLIC_KEY: 'pem-public',
    PAYMENT_GATEWAY: 'razorpay',
    RAZORPAY_KEY_ID: 'key-id',
    RAZORPAY_KEY_SECRET: 'key-secret',
    RAZORPAY_WEBHOOK_SECRET: 'webhook-secret',
    WHATSAPP_PROVIDER: 'meta',
    WHATSAPP_ACCESS_TOKEN: 'a',
    WHATSAPP_PHONE_NUMBER_ID: 'b',
    WHATSAPP_APP_SECRET: 'c',
    WHATSAPP_VERIFY_TOKEN: 'd',
    PUSH_PROVIDER: 'fcm',
    FCM_SERVICE_ACCOUNT_JSON: '{}',
    MAPS_PROVIDER: 'osm',
    AI_PROVIDER: 'anthropic',
    ANTHROPIC_API_KEY: 'key',
    STORAGE_DRIVER: 's3',
    STORAGE_BUCKET: 'bucket',
    STORAGE_REGION: 'ap-south-1',
    STORAGE_ACCESS_KEY: 'access',
    STORAGE_SECRET_KEY: 'secret',
  });
}

describe('environment validation', () => {
  it('accepts a complete development/test configuration and applies types', () => {
    const environment = validateEnvironment(validTestEnvironment());
    expect(environment.PORT).toBe(4000);
    expect(environment.CORS_ALLOWED_ORIGINS).toEqual([
      'http://localhost:3000',
      'http://localhost:5000',
    ]);
    expect(environment.STORAGE_LOCAL_ROOT).toBe('./storage');
  });

  it('reports every missing required variable by name', () => {
    const problems = problemsOf(
      validTestEnvironment({ MONGODB_URI: undefined, OTP_HASH_SECRET: undefined }),
    );
    expect(problems).toEqual(
      expect.arrayContaining(['MONGODB_URI: is required', 'OTP_HASH_SECRET: is required']),
    );
  });

  it('treats empty values (KEY=) as missing', () => {
    expect(problemsOf(validTestEnvironment({ REDIS_URL: '' }))).toContain('REDIS_URL: is required');
  });

  it('never includes secret values in error messages', () => {
    const secret = 'too-short-secret-value';
    const problems = problemsOf(validTestEnvironment({ JWT_ACCESS_SECRET: secret }));
    expect(problems.join('\n')).toContain('JWT_ACCESS_SECRET');
    expect(problems.join('\n')).not.toContain(secret);
  });

  it('rejects a field encryption key that is not 32 bytes', () => {
    expect(problemsOf(validTestEnvironment({ FIELD_ENCRYPTION_KEY: 'c2hvcnQ=' }))).toContain(
      'FIELD_ENCRYPTION_KEY: must be 32 random bytes encoded as base64',
    );
  });

  it('accepts production real providers and JWT keys, but refuses start until SMS and email providers exist', () => {
    // No real SMS / email adapter is chosen yet (open business decision), so production must not start
    expect(problemsOf(validProductionEnvironment())).toEqual([
      'SMS_PROVIDER: "development" is a development-only adapter and is not allowed in production',
      'EMAIL_PROVIDER: "development" is a development-only adapter and is not allowed in production',
    ]);
  });

  it.each([
    ['PAYMENT_GATEWAY', 'development'],
    ['WHATSAPP_PROVIDER', 'development'],
    ['SMS_PROVIDER', 'development'],
    ['EMAIL_PROVIDER', 'development'],
    ['PUSH_PROVIDER', 'development'],
    ['MAPS_PROVIDER', 'development'],
    ['AI_PROVIDER', 'development'],
    ['STORAGE_DRIVER', 'local'],
  ])('refuses %s=%s in production', (key, value) => {
    const problems = problemsOf({ ...validProductionEnvironment(), [key]: value });
    expect(problems.some((problem) => problem.startsWith(`${key}:`))).toBe(true);
  });

  it('requires MFA for staff in production', () => {
    expect(
      problemsOf({ ...validProductionEnvironment(), MFA_REQUIRED_FOR_STAFF: 'false' }),
    ).toContain('MFA_REQUIRED_FOR_STAFF: must be true in production (staff accounts require MFA)');
    expect(
      problemsOf({ ...validProductionEnvironment(), MFA_REQUIRED_FOR_STAFF: undefined }),
    ).toContain('MFA_REQUIRED_FOR_STAFF: must be true in production (staff accounts require MFA)');
  });

  it('refuses API docs in production', () => {
    const problems = problemsOf({ ...validProductionEnvironment(), API_DOCS_ENABLED: 'true' });
    expect(problems.some((problem) => problem.startsWith('API_DOCS_ENABLED:'))).toBe(true);
  });

  it('requires JWT key pair in production and a JWT secret in development', () => {
    const production = problemsOf({ ...validProductionEnvironment(), JWT_ACCESS_PRIVATE_KEY: '' });
    expect(production).toContain('JWT_ACCESS_PRIVATE_KEY: required in staging and production');

    const development = problemsOf(
      validTestEnvironment({ NODE_ENV: 'development', JWT_ACCESS_SECRET: undefined }),
    );
    expect(development).toContain('JWT_ACCESS_SECRET: required in development and test');
  });

  it('requires provider credentials when a real provider is selected', () => {
    const problems = problemsOf(validTestEnvironment({ PAYMENT_GATEWAY: 'razorpay' }));
    expect(problems).toEqual(
      expect.arrayContaining([
        'RAZORPAY_KEY_ID: required when PAYMENT_GATEWAY=razorpay',
        'RAZORPAY_KEY_SECRET: required when PAYMENT_GATEWAY=razorpay',
        'RAZORPAY_WEBHOOK_SECRET: required when PAYMENT_GATEWAY=razorpay',
      ]),
    );
  });
});

describe('loadEnvironment', () => {
  let directory: string;

  beforeEach(() => {
    directory = mkdtempSync(join(tmpdir(), 'abra-env-'));
  });
  afterEach(() => rmSync(directory, { recursive: true, force: true }));

  it('reads .env.<NODE_ENV> and lets real environment variables win', () => {
    const fileLines = Object.entries(validTestEnvironment({ PORT: '4100' }))
      .map(([key, value]) => `${key}=${value ?? ''}`)
      .join('\n');
    writeFileSync(join(directory, '.env.test'), fileLines);

    const environment = loadEnvironment({ NODE_ENV: 'test', PORT: '4200' }, directory);
    expect(environment.PORT).toBe(4200);
  });

  it('ignores .env files in production', () => {
    writeFileSync(join(directory, '.env.production'), 'PORT=4300');
    expect(() => loadEnvironment({ NODE_ENV: 'production' }, directory)).toThrow(
      EnvironmentValidationError,
    );
  });
});
