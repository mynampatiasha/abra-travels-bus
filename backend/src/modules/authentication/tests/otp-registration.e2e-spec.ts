import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  expireOtpCooldowns,
  lastOtp,
  seedPasswordUser,
  signInWithOtp,
  type Tokens,
  uniqueEmail,
  uniquePhone,
} from './auth-e2e.harness';

/** Phone OTP, customer registration, the global guard and /me — real MongoDB + Redis. */
describe('Authentication e2e: OTP, registration, guard, /me', () => {
  let context: AuthTestContext;

  beforeAll(async () => {
    context = await createAuthTestApp();
  }, 60_000);

  afterAll(async () => {
    await context?.close();
  }, 60_000);

  describe('authentication guard', () => {
    it('keeps public endpoints reachable without a token', async () => {
      const caller = client(context);
      await caller.get('/health/live').expect(200);
      await caller.post('/api/v1/auth/otp/send').send({ phone: uniquePhone() }).expect(200);
    });

    it('answers 401 UNAUTHENTICATED on a protected endpoint without a token', async () => {
      const caller = client(context);
      for (const path of ['/api/v1/me', '/api/v1/me/sessions', '/api/v1/me/mfa']) {
        const response = await caller.get(path).expect(401);
        expect(errorCodeOf(response)).toBe('UNAUTHENTICATED');
      }
    });

    it('rejects malformed and forged bearer tokens', async () => {
      const caller = client(context);
      for (const value of ['Bearer abc', 'Basic dXNlcjpwYXNz', 'Bearer ' + 'x'.repeat(40)]) {
        const response = await caller.get('/api/v1/me').set('Authorization', value).expect(401);
        expect(errorCodeOf(response)).toBe('UNAUTHENTICATED');
      }
    });
  });

  describe('phone OTP', () => {
    it('sends a code without ever returning it', async () => {
      const phone = uniquePhone();
      const response = await client(context)
        .post('/api/v1/auth/otp/send')
        .send({ phone: phone.slice(3) }) // national format is normalised
        .expect(200);
      expect(dataOf(response)).toEqual({ expiresInSeconds: 300, resendAfterSeconds: 30 });
      const code = lastOtp(context, phone);
      expect(JSON.stringify(response.body)).not.toContain(code);
    });

    it('verifies the code, creates the customer on first use and reuses it afterwards', async () => {
      const phone = uniquePhone();
      const first = await signInWithOtp(context, phone);
      expect(first).toMatchObject({
        user: { userType: 'CUSTOMER', phone, hasPassword: false },
        mfaEnrollmentRequired: false,
      });
      expect(first.accessToken).toEqual(expect.any(String));
      expect(first.refreshToken).toEqual(expect.any(String));

      const stored = await context.users.find({ phone }).lean();
      expect(stored).toHaveLength(1);
      expect(stored[0]).toMatchObject({ userType: 'CUSTOMER', status: 'ACTIVE' });
      expect(stored[0]?.phoneVerifiedAt).toBeInstanceOf(Date);
      const profiles = await context.connection
        .collection('customers')
        .countDocuments({ userId: stored[0]?._id });
      expect(profiles).toBe(1);

      await expireOtpCooldowns(context);
      const second = await signInWithOtp(context, phone);
      expect(second.user.id).toBe(first.user.id);
      expect(await context.users.countDocuments({ phone })).toBe(1);
    });

    it('stores only a keyed hash of the code', async () => {
      const phone = uniquePhone();
      await client(context).post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      const challenge = await context.connection
        .collection('otp_challenges')
        .findOne({ target: phone });
      expect(challenge?.codeHash).toMatch(/^[0-9a-f]{64}$/);
      expect(JSON.stringify(challenge)).not.toContain(`"${lastOtp(context, phone)}"`);
    });

    it('rejects a wrong code with OTP_INVALID and still accepts the right one afterwards', async () => {
      const phone = uniquePhone();
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      const code = lastOtp(context, phone);
      const wrong = code === '000000' ? '111111' : '000000';

      const rejected = await caller.post('/api/v1/auth/otp/verify').send({ phone, code: wrong });
      expect(rejected.status).toBe(401);
      expect(errorCodeOf(rejected)).toBe('OTP_INVALID');
      await caller.post('/api/v1/auth/otp/verify').send({ phone, code }).expect(200);
    });

    it('rejects an expired code', async () => {
      const phone = uniquePhone();
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      await context.connection
        .collection('otp_challenges')
        .updateOne({ target: phone }, { $set: { expiresAt: new Date(Date.now() - 1_000) } });

      const response = await caller
        .post('/api/v1/auth/otp/verify')
        .send({ phone, code: lastOtp(context, phone) });
      expect(errorCodeOf(response)).toBe('OTP_INVALID');
    });

    it('locks a code after the maximum number of attempts, even for the right code', async () => {
      const phone = uniquePhone();
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      const code = lastOtp(context, phone);
      const wrong = code === '000000' ? '111111' : '000000';
      for (let attempt = 0; attempt < 5; attempt++) {
        await caller.post('/api/v1/auth/otp/verify').send({ phone, code: wrong }).expect(401);
      }
      const response = await caller.post('/api/v1/auth/otp/verify').send({ phone, code });
      expect(errorCodeOf(response)).toBe('OTP_INVALID');
    });

    it('accepts a code only once', async () => {
      const phone = uniquePhone();
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      const code = lastOtp(context, phone);
      await caller.post('/api/v1/auth/otp/verify').send({ phone, code }).expect(200);
      const replay = await caller.post('/api/v1/auth/otp/verify').send({ phone, code });
      expect(errorCodeOf(replay)).toBe('OTP_INVALID');
    });

    it('enforces the resend cooldown per number', async () => {
      const phone = uniquePhone();
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      const response = await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(429);
      expect(response.body).toMatchObject({
        error: {
          code: 'RATE_LIMITED',
          details: { retryAfterSeconds: expect.any(Number) as unknown },
        },
      });
    });

    it('limits sends per IP across different numbers', async () => {
      const caller = client(context);
      for (let send = 0; send < 20; send++) {
        await caller.post('/api/v1/auth/otp/send').send({ phone: uniquePhone() }).expect(200);
      }
      const response = await caller.post('/api/v1/auth/otp/send').send({ phone: uniquePhone() });
      expect(response.status).toBe(429);
      expect(errorCodeOf(response)).toBe('RATE_LIMITED');
    });

    it('does not accept a code issued for a different purpose', async () => {
      const { phone } = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const caller = client(context);
      await caller
        .post('/api/v1/auth/otp/send')
        .send({ phone, purpose: 'PASSWORD_RESET' })
        .expect(200);
      const response = await caller
        .post('/api/v1/auth/otp/verify')
        .send({ phone, code: lastOtp(context, phone) });
      expect(errorCodeOf(response)).toBe('OTP_INVALID');
    });

    it('answers a reset request for an unknown number exactly like a known one, sending nothing', async () => {
      const phone = uniquePhone();
      const response = await client(context)
        .post('/api/v1/auth/otp/send')
        .send({ phone, purpose: 'PASSWORD_RESET' })
        .expect(200);
      expect(dataOf(response)).toEqual({ expiresInSeconds: 300, resendAfterSeconds: 30 });
      expect(context.sms.lastMessageTo(phone)).toBeUndefined();
    });

    it('refuses OTP-only sign-in for staff accounts', async () => {
      const { phone } = await seedPasswordUser(context, { userType: 'STAFF' });
      const caller = client(context);
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      const response = await caller
        .post('/api/v1/auth/otp/verify')
        .send({ phone, code: lastOtp(context, phone) });
      expect(response.status).toBe(403);
      expect(errorCodeOf(response)).toBe('PERMISSION_DENIED');
    });
  });

  describe('registration', () => {
    async function register(body: Record<string, unknown>) {
      const caller = client(context);
      const phone = (body.phone as string | undefined) ?? uniquePhone();
      await caller.post('/api/v1/auth/otp/send').send({ phone }).expect(200);
      return caller
        .post('/api/v1/auth/register')
        .send({ phone, code: lastOtp(context, phone), acceptTerms: true, ...body });
    }

    it('creates a customer with profile and password; the password then works for sign-in', async () => {
      const email = uniqueEmail();
      const response = await register({
        name: 'Asha Rao',
        email,
        password: 'a long enough passphrase',
        preferredLanguage: 'kn',
        marketingConsent: true,
      });
      expect(response.status).toBe(201);
      expect(dataOf<Tokens>(response).user).toMatchObject({
        name: 'Asha Rao',
        email,
        hasPassword: true,
        preferredLanguage: 'kn',
        userType: 'CUSTOMER',
      });
      await client(context)
        .post('/api/v1/auth/login')
        .send({ identifier: email, password: 'a long enough passphrase' })
        .expect(200);
    });

    it('answers ALREADY_REGISTERED for a phone that already has an account', async () => {
      const phone = uniquePhone();
      await signInWithOtp(context, phone);
      await expireOtpCooldowns(context);
      const response = await register({ phone, name: 'Second Try' });
      expect(response.status).toBe(409);
      expect(errorCodeOf(response)).toBe('ALREADY_REGISTERED');
      expect(await context.users.countDocuments({ phone })).toBe(1);
    });

    it('requires the terms to be accepted', async () => {
      for (const acceptTerms of [false, undefined]) {
        const response = await register({ name: 'No Terms', acceptTerms });
        expect(response.status).toBe(400);
        expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
      }
    });

    it('rejects a weak password and unknown fields', async () => {
      expect((await register({ name: 'Weak', password: 'short' })).status).toBe(400);
      expect((await register({ name: 'Extra', isAdmin: true })).status).toBe(400);
    });
  });

  describe('/me', () => {
    it('returns the authenticated profile and the current session, never credentials', async () => {
      const phone = uniquePhone();
      const tokens = await signInWithOtp(context, phone);
      const response = await client(context)
        .get('/api/v1/me')
        .set(...bearer(tokens))
        .expect(200);
      expect(dataOf(response)).toMatchObject({
        user: { id: tokens.user.id, phone, userType: 'CUSTOMER', mfaEnabled: false },
        session: { id: tokens.sessionId, mfaEnrollmentRequired: false },
      });
      expect(JSON.stringify(response.body)).not.toMatch(/passwordHash|secret|refreshToken/i);
    });
  });
});
