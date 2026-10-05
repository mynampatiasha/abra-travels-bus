import { type Types } from 'mongoose';
import {
  type AuthTestContext,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
} from '../../authentication/tests/auth-e2e.harness';
import { type TripSummaryView } from '../services/trip-discovery.views';
import {
  clearDiscoveryData,
  indiaTime,
  seedCity,
  seedOperator,
  seedTrip,
  travelDateIn,
} from './discovery-e2e.fixture';

/** Point ids are generated; any string is accepted. */
const anyId = expect.any(String) as unknown as string;

const SEARCH = '/api/v1/trips/search';

interface Page {
  body: { data: TripSummaryView[]; meta: { page: number; pageSize: number; total: number } };
}

/** Trip search for customers and guests — real application, MongoDB replica set and Redis. */
describe('Discovery e2e: trip search', () => {
  let context: AuthTestContext;
  let bengaluru: Types.ObjectId;
  let mysuru: Types.ObjectId;
  let hubballi: Types.ObjectId;
  let abra: Types.ObjectId;
  let kaveri: Types.ObjectId;
  const date = travelDateIn(3);
  const trips: Record<string, Types.ObjectId> = {};

  const search = (query: Record<string, string | number>) =>
    client(context)
      .get(SEARCH)
      .query({ from: bengaluru.toHexString(), to: mysuru.toHexString(), date, ...query });
  const names = (response: Page) => response.body.data.map((trip) => trip.bus.name);

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearDiscoveryData(context);
    bengaluru = await seedCity(context, 'Bengaluru', { translations: { kn: 'ಬೆಂಗಳೂರು' } });
    mysuru = await seedCity(context, 'Mysuru');
    hubballi = await seedCity(context, 'Hubballi');
    abra = await seedOperator(context, 'Abra Travels Private Limited', 'ACTIVE', 'Abra Travels');
    kaveri = await seedOperator(context, 'Kaveri Lines');
    const suspended = await seedOperator(context, 'Suspended Lines', 'SUSPENDED');
    const base = { originCityId: bengaluru, destinationCityId: mysuru, travelDate: date };

    trips.morning = await seedTrip(context, {
      ...base,
      operatorId: abra,
      busName: 'Morning Volvo',
      departure: '06:30',
      durationMinutes: 210,
      farePaise: 65_000,
      amenities: ['WIFI', 'CHARGING_POINT', 'WATER_BOTTLE'],
      stopCityIds: [hubballi],
    });
    trips.afternoon = await seedTrip(context, {
      ...base,
      operatorId: kaveri,
      busName: 'Afternoon Seater',
      departure: '13:15',
      durationMinutes: 180,
      farePaise: 35_000,
      busType: { key: 'NON_AC_SEATER', name: 'Non-AC Seater', isAc: false, berthType: 'SEATER' },
      amenities: ['CHARGING_POINT'],
      seats: { total: 40, available: 2 },
    });
    trips.night = await seedTrip(context, {
      ...base,
      operatorId: abra,
      busName: 'Night Sleeper',
      departure: '22:45',
      durationMinutes: 240,
      farePaise: 90_000,
      amenities: ['WIFI', 'BLANKET', 'CHARGING_POINT'],
      seats: { total: 30, available: 0 },
    });

    // None of these may ever appear
    const hidden = { ...base, operatorId: abra, durationMinutes: 200, farePaise: 10_000 };
    await seedTrip(context, { ...hidden, busName: 'Draft', departure: '08:00', status: 'DRAFT' });
    await seedTrip(context, {
      ...hidden,
      busName: 'Cancelled',
      departure: '09:00',
      status: 'CANCELLED',
    });
    await seedTrip(context, {
      ...hidden,
      busName: 'Departed',
      departure: '10:00',
      status: 'DEPARTED',
    });
    await seedTrip(context, {
      ...hidden,
      busName: 'Already left',
      departure: '07:00',
      departureAt: new Date(Date.now() - 60_000),
    });
    await seedTrip(context, {
      ...hidden,
      busName: 'Other day',
      departure: '08:00',
      travelDate: travelDateIn(4),
    });
    await seedTrip(context, {
      ...hidden,
      busName: 'Return',
      departure: '08:00',
      originCityId: mysuru,
      destinationCityId: bengaluru,
    });
    await seedTrip(context, {
      ...hidden,
      busName: 'Suspended',
      departure: '11:00',
      operatorId: suspended,
    });
  }, 90_000);

  afterAll(async () => {
    await clearDiscoveryData(context);
    await context.close();
  }, 60_000);

  describe('results', () => {
    it('a guest finds exactly the trips on sale, earliest first', async () => {
      const response = (await search({}).expect(200)) as Page;
      expect(names(response)).toEqual(['Morning Volvo', 'Afternoon Seater', 'Night Sleeper']);
      expect(response.body.meta).toMatchObject({ page: 1, pageSize: 20, total: 3 });
    });

    it('a result carries what the app shows and nothing internal', async () => {
      const [first] = dataOf<TripSummaryView[]>(await search({}).expect(200));
      expect(first).toEqual({
        id: trips.morning!.toHexString(),
        operator: { id: abra.toHexString(), name: 'Abra Travels' },
        bus: {
          name: 'Morning Volvo',
          typeKey: 'AC_SLEEPER',
          typeName: 'AC Sleeper',
          isAc: true,
          berthType: 'SLEEPER',
          amenities: ['WIFI', 'CHARGING_POINT', 'WATER_BOTTLE'],
        },
        origin: { id: bengaluru.toHexString(), name: 'Bengaluru' },
        destination: { id: mysuru.toHexString(), name: 'Mysuru' },
        travelDate: date,
        timezone: 'Asia/Kolkata',
        departureAt: indiaTime(date, '06:30').toISOString(),
        arrivalAt: indiaTime(date, '10:00').toISOString(),
        durationMinutes: 210,
        fare: { startingPaise: 65_000, currency: 'INR' },
        seats: { total: 36, available: 20, isSoldOut: false },
        boardingPoints: [
          {
            id: anyId,
            name: 'Central Bus Stand',
            time: indiaTime(date, '06:30').toISOString(),
          },
          {
            id: anyId,
            name: 'Second Stage',
            time: indiaTime(date, '06:50').toISOString(),
          },
        ],
        droppingPoints: [
          {
            id: anyId,
            name: 'Town Hall',
            time: indiaTime(date, '10:00').toISOString(),
          },
        ],
      });
      const text = JSON.stringify(first);
      for (const internal of [
        'operatorId',
        'busId',
        'routeId',
        'seatLayoutVersionId',
        'KA01AB1234',
        'createdAt',
      ]) {
        expect(text).not.toContain(internal);
      }
    });

    it('city names follow the requested language', async () => {
      const [first] = dataOf<TripSummaryView[]>(
        await search({}).set('Accept-Language', 'kn-IN,kn;q=0.9').expect(200),
      );
      expect(first?.origin.name).toBe('ಬೆಂಗಳೂರು');
      expect(first?.destination.name).toBe('Mysuru');
    });

    it('a sold-out trip is listed as sold out, and left out when seats are required', async () => {
      const all = dataOf<TripSummaryView[]>(await search({}).expect(200));
      expect(all.find((trip) => trip.bus.name === 'Night Sleeper')?.seats).toEqual({
        total: 30,
        available: 0,
        isSoldOut: true,
      });
      expect(names((await search({ passengers: 1 }).expect(200)) as Page)).toEqual([
        'Morning Volvo',
        'Afternoon Seater',
      ]);
      expect(names((await search({ passengers: 3 }).expect(200)) as Page)).toEqual([
        'Morning Volvo',
      ]);
    });

    it('no trips on the route: an empty page, not an error', async () => {
      const response = (await search({ to: hubballi.toHexString() }).expect(200)) as Page;
      expect(response.body.data).toEqual([]);
      expect(response.body.meta.total).toBe(0);
    });
  });

  describe('sorting', () => {
    it.each([
      ['DEPARTURE_EARLIEST', ['Morning Volvo', 'Afternoon Seater', 'Night Sleeper']],
      ['DEPARTURE_LATEST', ['Night Sleeper', 'Afternoon Seater', 'Morning Volvo']],
      ['FARE_LOWEST', ['Afternoon Seater', 'Morning Volvo', 'Night Sleeper']],
      ['FARE_HIGHEST', ['Night Sleeper', 'Morning Volvo', 'Afternoon Seater']],
      ['DURATION_SHORTEST', ['Afternoon Seater', 'Morning Volvo', 'Night Sleeper']],
    ])('%s', async (sort, expected) => {
      expect(names((await search({ sort }).expect(200)) as Page)).toEqual(expected);
    });
  });

  describe('filters', () => {
    it.each<[string, Record<string, string | number>, string[]]>([
      ['one departure window', { departureWindows: 'MORNING' }, ['Morning Volvo']],
      [
        'several departure windows',
        { departureWindows: 'AFTERNOON,NIGHT' },
        ['Afternoon Seater', 'Night Sleeper'],
      ],
      ['a window with no trips', { departureWindows: 'EARLY_MORNING' }, []],
      ['bus type', { busTypes: 'NON_AC_SEATER' }, ['Afternoon Seater']],
      ['air conditioning', { ac: 'true' }, ['Morning Volvo', 'Night Sleeper']],
      ['no air conditioning', { ac: 'false' }, ['Afternoon Seater']],
      ['every listed amenity', { amenities: 'WIFI,BLANKET' }, ['Night Sleeper']],
      [
        'one amenity',
        { amenities: 'CHARGING_POINT' },
        ['Morning Volvo', 'Afternoon Seater', 'Night Sleeper'],
      ],
      ['fare range', { minFare: 40_000, maxFare: 70_000 }, ['Morning Volvo']],
      ['maximum fare', { maxFare: 65_000 }, ['Morning Volvo', 'Afternoon Seater']],
      [
        'combined',
        { ac: 'true', departureWindows: 'NIGHT', sort: 'FARE_LOWEST' },
        ['Night Sleeper'],
      ],
    ])('%s', async (_name, query, expected) => {
      const response = (await search(query).expect(200)) as Page;
      expect(names(response)).toEqual(expected);
      expect(response.body.meta.total).toBe(expected.length);
    });

    it('operator', async () => {
      const response = (await search({ operatorIds: kaveri.toHexString() }).expect(200)) as Page;
      expect(names(response)).toEqual(['Afternoon Seater']);
    });

    it('a filter cannot reveal trips that are not on sale', async () => {
      const response = (await search({ maxFare: 10_000 }).expect(200)) as Page;
      expect(response.body.data).toEqual([]);
    });
  });

  describe('pagination', () => {
    it('pages do not overlap and report the total', async () => {
      const first = (await search({ pageSize: 2 }).expect(200)) as Page;
      const second = (await search({ pageSize: 2, page: 2 }).expect(200)) as Page;
      expect(names(first)).toEqual(['Morning Volvo', 'Afternoon Seater']);
      expect(names(second)).toEqual(['Night Sleeper']);
      expect(second.body.meta).toMatchObject({ page: 2, pageSize: 2, total: 3 });
      expect(names((await search({ pageSize: 2, page: 3 }).expect(200)) as Page)).toEqual([]);
    });
  });

  describe('invalid searches', () => {
    it.each<[string, Record<string, string | number | undefined>]>([
      ['the same city twice', { to: 'FROM' }],
      ['a missing destination', { to: undefined }],
      ['an id that is not an id', { from: 'bengaluru' }],
      ['an unknown city', { to: '507f1f77bcf86cd799439011' }],
      ['a date in the past', { date: travelDateIn(-1) }],
      ['a date beyond 90 days', { date: travelDateIn(91) }],
      ['a date that does not exist', { date: '2027-02-30' }],
      ['a date in another format', { date: '05-10-2026' }],
      ['an unknown sort', { sort: 'CHEAPEST' }],
      ['an unknown amenity', { amenities: 'JACUZZI' }],
      ['an unknown departure window', { departureWindows: 'DAWN' }],
      ['a minimum fare above the maximum', { minFare: 500, maxFare: 100 }],
      ['a negative fare', { minFare: -1 }],
      ['too many passengers', { passengers: 7 }],
      ['page zero', { page: 0 }],
      ['an oversized page', { pageSize: 51 }],
      ['a query operator instead of a value', { 'from[$ne]': 'x' }],
    ])('rejects %s', async (_name, change) => {
      const query: Record<string, string | number | undefined> = {
        from: bengaluru.toHexString(),
        to: mysuru.toHexString(),
        date,
        ...change,
      };
      if (query.to === 'FROM') query.to = bengaluru.toHexString();
      const response = await client(context).get(SEARCH).query(query).expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
    });

    it('today and the last day of the range are accepted', async () => {
      await search({ date: travelDateIn(0) }).expect(200);
      await search({ date: travelDateIn(90) }).expect(200);
    });
  });

  describe('protection', () => {
    it('limits searches per client address and says when to retry', async () => {
      const ip = '203.0.113.77';
      const query = { from: bengaluru.toHexString(), to: mysuru.toHexString(), date };
      for (let i = 0; i < 60; i += 1) {
        await client(context, ip).get(SEARCH).query(query).expect(200);
      }
      const blocked = await client(context, ip).get(SEARCH).query(query).expect(429);
      expect(errorCodeOf(blocked)).toBe('RATE_LIMITED');
      expect(
        (blocked.body as { error: { details: { retryAfterSeconds: number } } }).error.details
          .retryAfterSeconds,
      ).toBeGreaterThan(0);
      // Another address is not affected
      await search({}).expect(200);
    }, 60_000);

    it('being a guest gives no access to anything personal', async () => {
      await client(context).get('/api/v1/me').expect(401);
      await client(context).get('/api/v1/users').expect(401);
    });
  });
});
