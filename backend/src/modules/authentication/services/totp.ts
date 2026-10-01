import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * TOTP (RFC 6238) on top of HOTP (RFC 4226) with the parameters every authenticator app
 * supports: HMAC-SHA1, 6 digits, 30-second steps. Pure functions; verified against the RFC test
 * vectors in totp.spec.ts.
 */
export const TOTP_DIGITS = 6;
export const TOTP_STEP_SECONDS = 30;
/** Steps accepted before and after the current one, to tolerate clock drift. */
export const TOTP_WINDOW = 1;
const SECRET_BYTES = 20;

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Encode(data: Buffer): string {
  let bits = 0;
  let value = 0;
  let output = '';
  for (const byte of data) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  return output;
}

export function base32Decode(encoded: string): Buffer {
  const cleaned = encoded.toUpperCase().replace(/[\s=-]/g, '');
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const character of cleaned) {
    const index = BASE32_ALPHABET.indexOf(character);
    if (index < 0) throw new Error('Invalid base32 character');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Buffer.from(bytes);
}

/** New random 160-bit secret, base32-encoded for authenticator apps. */
export function generateTotpSecret(): string {
  return base32Encode(randomBytes(SECRET_BYTES));
}

export function timeStepAt(timeMs: number): number {
  return Math.floor(timeMs / 1000 / TOTP_STEP_SECONDS);
}

export function hotp(secret: Buffer, counter: number, digits: number = TOTP_DIGITS): string {
  const counterBytes = Buffer.alloc(8);
  counterBytes.writeBigUInt64BE(BigInt(counter));
  const digest = createHmac('sha1', secret).update(counterBytes).digest();
  const offset = (digest[digest.length - 1] ?? 0) & 0x0f;
  const binary = digest.readUInt32BE(offset) & 0x7fffffff;
  return (binary % 10 ** digits).toString().padStart(digits, '0');
}

export function totpAt(secretBase32: string, timeMs: number): string {
  return hotp(base32Decode(secretBase32), timeStepAt(timeMs));
}

/**
 * Returns the time step the code is valid for (within ±TOTP_WINDOW of now), or undefined. The
 * caller stores the step so the same code cannot be accepted twice. Every candidate is compared
 * in constant time.
 */
export function verifyTotp(secretBase32: string, code: string, nowMs: number): number | undefined {
  if (!/^\d{6}$/.test(code)) return undefined;
  const secret = base32Decode(secretBase32);
  const presented = Buffer.from(code);
  const currentStep = timeStepAt(nowMs);

  let matched: number | undefined;
  for (let step = currentStep - TOTP_WINDOW; step <= currentStep + TOTP_WINDOW; step++) {
    if (timingSafeEqual(Buffer.from(hotp(secret, step)), presented)) matched ??= step;
  }
  return matched;
}

/** URI encoded in the enrolment QR code (Google Authenticator key URI format). */
export function totpKeyUri(issuer: string, accountName: string, secretBase32: string): string {
  const label = `${encodeURIComponent(issuer)}:${encodeURIComponent(accountName)}`;
  const parameters = new URLSearchParams({
    secret: secretBase32,
    issuer,
    algorithm: 'SHA1',
    digits: String(TOTP_DIGITS),
    period: String(TOTP_STEP_SECONDS),
  });
  return `otpauth://totp/${label}?${parameters.toString()}`;
}
