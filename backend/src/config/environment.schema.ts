import { z } from 'zod';
import { applyEnvironmentRules } from './environment-rules';

/**
 * Every backend environment variable (documentation/environment-variables.md).
 * Values are validated once at start-up; the process refuses to start on any error.
 * Cross-field rules (production safety, provider credentials) live in environment-rules.ts.
 */

const positiveInt = z.coerce.number().int().positive();
const optionalText = z.string().min(1).optional();
const booleanFlag = z.enum(['true', 'false']).transform((value) => value === 'true');

const commaSeparatedOrigins = z
  .string()
  .min(1)
  .transform((value) =>
    value
      .split(',')
      .map((origin) => origin.trim())
      .filter((origin) => origin.length > 0),
  )
  .pipe(z.array(z.url()).min(1));

const base64Key32Bytes = z.string().refine((value) => Buffer.from(value, 'base64').length === 32, {
  message: 'must be 32 random bytes encoded as base64',
});

export const environmentShape = z.object({
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']),
  PORT: z.coerce.number().int().min(1).max(65535),
  PUBLIC_API_BASE_URL: z.url(),
  CORS_ALLOWED_ORIGINS: commaSeparatedOrigins,
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  API_DOCS_ENABLED: booleanFlag.optional(),

  MONGODB_URI: z
    .string()
    .regex(/^mongodb(\+srv)?:\/\//, 'must be a mongodb:// or mongodb+srv:// URI'),
  REDIS_URL: z.string().regex(/^rediss?:\/\//, 'must be a redis:// or rediss:// URL'),

  JWT_ACCESS_SECRET: z.string().min(32, 'must be at least 32 characters').optional(),
  JWT_ACCESS_PRIVATE_KEY: optionalText,
  JWT_ACCESS_PUBLIC_KEY: optionalText,
  JWT_ACCESS_TTL_SECONDS: positiveInt,
  REFRESH_TOKEN_TTL_DAYS: positiveInt,
  JWT_ISSUER: z.string().min(1),
  JWT_AUDIENCE: z.string().min(1),
  FIELD_ENCRYPTION_KEY: base64Key32Bytes,

  OTP_LENGTH: z.coerce.number().int().min(4).max(8),
  OTP_TTL_SECONDS: positiveInt,
  OTP_MAX_VERIFY_ATTEMPTS: positiveInt,
  OTP_MAX_SENDS_PER_WINDOW: positiveInt,
  OTP_SEND_WINDOW_SECONDS: positiveInt,
  OTP_HASH_SECRET: z.string().min(32, 'must be at least 32 characters'),
  LOGIN_MAX_FAILED_ATTEMPTS: positiveInt,
  LOGIN_LOCKOUT_SECONDS: positiveInt,
  MFA_TOTP_ISSUER: z.string().min(1),

  QUEUE_PREFIX: z.string().regex(/^[a-z0-9-]+$/, 'lowercase letters, digits and dashes only'),
  QUEUE_DEFAULT_ATTEMPTS: positiveInt,
  QUEUE_BACKOFF_DELAY_MS: positiveInt,
  WORKER_CONCURRENCY: positiveInt,

  PAYMENT_GATEWAY: z.enum(['razorpay', 'development']),
  RAZORPAY_KEY_ID: optionalText,
  RAZORPAY_KEY_SECRET: optionalText,
  RAZORPAY_WEBHOOK_SECRET: optionalText,

  WHATSAPP_PROVIDER: z.enum(['meta', 'development']),
  WHATSAPP_ACCESS_TOKEN: optionalText,
  WHATSAPP_PHONE_NUMBER_ID: optionalText,
  WHATSAPP_APP_SECRET: optionalText,
  WHATSAPP_VERIFY_TOKEN: optionalText,

  // Real SMS / email providers are an open business decision (implementation-plan.md);
  // their names are added here together with their adapters.
  SMS_PROVIDER: z.enum(['development']),
  SMS_API_KEY: optionalText,
  SMS_SENDER_ID: optionalText,
  SMS_DLT_ENTITY_ID: optionalText,

  EMAIL_PROVIDER: z.enum(['development']),
  EMAIL_API_KEY: optionalText,
  EMAIL_FROM: z.email(),

  PUSH_PROVIDER: z.enum(['fcm', 'development']),
  FCM_SERVICE_ACCOUNT_JSON: optionalText,

  MAPS_PROVIDER: z.enum(['google', 'osm', 'development']),
  MAPS_API_KEY: optionalText,

  AI_PROVIDER: z.enum(['anthropic', 'development']),
  ANTHROPIC_API_KEY: optionalText,
  AI_MODEL: z.string().min(1),

  STORAGE_DRIVER: z.enum(['s3', 'local']),
  STORAGE_LOCAL_ROOT: z.string().min(1).default('./storage'),
  STORAGE_BUCKET: optionalText,
  STORAGE_REGION: optionalText,
  STORAGE_ENDPOINT: z.url().optional(),
  STORAGE_ACCESS_KEY: optionalText,
  STORAGE_SECRET_KEY: optionalText,
});

export const environmentSchema = environmentShape.superRefine(applyEnvironmentRules);

export type AppEnvironment = z.output<typeof environmentSchema>;
