import { z } from 'zod';

const E164 = /^\+[1-9]\d{7,14}$/;
const INDIAN_MOBILE = /^[6-9]\d{9}$/;

/**
 * Returns the number in E.164 form, or undefined if it is not a usable phone number. A bare
 * 10-digit Indian mobile number is accepted and stored as +91XXXXXXXXXX; spaces and dashes are
 * ignored. Every stored and compared phone number goes through this function.
 */
export function normalizePhoneNumber(input: string): string | undefined {
  const compact = input.replace(/[\s()-]/g, '');
  if (INDIAN_MOBILE.test(compact)) return `+91${compact}`;
  return E164.test(compact) ? compact : undefined;
}

export function normalizeEmail(input: string): string {
  return input.trim().toLowerCase();
}

export const phoneNumberSchema = z
  .string()
  .max(20)
  .transform((value, context) => {
    const normalized = normalizePhoneNumber(value);
    if (!normalized) {
      context.addIssue({ code: 'custom', message: 'must be a valid mobile number' });
      return z.NEVER;
    }
    return normalized;
  });

export const emailSchema = z.string().max(254).transform(normalizeEmail).pipe(z.email());

/** Hides most of a phone number for display and logs: +91******3210. */
export function maskPhoneNumber(phone: string): string {
  return phone.length <= 7 ? '***' : `${phone.slice(0, 3)}******${phone.slice(-4)}`;
}
