import { preferredLanguage } from '../../../common/http/preferred-language';
import { TripSearchQueryDto } from '../dto/trip-search.dto';
import { tripSchema } from '../schemas/trip.schema';
import {
  addDays,
  isCalendarDate,
  localDateOf,
  searchableDates,
  SEARCH_HORIZON_DAYS,
} from '../services/travel-date';

describe('travel dates', () => {
  it('the calendar date is taken in India time, not UTC', () => {
    // 20:00 UTC is 01:30 the next day in India
    expect(localDateOf(new Date('2026-10-05T20:00:00.000Z'))).toBe('2026-10-06');
    expect(localDateOf(new Date('2026-10-05T18:29:59.000Z'))).toBe('2026-10-05');
    expect(localDateOf(new Date('2026-10-05T20:00:00.000Z'), 'UTC')).toBe('2026-10-05');
  });

  it('accepts only real calendar dates written YYYY-MM-DD', () => {
    expect(isCalendarDate('2028-02-29')).toBe(true);
    for (const value of ['2027-02-29', '2026-02-30', '2026-13-01', '2026-1-5', '05-10-2026', '']) {
      expect(isCalendarDate(value)).toBe(false);
    }
  });

  it('adds days across months and years', () => {
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28');
  });

  it('the searchable range starts today in India and ends after the horizon', () => {
    const range = searchableDates(new Date('2026-10-05T20:00:00.000Z'));
    expect(range).toEqual({
      first: '2026-10-06',
      last: addDays('2026-10-06', SEARCH_HORIZON_DAYS),
    });
  });
});

describe('preferredLanguage', () => {
  it('takes the language of the first entry', () => {
    expect(preferredLanguage('kn-IN,kn;q=0.9,en;q=0.8')).toBe('kn');
    expect(preferredLanguage('EN')).toBe('en');
  });

  it('ignores a missing or malformed header', () => {
    for (const header of [undefined, '', '*', '$ne', 'translations.x']) {
      expect(preferredLanguage(header)).toBeUndefined();
    }
  });
});

describe('TripSearchQueryDto', () => {
  const parse = (query: Record<string, unknown>) =>
    TripSearchQueryDto.zodSchema.safeParse({
      from: '507f1f77bcf86cd799439011',
      to: '507f1f77bcf86cd799439012',
      date: '2026-10-09',
      ...query,
    });

  it('applies defaults', () => {
    const result = parse({});
    expect(result.success && result.data).toMatchObject({
      sort: 'DEPARTURE_EARLIEST',
      page: 1,
      pageSize: 20,
    });
  });

  it('reads comma-separated lists and numbers from the query string', () => {
    const result = parse({
      amenities: 'WIFI, BLANKET,',
      departureWindows: 'MORNING,NIGHT',
      busTypes: 'AC_SLEEPER',
      minFare: '40000',
      passengers: '2',
      page: '3',
    });
    expect(result.success && result.data).toMatchObject({
      amenities: ['WIFI', 'BLANKET'],
      departureWindows: ['MORNING', 'NIGHT'],
      busTypes: ['AC_SLEEPER'],
      minFare: 40_000,
      passengers: 2,
      page: 3,
    });
  });

  it.each([
    ['an empty list', { amenities: ',' }],
    ['an unknown amenity', { amenities: 'WIFI,POOL' }],
    ['a bus type that is not a key', { busTypes: 'ac sleeper' }],
    ['an object instead of a string', { from: { $ne: '' } }],
    ['a fractional page', { page: '1.5' }],
    ['an ac value that is not a boolean', { ac: 'yes' }],
  ])('rejects %s', (_name, query) => {
    expect(parse(query).success).toBe(false);
  });
});

describe('trip schema', () => {
  it('has the index the customer search uses', () => {
    expect(tripSchema.indexes().map(([fields]) => Object.keys(fields))).toContainEqual([
      'originCityId',
      'destinationCityId',
      'travelDate',
      'status',
      'departureAt',
    ]);
  });
});
