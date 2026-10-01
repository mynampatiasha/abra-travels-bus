import { randomBytes } from 'node:crypto';
import { type AppConfigService } from '../../../config/app-config.service';
import { FieldEncryptionService } from '../field-encryption.service';
import { hmacSha256Hex, randomToken, safeEqualHex, sha256Hex } from '../secure-hash';

function service(key: Buffer = randomBytes(32)): FieldEncryptionService {
  return new FieldEncryptionService({
    get: () => key.toString('base64'),
  } as unknown as AppConfigService);
}

describe('FieldEncryptionService', () => {
  it('round-trips a value and never stores it in plain form', () => {
    const encryption = service();
    const stored = encryption.encrypt('JBSWY3DPEHPK3PXP');
    expect(stored).not.toContain('JBSWY3DPEHPK3PXP');
    expect(stored.startsWith('v1.')).toBe(true);
    expect(encryption.decrypt(stored)).toBe('JBSWY3DPEHPK3PXP');
  });

  it('uses a fresh IV, so equal values encrypt differently', () => {
    const encryption = service();
    expect(encryption.encrypt('same')).not.toBe(encryption.encrypt('same'));
  });

  it('rejects a tampered value', () => {
    const encryption = service();
    const [version, iv, tag, ciphertext] = encryption.encrypt('secret-value').split('.');
    const flipped = Buffer.from(ciphertext ?? '', 'base64url');
    flipped[0] = (flipped[0] ?? 0) ^ 0xff;
    const tampered = [version, iv, tag, flipped.toString('base64url')].join('.');
    expect(() => encryption.decrypt(tampered)).toThrow();
  });

  it('rejects a value encrypted with another key and unknown formats', () => {
    const stored = service().encrypt('secret-value');
    expect(() => service().decrypt(stored)).toThrow();
    expect(() => service().decrypt('not-an-encrypted-value')).toThrow('unknown format');
  });
});

describe('secure-hash helpers', () => {
  it('hashes deterministically and compares in constant time', () => {
    expect(sha256Hex('abc')).toBe(sha256Hex('abc'));
    expect(sha256Hex('abc')).toHaveLength(64);
    expect(safeEqualHex(sha256Hex('abc'), sha256Hex('abc'))).toBe(true);
    expect(safeEqualHex(sha256Hex('abc'), sha256Hex('abd'))).toBe(false);
    expect(safeEqualHex('', '')).toBe(false);
    expect(safeEqualHex(sha256Hex('abc'), 'ab')).toBe(false);
  });

  it('keyed hash depends on the key', () => {
    expect(hmacSha256Hex('key-one', '123456')).not.toBe(hmacSha256Hex('key-two', '123456'));
  });

  it('random tokens are unique and URL-safe', () => {
    const tokens = new Set(Array.from({ length: 200 }, () => randomToken(32)));
    expect(tokens.size).toBe(200);
    for (const token of tokens) expect(token).toMatch(/^[A-Za-z0-9_-]{43}$/);
  });
});
