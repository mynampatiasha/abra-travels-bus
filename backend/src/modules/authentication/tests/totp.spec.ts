import {
  base32Decode,
  base32Encode,
  generateTotpSecret,
  hotp,
  timeStepAt,
  totpAt,
  totpKeyUri,
  verifyTotp,
} from '../services/totp';

// RFC 6238 Appendix B (SHA-1): shared secret is the ASCII string "12345678901234567890"
const RFC_SECRET = Buffer.from('12345678901234567890', 'ascii');
const RFC_SECRET_BASE32 = base32Encode(RFC_SECRET);

describe('TOTP (RFC 6238 / RFC 4226)', () => {
  it.each([
    [59, '94287082'],
    [1111111109, '07081804'],
    [1111111111, '14050471'],
    [1234567890, '89005924'],
    [2000000000, '69279037'],
    [20000000000, '65353130'],
  ])('matches the RFC 6238 test vector at T=%i', (seconds, expected) => {
    expect(hotp(RFC_SECRET, timeStepAt(seconds * 1000), 8)).toBe(expected);
    // The 6-digit code used by authenticator apps is the last 6 digits of the 8-digit one
    expect(totpAt(RFC_SECRET_BASE32, seconds * 1000)).toBe(expected.slice(-6));
  });

  it('matches the RFC 4226 HOTP test vectors', () => {
    const expected = ['755224', '287082', '359152', '969429', '338314', '254676'];
    expected.forEach((code, counter) => expect(hotp(RFC_SECRET, counter)).toBe(code));
  });

  it('base32 round-trips and matches the RFC 4648 vectors', () => {
    expect(base32Encode(Buffer.from('foobar'))).toBe('MZXW6YTBOI');
    expect(base32Decode('MZXW6YTBOI======').toString()).toBe('foobar');
    expect(base32Decode('mzxw 6ytb-oi').toString()).toBe('foobar');
    expect(() => base32Decode('MZXW1')).toThrow('Invalid base32');
  });

  it('generates 160-bit secrets that differ every time', () => {
    const secrets = new Set(Array.from({ length: 50 }, generateTotpSecret));
    expect(secrets.size).toBe(50);
    for (const secret of secrets) {
      expect(secret).toMatch(/^[A-Z2-7]{32}$/);
      expect(base32Decode(secret)).toHaveLength(20);
    }
  });

  it('accepts the current step and one step either side, and reports the matched step', () => {
    const now = 1_700_000_015_000;
    const step = timeStepAt(now);
    expect(verifyTotp(RFC_SECRET_BASE32, totpAt(RFC_SECRET_BASE32, now), now)).toBe(step);
    expect(verifyTotp(RFC_SECRET_BASE32, totpAt(RFC_SECRET_BASE32, now - 30_000), now)).toBe(
      step - 1,
    );
    expect(verifyTotp(RFC_SECRET_BASE32, totpAt(RFC_SECRET_BASE32, now + 30_000), now)).toBe(
      step + 1,
    );
  });

  it('rejects codes outside the window, wrong codes and malformed input', () => {
    const now = 1_700_000_015_000;
    expect(
      verifyTotp(RFC_SECRET_BASE32, totpAt(RFC_SECRET_BASE32, now - 90_000), now),
    ).toBeUndefined();
    expect(
      verifyTotp(RFC_SECRET_BASE32, totpAt(RFC_SECRET_BASE32, now + 90_000), now),
    ).toBeUndefined();
    expect(verifyTotp(generateTotpSecret(), totpAt(RFC_SECRET_BASE32, now), now)).toBeUndefined();
    for (const malformed of ['', '12345', '1234567', 'abcdef', '12 345']) {
      expect(verifyTotp(RFC_SECRET_BASE32, malformed, now)).toBeUndefined();
    }
  });

  it('builds an otpauth URI authenticator apps accept', () => {
    const uri = new URL(totpKeyUri('Abra Travels', 'asha@example.com', 'JBSWY3DPEHPK3PXP'));
    expect(uri.protocol).toBe('otpauth:');
    expect(uri.host).toBe('totp');
    expect(decodeURIComponent(uri.pathname)).toBe('/Abra Travels:asha@example.com');
    expect(Object.fromEntries(uri.searchParams)).toEqual({
      secret: 'JBSWY3DPEHPK3PXP',
      issuer: 'Abra Travels',
      algorithm: 'SHA1',
      digits: '6',
      period: '30',
    });
  });
});
