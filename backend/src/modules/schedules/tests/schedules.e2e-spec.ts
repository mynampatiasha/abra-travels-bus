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

    // Create route
    const routeRes = await call(operatorA).post('/client/routes', {
      from: 'Bengaluru',
      to: 'Mysuru',
      name: 'Bengaluru to Mysuru Highway',
      km: 150,
      hours: 3,
      stops: [
        { placeId: 'P1', name: 'Majestic', city: 'Bengaluru', offset: 0, type: 'BOARDING' },
        { placeId: 'P2', name: 'Suburban Stand', city: 'Mysuru', offset: 180, type: 'DROPPING' },
      ],
    });
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

  it('A: creates a recurring schedule with days and bus', async () => {
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
    expect(sched.route).toBe('Bengaluru to Mysuru Highway');
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
});
