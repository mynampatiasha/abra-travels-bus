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

/** The shared soft delete: refuse while in use, hide, restore, permissions, audit. */
describe('Catalogue deletion e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let admin: Caller;
  let support: Caller;
  let operator: Caller;
  let superAdmin: Caller;

  interface Caller {
    tokens: Tokens;
  }

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
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}del`);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    operator = await signIn('OPERATOR_ADMIN', network.operator.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  const newCity = async (name: string) =>
    dataOf<Identified>(
      await call(admin).post('/catalogue/cities', { name: `${name} ${runId}`, state: 'Test' }),
    );

  it('refuses to delete a city that routes use, with a sentence that says what uses it', async () => {
    const response = await call(admin).delete(`/catalogue/cities/${network.bengaluru.id}`);
    expect(response.status).toBe(409);
    const error = (response.body as { error: { code: string; message: string } }).error;
    expect(error.code).toBe('RESOURCE_IN_USE');
    expect(error.message).toMatch(/used by .*route/);
    expect(error.message).toMatch(/cannot be deleted/);
    await call(admin).get(`/catalogue/cities/${network.bengaluru.id}`).expect(200);
  });

  it('deletes an unused city, hides it everywhere, and restores it', async () => {
    const city = await newCity('Spare');
    await call(admin).delete(`/catalogue/cities/${city.id}`).expect(200);

    await call(admin).get(`/catalogue/cities/${city.id}`).expect(404);
    const list = dataOf<{ id: string }[]>(await call(admin).get('/catalogue/cities?pageSize=100'));
    expect(list.map((entry) => entry.id)).not.toContain(city.id);

    // deleting again answers the same and does not add an audit entry
    const again = dataOf<{ deleted: boolean }>(
      await call(admin).delete(`/catalogue/cities/${city.id}`),
    );
    expect(again.deleted).toBe(true);

    const restored = dataOf<{ deleted: boolean }>(
      await call(admin).post(`/catalogue/cities/${city.id}/restore`),
    );
    expect(restored.deleted).toBe(false);
    await call(admin).get(`/catalogue/cities/${city.id}`).expect(200);

    // restoring a record that is not deleted changes nothing
    await call(admin).post(`/catalogue/cities/${city.id}/restore`).expect(201);
  });

  it('refuses a bus type that a bus uses and an operator that has buses', async () => {
    const busType = await call(admin).delete(`/catalogue/bus-types/${network.busType.id}`);
    expect(busType.status).toBe(409);
    expect(JSON.stringify(busType.body)).toMatch(/used by 1 bus/);

    const operatorResponse = await call(admin).delete(
      `/catalogue/operators/${network.operator.id}`,
    );
    expect(operatorResponse.status).toBe(409);
    expect(JSON.stringify(operatorResponse.body)).toMatch(/bus/);
  });

  it('deletes and restores an unused place, bus type and document type', async () => {
    const place = dataOf<Identified>(
      await call(admin).post('/catalogue/locations', {
        cityId: network.tirupati.id,
        name: `Spare stand ${runId}`,
        address: 'Spare road',
      }),
    );
    await call(admin).delete(`/catalogue/locations/${place.id}`).expect(200);
    await call(admin).get(`/catalogue/locations/${place.id}`).expect(404);
    await call(admin).post(`/catalogue/locations/${place.id}/restore`).expect(201);
    await call(admin).get(`/catalogue/locations/${place.id}`).expect(200);

    const busType = dataOf<Identified>(
      await call(admin).post('/catalogue/bus-types', {
        key: `SPARE_${runId}`.toUpperCase(),
        name: 'Spare type',
        isAc: false,
        berthType: 'SEATER',
      }),
    );
    await call(admin).delete(`/catalogue/bus-types/${busType.id}`).expect(200);
    await call(admin).post(`/catalogue/bus-types/${busType.id}/restore`).expect(201);

    const documentType = dataOf<Identified>(
      await call(admin).post('/catalogue/document-types', {
        key: `SPAREDOC_${runId}`
          .toUpperCase()
          .replace(/[^A-Z0-9_]/g, '')
          .slice(0, 39),
        name: 'Spare document',
        appliesTo: 'OPERATOR',
      }),
    );
    await call(admin).delete(`/catalogue/document-types/${documentType.id}`).expect(200);
    await call(admin).post(`/catalogue/document-types/${documentType.id}/restore`).expect(201);
  });

  it('needs the delete permission: support and operators are refused', async () => {
    const city = await newCity('Guarded');
    for (const caller of [support, operator]) {
      expect((await call(caller).delete(`/catalogue/cities/${city.id}`)).status).toBe(403);
      expect((await call(caller).post(`/catalogue/cities/${city.id}/restore`)).status).toBe(403);
    }
    await call(superAdmin).delete(`/catalogue/cities/${city.id}`).expect(200);
  });

  it('opens one bus type and one document type, and not a deleted or unknown one', async () => {
    const busType = await call(admin).get(`/catalogue/bus-types/${network.busType.id}`).expect(200);
    expect(dataOf<{ id: string; key: string }>(busType)).toMatchObject({ id: network.busType.id });

    const documentType = dataOf<Identified>(
      await call(admin).post('/catalogue/document-types', {
        key: `READONE_${runId}`
          .toUpperCase()
          .replace(/[^A-Z0-9_]/g, '')
          .slice(0, 39),
        name: 'Read one document',
        appliesTo: 'OPERATOR',
      }),
    );
    const read = await call(admin).get(`/catalogue/document-types/${documentType.id}`).expect(200);
    expect(dataOf<{ name: string }>(read).name).toBe('Read one document');

    await call(admin).delete(`/catalogue/document-types/${documentType.id}`).expect(200);
    await call(admin).get(`/catalogue/document-types/${documentType.id}`).expect(404);
    await call(admin).get(`/catalogue/bus-types/${new Types.ObjectId().toHexString()}`).expect(404);
    expect((await call(operator).get(`/catalogue/bus-types/${network.busType.id}`)).status).toBe(
      403,
    );
    await client(context).get(`${API}/catalogue/bus-types/${network.busType.id}`).expect(401);
  });

  it('answers 404 for an id that does not exist', async () => {
    await call(admin).delete(`/catalogue/cities/${new Types.ObjectId().toHexString()}`).expect(404);
  });

  it('writes one audit entry for the delete and one for the restore', async () => {
    const city = await newCity('Audited');
    await call(admin).delete(`/catalogue/cities/${city.id}`).expect(200);
    await call(admin).post(`/catalogue/cities/${city.id}/restore`).expect(201);

    const entries = dataOf<{ action: string; entityType: string; before: object; after: object }[]>(
      await call(superAdmin).get(`/audit-logs?entityId=${city.id}&pageSize=50`),
    );
    const actions = entries.map((entry) => entry.action);
    expect(actions.filter((action) => action === 'catalogue.deleted')).toHaveLength(1);
    expect(actions.filter((action) => action === 'catalogue.restored')).toHaveLength(1);
    const deleted = entries.find((entry) => entry.action === 'catalogue.deleted');
    expect(deleted?.entityType).toBe('city');
    expect(deleted?.after).toMatchObject({ deleted: true });
  });
});
