import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { isDuplicateKeyError, rejectDuplicates } from '../../../common/errors/duplicate-key';
import {
  hasPlatformScope,
  operatorForNewRecord,
} from '../../../common/request-context/operator-scope';
import { type UserActor } from '../../../common/request-context/request-actor';
import { type StoredBusType } from '../../bus-types/repositories/bus-type.repository';
import { type StoredBus } from '../../buses/repositories/bus.repository';
import { slugOf } from '../../cities/services/cities-admin.service';
import { type StoredLocation } from '../../locations/repositories/location.repository';
import { type StoredRoute } from '../../routes/repositories/route.repository';
import { type StoredTrip } from '../repositories/trip.repository';
import { indiaInstant, planOf, tripFieldsOf, type TripPlan } from '../services/trip-plan';

const id = () => new Types.ObjectId();
const operatorId = id();
const origin = id();
const stop = id();
const destination = id();

const bus = {
  _id: id(),
  operatorId,
  registrationNumber: 'KA01AB1234',
  name: 'Express',
  busTypeId: id(),
  amenities: ['WIFI'],
  seatCapacity: 36,
  status: 'ACTIVE',
} as StoredBus;
const busType = {
  _id: bus.busTypeId,
  key: 'AC_SLEEPER',
  name: 'AC Sleeper',
  isAc: true,
  berthType: 'SLEEPER',
  isActive: true,
} as StoredBusType;
const route = {
  _id: id(),
  operatorId,
  originCityId: origin,
  destinationCityId: destination,
  name: 'A to B',
  estimatedDurationMinutes: 300,
  stops: [{ cityId: stop, sequence: 1, offsetMinutes: 200 }],
  status: 'ACTIVE',
} as StoredRoute;
const location = (cityId: Types.ObjectId, name: string) =>
  ({ _id: id(), cityId, name, address: `${name} road`, isActive: true }) as StoredLocation;
const board = location(origin, 'Board');
const midway = location(stop, 'Midway');
const drop = location(destination, 'Drop');
const locations = new Map(
  [board, midway, drop].map((item) => [item._id.toHexString(), item] as const),
);

const plan = (overrides: Partial<TripPlan> = {}): TripPlan => ({
  busId: bus._id.toHexString(),
  routeId: route._id.toHexString(),
  travelDate: '2026-11-20',
  departureTime: '21:30',
  startingFarePaise: 85_000,
  boardingPoints: [{ locationId: board._id.toHexString(), offsetMinutes: 0 }],
  droppingPoints: [{ locationId: drop._id.toHexString(), offsetMinutes: 300 }],
  ...overrides,
});
const build = (overrides: Partial<TripPlan> = {}, context: object = {}) =>
  tripFieldsOf(plan(overrides), { bus, busType, route, locations, newPointId: id, ...context });

describe('tripFieldsOf', () => {
  it('derives timings, copies and search fields from the plan', () => {
    const trip = build();
    expect(trip.departureAt.toISOString()).toBe('2026-11-20T16:00:00.000Z');
    expect(trip.arrivalAt.toISOString()).toBe('2026-11-20T21:00:00.000Z');
    expect(trip).toMatchObject({
      operatorId,
      travelDate: '2026-11-20',
      timezone: 'Asia/Kolkata',
      departureTimeLocal: '21:30',
      departureMinuteOfDay: 21 * 60 + 30,
      durationMinutes: 300,
      originCityId: origin,
      destinationCityId: destination,
      stopCityIds: [stop],
      startingFarePaise: 85_000,
      currency: 'INR',
      bus: { name: 'Express', busTypeKey: 'AC_SLEEPER', isAc: true, amenities: ['WIFI'] },
      seatCounts: { total: 0, available: 0 },
    });
    expect(trip.boardingPoints[0]).toMatchObject({ name: 'Board', cityId: origin });
    expect(trip.droppingPoints[0]?.time.toISOString()).toBe('2026-11-20T21:00:00.000Z');
  });

  it('a duration on the plan replaces the estimate of the route', () => {
    const trip = build({
      durationMinutes: 240,
      droppingPoints: [{ locationId: drop._id.toHexString(), offsetMinutes: 240 }],
    });
    expect(trip.durationMinutes).toBe(240);
  });

  it('a stop city can be both a boarding and a dropping point', () => {
    const trip = build({
      boardingPoints: [
        { locationId: board._id.toHexString(), offsetMinutes: 0 },
        { locationId: midway._id.toHexString(), offsetMinutes: 200 },
      ],
      droppingPoints: [
        { locationId: midway._id.toHexString(), offsetMinutes: 200 },
        { locationId: drop._id.toHexString(), offsetMinutes: 300 },
      ],
    });
    expect(trip.boardingPoints).toHaveLength(2);
    expect(trip.droppingPoints).toHaveLength(2);
  });

  it('keeps the ids of points that already exist, by kind and location', () => {
    const kept = id();
    const trip = build(
      {},
      { existingPointIds: new Map([[`boarding:${board._id.toHexString()}`, kept]]) },
    );
    expect(trip.boardingPoints[0]?.pointId).toBe(kept);
    expect(trip.droppingPoints[0]?.pointId).not.toBe(kept);
  });

  it.each<[string, Partial<TripPlan>, object]>([
    ['a bus and route of different operators', {}, { bus: { ...bus, operatorId: id() } }],
    [
      'a boarding point in the destination',
      { boardingPoints: [{ locationId: drop._id.toHexString(), offsetMinutes: 0 }] },
      {},
    ],
    [
      'a dropping point in the origin',
      { droppingPoints: [{ locationId: board._id.toHexString(), offsetMinutes: 300 }] },
      {},
    ],
    [
      'an unknown location',
      { boardingPoints: [{ locationId: id().toHexString(), offsetMinutes: 0 }] },
      {},
    ],
    [
      'a boarding point at the arrival time',
      { boardingPoints: [{ locationId: board._id.toHexString(), offsetMinutes: 300 }] },
      {},
    ],
    [
      'a dropping point at departure',
      { droppingPoints: [{ locationId: drop._id.toHexString(), offsetMinutes: 0 }] },
      {},
    ],
    [
      'a dropping point before the first boarding point',
      {
        boardingPoints: [{ locationId: board._id.toHexString(), offsetMinutes: 100 }],
        droppingPoints: [{ locationId: drop._id.toHexString(), offsetMinutes: 90 }],
      },
      {},
    ],
    ['a date that does not exist', { travelDate: '2026-13-45' }, {}],
  ])('refuses %s', (_name, overrides, context) => {
    expect(() => build(overrides, context)).toThrow(ApiException);
  });

  it('the plan of a stored trip rebuilds the same trip', () => {
    const fields = build();
    const stored = { ...fields, _id: id(), status: 'DRAFT' } as StoredTrip;
    expect(planOf(stored)).toEqual(plan({ durationMinutes: 300 }));
    const rebuilt = tripFieldsOf(planOf(stored), {
      bus,
      busType,
      route,
      locations,
      newPointId: id,
    });
    expect(rebuilt.departureAt).toEqual(fields.departureAt);
    expect(rebuilt.droppingPoints[0]?.time).toEqual(fields.droppingPoints[0]?.time);
  });

  it('India time has no daylight saving: the offset is always +05:30', () => {
    expect(indiaInstant('2026-01-15', '00:00').toISOString()).toBe('2026-01-14T18:30:00.000Z');
    expect(indiaInstant('2026-07-15', '23:59').toISOString()).toBe('2026-07-15T18:29:00.000Z');
  });
});

describe('operatorForNewRecord', () => {
  const actor = (type: UserActor['dataScope']['type'], operatorIds: string[]): UserActor => ({
    actorType: 'USER',
    userId: id().toHexString(),
    dataScope: { type, operatorIds },
  });
  const own = id().toHexString();
  const other = id().toHexString();

  it('platform staff must name the operator', () => {
    expect(hasPlatformScope(actor('ALL', []))).toBe(true);
    expect(operatorForNewRecord(actor('ALL', []), other).toHexString()).toBe(other);
    expect(() => operatorForNewRecord(actor('ALL', []), undefined)).toThrow('operatorId');
  });

  it('operator staff create for their own operator, named or not', () => {
    const staff = actor('OWN_OPERATOR', [own]);
    expect(hasPlatformScope(staff)).toBe(false);
    expect(operatorForNewRecord(staff, undefined).toHexString()).toBe(own);
    expect(operatorForNewRecord(staff, own).toHexString()).toBe(own);
  });

  it('another operator is refused as not found', () => {
    const attempt = () => operatorForNewRecord(actor('OWN_OPERATOR', [own]), other);
    expect(attempt).toThrow(ApiException);
    expect(attempt).toThrow('Operator not found');
  });

  it('staff of several operators must say which one', () => {
    const staff = actor('SELECTED_OPERATORS', [own, other]);
    expect(() => operatorForNewRecord(staff, undefined)).toThrow('operatorId');
    expect(operatorForNewRecord(staff, other).toHexString()).toBe(other);
  });

  it('a customer has no operator to create for', () => {
    expect(() => operatorForNewRecord(actor('OWN_RECORDS', []), undefined)).toThrow(ApiException);
  });
});

describe('catalogue helpers', () => {
  it('makes a URL key from a city name', () => {
    expect(slugOf('Bengaluru')).toBe('bengaluru');
    expect(slugOf('  New   Delhi (NCR) ')).toBe('new-delhi-ncr');
    expect(slugOf('ಬೆಂಗಳೂರು')).toBe('');
  });

  it('turns a unique-index violation into ALREADY_REGISTERED and nothing else', async () => {
    const duplicate = Object.assign(new Error('E11000 duplicate key'), { code: 11000 });
    expect(isDuplicateKeyError(duplicate)).toBe(true);
    expect(isDuplicateKeyError(new Error('other'))).toBe(false);
    await expect(
      rejectDuplicates('Already there.', () => Promise.reject(duplicate)),
    ).rejects.toMatchObject({
      code: 'ALREADY_REGISTERED',
      message: 'Already there.',
    });
    const other = new Error('connection lost');
    await expect(rejectDuplicates('x', () => Promise.reject(other))).rejects.toBe(other);
    await expect(rejectDuplicates('x', () => Promise.resolve(7))).resolves.toBe(7);
  });
});
