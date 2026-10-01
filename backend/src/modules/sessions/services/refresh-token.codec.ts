import { isValidObjectId } from 'mongoose';
import { randomToken, sha256Hex } from '../../../common/crypto/secure-hash';

const SECRET_BYTES = 32; // 256 bits of entropy
const SECRET_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export interface ParsedRefreshToken {
  sessionId: string;
  secretHash: string;
}

/**
 * Refresh tokens are opaque to clients: `<sessionId>.<256-bit random secret>`. Only the SHA-256
 * of the secret is stored (a random 256-bit value cannot be guessed, so a fast hash is correct
 * here — unlike passwords). The session id lets the server find the session without a scan.
 */
export function newRefreshTokenSecret(): { secret: string; secretHash: string } {
  const secret = randomToken(SECRET_BYTES);
  return { secret, secretHash: sha256Hex(secret) };
}

export function formatRefreshToken(sessionId: string, secret: string): string {
  return `${sessionId}.${secret}`;
}

/** Returns undefined for anything that is not shaped like a refresh token. */
export function parseRefreshToken(token: unknown): ParsedRefreshToken | undefined {
  if (typeof token !== 'string' || token.length > 128) return undefined;
  const [sessionId, secret, ...rest] = token.split('.');
  if (rest.length > 0 || !sessionId || !secret) return undefined;
  if (!isValidObjectId(sessionId) || !SECRET_PATTERN.test(secret)) return undefined;
  return { sessionId, secretHash: sha256Hex(secret) };
}
