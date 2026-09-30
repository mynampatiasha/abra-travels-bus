import { randomBytes } from 'node:crypto';

/**
 * A complete, valid development-style environment for tests. Secrets are generated randomly per
 * test run and never written to disk. MongoDB / Redis point at the local Docker infrastructure
 * unless overridden by the real environment.
 */
export function validTestEnvironment(
  overrides: Record<string, string | undefined> = {},
): Record<string, string | undefined> {
  return {
    NODE_ENV: 'test',
    PORT: '4000',
    PUBLIC_API_BASE_URL: 'http://localhost:4000',
    CORS_ALLOWED_ORIGINS: 'http://localhost:3000,http://localhost:5000',
    LOG_LEVEL: 'warn',
    MONGODB_URI:
      process.env.MONGODB_URI ??
      'mongodb://localhost:27017/abra_travels_test?directConnection=true',
    REDIS_URL: process.env.REDIS_URL ?? 'redis://localhost:6379',
    JWT_ACCESS_SECRET: randomBytes(64).toString('base64'),
    JWT_ACCESS_TTL_SECONDS: '900',
    REFRESH_TOKEN_TTL_DAYS: '30',
    JWT_ISSUER: 'abra-travels',
    JWT_AUDIENCE: 'abra-travels-apps',
    FIELD_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
    OTP_LENGTH: '6',
    OTP_TTL_SECONDS: '300',
    OTP_MAX_VERIFY_ATTEMPTS: '5',
    OTP_MAX_SENDS_PER_WINDOW: '3',
    OTP_SEND_WINDOW_SECONDS: '900',
    OTP_HASH_SECRET: randomBytes(32).toString('base64'),
    LOGIN_MAX_FAILED_ATTEMPTS: '5',
    LOGIN_LOCKOUT_SECONDS: '900',
    MFA_TOTP_ISSUER: 'Abra Travels',
    QUEUE_PREFIX: 'abra-test',
    QUEUE_DEFAULT_ATTEMPTS: '5',
    QUEUE_BACKOFF_DELAY_MS: '5000',
    WORKER_CONCURRENCY: '5',
    PAYMENT_GATEWAY: 'development',
    WHATSAPP_PROVIDER: 'development',
    SMS_PROVIDER: 'development',
    EMAIL_PROVIDER: 'development',
    EMAIL_FROM: 'no-reply@abratravels.local',
    PUSH_PROVIDER: 'development',
    MAPS_PROVIDER: 'development',
    AI_PROVIDER: 'development',
    AI_MODEL: 'claude-sonnet-5-5',
    STORAGE_DRIVER: 'local',
    ...overrides,
  };
}
