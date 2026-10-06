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

export const changeReason = z.string().trim().min(3).max(300);

export function skipOf(query: { page: number; pageSize: number }): number {
  return (query.page - 1) * query.pageSize;
}

export function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
