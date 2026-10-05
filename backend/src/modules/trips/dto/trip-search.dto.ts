import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { BUS_AMENITIES } from '../../buses/schemas/bus.schema';

const objectId = z.string().regex(/^[0-9a-f]{24}$/i, 'must be a 24-character id');
const travelDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be a date written YYYY-MM-DD');

/** A comma-separated list in a query string, e.g. `amenities=WIFI,BLANKET`. */
function commaSeparated<Item extends z.ZodType<unknown, string>>(item: Item, maxItems = 20) {
  return z
    .string()
    .max(600)
    .transform((value) =>
      value
        .split(',')
        .map((part) => part.trim())
        .filter((part) => part.length > 0),
    )
    .pipe(z.array(item).min(1).max(maxItems));
}

/** Parts of the day a departure can fall in (local time of the trip). */
export const DEPARTURE_WINDOWS = {
  EARLY_MORNING: { fromMinute: 0, toMinute: 360 },
  MORNING: { fromMinute: 360, toMinute: 720 },
  AFTERNOON: { fromMinute: 720, toMinute: 1080 },
  NIGHT: { fromMinute: 1080, toMinute: 1440 },
} as const;
export type DepartureWindow = keyof typeof DEPARTURE_WINDOWS;
const DEPARTURE_WINDOW_KEYS = Object.keys(DEPARTURE_WINDOWS) as [
  DepartureWindow,
  ...DepartureWindow[],
];

export const TRIP_SORTS = [
  'DEPARTURE_EARLIEST',
  'DEPARTURE_LATEST',
  'FARE_LOWEST',
  'FARE_HIGHEST',
  'DURATION_SHORTEST',
] as const;
export type TripSort = (typeof TRIP_SORTS)[number];

const route = {
  /** Origin city id. */
  from: objectId,
  /** Destination city id. */
  to: objectId,
  /** Travel date in India time. */
  date: travelDate,
  /** Only trips with at least this many seats available. */
  passengers: z.coerce.number().int().min(1).max(6).optional(),
};

/** `GET /trips/search/filters`: the search itself, without filters, sorting or paging. */
export class TripSearchCriteriaDto extends createZodDto(z.object(route)) {}

/** `GET /trips/search`. */
export class TripSearchQueryDto extends createZodDto(
  z.object({
    ...route,
    sort: z.enum(TRIP_SORTS).default('DEPARTURE_EARLIEST'),
    departureWindows: commaSeparated(z.enum(DEPARTURE_WINDOW_KEYS), 4).optional(),
    busTypes: commaSeparated(
      z.string().regex(/^[A-Z][A-Z0-9_]{0,39}$/, 'must be a bus type key'),
    ).optional(),
    ac: z.enum(['true', 'false']).optional(),
    operatorIds: commaSeparated(objectId).optional(),
    /** Trips whose bus has every listed amenity. */
    amenities: commaSeparated(z.enum(BUS_AMENITIES)).optional(),
    /** Lowest fare in paise, inclusive. */
    minFare: z.coerce.number().int().min(0).max(100_000_00).optional(),
    maxFare: z.coerce.number().int().min(0).max(100_000_00).optional(),
    page: z.coerce.number().int().min(1).max(1000).default(1),
    pageSize: z.coerce.number().int().min(1).max(50).default(20),
  }),
) {}

export class TripIdParamDto extends createZodDto(z.object({ tripId: objectId })) {}
