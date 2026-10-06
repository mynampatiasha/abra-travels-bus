import { Types } from 'mongoose';
import { type Response } from 'supertest';
import {
  type AuthTestContext,
  bearer,
  client,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import { type SystemRoleKey } from '../../rbac/roles/system-roles';
import { clearDiscoveryData, runId, travelDateIn } from './discovery-e2e.fixture';

export const CATALOGUE = '/api/v1/catalogue';

export interface Caller {
  tokens: Tokens;
}

export interface Identified {
  id: string;
}

/** Calls the catalogue API as `user`. */
export function catalogueApi(context: AuthTestContext, user: Caller) {
  const send = (method: 'get' | 'post' | 'put', path: string, body?: object) => {
    const request = client(context)
      [method](`${CATALOGUE}${path}`)
      .set(...bearer(user.tokens));
    return body ? request.send(body) : request;
  };
  return {
    get: (path: string) => send('get', path),
    post: (path: string, body: object = {}) => send('post', path, body),
    put: (path: string, body: object) => send('put', path, body),
    /** POSTs and returns the created record; fails the test when it is not accepted. */
    create: async <T extends Identified>(path: string, body: object): Promise<T> => {
      const response = await send('post', path, body);
      if (response.status !== 201 && response.status !== 200) {
        throw new Error(`${path} answered ${response.status}: ${JSON.stringify(response.body)}`);
      }
      return dataOf<T>(response);
    },
  };
}

export type CatalogueApi = ReturnType<typeof catalogueApi>;

export function errorMessageOf(response: Response): string {
  return (response.body as { error?: { message?: string } }).error?.message ?? '';
}

let registration = 1000;

/** A registration number no other test uses. */
export function uniqueRegistration(): string {
  registration += 1;
  return `KA01T${Date.now().toString().slice(-5)}${registration}`.slice(0, 15);
}

export interface Network {
  operator: Identified;
  bengaluru: Identified;
  tirupati: Identified;
  chittoor: Identified;
  boarding: Identified;
  dropping: Identified;
  busType: Identified & { key: string };
  bus: Identified;
  route: Identified;
}

/**
 * Builds a small real catalogue through the API, the way platform staff would: two cities with
 * a stop between them, a shared boarding and dropping location, an approved operator with one
 * bus, and the route Bengaluru to Tirupati.
 */
export async function buildNetwork(admin: CatalogueApi, suffix: string): Promise<Network> {
  const city = (name: string) =>
    admin.create<Identified>('/cities', { name: `${name} ${suffix}`, state: 'Test State' });
  const bengaluru = await city('Bengaluru');
  const tirupati = await city('Tirupati');
  const chittoor = await city('Chittoor');

  const boarding = await admin.create<Identified>('/locations', {
    cityId: bengaluru.id,
    name: 'Majestic Bus Stand',
    address: 'Kempegowda Bus Station, Gandhi Nagar',
    landmark: 'Platform 12',
    instructions: 'Report 15 minutes early',
    contactPhone: '+918012345678',
    latitude: 12.9774,
    longitude: 77.5708,
  });
  const dropping = await admin.create<Identified>('/locations', {
    cityId: tirupati.id,
    name: 'Tirupati Central Bus Stand',
    address: 'Tirumala Bypass Road',
  });

  const operator = await admin.create<Identified>('/operators', {
    companyName: `Test Operator ${suffix} Private Limited`,
    displayName: `Test Operator ${suffix}`,
  });
  await admin
    .post(`/operators/${operator.id}/status`, { status: 'ACTIVE', reason: 'Documents verified' })
    .expect(201);

  const busType = await admin.create<Identified & { key: string }>('/bus-types', {
    key: `AC_SLEEPER_${suffix.toUpperCase()}`,
    name: 'AC Sleeper',
    isAc: true,
    berthType: 'SLEEPER',
  });
  const bus = await admin.create<Identified>('/buses', {
    operatorId: operator.id,
    registrationNumber: uniqueRegistration(),
    name: 'Tirupati Express',
    busTypeId: busType.id,
    amenities: ['WIFI', 'CHARGING_POINT', 'BLANKET'],
    seatCapacity: 36,
  });
  const route = await admin.create<Identified>('/routes', {
    operatorId: operator.id,
    originCityId: bengaluru.id,
    destinationCityId: tirupati.id,
    name: 'Bengaluru to Tirupati',
    distanceKm: 250,
    estimatedDurationMinutes: 300,
    stops: [{ cityId: chittoor.id, offsetMinutes: 210 }],
  });
  return { operator, bengaluru, tirupati, chittoor, boarding, dropping, busType, bus, route };
}

/** A valid trip on the network, `daysAhead` days from today. */
export function tripBody(network: Network, daysAhead = 7, overrides: object = {}) {
  return {
    busId: network.bus.id,
    routeId: network.route.id,
    travelDate: travelDateIn(daysAhead),
    departureTime: '21:30',
    startingFarePaise: 85_000,
    boardingPoints: [{ locationId: network.boarding.id, offsetMinutes: 0 }],
    droppingPoints: [{ locationId: network.dropping.id, offsetMinutes: 300 }],
    ...overrides,
  };
}

const CATALOGUE_COLLECTIONS = [
  'trips',
  'routes',
  'buses',
  'bus_types',
  'locations',
  'operators',
  'cities',
];

export async function clearCatalogue(context: AuthTestContext): Promise<void> {
  await clearDiscoveryData(context);
  for (const collection of CATALOGUE_COLLECTIONS) {
    await context.connection.collection(collection).deleteMany({});
  }
}

/** Signs in a new user holding `roleKey`, for an operator when one is given. */
export async function signInAs(
  context: AuthTestContext,
  roleKey: SystemRoleKey,
  operatorId?: string,
): Promise<CatalogueApi> {
  return catalogueApi(
    context,
    await seedAndSignIn(context, {
      roleKeys: [roleKey],
      ...(operatorId ? { operatorId: new Types.ObjectId(operatorId) } : {}),
    }),
  );
}

/** Two operators with their own catalogue, and one caller of every kind. */
export interface AccessWorld {
  superAdmin: CatalogueApi;
  admin: CatalogueApi;
  support: CatalogueApi;
  customer: CatalogueApi;
  operatorA: CatalogueApi;
  managerA: CatalogueApi;
  bookingStaffA: CatalogueApi;
  operatorB: CatalogueApi;
  a: Network;
  b: Network;
}

export async function createAccessWorld(
  context: AuthTestContext,
  label: string,
): Promise<AccessWorld> {
  await clearCatalogue(context);
  const superAdmin = await signInAs(context, 'SUPER_ADMIN');
  const a = await buildNetwork(superAdmin, `${runId}${label}a`);
  const b = await buildNetwork(superAdmin, `${runId}${label}b`);
  return {
    superAdmin,
    admin: await signInAs(context, 'ADMIN'),
    support: await signInAs(context, 'SUPPORT'),
    customer: await signInAs(context, 'CUSTOMER'),
    operatorA: await signInAs(context, 'OPERATOR_ADMIN', a.operator.id),
    managerA: await signInAs(context, 'OPERATOR_MANAGER', a.operator.id),
    bookingStaffA: await signInAs(context, 'BOOKING_STAFF', a.operator.id),
    operatorB: await signInAs(context, 'OPERATOR_ADMIN', b.operator.id),
    a,
    b,
  };
}

/** Asserts the status and error code of a response. */
export async function expectCode(
  request: PromiseLike<Response>,
  status: number,
  code: string,
): Promise<void> {
  const response = await request;
  const body = response.body as { error?: { code?: string } };
  expect({ status: response.status, code: body.error?.code }).toEqual({ status, code });
}
