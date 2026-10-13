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
  uniqueRegistration,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';

const API = '/api/v1';

interface Caller {
  tokens: Tokens;
}

interface AmenityBody {
  id: string;
  key: string;
  name: string;
  isActive: boolean;
}

/** The managed amenity list: starter list, add, switch on and off, and what buses may be given. */
describe('Amenities e2e', () => {
  let context: AuthTestContext;
  let network: Network;
  let admin: Caller;
  let support: Caller;
  let operator: Caller;
  let superAdmin: Caller;

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
    put: (path: string, body: object) =>
      client(context)
        .put(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
    patch: (path: string, body: object) =>
      client(context)
        .patch(`${API}${path}`)
        .set(...bearer(caller.tokens))
        .send(body),
  });
  const signIn = (roleKey: SystemRoleKey, operatorId?: string): Promise<Caller> =>
    seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    });
  const add = async (name: string) =>
    dataOf<AmenityBody>(await call(admin).post('/admin/amenities', { name }).expect(201));
  const list = async (query = '') =>
    dataOf<AmenityBody[]>(await call(admin).get(`/admin/amenities${query}`).expect(200));
  const newBus = (amenities: string[]) => ({
    operatorId: network.operator.id,
    registrationNumber: uniqueRegistration(),
    name: 'Amenity bus',
    busTypeId: network.busType.id,
    seatCapacity: 30,
    amenities,
  });
  const unique = (name: string) => `${name} ${runId}`;

  beforeAll(async () => {
    context = await createAuthTestApp();
    await clearCatalogue(context);
    superAdmin = await signIn('SUPER_ADMIN');
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}am`);
    admin = await signIn('ADMIN');
    support = await signIn('SUPPORT');
    operator = await signIn('OPERATOR_ADMIN', network.operator.id);
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('starts with the amenities buses could always have, all switched on', async () => {
    const amenities = await list();
    const byKey = new Map(amenities.map((amenity) => [amenity.key, amenity]));
    expect(byKey.get('CHARGING_POINT')).toMatchObject({ name: 'Charging point', isActive: true });
    expect(byKey.get('WIFI')).toMatchObject({ name: 'Wi-Fi' });
    expect(amenities.length).toBeGreaterThanOrEqual(13);
  });

  describe('adding', () => {
    it('makes the key from the name and starts switched on', async () => {
      const created = await add(unique('Reclining seats'));
      expect(created).toMatchObject({
        key: `RECLINING_SEATS_${runId.toUpperCase().replace(/[^A-Z0-9]/g, '_')}`.replace(/_+$/, ''),
        isActive: true,
      });
      expect((await list()).map((amenity) => amenity.id)).toContain(created.id);
    });

    it('refuses a name that makes a key that exists, and one with no letters', async () => {
      const again = await call(admin).post('/admin/amenities', { name: 'wifi' });
      expect(again.status).toBe(409);
      expect(JSON.stringify(again.body)).toMatch(/already exists/);

      const native = await call(admin).post('/admin/amenities', { name: 'తెలుగు' });
      expect(native.status).toBe(400);
      expect((await call(admin).post('/admin/amenities', { name: 'x' })).status).toBe(400);
    });

    it('writes an audit entry', async () => {
      const created = await add(unique('Audited extra'));
      const entries = dataOf<{ action: string; entityType: string }[]>(
        await call(superAdmin).get(`/audit-logs?entityId=${created.id}&pageSize=20`).expect(200),
      );
      expect(entries).toEqual([
        expect.objectContaining({ action: 'catalogue.created', entityType: 'amenity' }),
      ]);
    });
  });

  describe('switching on and off', () => {
    it('a switched-off amenity leaves the choices but stays in the staff list', async () => {
      const created = await add(unique('Foot rest'));
      const off = dataOf<AmenityBody>(
        await call(admin)
          .patch(`/admin/amenities/${created.id}/active`, { active: false })
          .expect(200),
      );
      expect(off.isActive).toBe(false);

      expect((await list('?active=true')).map((a) => a.id)).not.toContain(created.id);
      expect((await list('?active=false')).map((a) => a.id)).toContain(created.id);
      const choices = dataOf<{ key: string }[]>(
        await call(operator).get('/catalogue/amenities').expect(200),
      );
      expect(choices.map((choice) => choice.key)).not.toContain(created.key);
      expect(choices.map((choice) => choice.key)).toContain('CHARGING_POINT');

      const on = dataOf<AmenityBody>(
        await call(admin)
          .patch(`/admin/amenities/${created.id}/active`, { active: true })
          .expect(200),
      );
      expect(on.isActive).toBe(true);
      await call(admin)
        .patch(`/admin/amenities/${new Types.ObjectId().toHexString()}/active`, { active: false })
        .expect(404);
    });
  });

  describe('who may', () => {
    it('staff with catalogue.manage change the list; support and operators cannot', async () => {
      const created = await add(unique('Guarded extra'));
      for (const caller of [support, operator]) {
        expect((await call(caller).get('/admin/amenities')).status).toBe(403);
        expect((await call(caller).post('/admin/amenities', { name: 'No way' })).status).toBe(403);
        expect(
          (await call(caller).patch(`/admin/amenities/${created.id}/active`, { active: false }))
            .status,
        ).toBe(403);
      }
      await client(context).get(`${API}/admin/amenities`).expect(401);
    });

    it('operators can read the choices for a bus form', async () => {
      const choices = dataOf<{ key: string; name: string }[]>(
        await call(operator).get('/catalogue/amenities').expect(200),
      );
      expect(choices.find((choice) => choice.key === 'WIFI')?.name).toBe('Wi-Fi');
    });
  });

  describe('buses', () => {
    it('can be given a new amenity, but not one that is switched off or unknown', async () => {
      const fresh = await add(unique('Window blinds'));
      const bus = dataOf<Identified & { amenities: string[] }>(
        await call(admin)
          .post('/catalogue/buses', newBus([fresh.key, 'WIFI']))
          .expect(201),
      );
      expect(bus.amenities).toEqual([fresh.key, 'WIFI']);

      await call(admin).patch(`/admin/amenities/${fresh.id}/active`, { active: false }).expect(200);
      const refused = await call(admin).post('/catalogue/buses', newBus([fresh.key]));
      expect(refused.status).toBe(400);
      expect(JSON.stringify(refused.body)).toContain(`not available: ${fresh.key}`);

      const unknown = await call(admin).post('/catalogue/buses', newBus(['NO_SUCH_THING']));
      expect(unknown.status).toBe(400);
      expect((await call(admin).post('/catalogue/buses', newBus(['lower case']))).status).toBe(400);

      // the bus that already has it keeps it, and can be edited without failing over it
      const edited = dataOf<{ amenities: string[] }>(
        await call(admin)
          .put(`/catalogue/buses/${bus.id}`, { amenities: [fresh.key, 'WIFI', 'CCTV'] })
          .expect(200),
      );
      expect(edited.amenities).toEqual([fresh.key, 'WIFI', 'CCTV']);
      // but a switched-off amenity cannot be added to another bus by editing
      const other = dataOf<Identified>(
        await call(admin)
          .post('/catalogue/buses', newBus(['WIFI']))
          .expect(201),
      );
      expect(
        (await call(admin).put(`/catalogue/buses/${other.id}`, { amenities: [fresh.key] })).status,
      ).toBe(400);
    });
  });
});
