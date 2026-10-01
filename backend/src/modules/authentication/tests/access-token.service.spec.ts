import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { SignJWT } from 'jose';
import { ApiException } from '../../../common/errors/api-exception';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { AccessTokenService, type AccessTokenSubject } from '../services/access-token.service';

const SECRET = randomBytes(64).toString('base64');
const BASE = {
  JWT_ACCESS_SECRET: SECRET,
  JWT_ACCESS_TTL_SECONDS: 900,
  JWT_ISSUER: 'abra-travels',
  JWT_AUDIENCE: 'abra-travels-apps',
  MFA_CHALLENGE_TTL_SECONDS: 300,
};
const SUBJECT: AccessTokenSubject = {
  userId: '66f0c0ffee00000000000001',
  userType: 'OPERATOR_STAFF',
  sessionId: '66f0c0ffee00000000000002',
  permissionVersion: 3,
  operatorId: '66f0c0ffee00000000000003',
};

function service(overrides: Record<string, unknown> = {}): AccessTokenService {
  return new AccessTokenService(configOf({ ...BASE, ...overrides }));
}

function decodePart(token: string, index: number): Record<string, unknown> {
  return JSON.parse(Buffer.from(token.split('.')[index] ?? '', 'base64url').toString()) as Record<
    string,
    unknown
  >;
}

async function codeOf(work: Promise<unknown>): Promise<string> {
  const error: unknown = await work.then(
    () => undefined,
    (caught: unknown) => caught,
  );
  expect(error).toBeInstanceOf(ApiException);
  return (error as ApiException).code;
}

/** Signs an arbitrary token with the test secret, to forge what the service must reject. */
function forge(
  claims: Record<string, unknown>,
  options: {
    typ?: string;
    audience?: string;
    issuer?: string;
    expiresIn?: string;
    key?: string;
  } = {},
): Promise<string> {
  return new SignJWT(claims)
    .setProtectedHeader({ alg: 'HS256', typ: options.typ ?? 'at+jwt' })
    .setSubject(SUBJECT.userId)
    .setIssuer(options.issuer ?? BASE.JWT_ISSUER)
    .setAudience(options.audience ?? BASE.JWT_AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(options.expiresIn ?? '5m')
    .sign(new TextEncoder().encode(options.key ?? SECRET));
}

describe('AccessTokenService', () => {
  it('issues a short-lived token that round-trips its subject', async () => {
    const tokens = service();
    const issued = await tokens.issue(SUBJECT);
    expect(issued.expiresInSeconds).toBe(900);
    await expect(tokens.verify(issued.token)).resolves.toEqual(SUBJECT);
  });

  it('puts only the necessary claims in the token', async () => {
    const { token } = await service().issue(SUBJECT);
    const payload = decodePart(token, 1);
    expect(Object.keys(payload).sort()).toEqual(
      ['aud', 'exp', 'iat', 'iss', 'op', 'pv', 'sid', 'sub', 'typ'].sort(),
    );
    expect((payload.exp as number) - (payload.iat as number)).toBe(900);
    expect(decodePart(token, 0)).toEqual({ alg: 'HS256', typ: 'at+jwt' });
  });

  it('omits the operator claim for users without an operator', async () => {
    const tokens = service();
    const customer: AccessTokenSubject = {
      userId: SUBJECT.userId,
      userType: 'CUSTOMER',
      sessionId: SUBJECT.sessionId,
      permissionVersion: SUBJECT.permissionVersion,
    };
    const verified = await tokens.verify((await tokens.issue(customer)).token);
    expect(verified).toEqual(customer);
  });

  it('answers TOKEN_EXPIRED for an expired token', async () => {
    const expired = await forge({ typ: 'CUSTOMER', sid: 's', pv: 1 }, { expiresIn: '-1m' });
    expect(await codeOf(service().verify(expired))).toBe('TOKEN_EXPIRED');
  });

  it.each([
    ['garbage', () => Promise.resolve('not-a-token')],
    [
      'signed with another key',
      () => forge({ typ: 'CUSTOMER', sid: 's', pv: 1 }, { key: 'x'.repeat(64) }),
    ],
    [
      'wrong audience',
      () => forge({ typ: 'CUSTOMER', sid: 's', pv: 1 }, { audience: 'someone-else' }),
    ],
    ['wrong issuer', () => forge({ typ: 'CUSTOMER', sid: 's', pv: 1 }, { issuer: 'someone-else' })],
    ['wrong token type', () => forge({ typ: 'CUSTOMER', sid: 's', pv: 1 }, { typ: 'JWT' })],
    ['unknown user type', () => forge({ typ: 'ROOT', sid: 's', pv: 1 })],
    ['missing session id', () => forge({ typ: 'CUSTOMER', pv: 1 })],
    ['missing permission version', () => forge({ typ: 'CUSTOMER', sid: 's' })],
  ])('rejects a token that is %s', async (_label, make) => {
    expect(await codeOf(service().verify(await make()))).toBe('UNAUTHENTICATED');
  });

  it('rejects a tampered payload and an unsigned ("alg: none") token', async () => {
    const tokens = service();
    const { token } = await tokens.issue(SUBJECT);
    const [header, payload, signature] = token.split('.');
    const elevated = Buffer.from(
      JSON.stringify({ ...decodePart(token, 1), typ: 'STAFF' }),
    ).toString('base64url');
    expect(await codeOf(tokens.verify(`${header}.${elevated}.${signature}`))).toBe(
      'UNAUTHENTICATED',
    );

    const none = Buffer.from(JSON.stringify({ alg: 'none', typ: 'at+jwt' })).toString('base64url');
    expect(await codeOf(tokens.verify(`${none}.${payload}.`))).toBe('UNAUTHENTICATED');
  });

  it('MFA challenge tokens are single-purpose: they never authenticate a request', async () => {
    const tokens = service();
    const challenge = await tokens.issueMfaChallenge(SUBJECT.userId);
    expect(challenge.expiresInSeconds).toBe(300);
    expect(await codeOf(tokens.verify(challenge.token))).toBe('UNAUTHENTICATED');

    const verified = await tokens.verifyMfaChallenge(challenge.token);
    expect(verified.userId).toBe(SUBJECT.userId);
    expect(verified.challengeId).toMatch(/^[0-9a-f-]{36}$/);
    expect(verified.expiresInSeconds).toBeLessThanOrEqual(300);

    // An access token is not accepted as an MFA challenge either
    const access = await tokens.issue(SUBJECT);
    expect(await codeOf(tokens.verifyMfaChallenge(access.token))).toBe('MFA_INVALID');
    expect(await codeOf(tokens.verifyMfaChallenge('garbage'))).toBe('MFA_INVALID');
  });

  it('signs with RS256 when a key pair is configured (staging / production)', async () => {
    const { privateKey, publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
    // Secret managers often deliver PEM with literal "\n"
    const tokens = service({
      JWT_ACCESS_SECRET: undefined,
      JWT_ACCESS_PRIVATE_KEY: privateKey.replace(/\n/g, '\\n'),
      JWT_ACCESS_PUBLIC_KEY: publicKey,
    });
    const { token } = await tokens.issue(SUBJECT);
    expect(decodePart(token, 0).alg).toBe('RS256');
    await expect(tokens.verify(token)).resolves.toEqual(SUBJECT);
    // A token signed with the development secret is not accepted by the RS256 verifier
    expect(await codeOf(tokens.verify((await service().issue(SUBJECT)).token))).toBe(
      'UNAUTHENTICATED',
    );
  });

  it('validates the signing keys at start-up and refuses a malformed production key', async () => {
    const { publicKey } = generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
    const misconfigured = service({
      JWT_ACCESS_SECRET: undefined,
      JWT_ACCESS_PRIVATE_KEY: 'this is not a PEM private key',
      JWT_ACCESS_PUBLIC_KEY: publicKey,
    });
    await expect(misconfigured.onModuleInit()).rejects.toThrow();
    await expect(service().onModuleInit()).resolves.toBeUndefined();
  });

  it('refuses to work without any signing key', async () => {
    await expect(service({ JWT_ACCESS_SECRET: undefined }).issue(SUBJECT)).rejects.toThrow(
      'No access-token signing key',
    );
  });
});
