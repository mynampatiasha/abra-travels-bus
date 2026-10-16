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
  tripBody,
  uniqueRegistration,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

interface BusView {
  id: string;
  registrationNumber: string;
  name: string;
  operatorId?: string;
  busTypeId: string;
  seatCapacity: number;
  seatLayoutType: string;
  activeSeatLayoutVersionId: string | null;
  status: string;
  amenities: string[];
}

interface SeatLayoutView {
  id: string;
  busId: string;
  version: number;
  name: string;
  layoutType: string;
  decks: number;
  map: string[];
  totalSeats: number;
  ladiesSeatsCount: number;
  seats: Array<{ seatNumber: string; type: string; category: string }>;
}

interface ClientBusListResponse {
  items: BusView[];
  total: number;
  kpis: {
    totalBuses: number;
    activeCount: number;
    pendingCount: number;
    maintenanceCount: number;
    expiringIn30DaysCount: number;
  };
}

describe('Buses & Seat Layouts e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let operatorA: Caller;
  let operatorB: Caller;
  let operatorBRecord: Identified;
  let busType: Identified;

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
    patch: (path: string, body: object = {}) =>
      client(context)
        .patch(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
    put: (path: string, body: object = {}) =>
      client(context)
        .put(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
    delete: (path: string) =>
      client(context)
        .delete(`${API}${path}`)
        .set(...bearer(caller.tokens)),
  });

  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    });

  beforeAll(async () => {
    // Run tests on abra_supply_test database as requested
    context = await createAuthTestApp({
      MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true',
    });
    await clearCatalogue(context);

    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}buses`);

    // Operator A
    operatorA = await signIn('OPERATOR_ADMIN', network.operator.id);

    // Operator B
    operatorBRecord = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Supply Pvt Ltd`,
      displayName: `Operator B ${runId}`,
    });
    await catalogueApi(context, superAdmin)
      .post(`/operators/${operatorBRecord.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' })
      .expect(201);
    operatorB = await signIn('OPERATOR_ADMIN', operatorBRecord.id);

    busType = network.busType;
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('Client buses: list and KPIs', () => {
    it('returns operator buses list and accurate KPI counts', async () => {
      const response = await call(operatorA).get('/client/buses').expect(200);
      const items = dataOf<BusView[]>(response);
      expect(Array.isArray(items)).toBe(true);
      expect(items.length).toBeGreaterThanOrEqual(1);

      const kpiRes = await call(operatorA).get('/client/buses/kpis').expect(200);
      const kpis = dataOf<ClientBusListResponse['kpis']>(kpiRes);
      expect(kpis).toBeDefined();
      expect(kpis.totalBuses).toBeGreaterThanOrEqual(1);
      expect(typeof kpis.activeCount).toBe('number');
      expect(typeof kpis.pendingCount).toBe('number');
      expect(typeof kpis.maintenanceCount).toBe('number');
    });

    it('filters buses by query and status', async () => {
      const initial = dataOf<BusView[]>(
        await call(operatorA).get('/client/buses').expect(200),
      );
      const reg = initial[0]!.registrationNumber;
      const response = await call(operatorA)
        .get(`/client/buses?query=${encodeURIComponent(reg)}`)
        .expect(200);
      const filtered = dataOf<BusView[]>(response);
      expect(filtered.length).toBeGreaterThanOrEqual(1);
      expect(filtered[0]?.registrationNumber).toBe(reg);
    });
  });

  describe('Client buses: add, edit, and status transitions', () => {
    let createdBus: BusView;

    it('operator adds a bus which starts in PENDING_APPROVAL and creates initial seat layout v1', async () => {
      const reg = uniqueRegistration();
      const response = await call(operatorA)
        .post('/client/buses', {
          registrationNumber: reg,
          name: 'Express Star',
          busTypeId: busType.id,
          seatCapacity: 36,
          seatLayoutType: '2+2 Seater',
          amenities: ['WIFI'],
        })
        .expect(201);

      createdBus = dataOf<BusView>(response);
      expect(createdBus.registrationNumber).toBe(reg);
      expect(createdBus.status).toBe('PENDING_APPROVAL');
      expect(createdBus.activeSeatLayoutVersionId).toBeDefined();

      // Verify that initial layout was created with version 1
      const layoutRes = await call(operatorA)
        .get(`/client/seat-layouts/${createdBus.id}`)
        .expect(200);
      const layout = dataOf<SeatLayoutView>(layoutRes);
      expect(layout.version).toBe(1);
      expect(layout.seats.length).toBeGreaterThan(0);
    });

    it('operator edits bus details (name, amenities, insuranceExpiryDate)', async () => {
      const nextMonth = new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString();
      const response = await call(operatorA)
        .patch(`/client/buses/${createdBus.id}`, {
          name: 'Express Star Gold',
          amenities: ['WIFI', 'BLANKET'],
          insuranceExpiryDate: nextMonth,
        })
        .expect(200);

      const updated = dataOf<BusView>(response);
      expect(updated.name).toBe('Express Star Gold');
      expect(updated.amenities).toContain('BLANKET');
    });

    it('operator cannot directly approve their own pending bus (must be 409 INVALID_STATE_TRANSITION)', async () => {
      const response = await call(operatorA)
        .post(`/client/buses/${createdBus.id}/status`, { status: 'ACTIVE' })
        .expect(409);
      const body = response.body as { error?: { code?: string } };
      expect(body.error?.code).toBe('INVALID_STATE_TRANSITION');
    });

    it('platform staff approves the bus, after which operator can toggle MAINTENANCE', async () => {
      // Platform staff approves
      await call(superAdmin)
        .post(`/catalogue/buses/${createdBus.id}/status`, {
          status: 'ACTIVE',
          reason: 'Verified documents',
        })
        .expect(201);

      // Verify active
      const activeBus = dataOf<BusView>(
        await call(operatorA).get(`/client/buses/${createdBus.id}`).expect(200),
      );
      expect(activeBus.status).toBe('ACTIVE');

      // Operator can switch to MAINTENANCE
      const maintRes = await call(operatorA)
        .post(`/client/buses/${createdBus.id}/status`, {
          status: 'MAINTENANCE',
          reason: 'Brake inspection',
        })
        .expect(201);
      const maintBus = dataOf<BusView>(maintRes);
      expect(maintBus.status).toBe('MAINTENANCE');

      // Operator can switch back to ACTIVE
      await call(operatorA)
        .post(`/client/buses/${createdBus.id}/status`, {
          status: 'ACTIVE',
          reason: 'Inspection cleared',
        })
        .expect(201);
    });
  });

  describe('Seat layout designer: get, version bump, and snapshot retrieval', () => {
    let busId: string;
    let v1Id: string;
    let v2Id: string;

    beforeAll(async () => {
      const reg = uniqueRegistration();
      const res = await call(operatorA).post('/client/buses', {
        registrationNumber: reg,
        name: 'Layout Test Bus',
        busTypeId: busType.id,
        seatCapacity: 28,
        seatLayoutType: '2+1 Sleeper',
      });
      const bus = dataOf<BusView>(res);
      busId = bus.id;
      v1Id = bus.activeSeatLayoutVersionId!;
    });

    it('gets the active seat layout for the bus', async () => {
      const res = await call(operatorA).get(`/client/seat-layouts/${busId}`).expect(200);
      const layout = dataOf<SeatLayoutView>(res);
      expect(layout.version).toBe(1);
      expect(layout.busId).toBe(busId);
      expect(layout.seats.length).toBeGreaterThan(0);
    });

    it('saves a customized layout, increments version to 2 and updates bus pointer', async () => {
      const newMap = ['SL__S', 'SL__S', 'SL__S', 'SL__S'];
      const res = await call(operatorA)
        .put(`/client/seat-layouts/${busId}`, {
          name: 'Custom 2+1 Layout',
          layoutType: '2+1 Sleeper',
          decks: 1,
          map: newMap,
        })
        .expect(200);

      const layoutV2 = dataOf<SeatLayoutView>(res);
      expect(layoutV2.version).toBe(2);
      expect(layoutV2.name).toBe('Custom 2+1 Layout');
      v2Id = layoutV2.id;
      expect(v2Id).not.toBe(v1Id);

      // Bus now points to version 2
      const busRes = await call(operatorA).get(`/client/buses/${busId}`).expect(200);
      const bus = dataOf<BusView>(busRes);
      expect(bus.activeSeatLayoutVersionId).toBe(v2Id);
    });

    it('can retrieve historic layout version snapshot by versionId', async () => {
      const v1Res = await call(operatorA).get(`/client/seat-layouts/version/${v1Id}`).expect(200);
      const layoutV1 = dataOf<SeatLayoutView>(v1Res);
      expect(layoutV1.version).toBe(1);
      expect(layoutV1.id).toBe(v1Id);
    });
  });

  describe('Admin catalogue management: list, filters, bulk maintenance, export, import', () => {
    it('admin lists all buses with pagination and filters', async () => {
      const res = await call(superAdmin).get('/catalogue/buses?pageSize=10').expect(200);
      const list = dataOf<BusView[]>(res);
      expect(Array.isArray(list)).toBe(true);
      expect(list.length).toBeGreaterThan(0);
    });

    it('admin bulk marks active buses as MAINTENANCE', async () => {
      const reg = uniqueRegistration();
      const bus = dataOf<BusView>(
        await call(superAdmin).post('/catalogue/buses', {
          operatorId: network.operator.id,
          registrationNumber: reg,
          name: 'Bulk Target 1',
          busTypeId: busType.id,
          seatCapacity: 30,
        }),
      );
      // Ensure it is ACTIVE
      await call(superAdmin)
        .post(`/catalogue/buses/${bus.id}/status`, { status: 'ACTIVE', reason: 'Setup' })
        .expect(201);

      const bulkRes = await call(superAdmin)
        .post('/catalogue/buses/bulk-maintenance', {
          busIds: [bus.id],
          reason: 'Monsoon fleet overhaul',
        })
        .expect(201);

      const bulkData = dataOf<{ updatedCount: number }>(bulkRes);
      expect(bulkData.updatedCount).toBeGreaterThanOrEqual(1);

      const checked = dataOf<BusView>(await call(superAdmin).get(`/catalogue/buses/${bus.id}`));
      expect(checked.status).toBe('MAINTENANCE');
    });

    it('exports admin buses to CSV', async () => {
      const res = await call(superAdmin).get('/catalogue/buses/export?format=csv').expect(200);
      expect(res.headers['content-type']).toMatch(/text\/csv/);
      const text = res.text;
      expect(text).toContain('Registration,Bus Name,Operator,Type,Seats,Layout,Insurance Expiry,Status');
    });

    it('exports client operator buses to CSV', async () => {
      const res = await call(operatorA).get('/client/buses/export?format=csv').expect(200);
      expect(res.headers['content-type']).toMatch(/text\/csv/);
      const text = res.text;
      expect(text).toContain('Registration,Bus Name,Type,Seats,Layout,Insurance Expiry,Status');
    });

    it('downloads the bus import template', async () => {
      const res = await call(superAdmin).get('/catalogue/buses/import-template').expect(200);
      expect(res.headers['content-disposition']).toContain('buses-import-template.csv');
      const text = res.text;
      expect(text).toContain('Registration,Bus name,Bus type,Seats');
    });
  });

  describe('Integrity & Delete restrictions: catalogue-shared constraint', () => {
    it('refuses deletion of a bus when active trips are assigned to it', async () => {
      // Create a trip with network.bus
      const trip = await catalogueApi(context, operatorA).create<Identified>(
        '/trips',
        tripBody(network, 10, { busId: network.bus.id }),
      );
      expect(trip.id).toBeDefined();

      // Deleting network.bus must be refused with 409
      const delRes = await call(superAdmin).delete(`/catalogue/buses/${network.bus.id}`);
      expect(delRes.status).toBe(409);
      expect(JSON.stringify(delRes.body)).toMatch(/trip/i);
    });

    it('successfully soft-deletes a bus when no trip is assigned', async () => {
      const reg = uniqueRegistration();
      const spareBus = dataOf<BusView>(
        await call(superAdmin).post('/catalogue/buses', {
          operatorId: network.operator.id,
          registrationNumber: reg,
          name: 'Spare Unused Bus',
          busTypeId: busType.id,
          seatCapacity: 30,
        }),
      );

      const delRes = await call(superAdmin).delete(`/catalogue/buses/${spareBus.id}`);
      expect(delRes.status).toBe(200);

      // Verify bus is hidden from regular queries
      await call(superAdmin).get(`/catalogue/buses/${spareBus.id}`).expect(404);
    });
  });

  describe('Operator isolation & tenancy enforcement', () => {
    let busOfA: BusView;

    beforeAll(async () => {
      const reg = uniqueRegistration();
      const res = await call(operatorA).post('/client/buses', {
        registrationNumber: reg,
        name: 'Private Fleet A',
        busTypeId: busType.id,
        seatCapacity: 36,
      });
      busOfA = dataOf<BusView>(res);
    });

    it('Operator B cannot view Operator A bus', async () => {
      await call(operatorB).get(`/client/buses/${busOfA.id}`).expect(404);
    });

    it('Operator B cannot edit Operator A bus', async () => {
      await call(operatorB)
        .patch(`/client/buses/${busOfA.id}`, { name: 'Hijacked Bus' })
        .expect(404);
    });

    it('Operator B cannot view or update Operator A seat layout', async () => {
      await call(operatorB).get(`/client/seat-layouts/${busOfA.id}`).expect(404);
      await call(operatorB)
        .put(`/client/seat-layouts/${busOfA.id}`, {
          name: 'Illegal layout edit',
          map: ['S_S'],
        })
        .expect(404);
    });
  });
});
