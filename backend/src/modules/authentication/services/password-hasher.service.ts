import { argon2, randomBytes, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { Injectable } from '@nestjs/common';

const argon2Async = promisify(argon2);

/**
 * Argon2id parameters (OWASP password storage recommendation: 19 MiB memory, 2 passes,
 * 1 lane). Changing them here upgrades existing hashes gradually: `needsRehash` reports hashes
 * made with other parameters, and they are replaced at the next successful sign-in.
 */
export const ARGON2ID_PARAMETERS = {
  memoryKiB: 19_456,
  passes: 2,
  parallelism: 1,
  saltBytes: 16,
  hashBytes: 32,
} as const;

/** Upper bounds accepted when reading a stored hash, so corrupt data cannot exhaust memory. */
const MAX_MEMORY_KIB = 1_048_576;
const MAX_PASSES = 10;
const MAX_PARALLELISM = 8;

interface ParsedHash {
  memoryKiB: number;
  passes: number;
  parallelism: number;
  salt: Buffer;
  hash: Buffer;
}

const PHC_PATTERN =
  /^\$argon2id\$v=19\$m=(\d{1,7}),t=(\d{1,2}),p=(\d{1,2})\$([A-Za-z0-9+/]+)\$([A-Za-z0-9+/]+)$/;

function toPhcBase64(buffer: Buffer): string {
  return buffer.toString('base64').replace(/=+$/, '');
}

function parsePhc(stored: string): ParsedHash | undefined {
  const match = PHC_PATTERN.exec(stored);
  if (!match) return undefined;
  const [, memory, passes, parallelism, salt, hash] = match;
  const parsed: ParsedHash = {
    memoryKiB: Number(memory),
    passes: Number(passes),
    parallelism: Number(parallelism),
    salt: Buffer.from(salt ?? '', 'base64'),
    hash: Buffer.from(hash ?? '', 'base64'),
  };
  const withinBounds =
    parsed.memoryKiB >= 8 &&
    parsed.memoryKiB <= MAX_MEMORY_KIB &&
    parsed.passes >= 1 &&
    parsed.passes <= MAX_PASSES &&
    parsed.parallelism >= 1 &&
    parsed.parallelism <= MAX_PARALLELISM &&
    parsed.salt.length >= 8 &&
    parsed.hash.length >= 16;
  return withinBounds ? parsed : undefined;
}

function derive(password: string, parameters: Omit<ParsedHash, 'hash'>, length: number) {
  return argon2Async('argon2id', {
    message: password,
    nonce: parameters.salt,
    memory: parameters.memoryKiB,
    passes: parameters.passes,
    parallelism: parameters.parallelism,
    tagLength: length,
  });
}

/**
 * Password hashing with Argon2id (Node's built-in implementation, no native add-on). Hashes are
 * stored as standard PHC strings: `$argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>`, so the
 * parameters travel with each hash. Passwords and hashes are never logged.
 */
@Injectable()
export class PasswordHasher {
  private dummyHash: Promise<string> | undefined;

  async hash(password: string): Promise<string> {
    const { memoryKiB, passes, parallelism, saltBytes, hashBytes } = ARGON2ID_PARAMETERS;
    const salt = randomBytes(saltBytes);
    const hash = await derive(password, { memoryKiB, passes, parallelism, salt }, hashBytes);
    return `$argon2id$v=19$m=${memoryKiB},t=${passes},p=${parallelism}$${toPhcBase64(salt)}$${toPhcBase64(hash)}`;
  }

  /** False for a wrong password and for a stored value that is not a valid Argon2id hash. */
  async verify(password: string, stored: string): Promise<boolean> {
    const parsed = parsePhc(stored);
    if (!parsed) return false;
    const candidate = await derive(password, parsed, parsed.hash.length);
    return candidate.length === parsed.hash.length && timingSafeEqual(candidate, parsed.hash);
  }

  /**
   * Does the same work as a real verification and always returns false. Used when the account
   * does not exist or has no password, so response time does not reveal which accounts exist.
   */
  async verifyAgainstDummy(password: string): Promise<false> {
    this.dummyHash ??= this.hash(randomBytes(24).toString('base64'));
    await this.verify(password, await this.dummyHash);
    return false;
  }

  needsRehash(stored: string): boolean {
    const parsed = parsePhc(stored);
    if (!parsed) return true;
    const { memoryKiB, passes, parallelism, hashBytes } = ARGON2ID_PARAMETERS;
    return (
      parsed.memoryKiB !== memoryKiB ||
      parsed.passes !== passes ||
      parsed.parallelism !== parallelism ||
      parsed.hash.length !== hashBytes
    );
  }
}
