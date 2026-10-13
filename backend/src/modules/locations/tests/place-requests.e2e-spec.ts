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
  tripBody,
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
  cityId: string;
  cityName: string;
  name: string;
  status: string;
  reason: string | null;
  placeId: string | null;
}

interface PlaceBody {
  id: string;
  name: string;
  operatorId: string | null;
  usedFor: string;
  source: string;
  tripsUsing?: number;
}

/** Place requests: an operator asks, Abra approves or rejects, the place joins the shared list. */
describe('Place requests e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let admin: Caller;
  let support: Caller;
  let owner: Caller;
  let otherOwner: Caller;

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
  const ask = async (caller: Caller, name: string, cityId = network.bengaluru.id) =>
    dataOf<RequestBody>(
      await call(caller)
        .post('/client/place-requests', {
          cityId,
          name,
          address: `${name} Road`,
          landmark: 'Gate 2',
        })
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
    await context.connection.collection('place_requests').deleteMany({});
    superAdmin = await signIn('SUPER_ADMIN');
    const catalogue = catalogueApi(context, superAdmin);
    network = await buildNetwork(catalogue, `${runId}pr`);
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
    await context.connection.collection('place_requests').deleteMany({});
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('the operator asks', () => {
    it('sends a request for its own company, audited and announced to Abra', async () => {
      const sent = await ask(owner, 'Hosur Gate 2');
      expect(sent).toMatchObject({
        operatorId: network.operator.id,
        operatorName: `Test Operator ${runId}pr`,
        cityId: network.bengaluru.id,
        status: 'PENDING',
        reason: null,
      });
      expect((await auditOf(sent.id)).map((entry) => String(entry.action))).toEqual([
        'place-request.created',
      ]);
      expect((await outboxOf(sent.id)).map((event) => String(event.type))).toEqual([
        'place-request.created',
      ]);
    });

    it('refuses a place that exists and one already waiting', async () => {
      const exists = await call(owner).post('/client/place-requests', {
        cityId: network.bengaluru.id,
        name: 'majestic bus stand',
        address: 'Somewhere',
      });
      expect(exists.status).toBe(400);
      expect(errorMessageOf(exists)).toMatch(/already exists/);

      const waiting = await call(otherOwner).post('/client/place-requests', {
        cityId: network.bengaluru.id,
        name: 'HOSUR GATE 2',
        address: 'Hosur Road',
      });
      expect(waiting.status).toBe(400);
      expect(errorMessageOf(waiting)).toMatch(/already been asked for/);
    });

    it('lists the active cities for the form', async () => {
      const cities = dataOf<Array<{ id: string; name: string }>>(
        await call(owner).get('/client/place-requests/cities').expect(200),
      );
      expect(cities.map((city) => city.id)).toEqual(
        expect.arrayContaining([network.bengaluru.id, network.tirupati.id]),
      );
    });

    it('shows each operator only its own requests', async () => {
      const mine = await ask(otherOwner, 'Other Pickup');
      const ownList = dataOf<RequestBody[]>(
        await call(owner).get('/client/place-requests').expect(200),
      );
      expect(ownList.map((request) => request.name)).toEqual(['Hosur Gate 2']);
      await call(owner).get(`/client/place-requests/${mine.id}`).expect(404);
      await call(otherOwner).get(`/client/place-requests/${mine.id}`).expect(200);
    });

    it('exports its own requests as CSV', async () => {
      const file = await call(owner).get('/client/place-requests/export?format=csv').expect(200);
      expect(file.text).toContain('Hosur Gate 2');
      expect(file.text).not.toContain('Other Pickup');
    });

    it('is for operator staff only', async () => {
      await call(admin)
        .post('/client/place-requests', {
          cityId: network.bengaluru.id,
          name: 'Staff Place',
          address: 'Staff Road',
        })
        .expect(403);
    });
  });

  describe('Abra decides', () => {
    it('lists every request, searchable, for staff with catalogue.read only', async () => {
      const all = dataOf<RequestBody[]>(
        await call(admin).get('/admin/place-requests?status=PENDING').expect(200),
      );
      expect(all.map((request) => request.name).sort()).toEqual(['Hosur Gate 2', 'Other Pickup']);
      const found = dataOf<RequestBody[]>(
        await call(admin).get('/admin/place-requests?query=other%20operator').expect(200),
      );
      expect(found.map((request) => request.name)).toEqual(['Other Pickup']);
      expect(
        dataOf<{ pending: number }>(
          await call(admin).get('/admin/place-requests/pending-count').expect(200),
        ),
      ).toEqual({ pending: 2 });
      await call(owner).get('/admin/place-requests').expect(403);
      await call(support).get('/admin/place-requests').expect(403);
    });

    it('approving adds a shared place for every operator, once', async () => {
      const [request] = dataOf<RequestBody[]>(
        await call(admin).get('/admin/place-requests?query=hosur').expect(200),
      );
      await call(owner).post(`/admin/place-requests/${request!.id}/approve`).expect(403);
      const approved = dataOf<RequestBody>(
        await call(admin).post(`/admin/place-requests/${request!.id}/approve`).expect(200),
      );
      expect(approved.status).toBe('APPROVED');
      expect(approved.placeId).toEqual(expect.any(String));

      // Every operator sees it, marked as coming from a request
      const seen = dataOf<PlaceBody[]>(
        await call(otherOwner).get('/catalogue/locations?query=hosur').expect(200),
      );
      expect(seen).toEqual([
        expect.objectContaining({
          id: approved.placeId,
          operatorId: null,
          usedFor: 'BOTH',
          source: 'OPERATOR_REQUEST',
        }),
      ]);

      const again = await call(admin).post(`/admin/place-requests/${request!.id}/approve`);
      expect(again.status).toBe(409);
      expect((await auditOf(request!.id)).map((entry) => String(entry.action))).toEqual([
        'place-request.created',
        'place-request.approved',
      ]);
      expect((await outboxOf(request!.id)).map((event) => String(event.type))).toContain(
        'place-request.approved',
      );
      const mine = dataOf<RequestBody>(
        await call(owner).get(`/client/place-requests/${request!.id}`).expect(200),
      );
      expect(mine.status).toBe('APPROVED');
    });

    it('rejecting needs a reason the operator reads', async () => {
      const [request] = dataOf<RequestBody[]>(
        await call(admin).get('/admin/place-requests?query=other%20pickup').expect(200),
      );
      await call(admin).post(`/admin/place-requests/${request!.id}/reject`, {}).expect(400);
      const rejected = dataOf<RequestBody>(
        await call(admin)
          .post(`/admin/place-requests/${request!.id}/reject`, {
            reason: 'Too close to Majestic Bus Stand',
          })
          .expect(200),
      );
      expect(rejected).toMatchObject({
        status: 'REJECTED',
        reason: 'Too close to Majestic Bus Stand',
      });
      const seen = dataOf<RequestBody>(
        await call(otherOwner).get(`/client/place-requests/${request!.id}`).expect(200),
      );
      expect(seen.reason).toBe('Too close to Majestic Bus Stand');
      await call(admin).post(`/admin/place-requests/${request!.id}/approve`).expect(409);
    });

    it('exports the requests as CSV for staff with catalogue.export', async () => {
      const file = await call(admin).get('/admin/place-requests/export?format=csv').expect(200);
      expect(file.text).toContain('Requested place');
      expect(file.text).toContain('Other Pickup');
    });
  });

  describe('the places list', () => {
    it('filters by search and used for, and counts the trips that use a place', async () => {
      const catalogue = catalogueApi(context, superAdmin);
      await catalogue.create<Identified>('/trips', tripBody(network));
      const boarding = dataOf<PlaceBody[]>(
        await call(admin).get('/catalogue/locations?query=majestic').expect(200),
      );
      expect(boarding).toEqual([
        expect.objectContaining({ id: network.boarding.id, tripsUsing: 1, source: 'ADMIN' }),
      ]);
      const onlyDropping = dataOf<PlaceBody[]>(
        await call(admin).get('/catalogue/locations?usedFor=DROPPING').expect(200),
      );
      expect(onlyDropping).toEqual([]);
      const both = dataOf<PlaceBody[]>(
        await call(admin).get('/catalogue/locations?usedFor=BOTH').expect(200),
      );
      expect(both.length).toBeGreaterThanOrEqual(3);
    });
  });
});
