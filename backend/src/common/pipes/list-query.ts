import { z } from 'zod';

export const objectIdString = z.string().regex(/^[0-9a-f]{24}$/i, 'must be a 24-character id');

/** `page` and `pageSize` of a list endpoint. */
export const pagingShape = {
  page: z.coerce.number().int().min(1).max(10_000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
};

/** `active=true|false` in a query string. */
export const activeFlag = z
  .enum(['true', 'false'])
  .transform((value) => value === 'true')
  .optional();

/** `from` and `to` of a list: days as YYYY-MM-DD, both included. */
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be a date like 2026-10-31');
export const dateRangeShape = { from: day.optional(), to: day.optional() };

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * The MongoDB condition for a date range, or nothing when no day was given. `to` is a whole day:
 * everything before the start of the day after it. Days are UTC.
 */
export function dayRange(range: {
  from?: string | undefined;
  to?: string | undefined;
}): { $gte?: Date; $lt?: Date } | undefined {
  const from = range.from ? new Date(`${range.from}T00:00:00.000Z`) : undefined;
  const to = range.to
    ? new Date(new Date(`${range.to}T00:00:00.000Z`).getTime() + DAY_MS)
    : undefined;
  if (!from && !to) return undefined;
  return { ...(from ? { $gte: from } : {}), ...(to ? { $lt: to } : {}) };
}

export const changeReason = z.string().trim().min(3).max(300);

export function skipOf(query: { page: number; pageSize: number }): number {
  return (query.page - 1) * query.pageSize;
}

export function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
