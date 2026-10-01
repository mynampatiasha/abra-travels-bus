import { z } from 'zod';
import { ApiException } from '../../../common/errors/api-exception';

/** authentication.md §4. The upper bound caps hashing cost for absurdly long input. */
export const PASSWORD_MIN_LENGTH = 10;
export const PASSWORD_MAX_LENGTH = 128;

export const newPasswordSchema = z
  .string()
  .min(PASSWORD_MIN_LENGTH, `must be at least ${PASSWORD_MIN_LENGTH} characters`)
  .max(PASSWORD_MAX_LENGTH, `must be at most ${PASSWORD_MAX_LENGTH} characters`);

export interface PasswordOwner {
  email?: string | null;
  phone?: string | null;
  name?: string | null;
}

function invalid(message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path: 'password', code: 'custom', message }],
  });
}

/**
 * Rejects passwords that are trivially guessable from the account itself. Length is the main
 * requirement (no forced character classes, which only produce predictable patterns).
 */
export function assertPasswordAcceptable(password: string, owner: PasswordOwner): void {
  const lowered = password.toLowerCase();
  if (new Set(lowered).size < 4) throw invalid('must not be a repeated character or pattern');

  const personal = [owner.email, owner.email?.split('@')[0], owner.phone, owner.phone?.slice(-10)]
    .filter((value): value is string => typeof value === 'string' && value.length >= 6)
    .map((value) => value.toLowerCase());
  if (personal.some((value) => lowered.includes(value))) {
    throw invalid('must not contain your email address or phone number');
  }
}
