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
  errorMessageOf,
  type Identified,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

interface RequestBody {
  id: string;
  operatorId: string;
  operatorName: string;
  name: string;
  isAc: boolean;
  berthType: string;
  status: string;
  reason: string | null;
  busTypeId: string | null;
}

interface BusTypeBody {
  id: string;
  key: string;
  name: string;
  isAc: boolean;
  berthType: string;
  isActive: boolean;
}

/** Bus type requests: an operator asks, Abra approves or rejects, the bus type joins the list. */
describe('Bus type requests e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let admin: Caller;
  let support: Caller;
  let owner: Caller;
  let otherOwner: Caller;
  const miniCoach = `Mini Coach ${runId}`;
  const luxuryVan = `Luxury Van ${runId}`;

  const call = (caller: Caller) => ({
    get: (path: string) =>
      client(context)
        .get(`${API}${path}`)
        .set(...bearer(caller.tokens)),
    post: (path: string, body: object = {}) =>
      client(context)
        .post(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
  });
  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    });
  const ask = async (caller: Caller, name: string) =>
    dataOf<RequestBody>(
      await call(caller)
        .post('/client/bus-type-requests', { name, isAc: false, berthType: 'MIXED' })
        .expect(201),
    );
  const auditOf = (entityId: string) =>
    context.connection
      .collection('audit_logs')
      .find({ entityId: new Types.ObjectId(entityId) })
      .toArray();
  const outboxOf = (aggregateId: string) =>
    context.connection.collection('outbox_events').find({ aggregateId }).toArray();

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    await context.connection.collection('bus_type_requests').deleteMany({});
    superAdmin = await signIn('SUPER_ADMIN');
    const catalogue = catalogueApi(context, superAdmin);
    network = await buildNetwork(catalogue, `${runId}btr`);
    const other = await catalogue.create<Identified>('/operators', {
      companyName: `Other Operator ${runId} Private Limited`,
      displayName: `Other Operator ${runId}`,
    });
    await catalogue
      .post(`/operators/${other.id}/status`, { status: 'ACTIVE', reason: 'Documents verified' })
      .expect(201);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    owner = await signIn('OPERATOR_ADMIN', network.operator.id);
    otherOwner = await signIn('OPERATOR_ADMIN', other.id);
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('bus_type_requests').deleteMany({});
    await context.connection
      .collection('bus_types')
      .deleteMany({ name: { $in: [miniCoach, luxuryVan] } });
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('the operator asks', () => {
    it('sends a request for its own company, audited and announced to Abra', async () => {
      const sent = await ask(owner, miniCoach);
      expect(sent).toMatchObject({
        operatorId: network.operator.id,
        operatorName: `Test Operator ${runId}btr`,
        name: miniCoach,
        isAc: false,
        berthType: 'MIXED',
        status: 'PENDING',
        reason: null,
      });
      expect((await auditOf(sent.id)).map((entry) => String(entry.action))).toEqual([
        'bus-type-request.created',
      ]);
      expect((await outboxOf(sent.id)).map((event) => String(event.type))).toEqual([
        'bus-type-request.created',
      ]);
    });

    it('refuses a bus type that exists and one already waiting', async () => {
      const exists = await call(owner).post('/client/bus-type-requests', {
        name: 'ac sleeper',
        isAc: true,
        berthType: 'SLEEPER',
      });
      expect(exists.status).toBe(400);
      expect(errorMessageOf(exists)).toMatch(/already exists/);

      const waiting = await call(otherOwner).post('/client/bus-type-requests', {
        name: miniCoach.toUpperCase(),
        isAc: false,
        berthType: 'MIXED',
      });
      expect(waiting.status).toBe(400);
      expect(errorMessageOf(waiting)).toMatch(/already been asked for/);
    });

    it('refuses a name that is too short or a berth type that does not exist', async () => {
      await call(owner)
        .post('/client/bus-type-requests', { name: 'A', isAc: true, berthType: 'SLEEPER' })
        .expect(400);
      await call(owner)
        .post('/client/bus-type-requests', { name: luxuryVan, isAc: true, berthType: 'FLYING' })
        .expect(400);
    });

    it('shows each operator only its own requests', async () => {
      const mine = await ask(otherOwner, luxuryVan);
      const ownList = dataOf<RequestBody[]>(
        await call(owner).get('/client/bus-type-requests').expect(200),
      );
      expect(ownList.map((request) => request.name)).toEqual([miniCoach]);
      await call(owner).get(`/client/bus-type-requests/${mine.id}`).expect(404);
      await call(otherOwner).get(`/client/bus-type-requests/${mine.id}`).expect(200);
    });

    it('is for operator staff only', async () => {
      await call(admin)
        .post('/client/bus-type-requests', { name: 'Staff Coach', isAc: true, berthType: 'SEATER' })
        .expect(403);
    });
  });

  describe('Abra decides', () => {
    it('lists every request, searchable, for staff with catalogue.read only', async () => {
      const all = dataOf<RequestBody[]>(
        await call(admin).get('/admin/bus-type-requests?status=PENDING').expect(200),
      );
      expect(all.map((request) => request.name).sort()).toEqual([luxuryVan, miniCoach].sort());
      const found = dataOf<RequestBody[]>(
        await call(admin).get('/admin/bus-type-requests?query=other%20operator').expect(200),
      );
      expect(found.map((request) => request.name)).toEqual([luxuryVan]);
      expect(
        dataOf<{ pending: number }>(
          await call(admin).get('/admin/bus-type-requests/pending-count').expect(200),
        ),
      ).toEqual({ pending: 2 });
      await call(owner).get('/admin/bus-type-requests').expect(403);
      await call(support).get('/admin/bus-type-requests').expect(403);
    });

    it('approving adds the bus type for every operator, once', async () => {
      const [request] = dataOf<RequestBody[]>(
        await call(admin).get('/admin/bus-type-requests?query=mini%20coach').expect(200),
      );
      await call(owner).post(`/admin/bus-type-requests/${request!.id}/approve`).expect(403);
      const approved = dataOf<RequestBody>(
        await call(admin).post(`/admin/bus-type-requests/${request!.id}/approve`).expect(200),
      );
      expect(approved.status).toBe('APPROVED');
      expect(approved.busTypeId).toEqual(expect.any(String));

      // Every operator sees it on the bus type list, with what the operator asked for
      const list = dataOf<BusTypeBody[]>(
        await call(otherOwner).get('/catalogue/bus-types?active=true&pageSize=100').expect(200),
      );
      expect(list.find((type) => type.id === approved.busTypeId)).toMatchObject({
        name: miniCoach,
        isAc: false,
        berthType: 'MIXED',
        isActive: true,
      });

      const again = await call(admin).post(`/admin/bus-type-requests/${request!.id}/approve`);
      expect(again.status).toBe(409);
      expect((await auditOf(request!.id)).map((entry) => String(entry.action))).toEqual([
        'bus-type-request.created',
        'bus-type-request.approved',
      ]);
      expect((await outboxOf(request!.id)).map((event) => String(event.type))).toContain(
        'bus-type-request.approved',
      );
      const mine = dataOf<RequestBody>(
        await call(owner).get(`/client/bus-type-requests/${request!.id}`).expect(200),
      );
      expect(mine.status).toBe('APPROVED');
    });

    it('rejecting needs a reason the operator reads', async () => {
      const [request] = dataOf<RequestBody[]>(
        await call(admin).get('/admin/bus-type-requests?query=luxury%20van').expect(200),
      );
      await call(admin).post(`/admin/bus-type-requests/${request!.id}/reject`, {}).expect(400);
      const rejected = dataOf<RequestBody>(
        await call(admin)
          .post(`/admin/bus-type-requests/${request!.id}/reject`, {
            reason: 'Use AC Seater + Sleeper instead',
          })
          .expect(200),
      );
      expect(rejected).toMatchObject({
        status: 'REJECTED',
        reason: 'Use AC Seater + Sleeper instead',
      });
      const seen = dataOf<RequestBody>(
        await call(otherOwner).get(`/client/bus-type-requests/${request!.id}`).expect(200),
      );
      expect(seen.reason).toBe('Use AC Seater + Sleeper instead');
      await call(admin).post(`/admin/bus-type-requests/${request!.id}/approve`).expect(409);
      const rejectedBusTypes = await context.connection
        .collection('bus_types')
        .countDocuments({ name: luxuryVan });
      expect(rejectedBusTypes).toBe(0);
    });
  });
});
