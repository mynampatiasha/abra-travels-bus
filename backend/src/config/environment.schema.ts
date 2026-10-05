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

/**
 * Ordered OTP delivery channels: the first that accepts the message is used, the next ones only
 * when it fails. `whatsapp,sms` = WhatsApp, SMS as fallback. Exactly one message is sent.
 */
const otpDeliveryChannels = z
  .string()
  .min(1)
  .transform((value) =>
    value
      .split(',')
      .map((channel) => channel.trim().toLowerCase())
      .filter((channel) => channel.length > 0),
  )
  .pipe(
    z
      .array(z.enum(['whatsapp', 'sms']))
      .min(1)
      .refine((channels) => new Set(channels).size === channels.length, {
        message: 'must not list a channel twice',
      }),
  );

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

  /** Reverse proxies / load balancers in front of the API, so `request.ip` is the real client. */
  TRUST_PROXY_HOPS: z.coerce.number().int().min(0).max(5).default(0),

  MONGODB_URI: z
    .string()
    .regex(/^mongodb(\+srv)?:\/\//, 'must be a mongodb:// or mongodb+srv:// URI'),
  REDIS_URL: z.string().regex(/^rediss?:\/\//, 'must be a redis:// or rediss:// URL'),
  /** Namespace of rate-limit and lockout keys (BullMQ uses QUEUE_PREFIX). */
  REDIS_KEY_PREFIX: z
    .string()
    .regex(/^[a-z0-9-]+$/, 'lowercase letters, digits and dashes only')
    .default('abra'),

  JWT_ACCESS_SECRET: z.string().min(32, 'must be at least 32 characters').optional(),
  JWT_ACCESS_PRIVATE_KEY: optionalText,
  JWT_ACCESS_PUBLIC_KEY: optionalText,
  JWT_ACCESS_TTL_SECONDS: positiveInt,
  REFRESH_TOKEN_TTL_DAYS: positiveInt,
  /** Shorter refresh-token lifetime for staff, operator staff and partner users. */
  REFRESH_TOKEN_TTL_DAYS_STAFF: positiveInt.default(7),
  /** Domain attribute of the web refresh-token cookie; unset = host-only cookie. */
  AUTH_COOKIE_DOMAIN: optionalText,
  JWT_ISSUER: z.string().min(1),
  JWT_AUDIENCE: z.string().min(1),
  FIELD_ENCRYPTION_KEY: base64Key32Bytes,

  OTP_LENGTH: z.coerce.number().int().min(4).max(8),
  OTP_TTL_SECONDS: positiveInt,
  OTP_MAX_VERIFY_ATTEMPTS: positiveInt,
  OTP_MAX_SENDS_PER_WINDOW: positiveInt,
  OTP_SEND_WINDOW_SECONDS: positiveInt,
  OTP_HASH_SECRET: z.string().min(32, 'must be at least 32 characters'),
  /** Minimum time between two OTP messages to the same number. */
  OTP_RESEND_COOLDOWN_SECONDS: positiveInt.default(30),
  OTP_DELIVERY_CHANNELS: otpDeliveryChannels.default(['whatsapp', 'sms']),
  /** Per-IP send limit in the OTP window; higher than per number because carriers share IPs. */
  OTP_MAX_SENDS_PER_IP_PER_WINDOW: positiveInt.default(20),
  LOGIN_MAX_FAILED_ATTEMPTS: positiveInt,
  LOGIN_LOCKOUT_SECONDS: positiveInt,
  /** Sign-in attempts (any identifier) allowed per IP within LOGIN_LOCKOUT_SECONDS. */
  LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW: positiveInt.default(50),
  MFA_TOTP_ISSUER: z.string().min(1),
  /** STAFF accounts must enrol TOTP before their session can do anything else. */
  MFA_REQUIRED_FOR_STAFF: booleanFlag.default(false),
  /** Lifetime of the token that links a password login to its MFA step. */
  MFA_CHALLENGE_TTL_SECONDS: positiveInt.default(300),

  QUEUE_PREFIX: z.string().regex(/^[a-z0-9-]+$/, 'lowercase letters, digits and dashes only'),
  QUEUE_DEFAULT_ATTEMPTS: positiveInt,
  QUEUE_BACKOFF_DELAY_MS: positiveInt,
  WORKER_CONCURRENCY: positiveInt,
  /** Queue whose oldest waiting job is older than this is reported as lagging in readiness. */
  QUEUE_LAG_ALERT_MS: positiveInt.default(60_000),

  // Transactional outbox relay (architecture.md §7)
  OUTBOX_POLL_INTERVAL_MS: positiveInt.default(1_000),
  OUTBOX_BATCH_SIZE: positiveInt.default(100),
  /** How long a relay may hold a claimed event before another relay can take it over. */
  OUTBOX_LEASE_MS: positiveInt.default(30_000),
  /** Publish attempts before an event is parked as FAILED (kept, logged, requeueable). */
  OUTBOX_MAX_PUBLISH_ATTEMPTS: positiveInt.default(20),

  PAYMENT_GATEWAY: z.enum(['razorpay', 'development']),
  RAZORPAY_KEY_ID: optionalText,
  RAZORPAY_KEY_SECRET: optionalText,
  RAZORPAY_WEBHOOK_SECRET: optionalText,

  WHATSAPP_PROVIDER: z.enum(['meta', 'development']),
  WHATSAPP_ACCESS_TOKEN: optionalText,
  WHATSAPP_PHONE_NUMBER_ID: optionalText,
  WHATSAPP_APP_SECRET: optionalText,
  WHATSAPP_VERIFY_TOKEN: optionalText,
  /** Meta Graph API version used for sending, e.g. `v23.0` (pinned on purpose). */
  WHATSAPP_GRAPH_API_VERSION: z
    .string()
    .regex(/^v\d+\.\d+$/, 'must look like v23.0')
    .optional(),
  /** Approved WhatsApp authentication template that carries the one-time code. */
  WHATSAPP_OTP_TEMPLATE_NAME: z
    .string()
    .regex(/^[a-z0-9_]+$/, 'lowercase letters, digits and underscores only')
    .optional(),
  /** Language code of that template, e.g. `en` or `en_US`. */
  WHATSAPP_OTP_TEMPLATE_LANGUAGE: z
    .string()
    .regex(/^[a-z]{2,3}(_[A-Z]{2})?$/, 'must look like en or en_US')
    .optional(),

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
