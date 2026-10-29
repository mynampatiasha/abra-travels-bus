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
interface FareView {
  id: string;
  operatorId: string;
  routeId: string;
  route: string;
  seatType: string;
  weekday: number;
  weekend: number;
  festival: number;
  from: string;
  status: string;
  customerPaysWeekday: {
    fare: number;
    cm: number;
    gst: number;
    fee: number;
    total: number;
  };
}

describe('Fares Management e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let operatorA: Caller;
  let operatorB: Caller;
  let routeIdA: string;

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
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}fares`);
    operatorA = await signIn('OPERATOR_ADMIN', network.operator.id);

    const operatorBRecord = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Fares Pvt Ltd`,
      displayName: `Operator B ${runId}`,
    });
    await catalogueApi(context, superAdmin)
      .post(`/operators/${operatorBRecord.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' })
      .expect(201);
    operatorB = await signIn('OPERATOR_ADMIN', operatorBRecord.id);

    // A fare is priced per bus type and a route needs real cities: list them first.
    // ("AC Sleeper" already exists from the network.)
    const admin = catalogueApi(context, superAdmin);
    await admin.create<Identified>('/bus-types', {
      key: `AC_SEATER_${runId.toUpperCase()}FARES`,
      name: 'AC Seater',
      isAc: true,
      berthType: 'SEATER',
    });
    for (const name of ['Bengaluru', 'Chennai']) {
      await admin.create<Identified>('/cities', { name, state: 'Test State' });
    }

    // Create a route for operator A
    const routeRes = await call(operatorA).post('/client/routes', {
      from: 'Bengaluru',
      to: 'Chennai',
      name: 'Bengaluru to Chennai Airavat',
      km: 350,
      hours: 6,
      stops: [
        { placeId: 'P1', name: 'Majestic', city: 'Bengaluru', offset: 0, type: 'BOARDING' },
        { placeId: 'P2', name: 'Koyambedu', city: 'Chennai', offset: 360, type: 'DROPPING' },
      ],
    });
    routeIdA = dataOf<{ id: string }>(routeRes).id;
  }, 120000);

  afterAll(async () => {
    if (context) {
      await clearCatalogue(context);
      await context.close();
    }
  });

  it('A: creates a new fare and calculates customer pays breakdown correctly', async () => {
    const res = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'AC Sleeper',
      weekday: 100000, // Rs 1000
      weekend: 110000, // Rs 1100
      festival: 125000, // Rs 1250
      from: '2026-10-15',
      status: 'ACTIVE',
    });
    expect(res.status).toBe(201);
    const fare = dataOf<FareView>(res);
    expect(fare.id).toBeDefined();
    expect(fare.route).toBe('Bengaluru to Chennai Airavat');
    expect(fare.seatType).toBe('AC Sleeper');
    expect(fare.weekday).toBe(100000);

    // Verify customer pays calculation:
    // fare = 100000
    // cm = 8% = 8000
    // gst = 5% of (100000 + 8000) = 5400
    // fee = 500
    // total = 100000 + 8000 + 5400 + 500 = 113900
    expect(fare.customerPaysWeekday.fare).toBe(100000);
    expect(fare.customerPaysWeekday.cm).toBe(8000);
    expect(fare.customerPaysWeekday.gst).toBe(5400);
    expect(fare.customerPaysWeekday.fee).toBe(500);
    expect(fare.customerPaysWeekday.total).toBe(113900);
  });

  it('A2: refuses a seat type that is not an active bus type', async () => {
    const res = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'Luxury Hovercraft',
      weekday: 100000,
      weekend: 110000,
      festival: 125000,
      from: '2026-10-15',
      status: 'ACTIVE',
    });
    expect(res.status).toBe(400);
    expect(JSON.stringify(res.body)).toContain('is not an active bus type');
  });

  it('B: prevents creating a duplicate active fare for the same route and seat type', async () => {
    const res = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'AC Sleeper',
      weekday: 95000,
      weekend: 105000,
      festival: 120000,
      from: '2026-11-01',
      status: 'ACTIVE',
    });
    expect(res.status).toBe(400);
    expect(JSON.stringify(res.body)).toContain('An active fare already exists');
  });

  it('C: allows creating an INACTIVE fare for the same route and seat type', async () => {
    const res = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'AC Sleeper',
      weekday: 95000,
      weekend: 105000,
      festival: 120000,
      from: '2026-11-01',
      status: 'INACTIVE',
    });
    expect(res.status).toBe(201);
  });

  it('D: validates minimum fare rules', async () => {
    // Weekday < 100 Rs
    const resLow = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'AC Seater',
      weekday: 5000, // Rs 50
      weekend: 5000,
      festival: 10000,
      from: '2026-10-15',
    });
    expect(resLow.status).toBe(400);

    // Weekend < 50% of weekday
    const resWeekendLow = await call(operatorA).post('/client/fares', {
      routeId: routeIdA,
      seatType: 'AC Seater',
      weekday: 100000,
      weekend: 40000, // < 50%
      festival: 120000,
      from: '2026-10-15',
    });
    expect(resWeekendLow.status).toBe(400);
  });

  it('E: lists fares filtered by status or search', async () => {
    const res = await call(operatorA).get('/client/fares?status=ACTIVE');
    expect(res.status).toBe(200);
    const data = dataOf<FareView[]>(res);
    expect(data.length).toBeGreaterThanOrEqual(1);
    expect(data.every((f) => f.status === 'ACTIVE')).toBe(true);
  });

  it('F: tenant isolation: operator B cannot see or modify operator A fares', async () => {
    const listA = await call(operatorA).get('/client/fares');
    const fareA = dataOf<FareView[]>(listA)[0];
    expect(fareA).toBeDefined();

    const getRes = await call(operatorB).get(`/client/fares/${fareA!.id}`);
    expect(getRes.status).toBe(404);

    const delRes = await call(operatorB).delete(`/client/fares/${fareA!.id}`);
    expect(delRes.status).toBe(404);
  });
});
