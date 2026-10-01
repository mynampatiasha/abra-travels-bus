import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  DEFAULT_TEST_PASSWORD,
  errorCodeOf,
  expireOtpCooldowns,
  lastOtp,
  seedPasswordUser,
  signInWithOtp,
  type Tokens,
  uniqueEmail,
  uniquePhone,
} from './auth-e2e.harness';

const LOCKOUT_SECONDS = 3;
/** Small, so the attempts fit in the short window (every other test uses a fresh IP per call). */
const MAX_ATTEMPTS_PER_IP = 6;

/** Password sign-in, lockout, password change and reset — real MongoDB + Redis. */
describe('Authentication e2e: password sign-in and password management', () => {
  let context: AuthTestContext;

  beforeAll(async () => {
    context = await createAuthTestApp({
      LOGIN_LOCKOUT_SECONDS: String(LOCKOUT_SECONDS),
      LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW: String(MAX_ATTEMPTS_PER_IP),
    });
  }, 60_000);

  afterAll(async () => {
    await context?.close();
  }, 60_000);

  const login = (identifier: string, password: string, ip?: string) =>
    client(context, ip).post('/api/v1/auth/login').send({ identifier, password });

  describe('sign-in', () => {
    it('signs in with email (any case) and with phone (any common format)', async () => {
      const user = await seedPasswordUser(context, { userType: 'OPERATOR_STAFF' });
      const national = user.phone.slice(3);
      for (const identifier of [
        user.email,
        user.email.toUpperCase(),
        user.phone,
        national,
        `${national.slice(0, 5)} ${national.slice(5)}`,
      ]) {
        const response = await login(identifier, user.password).expect(200);
        expect(dataOf<Tokens>(response).user).toMatchObject({
          id: user.id,
          userType: 'OPERATOR_STAFF',
        });
      }
    });

    it('answers INVALID_CREDENTIALS identically for a wrong password and an unknown account', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const wrongPassword = await login(user.email, 'not the right password').expect(401);
      const unknown = await login(uniqueEmail(), 'not the right password').expect(401);
      const noPassword = await signInWithOtp(context, uniquePhone());
      const otpOnly = await login(
        (await context.users.findById(noPassword.user.id).lean())!.phone!,
        'whatever password',
      ).expect(401);

      for (const response of [wrongPassword, unknown, otpOnly]) {
        expect((response.body as { error: unknown }).error).toEqual({
          code: 'INVALID_CREDENTIALS',
          message: 'The email, phone number or password is incorrect.',
          requestId: expect.any(String) as unknown,
        });
      }
    });

    it('reveals a disabled account only after a correct password', async () => {
      const user = await seedPasswordUser(context, { userType: 'STAFF', status: 'SUSPENDED' });
      expect(errorCodeOf(await login(user.email, 'wrong password!!'))).toBe('INVALID_CREDENTIALS');
      const correct = await login(user.email, user.password).expect(403);
      expect(errorCodeOf(correct)).toBe('ACCOUNT_DISABLED');
    });

    it('never returns credentials', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const response = await login(user.email, user.password).expect(200);
      expect(JSON.stringify(response.body)).not.toMatch(/passwordHash|argon2|secretEncrypted/);
    });
  });

  describe('lockout', () => {
    it('locks the identifier after the configured failures, then lets it in after the lock expires', async () => {
      const user = await seedPasswordUser(context, { userType: 'OPERATOR_STAFF' });
      for (let attempt = 0; attempt < 5; attempt++) {
        await login(user.email, 'wrong password!!').expect(401);
      }
      const locked = await login(user.email, user.password).expect(423);
      expect(locked.body).toMatchObject({
        error: {
          code: 'ACCOUNT_LOCKED',
          details: { retryAfterSeconds: expect.any(Number) as unknown },
        },
      });

      await new Promise((resolve) => setTimeout(resolve, (LOCKOUT_SECONDS + 0.5) * 1000));
      await login(user.email, user.password).expect(200);
    }, 30_000);

    it('locks unknown identifiers the same way (no account enumeration)', async () => {
      const unknown = uniqueEmail();
      for (let attempt = 0; attempt < 5; attempt++) {
        await login(unknown, 'wrong password!!').expect(401);
      }
      expect(errorCodeOf(await login(unknown, 'wrong password!!'))).toBe('ACCOUNT_LOCKED');
    });

    it('counts failures across spellings of the same identifier', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const spellings = [user.email, user.email.toUpperCase(), ` ${user.email} `];
      for (let attempt = 0; attempt < 5; attempt++) {
        await login(spellings[attempt % spellings.length]!, 'wrong password!!').expect(401);
      }
      expect(errorCodeOf(await login(user.email, user.password))).toBe('ACCOUNT_LOCKED');
    });

    it('limits attempts per IP across many identifiers', async () => {
      const ip = '203.0.113.77';
      for (let attempt = 0; attempt < MAX_ATTEMPTS_PER_IP; attempt++) {
        await login(uniqueEmail(), 'wrong password!!', ip).expect(401);
      }
      expect(errorCodeOf(await login(uniqueEmail(), 'wrong password!!', ip))).toBe('RATE_LIMITED');
    }, 60_000);
  });

  describe('password change', () => {
    it('requires the current password, signs out the other devices and keeps this one', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const deviceA = dataOf<Tokens>(await login(user.email, user.password).expect(200));
      const deviceB = dataOf<Tokens>(await login(user.email, user.password).expect(200));

      const wrong = await client(context)
        .post('/api/v1/me/password')
        .set(...bearer(deviceA))
        .send({ currentPassword: 'not my password', newPassword: 'a brand new passphrase' });
      expect(errorCodeOf(wrong)).toBe('INVALID_CREDENTIALS');

      const changed = await client(context)
        .post('/api/v1/me/password')
        .set(...bearer(deviceA))
        .send({ currentPassword: user.password, newPassword: 'a brand new passphrase' })
        .expect(200);
      expect(dataOf(changed)).toEqual({ otherSessionsSignedOut: 1 });

      await client(context)
        .get('/api/v1/me')
        .set(...bearer(deviceA))
        .expect(200);
      await client(context)
        .get('/api/v1/me')
        .set(...bearer(deviceB))
        .expect(401);
      await client(context)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: deviceB.refreshToken })
        .expect(401);

      await login(user.email, user.password).expect(401);
      await login(user.email, 'a brand new passphrase').expect(200);
    });

    it('lets an OTP-only account set its first password without a current one', async () => {
      const phone = uniquePhone();
      const tokens = await signInWithOtp(context, phone);
      await client(context)
        .post('/api/v1/me/password')
        .set(...bearer(tokens))
        .send({ newPassword: 'my first passphrase' })
        .expect(200);
      await login(phone, 'my first passphrase').expect(200);
    });
  });

  describe('password reset by phone OTP', () => {
    it('sets a new password, signs out every device and lifts the lockout', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const sessions = [
        dataOf<Tokens>(await login(user.email, user.password).expect(200)),
        dataOf<Tokens>(await login(user.phone, user.password).expect(200)),
      ];
      for (let attempt = 0; attempt < 5; attempt++) {
        await login(user.email, 'wrong password!!').expect(401);
      }
      expect(errorCodeOf(await login(user.email, user.password))).toBe('ACCOUNT_LOCKED');

      const caller = client(context);
      await caller
        .post('/api/v1/auth/otp/send')
        .send({ phone: user.phone, purpose: 'PASSWORD_RESET' })
        .expect(200);
      await caller
        .post('/api/v1/auth/password/reset')
        .send({
          phone: user.phone,
          code: lastOtp(context, user.phone),
          newPassword: 'reset passphrase 42',
        })
        .expect(200);

      for (const session of sessions) {
        await client(context)
          .get('/api/v1/me')
          .set(...bearer(session))
          .expect(401);
      }
      await login(user.email, user.password).expect(401);
      await login(user.email, 'reset passphrase 42').expect(200);
    });

    it('rejects a wrong reset code and leaves the password unchanged', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const caller = client(context);
      await caller
        .post('/api/v1/auth/otp/send')
        .send({ phone: user.phone, purpose: 'PASSWORD_RESET' })
        .expect(200);
      const code = lastOtp(context, user.phone);
      const response = await caller.post('/api/v1/auth/password/reset').send({
        phone: user.phone,
        code: code === '000000' ? '111111' : '000000',
        newPassword: 'reset passphrase 42',
      });
      expect(errorCodeOf(response)).toBe('OTP_INVALID');
      await login(user.email, DEFAULT_TEST_PASSWORD).expect(200);
    });

    it('does not accept a SIGN_IN code for a reset', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      await expireOtpCooldowns(context);
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone: user.phone }).expect(200);
      const response = await caller.post('/api/v1/auth/password/reset').send({
        phone: user.phone,
        code: lastOtp(context, user.phone),
        newPassword: 'reset passphrase 42',
      });
      expect(errorCodeOf(response)).toBe('OTP_INVALID');
    });
  });
});
