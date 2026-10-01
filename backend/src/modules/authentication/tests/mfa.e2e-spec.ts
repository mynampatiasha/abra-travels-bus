import { totpAt, TOTP_STEP_SECONDS } from '../services/totp';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  seedPasswordUser,
  type Tokens,
} from './auth-e2e.harness';

const STEP_MS = TOTP_STEP_SECONDS * 1000;

interface MfaChallenge {
  mfaRequired: true;
  mfaToken: string;
}

/**
 * TOTP two-step verification — real MongoDB + Redis. Codes are produced exactly like an
 * authenticator app (RFC 6238). Each accepted code consumes its time step, so tests use the
 * current step and then the next one (the server accepts ±1 step).
 */
describe('Authentication e2e: MFA (TOTP)', () => {
  describe('optional MFA', () => {
    let context: AuthTestContext;

    beforeAll(async () => {
      context = await createAuthTestApp();
    }, 60_000);

    afterAll(async () => {
      await context?.close();
    }, 60_000);

    const login = (identifier: string, password: string) =>
      client(context).post('/api/v1/auth/login').send({ identifier, password });
    const verifyMfa = (body: Record<string, unknown>) =>
      client(context).post('/api/v1/auth/mfa/verify').send(body);
    /** Enabling/disabling MFA bumps permissionVersion: old access tokens must be refreshed. */
    const refreshed = async (tokens: Tokens) =>
      dataOf<Tokens>(
        await client(context)
          .post('/api/v1/auth/refresh')
          .send({ refreshToken: tokens.refreshToken })
          .expect(200),
      );

    /** Signs in, enrols and activates TOTP. Returns the secret, recovery codes and session. */
    async function userWithMfa() {
      const user = await seedPasswordUser(context, { userType: 'OPERATOR_STAFF' });
      const tokens = dataOf<Tokens>(await login(user.email, user.password).expect(200));
      const enrollment = dataOf<{ secret: string; keyUri: string }>(
        await client(context)
          .post('/api/v1/me/mfa/totp/enroll')
          .set(...bearer(tokens))
          .expect(200),
      );
      const activated = dataOf<{ recoveryCodes: string[] }>(
        await client(context)
          .post('/api/v1/me/mfa/totp/activate')
          .set(...bearer(tokens))
          .send({ code: totpAt(enrollment.secret, Date.now()) })
          .expect(200),
      );
      return {
        user,
        tokens: await refreshed(tokens),
        secret: enrollment.secret,
        recoveryCodes: activated.recoveryCodes,
      };
    }

    it('enrols and activates TOTP; the secret is stored encrypted and shown only once', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const tokens = dataOf<Tokens>(await login(user.email, user.password).expect(200));
      const enrollment = dataOf<{ secret: string; keyUri: string }>(
        await client(context)
          .post('/api/v1/me/mfa/totp/enroll')
          .set(...bearer(tokens))
          .expect(200),
      );
      expect(enrollment.secret).toMatch(/^[A-Z2-7]{32}$/);
      expect(enrollment.keyUri).toMatch(/^otpauth:\/\/totp\/Abra%20Travels:/);

      const wrongCode = await client(context)
        .post('/api/v1/me/mfa/totp/activate')
        .set(...bearer(tokens))
        .send({ code: '000000' === totpAt(enrollment.secret, Date.now()) ? '111111' : '000000' });
      expect(errorCodeOf(wrongCode)).toBe('MFA_INVALID');

      const activated = await client(context)
        .post('/api/v1/me/mfa/totp/activate')
        .set(...bearer(tokens))
        .send({ code: totpAt(enrollment.secret, Date.now()) })
        .expect(200);
      const { recoveryCodes } = dataOf<{ recoveryCodes: string[] }>(activated);
      expect(recoveryCodes).toHaveLength(10);
      expect(new Set(recoveryCodes).size).toBe(10);

      const stored = await context.users.findById(user.id).lean();
      expect(stored?.mfa.enabled).toBe(true);
      expect(stored?.mfa.secretEncrypted).toMatch(/^v1\./);
      expect(JSON.stringify(stored)).not.toContain(enrollment.secret);
      expect(JSON.stringify(stored)).not.toContain(recoveryCodes[0]!);

      // The account's security changed: the old access token must be refreshed
      const stale = await client(context)
        .get('/api/v1/me/mfa')
        .set(...bearer(tokens))
        .expect(401);
      expect(errorCodeOf(stale)).toBe('PERMISSIONS_CHANGED');
      const renewed = await refreshed(tokens);
      const status = await client(context)
        .get('/api/v1/me/mfa')
        .set(...bearer(renewed))
        .expect(200);
      expect(dataOf(status)).toEqual({
        enabled: true,
        required: false,
        recoveryCodesRemaining: 10,
      });
    });

    it('activation signs out the other devices', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const other = dataOf<Tokens>(await login(user.email, user.password).expect(200));
      const tokens = dataOf<Tokens>(await login(user.email, user.password).expect(200));
      const { secret } = dataOf<{ secret: string }>(
        await client(context)
          .post('/api/v1/me/mfa/totp/enroll')
          .set(...bearer(tokens))
          .expect(200),
      );
      await client(context)
        .post('/api/v1/me/mfa/totp/activate')
        .set(...bearer(tokens))
        .send({ code: totpAt(secret, Date.now()) })
        .expect(200);
      const otherResponse = await client(context)
        .get('/api/v1/me')
        .set(...bearer(other))
        .expect(401);
      expect(errorCodeOf(otherResponse)).toBe('UNAUTHENTICATED'); // revoked, not just stale
      await client(context)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: other.refreshToken })
        .expect(401);
      // This device keeps its session; it only needs a fresh access token
      const renewed = await refreshed(tokens);
      await client(context)
        .get('/api/v1/me')
        .set(...bearer(renewed))
        .expect(200);
    });

    it('requires the second factor at sign-in; a valid code completes it', async () => {
      const { user, secret } = await userWithMfa();
      const challenge = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      expect(challenge).toEqual({
        mfaRequired: true,
        mfaToken: expect.any(String) as unknown,
        mfaTokenExpiresInSeconds: 300,
      });
      expect(challenge).not.toHaveProperty('accessToken');

      // The challenge token is not an access token
      await client(context)
        .get('/api/v1/me')
        .set('Authorization', `Bearer ${challenge.mfaToken}`)
        .expect(401);

      const signedIn = await verifyMfa({
        mfaToken: challenge.mfaToken,
        code: totpAt(secret, Date.now() + STEP_MS),
      }).expect(200);
      await client(context)
        .get('/api/v1/me')
        .set(...bearer(dataOf<Tokens>(signedIn)))
        .expect(200);
    });

    it('rejects a wrong code, a replayed code and a reused challenge token', async () => {
      const { user, secret } = await userWithMfa();
      const first = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      const nextStepCode = totpAt(secret, Date.now() + STEP_MS);
      const wrong = nextStepCode === '000000' ? '111111' : '000000';

      expect(errorCodeOf(await verifyMfa({ mfaToken: first.mfaToken, code: wrong }))).toBe(
        'MFA_INVALID',
      );
      await verifyMfa({ mfaToken: first.mfaToken, code: nextStepCode }).expect(200);

      // The same challenge token cannot complete a second sign-in
      expect(errorCodeOf(await verifyMfa({ mfaToken: first.mfaToken, code: nextStepCode }))).toBe(
        'MFA_INVALID',
      );
      // A new sign-in cannot replay an already-used time step
      const second = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      expect(errorCodeOf(await verifyMfa({ mfaToken: second.mfaToken, code: nextStepCode }))).toBe(
        'MFA_INVALID',
      );
    });

    it('accepts each recovery code once', async () => {
      const { user, recoveryCodes } = await userWithMfa();
      const recoveryCode = recoveryCodes[0]!;

      const first = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      await verifyMfa({ mfaToken: first.mfaToken, recoveryCode }).expect(200);

      const second = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      expect(errorCodeOf(await verifyMfa({ mfaToken: second.mfaToken, recoveryCode }))).toBe(
        'MFA_INVALID',
      );
      // Formatting is ignored: lower case and without the dash still works for another code
      const relaxed = recoveryCodes[1]!.toLowerCase().replace('-', '');
      await verifyMfa({ mfaToken: second.mfaToken, recoveryCode: relaxed }).expect(200);
    });

    it('requires exactly one of code or recoveryCode', async () => {
      const { user, secret, recoveryCodes } = await userWithMfa();
      const challenge = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      for (const body of [
        { mfaToken: challenge.mfaToken },
        {
          mfaToken: challenge.mfaToken,
          code: totpAt(secret, Date.now() + STEP_MS),
          recoveryCode: recoveryCodes[0],
        },
      ]) {
        const response = await verifyMfa(body).expect(400);
        expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
      }
    });

    it('locks the second factor after repeated wrong codes', async () => {
      const { user, secret } = await userWithMfa();
      const challenge = dataOf<MfaChallenge>(await login(user.email, user.password).expect(200));
      const good = totpAt(secret, Date.now() + STEP_MS);
      const wrong = good === '000000' ? '111111' : '000000';
      for (let attempt = 0; attempt < 5; attempt++) {
        await verifyMfa({ mfaToken: challenge.mfaToken, code: wrong }).expect(401);
      }
      const locked = await verifyMfa({ mfaToken: challenge.mfaToken, code: good });
      expect(locked.status).toBe(423);
      expect(errorCodeOf(locked)).toBe('ACCOUNT_LOCKED');
    });

    it('disables MFA with a recovery code; sign-in then needs only the password', async () => {
      const { user, tokens, recoveryCodes } = await userWithMfa();
      await client(context)
        .post('/api/v1/me/mfa/totp/disable')
        .set(...bearer(tokens))
        .send({ recoveryCode: recoveryCodes[0] })
        .expect(200);
      const response = await login(user.email, user.password).expect(200);
      expect(dataOf<Tokens>(response).accessToken).toEqual(expect.any(String));
      expect((await context.users.findById(user.id).lean())?.mfa).toMatchObject({
        enabled: false,
        recoveryCodeHashes: [],
      });
    });
  });

  describe('mandatory MFA for staff (MFA_REQUIRED_FOR_STAFF=true)', () => {
    let context: AuthTestContext;

    beforeAll(async () => {
      context = await createAuthTestApp({ MFA_REQUIRED_FOR_STAFF: 'true' });
    }, 60_000);

    afterAll(async () => {
      await context?.close();
    }, 60_000);

    it('restricts a staff session to MFA enrolment until TOTP is active, then cannot be disabled', async () => {
      const user = await seedPasswordUser(context, { userType: 'STAFF' });
      const tokens = dataOf<Tokens>(
        await client(context)
          .post('/api/v1/auth/login')
          .send({ identifier: user.email, password: user.password })
          .expect(200),
      );
      expect(tokens.mfaEnrollmentRequired).toBe(true);

      const blocked = await client(context)
        .get('/api/v1/me/sessions')
        .set(...bearer(tokens))
        .expect(403);
      expect(errorCodeOf(blocked)).toBe('MFA_ENROLLMENT_REQUIRED');
      await client(context)
        .get('/api/v1/me')
        .set(...bearer(tokens))
        .expect(200);

      const { secret } = dataOf<{ secret: string }>(
        await client(context)
          .post('/api/v1/me/mfa/totp/enroll')
          .set(...bearer(tokens))
          .expect(200),
      );
      const { recoveryCodes } = dataOf<{ recoveryCodes: string[] }>(
        await client(context)
          .post('/api/v1/me/mfa/totp/activate')
          .set(...bearer(tokens))
          .send({ code: totpAt(secret, Date.now()) })
          .expect(200),
      );

      // The same session is unrestricted once MFA is active (after the usual token refresh)
      const fresh = dataOf<Tokens>(
        await client(context)
          .post('/api/v1/auth/refresh')
          .send({ refreshToken: tokens.refreshToken })
          .expect(200),
      );
      expect(fresh.sessionId).toBe(tokens.sessionId);
      expect(fresh.mfaEnrollmentRequired).toBe(false);
      await client(context)
        .get('/api/v1/me/sessions')
        .set(...bearer(fresh))
        .expect(200);
      expect(
        dataOf(
          await client(context)
            .get('/api/v1/me/mfa')
            .set(...bearer(fresh))
            .expect(200),
        ),
      ).toMatchObject({ enabled: true, required: true });

      const disable = await client(context)
        .post('/api/v1/me/mfa/totp/disable')
        .set(...bearer(fresh))
        .send({ recoveryCode: recoveryCodes[0] })
        .expect(403);
      expect(errorCodeOf(disable)).toBe('PERMISSION_DENIED');
    });

    it('does not impose MFA on customers', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const tokens = dataOf<Tokens>(
        await client(context)
          .post('/api/v1/auth/login')
          .send({ identifier: user.email, password: user.password })
          .expect(200),
      );
      expect(tokens.mfaEnrollmentRequired).toBe(false);
      await client(context)
        .get('/api/v1/me/sessions')
        .set(...bearer(tokens))
        .expect(200);
    });
  });
});
