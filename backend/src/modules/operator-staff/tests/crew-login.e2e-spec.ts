import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
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
interface Caller { tokens: Tokens }
interface Credentials { username: string; temporaryPassword: string }
interface CrewRow { id: string; loginState?: string }

describe('Driver app login e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let owner: Caller;
  let otherOwner: Caller;
  let driverId: string;
  let managerId: string;
  let phone: string;
  let credentials: Credentials;

  const auth = (caller: Caller) => bearer(caller.tokens);
  const device = { clientType: 'MOBILE', deviceName: 'Driver Mobile App' };
  const signIn = (identifier: string, password: string) =>
    client(context).post(`${API}/auth/login`).send({ identifier, password, device });

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    await clearCatalogue(context);
    const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}login`);
    owner = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: new Types.ObjectId(network.operator.id) });
    const other = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} Login Pvt Ltd`,
      displayName: `Operator B ${runId} Login`,
    });
    await catalogueApi(context, superAdmin).post(`/operators/${other.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' }).expect(201);
    otherOwner = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: new Types.ObjectId(other.id) });

    phone = `+9197${String(Date.now()).slice(-8)}`;
    const driver = await client(context).post(`${API}/client/crew`).set(...auth(owner))
      .send({ name: 'Login Driver', role: 'DRIVER', phone }).expect(201);
    driverId = dataOf<{ id: string }>(driver).id;
    const manager = await client(context).post(`${API}/client/crew`).set(...auth(owner))
      .send({ name: 'Login Manager', role: 'MANAGER', phone: `+9196${String(Date.now()).slice(-8)}` }).expect(201);
    managerId = dataOf<{ id: string }>(manager).id;
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('has no login until the operator makes one', async () => {
    const res = await client(context).get(`${API}/client/crew`).set(...auth(owner)).expect(200);
    const row = dataOf<CrewRow[]>(res).find((p) => p.id === driverId);
    expect(row?.loginState).toBe('NONE');
    await signIn(phone, 'anything-at-all-1').expect(401);
  });

  it('makes a login: the phone number and a temporary password shown once', async () => {
    const res = await client(context).post(`${API}/client/crew/${driverId}/login`).set(...auth(owner)).expect(201);
    credentials = dataOf<Credentials>(res);
    expect(credentials.username).toBe(phone);
    expect(credentials.temporaryPassword).toHaveLength(12);
    const list = await client(context).get(`${API}/client/crew`).set(...auth(owner)).expect(200);
    expect(dataOf<CrewRow[]>(list).find((p) => p.id === driverId)?.loginState).toBe('ACTIVE');
  });

  it('refuses a second login, a manager, and another operator', async () => {
    await client(context).post(`${API}/client/crew/${driverId}/login`).set(...auth(owner)).expect(409);
    await client(context).post(`${API}/client/crew/${managerId}/login`).set(...auth(owner)).expect(400);
    await client(context).post(`${API}/client/crew/${driverId}/login/reset-password`).set(...auth(otherOwner)).expect(404);
  });

  it('the driver signs in with the temporary password and must choose their own', async () => {
    const login = await signIn(credentials.username, credentials.temporaryPassword).expect(200);
    const tokens = dataOf<{ accessToken: string }>(login);
    const driver: Caller = { tokens: tokens as unknown as Tokens };
    const me = await client(context).get(`${API}/me`).set(...auth(driver)).expect(200);
    const profile = dataOf<{ user: { userType: string; mustChangePassword: boolean } }>(me).user;
    expect(profile.userType).toBe('DRIVER');
    expect(profile.mustChangePassword).toBe(true);

    await client(context).post(`${API}/me/password`).set(...auth(driver))
      .send({ currentPassword: credentials.temporaryPassword, newPassword: 'My-own-secret-77' }).expect(200);
    const after = await client(context).get(`${API}/me`).set(...auth(driver)).expect(200);
    expect(dataOf<{ user: { mustChangePassword: boolean } }>(after).user.mustChangePassword).toBe(false);
    await signIn(phone, credentials.temporaryPassword).expect(401);
    await signIn(phone, 'My-own-secret-77').expect(200);
  });

  it('a reset gives a new temporary password and signs the person out', async () => {
    const res = await client(context).post(`${API}/client/crew/${driverId}/login/reset-password`).set(...auth(owner)).expect(200);
    const fresh = dataOf<Credentials>(res);
    expect(fresh.temporaryPassword).not.toBe(credentials.temporaryPassword);
    await signIn(phone, 'My-own-secret-77').expect(401);
    const login = await signIn(phone, fresh.temporaryPassword).expect(200);
    expect(login.body).toBeDefined();
    const me = await client(context).get(`${API}/me`)
      .set(...bearer(dataOf<{ accessToken: string }>(login) as unknown as Tokens)).expect(200);
    expect(dataOf<{ user: { mustChangePassword: boolean } }>(me).user.mustChangePassword).toBe(true);
  });

  it('switching the login off blocks sign-in; switching it on allows it again', async () => {
    const list = await client(context).get(`${API}/client/crew`).set(...auth(owner)).expect(200);
    expect(dataOf<CrewRow[]>(list).find((p) => p.id === driverId)?.loginState).toBe('ACTIVE');
    await client(context).post(`${API}/client/crew/${driverId}/login/disable`).set(...auth(owner)).expect(200);
    const off = await client(context).get(`${API}/client/crew`).set(...auth(owner)).expect(200);
    expect(dataOf<CrewRow[]>(off).find((p) => p.id === driverId)?.loginState).toBe('DISABLED');
    const reset = await client(context).post(`${API}/client/crew/${driverId}/login/reset-password`).set(...auth(owner)).expect(200);
    await signIn(phone, dataOf<Credentials>(reset).temporaryPassword).expect(403);
    await client(context).post(`${API}/client/crew/${driverId}/login/enable`).set(...auth(owner)).expect(200);
    await signIn(phone, dataOf<Credentials>(reset).temporaryPassword).expect(200);
  });

  it('removing the person switches the login off', async () => {
    await client(context).delete(`${API}/client/crew/${driverId}`).set(...auth(owner)).expect(200);
    const reset = await signIn(phone, 'My-own-secret-77');
    expect([401, 403]).toContain(reset.status);
  });
});
