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
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';
import { CrewClientManageService } from '../crew_client_manage.service';

const API = '/api/v1';
interface Caller { tokens: Tokens; }
interface CrewView {
  id: string; operatorId: string; name: string; role: string; phone: string;
  licenseNumber?: string; licenseExpiryDate?: string; badgeNumber?: string;
  status: string; isLicenceExpired?: boolean; isLicenceExpiringSoon?: boolean;
}
interface CrewKpis { totalDrivers: number; totalActive: number; totalOnLeave: number; expiringLicences30Days: number; }

describe('Crew Management e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let superAdmin: Caller;
  let operatorA: Caller;
  let operatorB: Caller;
  let operatorBRecord: Identified;
  let crewService: CrewClientManageService;

  const call = (caller: Caller) => ({
    get: (pathStr: string) => client(context).get(`${API}${pathStr}`).set(...bearer(caller.tokens)),
    post: (pathStr: string, body: object = {}) => client(context).post(`${API}${pathStr}`).set(...bearer(caller.tokens)).send(body),
    patch: (pathStr: string, body: object = {}) => client(context).patch(`${API}${pathStr}`).set(...bearer(caller.tokens)).send(body),
    put: (pathStr: string, body: object = {}) => client(context).put(`${API}${pathStr}`).set(...bearer(caller.tokens)).send(body),
    delete: (pathStr: string) => client(context).delete(`${API}${pathStr}`).set(...bearer(caller.tokens)),
  });

  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, { roleKeys: [roleKey], ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}) });

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    await clearCatalogue(context);
    crewService = context.app.get(CrewClientManageService);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}crew`);
    operatorA = await signIn('OPERATOR_ADMIN', network.operator.id);
    operatorBRecord = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Supply Pvt Ltd`,
      displayName: `Operator B ${runId}`,
    });
    await catalogueApi(context, superAdmin).post(`/operators/${operatorBRecord.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' }).expect(201);
    operatorB = await signIn('OPERATOR_ADMIN', operatorBRecord.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('Feature 2: Client Operator Crew CRUD & KPIs', () => {
    let driverId: string;
    let conductorId: string;

    it('creates driver and conductor for Operator A', async () => {
      const in60Days = new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      const res1 = await call(operatorA).post('/client/crew', {
        name: 'Ramesh Sharma', role: 'DRIVER', phone: '+919876543210',
        licenseNumber: 'DL0420220012345', licenseExpiryDate: in60Days, badgeNumber: 'BDG-101', status: 'ACTIVE',
      }).expect(201);
      const driver = dataOf<CrewView>(res1);
      expect(driver.id).toBeDefined();
      expect(driver.name).toBe('Ramesh Sharma');
      expect(driver.isLicenceExpired).toBe(false);
      driverId = driver.id;

      const res2 = await call(operatorA).post('/client/crew', {
        name: 'Suresh Verma', role: 'CONDUCTOR', phone: '+919876543211', status: 'ACTIVE',
      }).expect(201);
      conductorId = dataOf<CrewView>(res2).id;
      expect(conductorId).toBeDefined();
    });

    it('refuses duplicate phone number for same operator', async () => {
      await call(operatorA).post('/client/crew', { name: 'Dup', role: 'DRIVER', phone: '+919876543210' }).expect(409);
    });

    it('fetches crew KPIs for Operator A', async () => {
      const res = await call(operatorA).get('/client/crew/kpis').expect(200);
      const kpis = dataOf<CrewKpis>(res);
      expect(kpis.totalDrivers).toBeGreaterThanOrEqual(1);
      expect(kpis.totalActive).toBeGreaterThanOrEqual(2);
    });

    it('lists crew with search and role filters', async () => {
      const listRes = await call(operatorA).get('/client/crew?role=DRIVER').expect(200);
      expect(dataOf<CrewView[]>(listRes).every((c) => c.role === 'DRIVER')).toBe(true);
      const searchRes = await call(operatorA).get('/client/crew?search=Ramesh').expect(200);
      expect(dataOf<CrewView[]>(searchRes).some((c) => c.name.includes('Ramesh'))).toBe(true);
    });

    it('updates crew details and status', async () => {
      const putRes = await call(operatorA).put(`/client/crew/${driverId}`, { name: 'Ramesh Kumar Sharma', badgeNumber: 'BDG-101-A' }).expect(200);
      expect(dataOf<CrewView>(putRes).name).toBe('Ramesh Kumar Sharma');

      const patchRes = await call(operatorA).patch(`/client/crew/${conductorId}/status`, { status: 'ON_LEAVE' }).expect(200);
      expect(dataOf<CrewView>(patchRes).status).toBe('ON_LEAVE');
    });

    it('exports crew to CSV', async () => {
      const res = await call(operatorA).get('/client/crew/export?format=csv').expect(200);
      expect(res.header['content-type']).toContain('text/csv');
      expect(res.text).toContain('Ramesh Kumar Sharma');
    });
  });

  describe('Operator Isolation', () => {
    let opACrewId: string;

    beforeAll(async () => {
      const res = await call(operatorA).post('/client/crew', { name: 'Private Driver', role: 'DRIVER', phone: '+919876543299' }).expect(201);
      opACrewId = dataOf<CrewView>(res).id;
    });

    it('operator B cannot view, update, or delete operator A crew', async () => {
      await call(operatorB).get(`/client/crew/${opACrewId}`).expect(403);
      await call(operatorB).put(`/client/crew/${opACrewId}`, { name: 'Hacked' }).expect(403);
      await call(operatorB).delete(`/client/crew/${opACrewId}`).expect(403);
    });

    it('operator B crew list does not include operator A crew', async () => {
      const res = await call(operatorB).get('/client/crew').expect(200);
      expect(dataOf<CrewView[]>(res).some((c) => c.id === opACrewId)).toBe(false);
    });
  });

  describe('Decision (d): Licence Expiry & Assignment Eligibility', () => {
    let expiredId: string;
    let soonExpiringId: string;
    let validId: string;

    beforeAll(async () => {
      const yday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      const in15d = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      const in90d = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

      const r1 = await call(operatorA).post('/client/crew', { name: 'Expired', role: 'DRIVER', phone: '+919876540001', licenseExpiryDate: yday }).expect(201);
      expiredId = dataOf<CrewView>(r1).id;
      const r2 = await call(operatorA).post('/client/crew', { name: 'Soon', role: 'DRIVER', phone: '+919876540002', licenseExpiryDate: in15d }).expect(201);
      soonExpiringId = dataOf<CrewView>(r2).id;
      const r3 = await call(operatorA).post('/client/crew', { name: 'Valid', role: 'DRIVER', phone: '+919876540003', licenseExpiryDate: in90d }).expect(201);
      validId = dataOf<CrewView>(r3).id;
    });

    it('flags licence expiry states accurately', async () => {
      const resExpired = await call(operatorA).get(`/client/crew/${expiredId}`).expect(200);
      expect(dataOf<CrewView>(resExpired).isLicenceExpired).toBe(true);
      const resSoon = await call(operatorA).get(`/client/crew/${soonExpiringId}`).expect(200);
      expect(dataOf<CrewView>(resSoon).isLicenceExpiringSoon).toBe(true);
    });

    it('service blocks assignment when licence is expired for travel date', async () => {
      const actor = { actorType: 'USER' as const, userId: new Types.ObjectId(), operatorId: network.operator.id };
      const eligibility = await crewService.checkAssignmentEligibility(actor as never, expiredId, new Date());
      expect(eligibility.eligible).toBe(false);
      expect(eligibility.code).toBe('LICENCE_EXPIRED');
    });

    it('service warns when licence expires within 30 days of travel date', async () => {
      const actor = { actorType: 'USER' as const, userId: new Types.ObjectId(), operatorId: network.operator.id };
      const eligibility = await crewService.checkAssignmentEligibility(actor as never, soonExpiringId, new Date());
      expect(eligibility.eligible).toBe(true);
      expect(eligibility.code).toBe('LICENCE_EXPIRING_SOON');
      expect(eligibility.warning).toBeDefined();
    });

    it('service approves valid driver with no warning', async () => {
      const actor = { actorType: 'USER' as const, userId: new Types.ObjectId(), operatorId: network.operator.id };
      const eligibility = await crewService.checkAssignmentEligibility(actor as never, validId, new Date());
      expect(eligibility.eligible).toBe(true);
      expect(eligibility.warning).toBeUndefined();
    });
  });

  describe('Active Trip Delete Prevention', () => {
    let driverAssignedId: string;
    let driverFreeId: string;

    beforeAll(async () => {
      const r1 = await call(operatorA).post('/client/crew', { name: 'Assigned Driver', role: 'DRIVER', phone: '+919876541111' }).expect(201);
      driverAssignedId = dataOf<CrewView>(r1).id;
      const r2 = await call(operatorA).post('/client/crew', { name: 'Free Driver', role: 'DRIVER', phone: '+919876542222' }).expect(201);
      driverFreeId = dataOf<CrewView>(r2).id;

      await context.connection.collection('trips').insertOne({
        operatorId: new Types.ObjectId(network.operator.id),
        driverIds: [new Types.ObjectId(driverAssignedId)],
        status: 'SCHEDULED',
      });
    });

    it('refuses to delete crew member assigned to active trip (409 RESOURCE_IN_USE)', async () => {
      await call(operatorA).delete(`/client/crew/${driverAssignedId}`).expect(409);
    });

    it('successfully deletes unassigned crew member', async () => {
      await call(operatorA).delete(`/client/crew/${driverFreeId}`).expect(200);
      const res = await call(operatorA).get('/client/crew').expect(200);
      expect(dataOf<CrewView[]>(res).some((c) => c.id === driverFreeId)).toBe(false);
    });
  });
});