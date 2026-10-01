import { Writable } from 'node:stream';
import pino from 'pino';
import { REDACTED_LOG_PATHS } from '../logger-options.factory';

/**
 * Proves the redaction list against a real pino logger: whatever a developer accidentally passes
 * to the logger, credential values never reach the log output.
 */
function captureLog(payload: Record<string, unknown>): string {
  let output = '';
  const sink = new Writable({
    write(chunk: Buffer, _encoding, done) {
      output += chunk.toString();
      done();
    },
  });
  pino({ redact: { paths: REDACTED_LOG_PATHS, censor: '[REDACTED]' } }, sink).info(
    payload,
    'event',
  );
  return output;
}

const SECRETS = {
  password: 'correct-horse-battery',
  currentPassword: 'old-password-value',
  newPassword: 'new-password-value',
  passwordHash: '$argon2id$v=19$m=19456,t=2,p=1$c2FsdA$aGFzaA',
  otp: '482913',
  otpCode: '739104',
  totpCode: '204981',
  codeHash: 'f3a9c1d2e4',
  recoveryCode: 'ABCDE-FGHIJ',
  mfaToken: 'mfa-challenge-token-value',
  totpSecret: 'JBSWY3DPEHPK3PXP',
  secretEncrypted: 'v1.iv.tag.ciphertext',
  accessToken: 'eyJhbGciOiJIUzI1NiJ9.payload.signature',
  refreshToken: '66f0c0ffee00000000000001.refresh-secret-value',
  refreshTokenHash: 'deadbeefcafe',
  token: 'generic-token-value',
  secret: 'generic-secret-value',
};

describe('authentication log redaction', () => {
  it.each(Object.entries(SECRETS))('redacts %s at the top level', (key, value) => {
    const output = captureLog({ [key]: value, userId: 'user-1' });
    expect(output).not.toContain(value);
    expect(output).toContain('[REDACTED]');
    expect(output).toContain('user-1');
  });

  it('redacts credentials nested one and two levels deep (request bodies, results)', () => {
    const output = captureLog({
      body: { ...SECRETS },
      result: { tokens: { accessToken: SECRETS.accessToken, refreshToken: SECRETS.refreshToken } },
    });
    for (const value of Object.values(SECRETS)) expect(output).not.toContain(value);
  });

  it('redacts Authorization, Cookie and Set-Cookie headers', () => {
    const output = captureLog({
      req: { headers: { authorization: 'Bearer abc.def.ghi', cookie: 'abra_refresh_token=xyz' } },
      res: { headers: { 'set-cookie': 'abra_refresh_token=new-value' } },
    });
    expect(output).not.toContain('abc.def.ghi');
    expect(output).not.toContain('xyz');
    expect(output).not.toContain('new-value');
  });
});
