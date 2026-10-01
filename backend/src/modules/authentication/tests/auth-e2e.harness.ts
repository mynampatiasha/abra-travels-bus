import { randomBytes, randomInt } from 'node:crypto';
import { getConnectionToken, getModelToken } from '@nestjs/mongoose';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { Redis } from 'ioredis';
import { type Connection, type Model } from 'mongoose';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../../../app.module';
import { validTestEnvironment } from '../../../config/tests/valid-test-environment';
import { configureHttpApplication } from '../../../configure-http-application';
import { type DevelopmentSmsProvider } from '../../../integrations/sms/development-sms.provider';
import { SMS_PROVIDER } from '../../../integrations/sms/sms-provider.interface';
import { deleteQueueKeys, uniqueQueuePrefix } from '../../../queues/tests/queue-test-support';
import { USER_MODEL, type User, type UserStatus } from '../../users/schemas/user.schema';
import { PasswordHasher } from '../services/password-hasher.service';

/**
 * Real authentication e2e harness: the full AppModule over HTTP against the Docker MongoDB
 * replica set (disposable `abra_travels_test` database) and Redis (unique key prefix per suite).
 * Every test uses its own phone number, email and client IP, so limits never leak between tests.
 * The development SMS adapter (in-memory inbox) delivers the OTP codes.
 */
export interface AuthTestContext {
  app: NestExpressApplication;
  server: App;
  jwtSecret: string;
  sms: DevelopmentSmsProvider;
  users: Model<User>;
  connection: Connection;
  /** Redis key prefix of this suite (rate limits, lockouts, queues). */
  prefix: string;
  close(): Promise<void>;
}

export const DEFAULT_TEST_PASSWORD = 'correct horse battery staple';

export async function createAuthTestApp(
  overrides: Record<string, string> = {},
): Promise<AuthTestContext> {
  const prefix = uniqueQueuePrefix();
  const jwtSecret = randomBytes(48).toString('base64');
  Object.assign(
    process.env,
    validTestEnvironment({
      LOG_LEVEL: 'fatal',
      API_DOCS_ENABLED: 'false',
      QUEUE_PREFIX: prefix,
      REDIS_KEY_PREFIX: prefix,
      JWT_ACCESS_SECRET: jwtSecret,
      // Each test sends its own X-Forwarded-For, so per-IP limits are per test
      TRUST_PROXY_HOPS: '1',
      ...overrides,
    }),
  );
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication<NestExpressApplication>({ logger: false });
  configureHttpApplication(app);
  await app.init();

  const connection = app.get<Connection>(getConnectionToken());
  return {
    app,
    server: app.getHttpServer(),
    jwtSecret,
    sms: app.get<DevelopmentSmsProvider>(SMS_PROVIDER),
    users: app.get<Model<User>>(getModelToken(USER_MODEL)),
    connection,
    prefix,
    async close() {
      try {
        await connection.dropDatabase();
      } finally {
        await app.close();
        await deleteQueueKeys(process.env.REDIS_URL ?? 'redis://localhost:6379', prefix);
      }
    },
  };
}

/**
 * Simulates the OTP resend cooldown elapsing (like moving an OTP's expiresAt into the past), so
 * a test can send a second code to the same number. Only this suite's keys are touched.
 */
export async function expireOtpCooldowns(context: AuthTestContext): Promise<void> {
  const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');
  try {
    let cursor = '0';
    do {
      const [next, keys] = await redis.scan(cursor, 'MATCH', `${context.prefix}:otp:cooldown:*`);
      cursor = next;
      if (keys.length > 0) await redis.del(...keys);
    } while (cursor !== '0');
  } finally {
    redis.disconnect();
  }
}

/** A fresh Indian mobile number in E.164 form. */
export function uniquePhone(): string {
  return `+919${randomInt(100_000_000, 999_999_999)}`;
}

export function uniqueEmail(): string {
  return `user-${randomBytes(5).toString('hex')}@example.test`;
}

/** A documentation-range IP (TEST-NET-2) unique to the caller. */
export function uniqueIp(): string {
  return `198.51.${randomInt(0, 255)}.${randomInt(1, 254)}`;
}

/** Supertest agent bound to one client IP. */
export function client(context: AuthTestContext, ip: string = uniqueIp()) {
  const agent = request(context.server);
  return {
    ip,
    post: (path: string) => agent.post(path).set('X-Forwarded-For', ip),
    get: (path: string) => agent.get(path).set('X-Forwarded-For', ip),
    delete: (path: string) => agent.delete(path).set('X-Forwarded-For', ip),
  };
}

export function lastOtp(context: AuthTestContext, phone: string): string {
  const body = context.sms.lastMessageTo(phone)?.body;
  const code = body ? /^(\d{4,8}) /.exec(body)?.[1] : undefined;
  if (!code) throw new Error(`No OTP was sent to ${phone}`);
  return code;
}

export interface Tokens {
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  user: { id: string; userType: string };
  mfaEnrollmentRequired: boolean;
}

export function bearer(tokens: Pick<Tokens, 'accessToken'>): [string, string] {
  return ['Authorization', `Bearer ${tokens.accessToken}`];
}

/** Sends a SIGN_IN code and signs in with it (creates the customer on first use). */
export async function signInWithOtp(
  context: AuthTestContext,
  phone: string,
  ip?: string,
): Promise<Tokens> {
  const caller = client(context, ip);
  await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
  const response = await caller
    .post('/api/v1/auth/otp/verify')
    .send({ phone, code: lastOtp(context, phone) })
    .expect(200);
  return (response.body as { data: Tokens }).data;
}

/** Inserts a password account directly (staff and partner accounts have no sign-up endpoint). */
export async function seedPasswordUser(
  context: AuthTestContext,
  input: {
    userType: User['userType'];
    email?: string;
    phone?: string;
    password?: string;
    status?: UserStatus;
  },
): Promise<{ id: string; email: string; phone: string; password: string }> {
  const email = input.email ?? uniqueEmail();
  const phone = input.phone ?? uniquePhone();
  const password = input.password ?? DEFAULT_TEST_PASSWORD;
  const passwordHash = await context.app.get(PasswordHasher).hash(password);
  const [created] = await context.users.create([
    {
      email,
      phone,
      passwordHash,
      passwordChangedAt: new Date(),
      userType: input.userType,
      roleIds: [],
      dataScope: { type: input.userType === 'CUSTOMER' ? 'OWN_RECORDS' : 'ALL', operatorIds: [] },
      status: input.status ?? 'ACTIVE',
      permissionVersion: 1,
      mfa: { enabled: false, recoveryCodeHashes: [] },
      preferredLanguage: 'en',
    },
  ]);
  return { id: created!._id.toHexString(), email, phone, password };
}

export function dataOf<T>(response: { body: unknown }): T {
  return (response.body as { data: T }).data;
}

export function errorCodeOf(response: { body: unknown }): string | undefined {
  return (response.body as { error?: { code?: string } }).error?.code;
}
