/** Timezone travel dates are expressed in (trips store their own; India is the launch market). */
export const DEFAULT_TRIP_TIMEZONE = 'Asia/Kolkata';

/** How far ahead customers can search. */
export const SEARCH_HORIZON_DAYS = 90;

const DAY_MS = 24 * 60 * 60 * 1000;

/** The calendar date of `at` in `timezone`, as `YYYY-MM-DD`. */
export function localDateOf(at: Date, timezone: string = DEFAULT_TRIP_TIMEZONE): string {
  // en-CA formats dates as YYYY-MM-DD
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(at);
}

/** True for a real calendar date written `YYYY-MM-DD` (rejects 2026-02-30). */
export function isCalendarDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

/** `date` plus `days` (calendar arithmetic, no timezone involved). */
export function addDays(date: string, days: number): string {
  return new Date(new Date(`${date}T00:00:00.000Z`).getTime() + days * DAY_MS)
    .toISOString()
    .slice(0, 10);
}

/** First and last travel date customers can search today. */
export function searchableDates(now: Date): { first: string; last: string } {
  const first = localDateOf(now);
  return { first, last: addDays(first, SEARCH_HORIZON_DAYS) };
}
