import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/** SHA-256 hex digest. For high-entropy values only (random tokens), never for passwords or OTPs. */
export function sha256Hex(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/** Keyed hash for low-entropy values (OTP codes): useless to an attacker without the key. */
export function hmacSha256Hex(key: string, value: string): string {
  return createHmac('sha256', key).update(value).digest('hex');
}

/** Constant-time comparison of two hex digests of the same algorithm. */
export function safeEqualHex(left: string, right: string): boolean {
  const a = Buffer.from(left, 'hex');
  const b = Buffer.from(right, 'hex');
  return a.length === b.length && a.length > 0 && timingSafeEqual(a, b);
}

/** URL-safe random token with `bytes` bytes of entropy. */
export function randomToken(bytes: number): string {
  return randomBytes(bytes).toString('base64url');
}
