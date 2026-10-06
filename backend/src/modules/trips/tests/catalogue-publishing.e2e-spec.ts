import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
} from '../../authentication/tests/auth-e2e.harness';
import { type AuditEntry, seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import { type ManagedTripView } from '../services/trip-management.service';
import { type TripDetailView, type TripSummaryView } from '../services/trip-discovery.views';
import {
  buildNetwork,
  type CatalogueApi,
  catalogueApi,
  errorMessageOf,
  type Identified,
  type Network,
  tripBody,
  uniqueRegistration,
} from './catalogue-e2e.support';
import { clearDiscoveryData, indiaTime, runId, travelDateIn } from './discovery-e2e.fixture';

const COLLECTIONS = ['trips', 'routes', 'buses', 'bus_types', 'locations', 'operators', 'cities'];

async function clearCatalogue(context: AuthTestContext): Promise<void> {
  await clearDiscoveryData(context);
  for (const collection of COLLECTIONS) {
    await context.connection.collection(collection).deleteMany({});
  }
}

/**
 * From an empty database to a bus in customer search, entirely through the API — real
 * application, MongoDB replica set and Redis.
 */
describe('Catalogue e2e: publishing a trip to customer search', () => {
  let context: AuthTestContext;
  let admin: CatalogueApi;
  let network: Network;

  /** What a guest finds for Bengaluru to Tirupati on a date. */
  const customerSearch = async (daysAhead: number) =>
    dataOf<TripSummaryView[]>(
      await client(context)
        .get('/api/v1/trips/search')
        .query({
          from: network.bengaluru.id,
          to: network.tirupati.id,
          date: travelDateIn(daysAhead),
        })
        .expect(200),
    );
  const draft = (daysAhead: number, overrides: object = {}) =>
    admin.create<ManagedTripView>('/trips', tripBody(network, daysAhead, overrides));
  const publish = (id: string) => admin.post(`/trips/${id}/publish`);

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    admin = catalogueApi(context, await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] }));
    network = await buildNetwork(admin, runId);
  }, 120_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('the catalogue built through the API is what customers choose from', async () => {
    const cities = dataOf<{ id: string; name: string }[]>(
      await client(context).get('/api/v1/cities').query({ query: 'Tirupati' }).expect(200),
    );
    expect(cities.map((city) => city.id)).toEqual([network.tirupati.id]);
  });

  it('a draft is invisible; publishing puts it in customer search with real data', async () => {
    const trip = await draft(7);
    expect(trip).toMatchObject({
      status: 'DRAFT',
      operatorId: network.operator.id,
      departureTime: '21:30',
      durationMinutes: 300,
      departureAt: indiaTime(travelDateIn(7), '21:30').toISOString(),
      seatCounts: { total: 0, available: 0 },
      publishedAt: null,
    });
    expect(await customerSearch(7)).toEqual([]);
    await client(context).get(`/api/v1/trips/${trip.id}`).expect(404);

    const published = dataOf<ManagedTripView>(await publish(trip.id).expect(201));
    expect(published).toMatchObject({
      status: 'SCHEDULED',
      seatCounts: { total: 36, available: 36, booked: 0 },
    });
    expect(published.publishedAt).not.toBeNull();

    const [found, ...others] = await customerSearch(7);
    expect(others).toEqual([]);
    expect(found).toMatchObject({
      id: trip.id,
      operator: { id: network.operator.id, name: `Test Operator ${runId}` },
      bus: {
        name: 'Tirupati Express',
        typeName: 'AC Sleeper',
        isAc: true,
        amenities: ['WIFI', 'CHARGING_POINT', 'BLANKET'],
      },
      origin: { id: network.bengaluru.id, name: `Bengaluru ${runId}` },
      destination: { id: network.tirupati.id, name: `Tirupati ${runId}` },
      travelDate: travelDateIn(7),
      departureAt: indiaTime(travelDateIn(7), '21:30').toISOString(),
      arrivalAt: indiaTime(travelDateIn(7), '02:30', 1).toISOString(),
      durationMinutes: 300,
      fare: { startingPaise: 85_000, currency: 'INR' },
      seats: { total: 36, available: 36, isSoldOut: false },
      boardingPoints: [{ name: 'Majestic Bus Stand' }],
      droppingPoints: [{ name: 'Tirupati Central Bus Stand' }],
    });

    const details = dataOf<TripDetailView>(
      await client(context).get(`/api/v1/trips/${trip.id}`).expect(200),
    );
    expect(details.stops).toEqual([{ id: network.chittoor.id, name: `Chittoor ${runId}` }]);
    expect(details.boardingPoints[0]).toMatchObject({
      address: 'Kempegowda Bus Station, Gandhi Nagar',
      landmark: 'Platform 12',
      instructions: 'Report 15 minutes early',
      location: { latitude: 12.9774, longitude: 77.5708 },
    });
    // Another date and the opposite direction stay empty
    expect(await customerSearch(8)).toEqual([]);
  });

  it('a cancelled trip leaves customer search at once', async () => {
    const trip = await draft(9, { departureTime: '06:00' });
    await publish(trip.id).expect(201);
    expect((await customerSearch(9)).map((found) => found.id)).toEqual([trip.id]);

    const cancelled = dataOf<ManagedTripView>(
      await admin.post(`/trips/${trip.id}/cancel`, { reason: 'Bus breakdown' }).expect(201),
    );
    expect(cancelled).toMatchObject({ status: 'CANCELLED', cancellationReason: 'Bus breakdown' });
    expect(await customerSearch(9)).toEqual([]);
    await client(context).get(`/api/v1/trips/${trip.id}`).expect(404);
  });

  it('the lifecycle only moves forward', async () => {
    const trip = await draft(10);
    await admin.post(`/trips/${trip.id}/cancel`, { reason: 'No demand' }).expect(201);
    for (const response of [
      await publish(trip.id),
      await admin.post(`/trips/${trip.id}/cancel`, { reason: 'Again' }),
      await admin.put(`/trips/${trip.id}`, { startingFarePaise: 90_000 }),
    ]) {
      expect(response.status).toBe(409);
      expect(errorCodeOf(response)).toBe('INVALID_STATE_TRANSITION');
    }

    const live = await draft(11);
    await publish(live.id).expect(201);
    // Published trips are not edited, and not published twice
    expect(errorCodeOf(await admin.put(`/trips/${live.id}`, { startingFarePaise: 1_000 }))).toBe(
      'INVALID_STATE_TRANSITION',
    );
    expect(errorCodeOf(await publish(live.id))).toBe('INVALID_STATE_TRANSITION');
    await admin.post(`/trips/${live.id}/cancel`, { reason: 'Cleanup' }).expect(201);
  });

  it('a draft can be edited before it is published', async () => {
    const trip = await draft(12);
    const edited = dataOf<ManagedTripView>(
      await admin
        .put(`/trips/${trip.id}`, { departureTime: '22:15', startingFarePaise: 99_900 })
        .expect(200),
    );
    expect(edited).toMatchObject({
      status: 'DRAFT',
      departureTime: '22:15',
      startingFarePaise: 99_900,
      departureAt: indiaTime(travelDateIn(12), '22:15').toISOString(),
    });
    // Point ids stay the same across edits, so later references to them remain valid
    expect(edited.boardingPoints[0]?.pointId).toBe(trip.boardingPoints[0]?.pointId);
    await publish(trip.id).expect(201);
    expect((await customerSearch(12))[0]?.fare.startingPaise).toBe(99_900);
    await admin.post(`/trips/${trip.id}/cancel`, { reason: 'Cleanup' }).expect(201);
  });

  describe('publishing is refused while something the trip depends on is not in order', () => {
    const refusal = async (id: string) => {
      const response = await publish(id).expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
      return errorMessageOf(response);
    };

    it('an inactive bus', async () => {
      const trip = await draft(14);
      await admin.post(`/buses/${network.bus.id}/status`, { status: 'MAINTENANCE' }).expect(201);
      expect(await refusal(trip.id)).toBe('The bus is not active.');
      expect(await customerSearch(14)).toEqual([]);

      await admin.post(`/buses/${network.bus.id}/status`, { status: 'ACTIVE' }).expect(201);
      await publish(trip.id).expect(201);
      await admin.post(`/trips/${trip.id}/cancel`, { reason: 'Cleanup' }).expect(201);
    });

    it('an inactive route', async () => {
      const trip = await draft(15);
      await admin.post(`/routes/${network.route.id}/status`, { status: 'INACTIVE' }).expect(201);
      expect(await refusal(trip.id)).toBe('The route is not active.');
      await admin.post(`/routes/${network.route.id}/status`, { status: 'ACTIVE' }).expect(201);
    });

    it('an inactive boarding location', async () => {
      const trip = await draft(16);
      await admin.post(`/locations/${network.boarding.id}/active`, { active: false }).expect(201);
      expect(await refusal(trip.id)).toBe('The location "Majestic Bus Stand" is not active.');
      await admin.post(`/locations/${network.boarding.id}/active`, { active: true }).expect(201);
    });

    it('an inactive bus type, and an inactive destination city', async () => {
      const trip = await draft(17);
      await admin.post(`/bus-types/${network.busType.id}/active`, { active: false }).expect(201);
      expect(await refusal(trip.id)).toBe('The bus type is not active.');
      await admin.post(`/bus-types/${network.busType.id}/active`, { active: true }).expect(201);

      await admin.post(`/cities/${network.tirupati.id}/active`, { active: false }).expect(201);
      expect(await refusal(trip.id)).toBe('The origin or destination city is not active.');
      await admin.post(`/cities/${network.tirupati.id}/active`, { active: true }).expect(201);
    });

    it('a suspended operator; and suspending hides trips already on sale', async () => {
      const live = await draft(18);
      await publish(live.id).expect(201);
      const waiting = await draft(19);
      await admin
        .post(`/operators/${network.operator.id}/status`, {
          status: 'SUSPENDED',
          reason: 'Compliance review',
        })
        .expect(201);

      expect(await refusal(waiting.id)).toBe('The operator is not active.');
      expect(await customerSearch(18)).toEqual([]);

      await admin
        .post(`/operators/${network.operator.id}/status`, { status: 'ACTIVE', reason: 'Cleared' })
        .expect(201);
      expect((await customerSearch(18)).map((found) => found.id)).toEqual([live.id]);
      await admin.post(`/trips/${live.id}/cancel`, { reason: 'Cleanup' }).expect(201);
    });

    it('a bus that is already on another trip at that time', async () => {
      const first = await draft(21, { departureTime: '20:00' });
      const overlapping = await draft(21, { departureTime: '23:00' });
      const later = await draft(22, { departureTime: '08:00' });
      await publish(first.id).expect(201);
      expect(await refusal(overlapping.id)).toBe(
        'The bus is already on another trip during this time.',
      );
      await publish(later.id).expect(201);
    });

    it('a departure that has already passed', async () => {
      const trip = await draft(0, { departureTime: '00:00' });
      expect(await refusal(trip.id)).toBe('The departure time has already passed.');
    });
  });

  describe('a trip must be consistent with its bus and route', () => {
    let otherOperator: Identified;
    let otherBus: Identified;
    let elsewhere: Identified;

    beforeAll(async () => {
      otherOperator = await admin.create<Identified>('/operators', { companyName: 'Other Lines' });
      otherBus = await admin.create<Identified>('/buses', {
        operatorId: otherOperator.id,
        registrationNumber: uniqueRegistration(),
        name: 'Other Bus',
        busTypeId: network.busType.id,
        seatCapacity: 40,
      });
      const hyderabad = await admin.create<Identified>('/cities', {
        name: `Hyderabad ${runId}`,
        state: 'Test State',
      });
      elsewhere = await admin.create<Identified>('/locations', {
        cityId: hyderabad.id,
        name: 'MGBS',
        address: 'Gowliguda',
      });
    });

    it.each<[string, () => object, string]>([
      [
        'a bus of another operator',
        () => ({ busId: otherBus.id }),
        'The bus and the route belong to different operators.',
      ],
      ['a bus that does not exist', () => ({ busId: '507f1f77bcf86cd799439011' }), 'busId'],
      ['a route that does not exist', () => ({ routeId: '507f1f77bcf86cd799439011' }), 'routeId'],
      [
        'a boarding point outside the route',
        () => ({ boardingPoints: [{ locationId: elsewhere.id, offsetMinutes: 0 }] }),
        'is not in a city of this route',
      ],
      [
        'a boarding point in the destination city',
        () => ({ boardingPoints: [{ locationId: network.dropping.id, offsetMinutes: 0 }] }),
        'is not in a city of this route',
      ],
      [
        'a dropping point in the origin city',
        () => ({ droppingPoints: [{ locationId: network.boarding.id, offsetMinutes: 300 }] }),
        'is not in a city of this route',
      ],
      [
        'a location that does not exist',
        () => ({
          droppingPoints: [{ locationId: '507f1f77bcf86cd799439011', offsetMinutes: 300 }],
        }),
        'not a location this operator can use',
      ],
      [
        'a dropping point after the arrival',
        () => ({ droppingPoints: [{ locationId: network.dropping.id, offsetMinutes: 301 }] }),
        'outside the journey',
      ],
      [
        'a dropping point before boarding',
        () => ({
          boardingPoints: [{ locationId: network.boarding.id, offsetMinutes: 60 }],
          droppingPoints: [{ locationId: network.dropping.id, offsetMinutes: 60 }],
        }),
        'must come after the first boarding point',
      ],
      [
        'the same boarding location twice',
        () => ({
          boardingPoints: [
            { locationId: network.boarding.id, offsetMinutes: 0 },
            { locationId: network.boarding.id, offsetMinutes: 10 },
          ],
        }),
        'can be used once',
      ],
      ['a date in the past', () => ({ travelDate: travelDateIn(-1) }), 'travelDate must be'],
      ['a date beyond 180 days', () => ({ travelDate: travelDateIn(181) }), 'travelDate must be'],
      ['a date that does not exist', () => ({ travelDate: '2027-02-30' }), 'travelDate must be'],
    ])('rejects %s', async (_name, overrides, message) => {
      const response = await admin.post('/trips', tripBody(network, 30, overrides())).expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
      expect(errorMessageOf(response)).toContain(message);
    });

    it.each<[string, object]>([
      ['a malformed time', { departureTime: '25:00' }],
      ['a zero fare', { startingFarePaise: 0 }],
      ['a fractional fare', { startingFarePaise: 850.5 }],
      ['no boarding points', { boardingPoints: [] }],
      ['no dropping points', { droppingPoints: [] }],
      ['an unknown field', { status: 'SCHEDULED' }],
      ['a seat count set by the client', { seatCounts: { total: 500, available: 500 } }],
    ])('rejects %s', async (_name, overrides) => {
      const response = await admin.post('/trips', tripBody(network, 30, overrides)).expect(400);
      expect(errorCodeOf(response)).toBe('VALIDATION_FAILED');
    });
  });

  it('every step is in the audit trail, with who and why', async () => {
    const trip = await draft(40);
    await publish(trip.id).expect(201);
    await admin.post(`/trips/${trip.id}/cancel`, { reason: 'Audit check' }).expect(201);

    const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    const entries = dataOf<AuditEntry[]>(
      await client(context)
        .get(`/api/v1/audit-logs?entityId=${trip.id}&pageSize=50`)
        .set(...bearer(superAdmin.tokens))
        .expect(200),
    );
    expect(entries.map((entry) => entry.action).sort()).toEqual([
      'catalogue.created',
      'trip.cancelled',
      'trip.published',
    ]);
    const cancelled = entries.find((entry) => entry.action === 'trip.cancelled');
    expect(cancelled).toMatchObject({
      entityType: 'trip',
      operatorId: network.operator.id,
      reason: 'Audit check',
      before: { status: 'SCHEDULED' },
      after: { status: 'CANCELLED', cancellationReason: 'Audit check' },
    });
  });
});
