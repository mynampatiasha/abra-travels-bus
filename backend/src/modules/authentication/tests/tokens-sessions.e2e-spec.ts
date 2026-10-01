import { SignJWT } from 'jose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  seedPasswordUser,
  signInWithOtp,
  type Tokens,
  uniquePhone,
} from './auth-e2e.harness';

interface SessionSummary {
  id: string;
  current: boolean;
  clientType: string;
  deviceName: string | null;
}

/** Access tokens, refresh rotation and reuse detection, sessions — real MongoDB + Redis. */
describe('Authentication e2e: tokens and sessions', () => {
  let context: AuthTestContext;

  beforeAll(async () => {
    context = await createAuthTestApp();
  }, 60_000);

  afterAll(async () => {
    await context?.close();
  }, 60_000);

  const me = (tokens: Pick<Tokens, 'accessToken'>) =>
    client(context)
      .get('/api/v1/me')
      .set(...bearer(tokens));
  const refresh = (refreshToken: string) =>
    client(context).post('/api/v1/auth/refresh').send({ refreshToken });

  /** Signs a token with the suite's real development key, so only the claims are wrong. */
  async function forgeAccessToken(
    tokens: Tokens,
    claims: { issuedAt: number; expiresAt: number },
  ): Promise<string> {
    return new SignJWT({ typ: 'CUSTOMER', sid: tokens.sessionId, pv: 1 })
      .setProtectedHeader({ alg: 'HS256', typ: 'at+jwt' })
      .setSubject(tokens.user.id)
      .setIssuer('abra-travels')
      .setAudience('abra-travels-apps')
      .setIssuedAt(claims.issuedAt)
      .setExpirationTime(claims.expiresAt)
      .sign(new TextEncoder().encode(context.jwtSecret));
  }

  describe('access token', () => {
    it('authenticates a valid token', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      await me(tokens).expect(200);
    });

    it('answers TOKEN_EXPIRED for an expired token signed with the real key', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      const now = Math.floor(Date.now() / 1000);
      const expired = await forgeAccessToken(tokens, {
        issuedAt: now - 1_000,
        expiresAt: now - 60,
      });
      const response = await me({ accessToken: expired }).expect(401);
      expect(errorCodeOf(response)).toBe('TOKEN_EXPIRED');

      // Same claims, still valid → accepted: only the expiry made the difference
      const valid = await forgeAccessToken(tokens, { issuedAt: now, expiresAt: now + 600 });
      await me({ accessToken: valid }).expect(200);
    });

    it('rejects a token signed with another key or with alg "none"', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      const [header, payload] = tokens.accessToken.split('.');
      const tamperedSignature = `${header}.${payload}.${'A'.repeat(43)}`;
      const unsignedHeader = Buffer.from(JSON.stringify({ alg: 'none', typ: 'at+jwt' })).toString(
        'base64url',
      );
      for (const accessToken of [tamperedSignature, `${unsignedHeader}.${payload}.`]) {
        expect(errorCodeOf(await me({ accessToken }))).toBe('UNAUTHENTICATED');
      }
    });

    it('answers PERMISSIONS_CHANGED when the account changed after the token was issued', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      await context.users.updateOne({ _id: tokens.user.id }, { $inc: { permissionVersion: 1 } });
      expect(errorCodeOf(await me(tokens).expect(401))).toBe('PERMISSIONS_CHANGED');
      // A refresh issues a token with the new version
      const renewed = dataOf<Tokens>(await refresh(tokens.refreshToken).expect(200));
      await me(renewed).expect(200);
    });

    it('rejects a deactivated account immediately, before the token expires', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      await context.users.updateOne({ _id: tokens.user.id }, { $set: { status: 'DEACTIVATED' } });
      expect(errorCodeOf(await me(tokens).expect(401))).toBe('UNAUTHENTICATED');
      await refresh(tokens.refreshToken).expect(401);
    });
  });

  describe('refresh tokens', () => {
    it('rotates on every use: the new token works, the replaced one is rejected', async () => {
      const first = await signInWithOtp(context, uniquePhone());
      const second = dataOf<Tokens>(await refresh(first.refreshToken).expect(200));
      expect(second.refreshToken).not.toBe(first.refreshToken);
      expect(second.sessionId).toBe(first.sessionId);
      await me(second).expect(200);

      const replayed = await refresh(first.refreshToken).expect(401);
      expect(errorCodeOf(replayed)).toBe('UNAUTHENTICATED');
    });

    it('stores only a hash of the refresh token', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      const secret = tokens.refreshToken.split('.')[1]!;
      const session = await context.connection
        .collection('auth_sessions')
        .findOne({ userId: (await context.users.findById(tokens.user.id))!._id });
      expect(session?.refreshTokenHash).toMatch(/^[0-9a-f]{64}$/);
      expect(JSON.stringify(session)).not.toContain(secret);
    });

    it('treats reuse of an older replaced token as theft and revokes the whole session', async () => {
      const first = await signInWithOtp(context, uniquePhone());
      const second = dataOf<Tokens>(await refresh(first.refreshToken).expect(200));
      const third = dataOf<Tokens>(await refresh(second.refreshToken).expect(200));

      await refresh(first.refreshToken).expect(401); // reuse of a token replaced earlier
      await refresh(third.refreshToken).expect(401); // the legitimate token died with the session
      await me(third).expect(401);
      const stored = await context.connection
        .collection('auth_sessions')
        .findOne({ refreshTokenHash: { $exists: true }, revokedReason: 'REFRESH_TOKEN_REUSE' });
      expect(stored).not.toBeNull();
    });

    it('does not revoke the session for a just-replaced token (concurrent refresh)', async () => {
      const first = await signInWithOtp(context, uniquePhone());
      const second = dataOf<Tokens>(await refresh(first.refreshToken).expect(200));
      await refresh(first.refreshToken).expect(401); // the loser of the race
      await refresh(second.refreshToken).expect(200); // the winner carries on
    });

    it('ignores a made-up token without revoking the real session', async () => {
      const tokens = await signInWithOtp(context, uniquePhone());
      const forged = `${tokens.sessionId}.${'B'.repeat(43)}`;
      await refresh(forged).expect(401);
      await refresh(tokens.refreshToken).expect(200);
    });
  });

  describe('web clients (HttpOnly cookie)', () => {
    it('sets a hardened cookie, blanks the body token and requires the anti-CSRF header', async () => {
      const user = await seedPasswordUser(context, { userType: 'OPERATOR_STAFF' });
      const caller = client(context);
      const signedIn = await caller
        .post('/api/v1/auth/login')
        .send({ identifier: user.email, password: user.password, device: { clientType: 'WEB' } })
        .expect(200);
      expect(dataOf<Tokens>(signedIn).refreshToken).toBe('');
      const setCookie = String(signedIn.headers['set-cookie']);
      expect(setCookie).toMatch(/^abra_refresh_token=[^;]+;/);
      expect(setCookie).toMatch(/HttpOnly/);
      expect(setCookie).toMatch(/SameSite=Strict/);
      expect(setCookie).toMatch(/Path=\/api\/v1\/auth/);
      const cookie = setCookie.split(';')[0]!;

      const withoutHeader = await caller.post('/api/v1/auth/refresh').set('Cookie', cookie);
      expect(withoutHeader.status).toBe(401);

      // Browsers send no body: only the cookie and the header
      const withHeader = await caller
        .post('/api/v1/auth/refresh')
        .set('Cookie', cookie)
        .set('X-Abra-Client', 'web')
        .expect(200);
      const rotatedCookie = String(withHeader.headers['set-cookie']).split(';')[0]!;
      expect(rotatedCookie).toMatch(/^abra_refresh_token=/);
      expect(rotatedCookie).not.toBe(cookie);
      expect(dataOf<Tokens>(withHeader).refreshToken).toBe('');
      await me(dataOf<Tokens>(withHeader)).expect(200);

      // The replaced cookie no longer works; logout with the current cookie (no body) ends it
      await caller
        .post('/api/v1/auth/refresh')
        .set('Cookie', cookie)
        .set('X-Abra-Client', 'web')
        .expect(401);
      // Without the anti-CSRF header the cookie is ignored: nothing is revoked or cleared
      const forged = await caller.post('/api/v1/auth/logout').set('Cookie', rotatedCookie);
      expect(forged.status).toBe(401);
      expect(forged.headers['set-cookie']).toBeUndefined();
      await me(dataOf<Tokens>(withHeader)).expect(200);

      const loggedOut = await caller
        .post('/api/v1/auth/logout')
        .set('Cookie', rotatedCookie)
        .set('X-Abra-Client', 'web')
        .expect(200);
      expect(String(loggedOut.headers['set-cookie'])).toMatch(/abra_refresh_token=;/);
      await me(dataOf<Tokens>(withHeader)).expect(401);
    });
  });

  describe('sessions', () => {
    it('lists my sessions with the current one marked, and no tokens', async () => {
      const phone = uniquePhone();
      const deviceA = await signInWithOtp(context, phone);
      const user = await context.users.findById(deviceA.user.id);
      await context.users.updateOne(
        { _id: user!._id },
        { $set: { email: `${deviceA.user.id}@example.test` } },
      );
      const deviceB = dataOf<Tokens>(
        await client(context)
          .post('/api/v1/auth/refresh')
          .send({ refreshToken: deviceA.refreshToken })
          .expect(200),
      );
      const response = await client(context)
        .get('/api/v1/me/sessions')
        .set(...bearer(deviceB))
        .expect(200);
      const sessions = dataOf<SessionSummary[]>(response);
      expect(sessions).toHaveLength(1);
      expect(sessions[0]).toMatchObject({ id: deviceB.sessionId, current: true });
      expect(JSON.stringify(response.body)).not.toMatch(/refreshToken|Hash/);
    });

    it('revokes another of my sessions; it can no longer authenticate or refresh', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const signIn = async (deviceName: string) =>
        dataOf<Tokens>(
          await client(context)
            .post('/api/v1/auth/login')
            .send({ identifier: user.email, password: user.password, device: { deviceName } })
            .expect(200),
        );
      const phoneSession = await signIn('Pixel');
      const tabletSession = await signIn('Tablet');

      const listed = dataOf<SessionSummary[]>(
        await client(context)
          .get('/api/v1/me/sessions')
          .set(...bearer(phoneSession))
          .expect(200),
      );
      expect(listed.map((session) => session.deviceName).sort()).toEqual(['Pixel', 'Tablet']);

      await client(context)
        .delete(`/api/v1/me/sessions/${tabletSession.sessionId}`)
        .set(...bearer(phoneSession))
        .expect(200);
      await me(tabletSession).expect(401);
      await refresh(tabletSession.refreshToken).expect(401);
      await me(phoneSession).expect(200);
    });

    it("answers 404 for another user's session and leaves it alone", async () => {
      const mine = await signInWithOtp(context, uniquePhone());
      const theirs = await signInWithOtp(context, uniquePhone());
      const response = await client(context)
        .delete(`/api/v1/me/sessions/${theirs.sessionId}`)
        .set(...bearer(mine))
        .expect(404);
      expect(errorCodeOf(response)).toBe('RESOURCE_NOT_FOUND');
      await me(theirs).expect(200);
    });

    it('logout ends only the current session, with the refresh token alone', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const login = async () =>
        dataOf<Tokens>(
          await client(context)
            .post('/api/v1/auth/login')
            .send({ identifier: user.email, password: user.password })
            .expect(200),
        );
      const current = await login();
      const other = await login();

      await client(context)
        .post('/api/v1/auth/logout')
        .send({ refreshToken: current.refreshToken })
        .expect(200);
      await me(current).expect(401);
      await refresh(current.refreshToken).expect(401);
      await me(other).expect(200);
    });

    it('logout-all ends every session of the account', async () => {
      const user = await seedPasswordUser(context, { userType: 'CUSTOMER' });
      const login = async () =>
        dataOf<Tokens>(
          await client(context)
            .post('/api/v1/auth/login')
            .send({ identifier: user.email, password: user.password })
            .expect(200),
        );
      const sessions = [await login(), await login(), await login()];

      const response = await client(context)
        .post('/api/v1/auth/logout-all')
        .set(...bearer(sessions[0]!))
        .expect(200);
      expect(dataOf(response)).toEqual({ sessionsSignedOut: 3 });
      for (const session of sessions) {
        await me(session).expect(401);
        await refresh(session.refreshToken).expect(401);
      }
    });
  });
});
