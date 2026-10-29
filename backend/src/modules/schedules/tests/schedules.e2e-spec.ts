import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  buildNetwork,
  catalogueApi,
  clearCatalogue,
  type Identified,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';
interface Caller { tokens: Tokens; }
interface ScheduleView {
  id: string;
  operatorId: string;
  routeId: string;
  route: string;
  busId: string;
  bus: string;
  time: string;
  days: string[];
  from: string;
  to: string;
  status: string;
  fare: number;
}
interface GeneratedTrip {
  bus: { isAc: boolean; berthType: string; busTypeName: string };
  originCityId: Types.ObjectId;
  destinationCityId: Types.ObjectId;
  stopCityIds: Types.ObjectId[];
  boardingPoints: { name: string; time: Date }[];
  droppingPoints: { name: string; time: Date }[];
  departureAt: Date;
  travelDate: string;
  startingFarePaise: number;
}
interface GenerateResult {
  createdCount: number;
  skippedCount: number;
  message: string;
}

describe('Schedules Management e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let operatorA: Caller;
  let operatorB: Caller;
  let routeIdA: string;
  let busIdA: string;
  let cityNames: { origin: string; destination: string; via: string };
  const SEARCH = `${API}/trips/search`;

  const call = (caller: Caller) => ({
    get: (pathStr: string) => client(context).get(`${API}${pathStr}`).set(...bearer(caller.tokens)),
    post: (pathStr: string, body: object = {}) => client(context).post(`${API}${pathStr}`).set(...bearer(caller.tokens)).send(body),
    put: (pathStr: string, body: object = {}) => client(context).put(`${API}${pathStr}`).set(...bearer(caller.tokens)).send(body),
    delete: (pathStr: string) => client(context).delete(`${API}${pathStr}`).set(...bearer(caller.tokens)),
  });

  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, { roleKeys: [roleKey], ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}) });

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}sched`);
    operatorA = await signIn('OPERATOR_ADMIN', network.operator.id);

    const operatorBRecord = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Sched Pvt Ltd`,
      displayName: `Operator B ${runId}`,
    });
    await catalogueApi(context, superAdmin)
      .post(`/operators/${operatorBRecord.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' })
      .expect(201);
    operatorB = await signIn('OPERATOR_ADMIN', operatorBRecord.id);

    // The route runs between the network's real cities, through Chittoor, and its end stops are
    // real approved places.
    cityNames = {
      origin: `Bengaluru ${runId}sched`,
      destination: `Tirupati ${runId}sched`,
      via: `Chittoor ${runId}sched`,
    };
    const routeRes = await call(operatorA).post('/client/routes', {
      from: cityNames.origin,
      to: cityNames.destination,
      name: 'Bengaluru to Tirupati Highway',
      km: 250,
      hours: 5,
      stops: [
        { placeId: network.boarding.id, name: 'Majestic', city: cityNames.origin, offset: 0, type: 'BOARDING' },
        { placeId: 'P-via', name: 'Chittoor Stand', city: cityNames.via, offset: 150, type: 'BOTH' },
        { placeId: network.dropping.id, name: 'Tirupati Central', city: cityNames.destination, offset: 300, type: 'DROPPING' },
      ],
    });
    expect(routeRes.status).toBe(201);
    routeIdA = dataOf<{ id: string }>(routeRes).id;

    // Use active bus from buildNetwork
    busIdA = network.bus.id;
  }, 120000);

  afterAll(async () => {
    if (context) {
      await clearCatalogue(context);
      await context.close();
    }
  });

  const scheduleBody = (overrides: object = {}) => {
    const today = new Date().toISOString().slice(0, 10);
    const in60Days = new Date(Date.now() + 60 * 24 * 3600000).toISOString().slice(0, 10);
    return {
      routeId: routeIdA,
      busId: busIdA,
      time: '21:30',
      days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      from: today,
      to: in60Days,
      status: 'ACTIVE',
      ...overrides,
    };
  };

  it('A0: refuses a schedule when the route has no fare for the bus type', async () => {
    const res = await call(operatorA).post('/client/schedules', scheduleBody());
    expect(res.status).toBe(400);
    expect(JSON.stringify(res.body)).toContain(
      'Add a fare for Bengaluru to Tirupati Highway and AC Sleeper first.',
    );
    const stored = await context.connection.collection('schedules').countDocuments({});
    expect(stored).toBe(0);
  });

  it('A: creates a recurring schedule with days and bus', async () => {
    const fareRes = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'AC Sleeper',
      weekday: 120000,
      weekend: 135000,
      festival: 150000,
      from: '2026-01-01',
      status: 'ACTIVE',
    });
    expect(fareRes.status).toBe(201);

    const today = new Date().toISOString().slice(0, 10);
    const in60Days = new Date(Date.now() + 60 * 24 * 3600000).toISOString().slice(0, 10);

    const res = await call(operatorA).post('/client/schedules', {
      routeId: routeIdA,
      busId: busIdA,
      time: '21:30',
      days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      from: today,
      to: in60Days,
      status: 'ACTIVE',
    });
    expect(res.status).toBe(201);
    const sched = dataOf<ScheduleView>(res);
    expect(sched.id).toBeDefined();
    expect(sched.route).toBe('Bengaluru to Tirupati Highway');
    expect(sched.days).toHaveLength(7);
    expect(sched.status).toBe('ACTIVE');
  });

  it('B: validates schedule days and date range', async () => {
    // No days selected
    const resNoDays = await call(operatorA).post('/client/schedules', {
      routeId: routeIdA,
      busId: busIdA,
      time: '21:30',
      days: [],
      from: '2026-10-15',
      to: '2026-11-15',
    });
    expect(resNoDays.status).toBe(400);

    // Till before From
    const resBadDates = await call(operatorA).post('/client/schedules', {
      routeId: routeIdA,
      busId: busIdA,
      time: '21:30',
      days: ['Mon'],
      from: '2026-11-15',
      to: '2026-10-15',
    });
    expect(resBadDates.status).toBe(400);
  });

  it('C: generates trips for the next 14 days and detects conflicts on re-generation', async () => {
    const listRes = await call(operatorA).get('/client/schedules');
    const schedId = dataOf<ScheduleView[]>(listRes)[0]!.id;

    // First trip generation
    const gen1 = await call(operatorA).post(`/client/schedules/${schedId}/generate-trips`);
    expect(gen1.status).toBe(201);
    const result1 = dataOf<GenerateResult>(gen1);
    expect(result1.createdCount).toBeGreaterThan(0);
    expect(result1.skippedCount).toBe(0);
    expect(result1.message).toContain('draft trips created');

    // Every generated trip says the truth about the bus, the cities and the points.
    const trips = await context.connection
      .collection<GeneratedTrip>('trips')
      .find({ scheduleId: new Types.ObjectId(schedId) } as object)
      .toArray();
    expect(trips).toHaveLength(result1.createdCount);
    const cityIds = new Set(
      (await context.connection.collection('cities').find({}).toArray()).map((c) => String(c._id)),
    );
    const viaCity = await context.connection.collection('cities').findOne({ name: cityNames.via });
    for (const trip of trips) {
      expect(trip.bus.isAc).toBe(true);
      expect(trip.bus.berthType).toBe('SLEEPER');
      expect(trip.bus.busTypeName).toBe('AC Sleeper');
      expect(String(trip.originCityId)).toBe(network.bengaluru.id);
      expect(String(trip.destinationCityId)).toBe(network.tirupati.id);
      expect(cityIds.has(String(trip.originCityId))).toBe(true);
      expect(cityIds.has(String(trip.destinationCityId))).toBe(true);
      // Only the places in between, never the two ends
      expect(trip.stopCityIds.map(String)).toEqual([String(viaCity?._id)]);
      expect(trip.boardingPoints.length).toBeGreaterThan(0);
      expect(trip.droppingPoints.length).toBeGreaterThan(0);
      for (const point of [...trip.boardingPoints, ...trip.droppingPoints]) {
        expect(point.time).toBeInstanceOf(Date);
        expect(point.name).toBeTruthy();
      }
      // The price comes from the fare, not a default
      const weekend = [5, 6].includes((new Date(trip.departureAt).getDay() + 6) % 7);
      expect(trip.startingFarePaise).toBe(weekend ? 135000 : 120000);
    }

    // Second trip generation on same schedule: should skip existing trips
    const gen2 = await call(operatorA).post(`/client/schedules/${schedId}/generate-trips`);
    expect(gen2.status).toBe(201);
    const result2 = dataOf<GenerateResult>(gen2);
    expect(result2.createdCount).toBe(0);
    expect(result2.skippedCount).toBe(result1.createdCount);
    expect(result2.message).toContain('skipped (bus already busy that day)');
  });

  it('D: tenant isolation: operator B cannot access or generate trips from operator A schedule', async () => {
    const listA = await call(operatorA).get('/client/schedules');
    const schedIdA = dataOf<ScheduleView[]>(listA)[0]!.id;

    const getRes = await call(operatorB).get(`/client/schedules/${schedIdA}`);
    expect(getRes.status).toBe(404);

    const genRes = await call(operatorB).post(`/client/schedules/${schedIdA}/generate-trips`);
    expect(genRes.status).toBe(404);
  });

  it('E: repairs an old route with made-up city ids when trips are generated', async () => {
    const admin = catalogueApi(context, superAdmin);
    const secondBus = await admin.create<Identified>('/buses', {
      operatorId: network.operator.id,
      registrationNumber: `KA${Math.floor(10 + Math.random() * 89)}ZZ${Math.floor(1000 + Math.random() * 8999)}`,
      name: 'Repair Express',
      busTypeId: network.busType.id,
      amenities: [],
      seatCapacity: 30,
    });
    // An old route, saved before cities were checked: random ids everywhere
    await context.connection.collection('routes').updateOne(
      { _id: new Types.ObjectId(routeIdA) },
      {
        $set: {
          originCityId: new Types.ObjectId(),
          destinationCityId: new Types.ObjectId(),
          'stops.0.cityId': new Types.ObjectId(),
          'stops.1.cityId': new Types.ObjectId(),
          'stops.2.cityId': new Types.ObjectId(),
        },
      },
    );
    const created = await call(operatorA).post(
      '/client/schedules',
      scheduleBody({ busId: secondBus.id, time: '23:00' }),
    );
    expect(created.status).toBe(201);
    const scheduleId = dataOf<ScheduleView>(created).id;
    const gen = await call(operatorA).post(`/client/schedules/${scheduleId}/generate-trips`);
    expect(gen.status).toBe(201);
    expect(dataOf<GenerateResult>(gen).createdCount).toBeGreaterThan(0);

    const route = await context.connection.collection('routes').findOne({ _id: new Types.ObjectId(routeIdA) });
    expect(String(route?.originCityId)).toBe(network.bengaluru.id);
    expect(String(route?.destinationCityId)).toBe(network.tirupati.id);
    const trip = await context.connection
      .collection('trips')
      .findOne({ scheduleId: new Types.ObjectId(scheduleId) });
    expect(String(trip?.originCityId)).toBe(network.bengaluru.id);
    expect(String(trip?.destinationCityId)).toBe(network.tirupati.id);
  });

  it('F: a published generated trip is found by customer search on the real city ids', async () => {
    const trip = await context.connection
      .collection<GeneratedTrip>('trips')
      .findOne({ busId: new Types.ObjectId(busIdA) } as object, { sort: { departureAt: 1 } });
    expect(trip).not.toBeNull();
    // Put it on sale as publishing does (publishing itself needs a seat layout, which is not
    // what this test is about).
    await context.connection
      .collection('trips')
      .updateOne(
        { _id: trip!._id },
        { $set: { status: 'SCHEDULED', publishedAt: new Date(), seatLayoutVersionId: new Types.ObjectId() } },
      );

    const res = await client(context)
      .get(SEARCH)
      .query({ from: network.bengaluru.id, to: network.tirupati.id, date: trip!.travelDate });
    expect(res.status).toBe(200);
    const found = dataOf<{ id: string }[]>(res);
    expect(found.some((t) => t.id === String(trip!._id))).toBe(true);
  });
});
