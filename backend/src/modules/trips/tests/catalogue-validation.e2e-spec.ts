import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
} from '../../authentication/tests/auth-e2e.harness';
import { type AuditEntry, seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  type AccessWorld,
  clearCatalogue,
  createAccessWorld,
  expectCode,
  type Identified,
  uniqueRegistration,
} from './catalogue-e2e.support';
import { runId } from './discovery-e2e.fixture';

interface Paged<T> {
  body: { data: T[]; meta: { page: number; pageSize: number; total: number } };
}

/** validation, lists and audit — real application, MongoDB replica set and Redis. */
describe('Catalogue e2e: validation, lists and audit', () => {
  let context: AuthTestContext;
  let w: AccessWorld;

  beforeAll(async () => {
    context = await createAuthTestApp();
    w = await createAccessWorld(context, 'v');
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('validation', () => {
    it('cities: required fields, unique identity, slug from the name', async () => {
      const city = await w.superAdmin.create<{
        id: string;
        slug: string;
        countryCode: string;
        isActive: boolean;
      }>('/cities', {
        name: `New Town ${runId}`,
        state: 'Test State',
        translations: { kn: 'ಹೊಸ ಊರು' },
        isPopular: true,
        sortOrder: 3,
      });
      expect(city).toMatchObject({ slug: `new-town-${runId}`, countryCode: 'IN', isActive: true });
      await expectCode(
        w.superAdmin.post('/cities', { name: `New Town ${runId}`, state: 'Test State' }),
        409,
        'ALREADY_REGISTERED',
      );
      for (const body of [
        { state: 'Test State' },
        { name: 'X', state: 'Test State' },
        { name: 'Somewhere', state: 'Test State', countryCode: 'India' },
        { name: 'Somewhere', state: 'Test State', latitude: 95, longitude: 10 },
        { name: 'Somewhere', state: 'Test State', latitude: 12.5 },
        { name: 'Somewhere', state: 'Test State', isActive: false },
      ]) {
        await expectCode(w.superAdmin.post('/cities', body), 400, 'VALIDATION_FAILED');
      }
      await expectCode(w.superAdmin.put(`/cities/${city.id}`, {}), 400, 'VALIDATION_FAILED');
      await expectCode(
        w.superAdmin.get('/cities/507f1f77bcf86cd799439011'),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(w.superAdmin.get('/cities/not-an-id'), 400, 'VALIDATION_FAILED');

      const updated = dataOf<{ name: string; slug: string }>(
        await w.superAdmin.put(`/cities/${city.id}`, { name: `Newer Town ${runId}` }).expect(200),
      );
      expect(updated).toMatchObject({ name: `Newer Town ${runId}`, slug: `new-town-${runId}` });
    });

    it('a disabled city is no longer offered to customers or accepted for new routes and locations', async () => {
      const city = await w.superAdmin.create<Identified>('/cities', {
        name: `Closing ${runId}`,
        state: 'Test State',
      });
      await w.superAdmin.post(`/cities/${city.id}/active`, { active: false }).expect(201);
      const offered = dataOf<Identified[]>(
        await client(context).get('/api/v1/cities').query({ query: 'Closing' }).expect(200),
      );
      expect(offered).toEqual([]);
      await expectCode(
        w.superAdmin.post('/locations', { cityId: city.id, name: 'Stand', address: 'Main Road' }),
        400,
        'VALIDATION_FAILED',
      );
      await expectCode(
        w.superAdmin.post('/routes', {
          operatorId: w.a.operator.id,
          originCityId: w.a.bengaluru.id,
          destinationCityId: city.id,
          name: 'To a closed city',
          estimatedDurationMinutes: 120,
        }),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('bus types: unique permanent key', async () => {
      await expectCode(
        w.superAdmin.post('/bus-types', {
          key: w.a.busType.key,
          name: 'Duplicate',
          isAc: true,
          berthType: 'SLEEPER',
        }),
        409,
        'ALREADY_REGISTERED',
      );
      for (const body of [
        { key: 'lower_case', name: 'Bad key', isAc: true, berthType: 'SEATER' },
        { key: 'NO_BERTH', name: 'No berth type', isAc: true },
        { key: 'BAD_BERTH', name: 'Bad berth', isAc: true, berthType: 'HAMMOCK' },
      ]) {
        await expectCode(w.superAdmin.post('/bus-types', body), 400, 'VALIDATION_FAILED');
      }
      await expectCode(
        w.superAdmin.put(`/bus-types/${w.a.busType.id}`, { key: 'RENAMED' }),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('buses: unique registration, an active bus type, a real capacity', async () => {
      const base = {
        operatorId: w.a.operator.id,
        name: 'Checked bus',
        busTypeId: w.a.busType.id,
        seatCapacity: 30,
      };
      const registrationNumber = uniqueRegistration();
      const bus = await w.superAdmin.create<{
        id: string;
        registrationNumber: string;
        status: string;
      }>('/buses', {
        ...base,
        registrationNumber: registrationNumber.toLowerCase().replace(/^(.{4})/, '$1 '),
      });
      expect(bus).toMatchObject({ registrationNumber, status: 'ACTIVE' });
      await expectCode(
        w.superAdmin.post('/buses', { ...base, registrationNumber }),
        409,
        'ALREADY_REGISTERED',
      );
      for (const change of [
        { operatorId: undefined },
        { seatCapacity: 0 },
        { seatCapacity: 30.5 },
        { amenities: ['WIFI', 'WIFI'] },
        { amenities: ['JACUZZI'] },
        { busTypeId: '507f1f77bcf86cd799439011' },
        { operatorId: '507f1f77bcf86cd799439011' },
      ]) {
        const response = await w.superAdmin.post('/buses', {
          ...base,
          registrationNumber: uniqueRegistration(),
          ...change,
        });
        expect([400, 404]).toContain(response.status);
      }
      // Registration and operator are permanent
      await expectCode(
        w.superAdmin.put(`/buses/${bus.id}`, { registrationNumber: 'KA99ZZ9999' }),
        400,
        'VALIDATION_FAILED',
      );
      await expectCode(
        w.superAdmin.put(`/buses/${bus.id}`, { operatorId: w.b.operator.id }),
        400,
        'VALIDATION_FAILED',
      );
      // Retiring is final
      await w.superAdmin
        .post(`/buses/${bus.id}/status`, { status: 'RETIRED', reason: 'Sold' })
        .expect(201);
      await expectCode(
        w.superAdmin.post(`/buses/${bus.id}/status`, { status: 'ACTIVE' }),
        409,
        'INVALID_STATE_TRANSITION',
      );
    });

    it('routes: different active cities, each once, stops in order within the journey', async () => {
      const base = {
        operatorId: w.a.operator.id,
        originCityId: w.a.bengaluru.id,
        destinationCityId: w.a.tirupati.id,
        name: 'Checked route',
        estimatedDurationMinutes: 300,
      };
      for (const change of [
        { destinationCityId: w.a.bengaluru.id },
        { destinationCityId: '507f1f77bcf86cd799439011' },
        { stops: [{ cityId: w.a.tirupati.id, offsetMinutes: 100 }] },
        { stops: [{ cityId: w.a.chittoor.id, offsetMinutes: 300 }] },
        {
          stops: [
            { cityId: w.a.chittoor.id, offsetMinutes: 200 },
            { cityId: w.b.chittoor.id, offsetMinutes: 150 },
          ],
        },
        { estimatedDurationMinutes: 5 },
      ]) {
        await expectCode(
          w.superAdmin.post('/routes', { ...base, ...change }),
          400,
          'VALIDATION_FAILED',
        );
      }
      const route = await w.superAdmin.create<{
        id: string;
        stops: { sequence: number; cityId: string }[];
      }>('/routes', {
        ...base,
        stops: [
          { cityId: w.a.chittoor.id, offsetMinutes: 150 },
          { cityId: w.b.chittoor.id, offsetMinutes: 200 },
        ],
      });
      expect(route.stops.map((stop) => stop.sequence)).toEqual([1, 2]);
      // Shortening the journey below an existing stop is refused
      await expectCode(
        w.superAdmin.put(`/routes/${route.id}`, { estimatedDurationMinutes: 180 }),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('operators: status changes follow the state machine and need a reason', async () => {
      const operator = await w.superAdmin.create<{ id: string; status: string }>('/operators', {
        companyName: 'Lifecycle Lines',
      });
      expect(operator.status).toBe('PENDING_APPROVAL');
      const status = (to: string, reason?: string) =>
        w.superAdmin.post(`/operators/${operator.id}/status`, {
          status: to,
          ...(reason ? { reason } : {}),
        });
      await expectCode(status('ACTIVE'), 400, 'VALIDATION_FAILED');
      await expectCode(status('SUSPENDED', 'Too early'), 409, 'INVALID_STATE_TRANSITION');
      await status('ACTIVE', 'Approved').expect(201);
      await expectCode(status('REJECTED', 'Too late'), 409, 'INVALID_STATE_TRANSITION');
      await status('SUSPENDED', 'Complaints').expect(201);
      await status('ACTIVE', 'Resolved').expect(201);
      await expectCode(status('PENDING_APPROVAL', 'Back'), 400, 'VALIDATION_FAILED');
    });
  });

  describe('lists', () => {
    it('are paginated and filterable', async () => {
      const first = (await w.superAdmin.get('/cities?pageSize=2').expect(200)) as Paged<{
        name: string;
      }>;
      const second = (await w.superAdmin.get('/cities?pageSize=2&page=2').expect(200)) as Paged<{
        name: string;
      }>;
      expect(first.body.data).toHaveLength(2);
      expect(first.body.meta).toMatchObject({ page: 1, pageSize: 2 });
      expect(first.body.meta.total).toBeGreaterThanOrEqual(6);
      const names = [...first.body.data, ...second.body.data].map((city) => city.name);
      expect(new Set(names).size).toBe(names.length);
      expect([...names].sort((x, y) => x.localeCompare(y))).toEqual(names);

      const inactive = (await w.superAdmin
        .get('/cities?active=false&pageSize=100')
        .expect(200)) as Paged<{ isActive: boolean }>;
      expect(inactive.body.data.length).toBeGreaterThan(0);
      expect(inactive.body.data.every((city) => !city.isActive)).toBe(true);

      const byCity = (await w.superAdmin
        .get(`/locations?cityId=${w.a.tirupati.id}`)
        .expect(200)) as Paged<Identified>;
      expect(byCity.body.data.map((location) => location.id)).toEqual([w.a.dropping.id]);
      const drafts = (await w.superAdmin
        .get(`/trips?status=DRAFT&operatorId=${w.b.operator.id}`)
        .expect(200)) as Paged<{ status: string }>;
      expect(drafts.body.data.every((trip) => trip.status === 'DRAFT')).toBe(true);
      for (const query of [
        '?pageSize=0',
        '?pageSize=101',
        '?page=0',
        '?active=maybe',
        '?unknown=1',
      ]) {
        await expectCode(w.superAdmin.get(`/cities${query}`), 400, 'VALIDATION_FAILED');
      }
    });
  });

  describe('audit', () => {
    it('catalogue changes are recorded, and an operator sees only its own', async () => {
      const bus = await w.operatorA.create<Identified>('/buses', {
        registrationNumber: uniqueRegistration(),
        name: 'Audited bus',
        busTypeId: w.a.busType.id,
        seatCapacity: 32,
      });
      await w.operatorA.put(`/buses/${bus.id}`, { name: 'Audited bus, renamed' }).expect(200);
      // new buses of an operator start unapproved; platform staff approve this one
      await w.superAdmin
        .post(`/buses/${bus.id}/status`, { status: 'ACTIVE', reason: 'Documents verified' })
        .expect(201);
      await w.operatorA
        .post(`/buses/${bus.id}/status`, { status: 'MAINTENANCE', reason: 'Service due' })
        .expect(201);

      const admins = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
      const entries = dataOf<AuditEntry[]>(
        await client(context)
          .get(`/api/v1/audit-logs?entityId=${bus.id}`)
          .set(...bearer(admins.tokens))
          .expect(200),
      );
      expect(entries.map((entry) => entry.action).sort()).toEqual([
        'catalogue.created',
        'catalogue.status-changed',
        'catalogue.status-changed',
        'catalogue.updated',
      ]);
      expect(entries.find((entry) => entry.reason === 'Service due')).toMatchObject({
        entityType: 'bus',
        operatorId: w.a.operator.id,
        reason: 'Service due',
        before: { status: 'ACTIVE' },
        after: { status: 'MAINTENANCE' },
      });

      const ownerB = await seedAndSignIn(context, {
        roleKeys: ['OPERATOR_ADMIN'],
        operatorId: new Types.ObjectId(w.b.operator.id),
      });
      const seenByB = dataOf<AuditEntry[]>(
        await client(context)
          .get(`/api/v1/audit-logs?entityId=${bus.id}`)
          .set(...bearer(ownerB.tokens))
          .expect(200),
      );
      expect(seenByB).toEqual([]);
    });

    it('a refused change leaves no record and no audit entry', async () => {
      const before = await context.connection.collection('audit_logs').countDocuments();
      await expectCode(
        w.operatorA.put(`/buses/${w.b.bus.id}`, { name: 'Refused' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(
        w.customer.post('/cities', { name: 'Refused', state: 'X' }),
        403,
        'PERMISSION_DENIED',
      );
      expect(await context.connection.collection('audit_logs').countDocuments()).toBe(before);
    });
  });
});
