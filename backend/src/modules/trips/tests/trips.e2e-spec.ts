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
  type Network,
} from './catalogue-e2e.support';
import { runId } from './discovery-e2e.fixture';

const API = '/api/v1';
interface Caller { tokens: Tokens; }

interface TripItem {
  id: string;
  status: string;
  startingFarePaise: number;
  blockedSeats?: number;
  delayMinutes?: number;
  cancellationReason?: string;
}

interface TripList {
  items: TripItem[];
  kpis: { drafts: number };
}

interface AdminTripList {
  items: TripItem[];
  kpis: Record<string, unknown>;
}

interface SeatItem {
  seatNumber: string;
}

describe('Trips & Seat Inventory Management e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let operatorA: Caller;

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
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}trips`);
    operatorA = await signIn('OPERATOR_ADMIN', network.operator.id);

    // Give bus an active seat layout version so it can be published
    const layoutId = new Types.ObjectId();
    await context.connection.collection('seat_layouts').deleteMany({ busId: new Types.ObjectId(network.bus.id) });
    await context.connection.collection('seat_layouts').insertOne({
      _id: layoutId,
      busId: new Types.ObjectId(network.bus.id),
      operatorId: new Types.ObjectId(network.operator.id),
      version: 1,
      totalSeats: 30,
      seats: [
        { seatNumber: '1', deck: 'LOWER', seatType: 'SEATER' },
        { seatNumber: '2', deck: 'LOWER', seatType: 'SEATER' },
      ],
    });
    await context.connection.collection('buses').updateOne(
      { _id: new Types.ObjectId(network.bus.id) },
      { $set: { activeSeatLayoutVersionId: layoutId, seatCapacity: 30 } },
    );
  });

  afterAll(async () => {
    await context.app.close();
  });

  it('allows an operator to create a draft trip and list it', async () => {
    const res = await call(operatorA).post('/client/trips', {
      routeId: network.route.id,
      busId: network.bus.id,
      travelDate: '2099-06-15',
      departureTime: '20:30',
      startingFarePaise: 85000,
    });
    expect(res.status).toBe(201);
    const trip = dataOf<TripItem>(res);
    expect(trip.status).toBe('DRAFT');
    expect(trip.startingFarePaise).toBe(85000);

    const listRes = await call(operatorA).get('/client/trips');
    expect(listRes.status).toBe(200);
    const list = dataOf<TripList>(listRes);
    expect(list.items.length).toBeGreaterThan(0);
    expect(list.kpis.drafts).toBeGreaterThan(0);
  });

  it('publishes a draft trip and creates seat inventory', async () => {
    const createRes = await call(operatorA).post('/client/trips', {
      routeId: network.route.id,
      busId: network.bus.id,
      travelDate: '2099-06-16',
      departureTime: '21:00',
      startingFarePaise: 90000,
    });
    const tripId = dataOf<TripItem>(createRes).id;

    const pubRes = await call(operatorA).post(`/client/trips/${tripId}/publish`);
    expect(pubRes.status).toBe(201);
    const published = dataOf<TripItem>(pubRes);
    expect(published.status).toBe('SCHEDULED');

    // Verify seats inventory
    const seatsRes = await call(operatorA).get(`/client/trips/${tripId}/seats`);
    expect(seatsRes.status).toBe(200);
    const seats = dataOf<SeatItem[]>(seatsRes);
    expect(seats.length).toBeGreaterThan(0);
  });

  it('allows blocking and unblocking seats on a trip', async () => {
    const createRes = await call(operatorA).post('/client/trips', {
      routeId: network.route.id,
      busId: network.bus.id,
      travelDate: '2099-06-17',
      departureTime: '21:00',
      startingFarePaise: 90000,
      publish: true,
    });
    const tripId = dataOf<TripItem>(createRes).id;

    // Block seat '1'
    const blockRes = await call(operatorA).post(`/client/trips/${tripId}/seats/block`, {
      seatNumbers: ['1'],
      reason: 'Counter sale',
    });
    expect(blockRes.status).toBe(201);

    const tripAfterBlock = dataOf<TripItem>(await call(operatorA).get(`/client/trips/${tripId}`));
    expect(tripAfterBlock.blockedSeats).toBe(1);

    // Unblock seat '1'
    const unblockRes = await call(operatorA).post(`/client/trips/${tripId}/seats/unblock`, {
      seatNumbers: ['1'],
    });
    expect(unblockRes.status).toBe(201);

    const tripAfterUnblock = dataOf<TripItem>(await call(operatorA).get(`/client/trips/${tripId}`));
    expect(tripAfterUnblock.blockedSeats).toBe(0);
  });

  it('delays a trip and records the reason', async () => {
    const createRes = await call(operatorA).post('/client/trips', {
      routeId: network.route.id,
      busId: network.bus.id,
      travelDate: '2099-06-18',
      departureTime: '22:00',
      startingFarePaise: 90000,
    });
    const tripId = dataOf<TripItem>(createRes).id;

    const delayRes = await call(operatorA).post(`/client/trips/${tripId}/delay`, {
      delayMinutes: 30,
      reason: 'Heavy traffic at boarding point',
    });
    expect(delayRes.status).toBe(201);
    const delayed = dataOf<TripItem>(delayRes);
    expect(delayed.status).toBe('DELAYED');
    expect(delayed.delayMinutes).toBe(30);
  });

  it('cancels a trip with a reason', async () => {
    const createRes = await call(operatorA).post('/client/trips', {
      routeId: network.route.id,
      busId: network.bus.id,
      travelDate: '2099-06-19',
      departureTime: '22:00',
      startingFarePaise: 90000,
    });
    const tripId = dataOf<TripItem>(createRes).id;

    const cancelRes = await call(operatorA).post(`/client/trips/${tripId}/cancel`, {
      reason: 'Vehicle maintenance',
    });
    expect(cancelRes.status).toBe(201);
    const cancelled = dataOf<TripItem>(cancelRes);
    expect(cancelled.status).toBe('CANCELLED');
    expect(cancelled.cancellationReason).toBe('Vehicle maintenance');
  });

  it('allows platform staff to view trips across operators and export them', async () => {
    const adminListRes = await call(superAdmin).get('/admin/trips');
    expect(adminListRes.status).toBe(200);
    const adminData = dataOf<AdminTripList>(adminListRes);
    expect(adminData.items.length).toBeGreaterThan(0);
    expect(adminData.kpis).toBeDefined();

    const exportRes = await call(superAdmin).get('/admin/trips/export');
    expect(exportRes.status).toBe(200);
  });
});
