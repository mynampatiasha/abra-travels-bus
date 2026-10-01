import { ApiException } from '../../../common/errors/api-exception';
import { ARGON2ID_PARAMETERS, PasswordHasher } from '../services/password-hasher.service';
import { assertPasswordAcceptable, newPasswordSchema } from '../services/password-policy';

describe('PasswordHasher (Argon2id)', () => {
  const hasher = new PasswordHasher();

  it('produces a PHC string with the configured Argon2id parameters and no plaintext', async () => {
    const hash = await hasher.hash('correct horse battery staple');
    const { memoryKiB, passes, parallelism } = ARGON2ID_PARAMETERS;
    expect(hash).toMatch(
      new RegExp(
        `^\\$argon2id\\$v=19\\$m=${memoryKiB},t=${passes},p=${parallelism}\\$[A-Za-z0-9+/]{22}\\$[A-Za-z0-9+/]{43}$`,
      ),
    );
    expect(hash).not.toContain('correct horse');
  });

  it('uses a random salt: the same password hashes differently every time', async () => {
    const [first, second] = await Promise.all([
      hasher.hash('same-password-1'),
      hasher.hash('same-password-1'),
    ]);
    expect(first).not.toBe(second);
  });

  it('verifies the right password and rejects a wrong one', async () => {
    const hash = await hasher.hash('S3cure-passphrase!');
    await expect(hasher.verify('S3cure-passphrase!', hash)).resolves.toBe(true);
    await expect(hasher.verify('S3cure-passphrase', hash)).resolves.toBe(false);
    await expect(hasher.verify('', hash)).resolves.toBe(false);
  });

  it('rejects stored values that are not valid Argon2id hashes', async () => {
    for (const stored of [
      '',
      'plaintext-password',
      '$2b$10$abcdefghijklmnopqrstuv',
      '$argon2i$v=19$m=19456,t=2,p=1$c2FsdHNhbHQ$aGFzaGhhc2hoYXNoaGFzaA',
      // Absurd memory cost must not be executed
      '$argon2id$v=19$m=9999999,t=2,p=1$c2FsdHNhbHRzYWx0$aGFzaGhhc2hoYXNoaGFzaGhhc2g',
    ]) {
      await expect(hasher.verify('anything', stored)).resolves.toBe(false);
    }
  });

  it('verifies hashes made with older parameters and flags them for rehash', async () => {
    // Argon2id, m=8192, t=1, p=1 — generated with the same algorithm, weaker parameters
    const { argon2Sync } = await import('node:crypto');
    const salt = Buffer.from('0123456789abcdef');
    const tag = argon2Sync('argon2id', {
      message: 'legacy-password',
      nonce: salt,
      memory: 8192,
      passes: 1,
      parallelism: 1,
      tagLength: 32,
    });
    const b64 = (buffer: Buffer): string => buffer.toString('base64').replace(/=+$/, '');
    const legacy = `$argon2id$v=19$m=8192,t=1,p=1$${b64(salt)}$${b64(tag)}`;

    await expect(hasher.verify('legacy-password', legacy)).resolves.toBe(true);
    expect(hasher.needsRehash(legacy)).toBe(true);
    expect(hasher.needsRehash(await hasher.hash('legacy-password'))).toBe(false);
    expect(hasher.needsRehash('garbage')).toBe(true);
  });

  it('verifyAgainstDummy always fails but does real hashing work', async () => {
    await expect(hasher.verifyAgainstDummy('whatever-password')).resolves.toBe(false);
    await expect(hasher.verifyAgainstDummy('')).resolves.toBe(false);
  });
});

describe('password policy', () => {
  it('requires 10 to 128 characters', () => {
    expect(newPasswordSchema.safeParse('123456789').success).toBe(false);
    expect(newPasswordSchema.safeParse('a-long-enough-password').success).toBe(true);
    expect(newPasswordSchema.safeParse('x'.repeat(129)).success).toBe(false);
  });

  it('rejects repeated characters and passwords built from the account identifiers', () => {
    const owner = { email: 'asha.kumar@example.com', phone: '+919876543210' };
    expect(() => assertPasswordAcceptable('aaaaaaaaaaaa', owner)).toThrow(ApiException);
    expect(() => assertPasswordAcceptable('asha.kumar@example.com', owner)).toThrow(ApiException);
    expect(() => assertPasswordAcceptable('Asha.Kumar-2026', owner)).toThrow(ApiException);
    expect(() => assertPasswordAcceptable('my9876543210pass', owner)).toThrow(ApiException);
    expect(() => assertPasswordAcceptable('violet-river-lantern', owner)).not.toThrow();
    expect(() => assertPasswordAcceptable('violet-river-lantern', {})).not.toThrow();
  });
});
