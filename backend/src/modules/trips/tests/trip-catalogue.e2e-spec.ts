import { type Types } from 'mongoose';
import {
  type AuthTestContext,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
} from '../../authentication/tests/auth-e2e.harness';
import { type CityView } from '../../cities/services/cities.service';
import { type TripDetailView, type TripSearchFiltersView } from '../services/trip-discovery.views';
import {
  clearDiscoveryData,
  indiaTime,
  runId,
  seedCity,
  seedOperator,
  seedTrip,
  travelDateIn,
} from './discovery-e2e.fixture';

/** Point ids are generated; any string is accepted. */
const anyId = expect.any(String) as unknown as string;

/** Cities, search filters and trip details — real application, MongoDB replica set and Redis. */
describe('Discovery e2e: cities, filters and trip details', () => {
  let context: AuthTestContext;
  let origin: Types.ObjectId;
  let destination: Types.ObjectId;
  let via: Types.ObjectId;
  let abra: Types.ObjectId;
  let kaveri: Types.ObjectId;
  const date = travelDateIn(5);
  // Names no other suite uses, so prefix searches see only these cities
  const prefix = `Zq${runId}`;
  const trips: Record<string, Types.ObjectId> = {};

  const api = () => client(context);

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearDiscoveryData(context);
    origin = await seedCity(context, `${prefix} Alpha`, {
      isPopular: true,
      sortOrder: 2,
      translations: { kn: `ಕನ್ನಡ${runId}` },
    });
    destination = await seedCity(context, `${prefix} Beta`, { isPopular: true, sortOrder: 1 });
    via = await seedCity(context, `${prefix} Gamma`);
    await seedCity(context, `${prefix} Retired`, { isActive: false, isPopular: true });
    abra = await seedOperator(context, 'Abra Travels Private Limited', 'ACTIVE', 'Abra Travels');
    kaveri = await seedOperator(context, 'Kaveri Lines');
    const suspended = await seedOperator(context, 'Suspended Lines', 'SUSPENDED');
    const base = { originCityId: origin, destinationCityId: destination, travelDate: date };

    trips.morning = await seedTrip(context, {
      ...base,
      operatorId: abra,
      departure: '05:30',
      durationMinutes: 300,
      farePaise: 80_000,
      amenities: ['WIFI', 'BLANKET'],
      stopCityIds: [via],
    });
    trips.evening = await seedTrip(context, {
      ...base,
      operatorId: kaveri,
      departure: '19:00',
      durationMinutes: 320,
      farePaise: 45_000,
      busType: { key: 'NON_AC_SEATER', name: 'Non-AC Seater', isAc: false, berthType: 'SEATER' },
      amenities: ['WIFI'],
    });
    trips.late = await seedTrip(context, {
      ...base,
      operatorId: abra,
      departure: '23:30',
      durationMinutes: 280,
      farePaise: 99_900,
    });
    trips.draft = await seedTrip(context, {
      ...base,
      operatorId: abra,
      departure: '12:00',
      durationMinutes: 300,
      farePaise: 1_000,
      status: 'DRAFT',
    });
    trips.suspended = await seedTrip(context, {
      ...base,
      operatorId: suspended,
      departure: '12:30',
      durationMinutes: 300,
      farePaise: 1_000,
      amenities: ['TOILET'],
    });
  }, 90_000);

  afterAll(async () => {
    await clearDiscoveryData(context);
    await context.close();
  }, 60_000);

  describe('GET /cities', () => {
    const cities = async (query: Record<string, string | number>, language?: string) => {
      const request = api().get('/api/v1/cities').query(query);
      if (language) void request.set('Accept-Language', language);
      return dataOf<CityView[]>(await request.expect(200));
    };

    it('without a query: the popular cities in their order, active only', async () => {
      const result = await cities({});
      expect(result.map((city) => city.name)).toEqual([`${prefix} Beta`, `${prefix} Alpha`]);
      expect(Object.keys(result[0]!).sort()).toEqual(['id', 'name', 'slug', 'state']);
    });

    it('finds cities by the start of the name, whatever the letter case', async () => {
      expect((await cities({ query: prefix.toUpperCase() })).map((city) => city.name)).toEqual([
        `${prefix} Beta`,
        `${prefix} Alpha`,
        `${prefix} Gamma`,
      ]);
      expect(
        (await cities({ query: `${prefix.toLowerCase()} ga` })).map((city) => city.id),
      ).toEqual([via.toHexString()]);
      expect(await cities({ query: 'Alpha' })).toEqual([]);
    });

    it('finds and names a city in the requested language', async () => {
      const [found] = await cities({ query: `ಕನ್ನಡ${runId}` }, 'kn');
      expect(found).toMatchObject({ id: origin.toHexString(), name: `ಕನ್ನಡ${runId}` });
      // The same request in English does not match the Kannada name
      expect(await cities({ query: `ಕನ್ನಡ${runId}` }, 'en')).toEqual([]);
    });

    it('treats the query as text, never as a pattern', async () => {
      expect(await cities({ query: '.*' })).toEqual([]);
      expect(await cities({ query: '(' })).toEqual([]);
    });

    it('honours the limit and rejects invalid input', async () => {
      expect(await cities({ query: prefix, limit: 1 })).toHaveLength(1);
      for (const query of [{ limit: 0 }, { limit: 51 }, { query: 'x'.repeat(41) }]) {
        const response = await api().get('/api/v1/cities').query(query).expect(400);
        expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
      }
    });
  });

  describe('GET /trips/search/filters', () => {
    it('lists what occurs in the search, with counts, for trips on sale only', async () => {
      const filters = dataOf<TripSearchFiltersView>(
        await api()
          .get('/api/v1/trips/search/filters')
          .query({ from: origin.toHexString(), to: destination.toHexString(), date })
          .expect(200),
      );
      expect(filters).toEqual({
        total: 3,
        busTypes: [
          { key: 'AC_SLEEPER', name: 'AC Sleeper', isAc: true, berthType: 'SLEEPER', count: 2 },
          {
            key: 'NON_AC_SEATER',
            name: 'Non-AC Seater',
            isAc: false,
            berthType: 'SEATER',
            count: 1,
          },
        ],
        operators: [
          { id: abra.toHexString(), name: 'Abra Travels', count: 2 },
          { id: kaveri.toHexString(), name: 'Kaveri Lines', count: 1 },
        ],
        // TOILET belongs to the suspended operator's trip and must not appear
        amenities: [
          { key: 'BLANKET', count: 1 },
          { key: 'WIFI', count: 2 },
        ],
        departureWindows: [
          { key: 'EARLY_MORNING', fromMinute: 0, toMinute: 360, count: 1 },
          { key: 'MORNING', fromMinute: 360, toMinute: 720, count: 0 },
          { key: 'AFTERNOON', fromMinute: 720, toMinute: 1080, count: 0 },
          { key: 'NIGHT', fromMinute: 1080, toMinute: 1440, count: 2 },
        ],
        fare: { minPaise: 45_000, maxPaise: 99_900, currency: 'INR' },
      });
    });

    it('an empty search has no filter values', async () => {
      const filters = dataOf<TripSearchFiltersView>(
        await api()
          .get('/api/v1/trips/search/filters')
          .query({ from: destination.toHexString(), to: origin.toHexString(), date })
          .expect(200),
      );
      expect(filters).toMatchObject({
        total: 0,
        busTypes: [],
        operators: [],
        amenities: [],
        fare: null,
      });
    });

    it('validates like the search', async () => {
      const response = await api()
        .get('/api/v1/trips/search/filters')
        .query({ from: origin.toHexString(), to: origin.toHexString(), date })
        .expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
    });
  });

  describe('GET /trips/:tripId', () => {
    it('a guest sees the trip with its points in time order', async () => {
      const trip = dataOf<TripDetailView>(
        await api().get(`/api/v1/trips/${trips.morning!.toHexString()}`).expect(200),
      );
      expect(trip).toMatchObject({
        id: trips.morning!.toHexString(),
        status: 'SCHEDULED',
        operator: { id: abra.toHexString(), name: 'Abra Travels' },
        bus: { name: 'Abra Express', registrationNumber: 'KA01AB1234', typeKey: 'AC_SLEEPER' },
        origin: { id: origin.toHexString(), name: `${prefix} Alpha` },
        destination: { id: destination.toHexString(), name: `${prefix} Beta` },
        stops: [{ id: via.toHexString(), name: `${prefix} Gamma` }],
        travelDate: date,
        departureAt: indiaTime(date, '05:30').toISOString(),
        arrivalAt: indiaTime(date, '10:30').toISOString(),
        durationMinutes: 300,
        fare: { startingPaise: 80_000, currency: 'INR' },
        seats: { total: 36, available: 20, isSoldOut: false },
      });
      expect(trip.boardingPoints).toEqual([
        {
          id: anyId,
          name: 'Central Bus Stand',
          time: indiaTime(date, '05:30').toISOString(),
          city: { id: origin.toHexString(), name: `${prefix} Alpha` },
          address: 'Central Bus Stand, Main Road',
          landmark: 'Opposite City Mall',
          instructions: 'Board at platform 4',
          contactPhone: '+918000000000',
          location: { latitude: 12.9716, longitude: 77.5946 },
        },
        {
          id: anyId,
          name: 'Second Stage',
          time: indiaTime(date, '05:50').toISOString(),
          city: { id: origin.toHexString(), name: `${prefix} Alpha` },
          address: 'Second Stage, Main Road',
          landmark: null,
          instructions: null,
          contactPhone: null,
          location: null,
        },
      ]);
      expect(trip.droppingPoints.map((point) => point.name)).toEqual(['Town Hall']);
      const text = JSON.stringify(trip);
      for (const internal of [
        'operatorId',
        'busId',
        'routeId',
        'seatLayoutVersionId',
        'createdAt',
        '"_id"',
      ]) {
        expect(text).not.toContain(internal);
      }
    });

    it.each([
      ['a draft', () => trips.draft!.toHexString()],
      ["a suspended operator's trip", () => trips.suspended!.toHexString()],
      ['an unknown id', () => '507f1f77bcf86cd799439011'],
    ])('%s answers RESOURCE_NOT_FOUND', async (_name, id) => {
      const response = await api().get(`/api/v1/trips/${id()}`).expect(404);
      expect(errorCodeOf(response)).toBe('RESOURCE_NOT_FOUND');
    });

    it('rejects an id that is not an id', async () => {
      const response = await api().get('/api/v1/trips/not-an-id').expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
    });
  });
});
