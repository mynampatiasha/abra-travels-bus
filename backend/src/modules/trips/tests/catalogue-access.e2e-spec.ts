import { Types } from 'mongoose';
import {
  type AuthTestContext,
  client,
  createAuthTestApp,
} from '../../authentication/tests/auth-e2e.harness';
import {
  type AccessWorld,
  CATALOGUE,
  clearCatalogue,
  createAccessWorld,
  expectCode,
  type Identified,
  tripBody,
  uniqueRegistration,
} from './catalogue-e2e.support';
import { runId } from './discovery-e2e.fixture';

interface Paged<T> {
  body: { data: T[]; meta: { page: number; pageSize: number; total: number } };
}

/** permissions and operator isolation — real application, MongoDB replica set and Redis. */
describe('Catalogue e2e: permissions and operator isolation', () => {
  let context: AuthTestContext;
  let w: AccessWorld;

  beforeAll(async () => {
    context = await createAuthTestApp();
    w = await createAccessWorld(context, 'p');
  }, 180_000);

  afterAll(async () => {
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  describe('sign-in and permissions are required', () => {
    it('nothing in the catalogue API is open without a token', async () => {
      for (const path of [
        '/cities',
        '/bus-types',
        '/operators',
        '/locations',
        '/buses',
        '/routes',
        '/trips',
      ]) {
        await client(context).get(`${CATALOGUE}${path}`).expect(401);
        await client(context).post(`${CATALOGUE}${path}`).send({}).expect(401);
      }
    });

    it('a customer can neither read nor change the catalogue', async () => {
      for (const path of [
        '/cities',
        '/bus-types',
        '/operators',
        '/locations',
        '/buses',
        '/routes',
        '/trips',
      ]) {
        await expectCode(w.customer.get(path), 403, 'PERMISSION_DENIED');
      }
      await expectCode(w.customer.post('/trips', tripBody(w.a)), 403, 'PERMISSION_DENIED');
      await expectCode(
        w.customer.post(`/trips/${new Types.ObjectId().toHexString()}/publish`),
        403,
        'PERMISSION_DENIED',
      );
    });

    it('support staff can look but not change', async () => {
      await w.support.get('/buses').expect(200);
      await w.support.get('/trips').expect(200);
      await w.support.get('/operators').expect(200);
      await expectCode(
        w.support.post('/cities', { name: 'Nowhere', state: 'X' }),
        403,
        'PERMISSION_DENIED',
      );
      await expectCode(w.support.post('/trips', tripBody(w.a)), 403, 'PERMISSION_DENIED');
      await expectCode(
        w.support.post(`/buses/${w.a.bus.id}/status`, { status: 'RETIRED' }),
        403,
        'PERMISSION_DENIED',
      );
    });

    it('operator staff cannot manage the platform catalogue or operators', async () => {
      await expectCode(w.operatorA.get('/cities'), 403, 'PERMISSION_DENIED');
      await expectCode(
        w.operatorA.post('/cities', { name: 'Own City', state: 'X' }),
        403,
        'PERMISSION_DENIED',
      );
      await expectCode(
        w.operatorA.post('/bus-types', {
          key: 'OWN_TYPE',
          name: 'Own',
          isAc: true,
          berthType: 'SEATER',
        }),
        403,
        'PERMISSION_DENIED',
      );
      await expectCode(
        w.operatorA.post('/operators', { companyName: 'Second Company' }),
        403,
        'PERMISSION_DENIED',
      );
      await expectCode(
        w.operatorA.post(`/operators/${w.a.operator.id}/status`, {
          status: 'SUSPENDED',
          reason: 'self',
        }),
        403,
        'PERMISSION_DENIED',
      );
      // They can still read the bus types they choose from
      await w.operatorA.get('/bus-types').expect(200);
    });

    it('roles inside an operator differ: booking staff read, managers plan, administrators also publish', async () => {
      await w.bookingStaffA.get('/trips').expect(200);
      await expectCode(w.bookingStaffA.post('/trips', tripBody(w.a, 50)), 403, 'PERMISSION_DENIED');
      await expectCode(w.bookingStaffA.get('/routes'), 403, 'PERMISSION_DENIED');

      const trip = await w.managerA.create<Identified>('/trips', tripBody(w.a, 50));
      await w.managerA.post(`/trips/${trip.id}/publish`).expect(201);
      await w.managerA.post(`/trips/${trip.id}/cancel`, { reason: 'Planning change' }).expect(201);
    });

    it('an administrator manages the catalogue; only approving operators needs the sensitive permission they also hold', async () => {
      const city = await w.admin.create<Identified>('/cities', {
        name: `Admin City ${runId}`,
        state: 'Test State',
      });
      await w.admin
        .post(`/cities/${city.id}/active`, { active: false, reason: 'Created by mistake' })
        .expect(201);
      const operator = await w.admin.create<Identified>('/operators', {
        companyName: 'Admin Created Lines',
      });
      await w.admin
        .post(`/operators/${operator.id}/status`, {
          status: 'REJECTED',
          reason: 'Incomplete documents',
        })
        .expect(201);
    });
  });

  describe('operator isolation', () => {
    it('lists contain only the caller’s operator', async () => {
      for (const path of ['/buses', '/routes', '/operators']) {
        const own = (await w.operatorA.get(path).expect(200)) as Paged<{
          id: string;
          operatorId?: string;
        }>;
        expect(own.body.data.length).toBeGreaterThan(0);
        for (const record of own.body.data) {
          expect(record.operatorId ?? record.id).toBe(w.a.operator.id);
        }
      }
      const all = (await w.superAdmin.get('/buses').expect(200)) as Paged<Identified>;
      expect(all.body.meta.total).toBe(2);
    });

    it('a filter cannot widen the scope', async () => {
      const response = (await w.operatorA
        .get(`/buses?operatorId=${w.b.operator.id}`)
        .expect(200)) as Paged<Identified>;
      expect(response.body.data).toEqual([]);
      expect(response.body.meta.total).toBe(0);
    });

    it('another operator’s records do not exist for the caller', async () => {
      for (const path of [
        `/buses/${w.b.bus.id}`,
        `/routes/${w.b.route.id}`,
        `/operators/${w.b.operator.id}`,
      ]) {
        await expectCode(w.operatorA.get(path), 404, 'RESOURCE_NOT_FOUND');
      }
      await expectCode(
        w.operatorA.put(`/buses/${w.b.bus.id}`, { name: 'Taken over' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(
        w.operatorA.post(`/buses/${w.b.bus.id}/status`, { status: 'RETIRED' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(
        w.operatorA.put(`/routes/${w.b.route.id}`, { name: 'Taken over' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(
        w.operatorA.put(`/operators/${w.b.operator.id}`, { displayName: 'Taken over' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
    });

    it('records cannot be created for another operator', async () => {
      await expectCode(
        w.operatorA.post('/buses', {
          operatorId: w.b.operator.id,
          registrationNumber: uniqueRegistration(),
          name: 'Planted bus',
          busTypeId: w.a.busType.id,
          seatCapacity: 30,
        }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(
        w.operatorA.post('/routes', {
          operatorId: w.b.operator.id,
          originCityId: w.a.bengaluru.id,
          destinationCityId: w.a.tirupati.id,
          name: 'Planted route',
          estimatedDurationMinutes: 300,
        }),
        404,
        'RESOURCE_NOT_FOUND',
      );
    });

    it('a trip cannot use another operator’s bus or route', async () => {
      await expectCode(
        w.operatorA.post('/trips', tripBody(w.a, 20, { busId: w.b.bus.id })),
        400,
        'VALIDATION_FAILED',
      );
      await expectCode(
        w.operatorA.post('/trips', tripBody(w.a, 20, { routeId: w.b.route.id })),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('another operator’s trips cannot be seen, edited, published or cancelled', async () => {
      const trip = await w.operatorB.create<Identified>('/trips', tripBody(w.b, 21));
      await expectCode(w.operatorA.get(`/trips/${trip.id}`), 404, 'RESOURCE_NOT_FOUND');
      await expectCode(
        w.operatorA.put(`/trips/${trip.id}`, { startingFarePaise: 100 }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(w.operatorA.post(`/trips/${trip.id}/publish`), 404, 'RESOURCE_NOT_FOUND');
      await expectCode(
        w.operatorA.post(`/trips/${trip.id}/cancel`, { reason: 'Sabotage' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      const mine = (await w.operatorA.get('/trips').expect(200)) as Paged<{ operatorId: string }>;
      expect(mine.body.data.every((found) => found.operatorId === w.a.operator.id)).toBe(true);
      // The owner is unaffected
      await w.operatorB.post(`/trips/${trip.id}/publish`).expect(201);
    });

    it('an operator creates and runs its own catalogue without naming itself', async () => {
      const bus = await w.operatorA.create<Identified & { operatorId: string }>('/buses', {
        registrationNumber: uniqueRegistration(),
        name: 'Own second bus',
        busTypeId: w.a.busType.id,
        seatCapacity: 28,
      });
      expect(bus.operatorId).toBe(w.a.operator.id);
      const trip = await w.operatorA.create<Identified>(
        '/trips',
        tripBody(w.a, 25, { busId: bus.id }),
      );
      await w.operatorA.post(`/trips/${trip.id}/publish`).expect(201);
      await w.operatorA
        .put(`/operators/${w.a.operator.id}`, { displayName: `Renamed ${runId}` })
        .expect(200);
    });

    it('locations: shared ones are visible to all operators, own ones only to their operator', async () => {
      const own = await w.operatorA.create<Identified & { operatorId: string }>('/locations', {
        cityId: w.a.bengaluru.id,
        name: 'Operator A office',
        address: 'Residency Road',
      });
      expect(own.operatorId).toBe(w.a.operator.id);

      const seenByA = (await w.operatorA
        .get('/locations?pageSize=100')
        .expect(200)) as Paged<Identified>;
      const seenByB = (await w.operatorB
        .get('/locations?pageSize=100')
        .expect(200)) as Paged<Identified>;
      expect(seenByA.body.data.map((location) => location.id)).toEqual(
        expect.arrayContaining([own.id, w.a.boarding.id]),
      );
      expect(seenByB.body.data.map((location) => location.id)).toContain(w.a.boarding.id);
      expect(seenByB.body.data.map((location) => location.id)).not.toContain(own.id);
      await expectCode(w.operatorB.get(`/locations/${own.id}`), 404, 'RESOURCE_NOT_FOUND');

      // Shared locations belong to the platform: operators use them but cannot change them
      await expectCode(
        w.operatorA.put(`/locations/${w.a.boarding.id}`, { name: 'Renamed' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await expectCode(
        w.operatorA.post(`/locations/${w.a.boarding.id}/active`, { active: false }),
        404,
        'RESOURCE_NOT_FOUND',
      );
      await w.operatorA.put(`/locations/${own.id}`, { landmark: 'Next to the bank' }).expect(200);

      // Another operator cannot board passengers at this operator's office
      await expectCode(
        w.operatorB.post(
          '/trips',
          tripBody(w.b, 26, { boardingPoints: [{ locationId: own.id, offsetMinutes: 0 }] }),
        ),
        400,
        'VALIDATION_FAILED',
      );
    });
  });
});
