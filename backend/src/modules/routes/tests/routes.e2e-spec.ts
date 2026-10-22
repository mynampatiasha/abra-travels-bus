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
interface RouteView {
  id: string;
  operatorId: string | null;
  name: string;
  from: string;
  to: string;
  km: number;
  hours: number;
  status: string;
  stops: { placeId: string; name: string; city: string; offset: number; type: string }[];
  tripsCount: number;
  faresCount: number;
  schedulesCount: number;
}

describe('Routes Management e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let operatorA: Caller;
  let operatorB: Caller;

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
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}routes`);
    operatorA = await signIn('OPERATOR_ADMIN', network.operator.id);

    const operatorBRecord = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Routes Pvt Ltd`,
      displayName: `Operator B ${runId}`,
    });
    await catalogueApi(context, superAdmin)
      .post(`/operators/${operatorBRecord.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' })
      .expect(201);
    operatorB = await signIn('OPERATOR_ADMIN', operatorBRecord.id);
  }, 120000);

  afterAll(async () => {
    if (context) {
      await clearCatalogue(context);
      await context.close();
    }
  });

  it('A: creates an operator route with validated stops in chronological order', async () => {
    const res = await call(operatorA).post('/client/routes', {
      from: 'Bengaluru',
      to: 'Hyderabad',
      name: 'Bengaluru to Hyderabad Express',
      km: 570,
      hours: 10,
      stops: [
        { placeId: 'PL1', name: 'Majestic Bus Stand', city: 'Bengaluru', offset: 0, type: 'BOARDING' },
        { placeId: 'PL2', name: 'Anantapur Bypass', city: 'Anantapur', offset: 240, type: 'BOTH' },
        { placeId: 'PL3', name: 'MGBS Bus Stand', city: 'Hyderabad', offset: 600, type: 'DROPPING' },
      ],
    });
    expect(res.status).toBe(201);
    const route = dataOf<RouteView>(res);
    expect(route.id).toBeDefined();
    expect(route.operatorId).toBe(network.operator.id);
    expect(route.name).toBe('Bengaluru to Hyderabad Express');
    expect(route.stops).toHaveLength(3);
    expect(route.status).toBe('ACTIVE');
  });

  it('B: rejects route creation if distance or duration is invalid', async () => {
    const res = await call(operatorA).post('/client/routes', {
      from: 'Bengaluru',
      to: 'Hyderabad',
      km: 0,
      hours: 10,
      stops: [
        { placeId: 'PL1', name: 'Majestic', city: 'Bengaluru', offset: 0, type: 'BOARDING' },
        { placeId: 'PL3', name: 'MGBS', city: 'Hyderabad', offset: 600, type: 'DROPPING' },
      ],
    });
    expect(res.status).toBe(400);
  });

  it('C: rejects route creation if stops are out of chronological order', async () => {
    const res = await call(operatorA).post('/client/routes', {
      from: 'Bengaluru',
      to: 'Hyderabad',
      km: 570,
      hours: 10,
      stops: [
        { placeId: 'PL1', name: 'Majestic', city: 'Bengaluru', offset: 300, type: 'BOARDING' },
        { placeId: 'PL2', name: 'Anantapur', city: 'Anantapur', offset: 100, type: 'BOTH' },
      ],
    });
    expect(res.status).toBe(400);
  });

  it('D: lists routes including operator routes and shared routes', async () => {
    // Insert a shared Abra route
    await context.connection.collection('routes').insertOne({
      operatorId: null,
      originCityId: new Types.ObjectId(),
      destinationCityId: new Types.ObjectId(),
      from: 'Chennai',
      to: 'Bengaluru',
      name: 'Chennai to Bengaluru Shared',
      km: 350,
      hours: 6,
      estimatedDurationMinutes: 360,
      stops: [
        { placeId: 'PLC1', name: 'Koyambedu', city: 'Chennai', offset: 0, offsetMinutes: 0, sequence: 1, type: 'BOARDING' },
        { placeId: 'PLC2', name: 'Shantinagar', city: 'Bengaluru', offset: 360, offsetMinutes: 360, sequence: 2, type: 'DROPPING' },
      ],
      status: 'ACTIVE',
      isDeleted: false,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const res = await call(operatorA).get('/client/routes');
    expect(res.status).toBe(200);
    const data = dataOf<RouteView[]>(res);
    expect(data.length).toBeGreaterThanOrEqual(2);
    const shared = data.find((r) => r.name.includes('Shared'));
    expect(shared).toBeDefined();
    expect(shared?.operatorId).toBeNull();
  });

  it('E: copies a shared route as an operator-owned route', async () => {
    const listRes = await call(operatorA).get('/client/routes');
    const data = dataOf<RouteView[]>(listRes);
    const shared = data.find((r) => r.operatorId === null);
    expect(shared).toBeDefined();

    const copyRes = await call(operatorA).post(`/client/routes/${shared!.id}/copy`);
    expect(copyRes.status).toBe(201);
    const copied = dataOf<RouteView>(copyRes);
    expect(copied.operatorId).toBe(network.operator.id);
    expect(copied.name).toBe(`${shared!.name} (mine)`);
  });

  it('F: edits an operator-owned route but forbids editing shared route', async () => {
    const listRes = await call(operatorA).get('/client/routes');
    const data = dataOf<RouteView[]>(listRes);
    const mine = data.find((r) => r.operatorId === network.operator.id);
    const shared = data.find((r) => r.operatorId === null);

    // Edit own route
    const editRes = await call(operatorA).put(`/client/routes/${mine!.id}`, {
      km: 580,
      hours: 11,
    });
    expect(editRes.status).toBe(200);
    expect(dataOf<RouteView>(editRes).km).toBe(580);

    // Edit shared route should fail
    const sharedEditRes = await call(operatorA).put(`/client/routes/${shared!.id}`, {
      km: 400,
    });
    expect(sharedEditRes.status).toBe(400);
  });

  it('G: tenant isolation: operator B cannot see or delete operator A route', async () => {
    const listA = await call(operatorA).get('/client/routes');
    const routeA = dataOf<RouteView[]>(listA).find((r) => r.operatorId === network.operator.id);
    expect(routeA).toBeDefined();

    // Operator B get
    const getRes = await call(operatorB).get(`/client/routes/${routeA!.id}`);
    expect(getRes.status).toBe(404);

    // Operator B delete
    const delRes = await call(operatorB).delete(`/client/routes/${routeA!.id}`);
    expect(delRes.status).toBe(404);
  });
});
