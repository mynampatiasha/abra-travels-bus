import { randomBytes } from 'node:crypto';
import { getModelToken } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { type AuthTestContext } from '../../authentication/tests/auth-e2e.harness';
import { type BusAmenity } from '../../buses/schemas/bus.schema';
import { CITY_MODEL, type City } from '../../cities/schemas/city.schema';
import {
  OPERATOR_MODEL,
  type Operator,
  type OperatorStatus,
} from '../../operators/schemas/operator.schema';
import { TRIP_MODEL, type Trip, type TripPoint, type TripStatus } from '../schemas/trip.schema';
import { addDays, localDateOf } from '../services/travel-date';

/** Unique per test run, so documents of different suites never collide. */
export const runId = randomBytes(4).toString('hex');

const model = <T>(context: AuthTestContext, token: string): Model<T> =>
  context.app.get<Model<T>>(getModelToken(token));

/** A travel date `daysAhead` days from today in India time. */
export function travelDateIn(daysAhead: number): string {
  return addDays(localDateOf(new Date()), daysAhead);
}

/** The instant of `time` (HH:mm, India time) on `travelDate`, plus whole days. */
export function indiaTime(travelDate: string, time: string, plusDays = 0): Date {
  return new Date(new Date(`${travelDate}T${time}:00+05:30`).getTime() + plusDays * 86_400_000);
}

export async function seedCity(
  context: AuthTestContext,
  name: string,
  extra: Partial<City> = {},
): Promise<Types.ObjectId> {
  const [city] = await model<City>(context, CITY_MODEL).create([
    {
      name,
      slug: `${name.toLowerCase().replace(/[^a-z0-9]+/g, '-')}-${runId}-${randomBytes(2).toString('hex')}`,
      state: 'Karnataka',
      isPopular: false,
      sortOrder: 0,
      isActive: true,
      ...extra,
    },
  ]);
  if (!city) throw new Error('City was not created');
  return city._id;
}

export async function seedOperator(
  context: AuthTestContext,
  companyName: string,
  status: OperatorStatus = 'ACTIVE',
  displayName?: string,
): Promise<Types.ObjectId> {
  const [operator] = await model<Operator>(context, OPERATOR_MODEL).create([
    { companyName, status, ...(displayName ? { displayName } : {}) },
  ]);
  if (!operator) throw new Error('Operator was not created');
  return operator._id;
}

export interface SeedTripInput {
  operatorId: Types.ObjectId;
  originCityId: Types.ObjectId;
  destinationCityId: Types.ObjectId;
  travelDate: string;
  /** Departure, HH:mm India time. */
  departure: string;
  durationMinutes: number;
  farePaise: number;
  status?: TripStatus;
  busName?: string;
  busType?: { key: string; name: string; isAc: boolean; berthType: Trip['bus']['berthType'] };
  amenities?: BusAmenity[];
  seats?: { total: number; available: number };
  stopCityIds?: Types.ObjectId[];
  /** Overrides the computed departure instant (to seed a trip that has already left). */
  departureAt?: Date;
}

const AC_SLEEPER = { key: 'AC_SLEEPER', name: 'AC Sleeper', isAc: true, berthType: 'SLEEPER' };

function point(
  cityId: Types.ObjectId,
  name: string,
  time: Date,
  extra: Partial<TripPoint> = {},
): TripPoint {
  return {
    pointId: new Types.ObjectId(),
    cityId,
    name,
    address: `${name}, Main Road`,
    time,
    ...extra,
  };
}

/** Inserts a trip the way publishing will: with its bus, points and seat totals copied in. */
export async function seedTrip(
  context: AuthTestContext,
  input: SeedTripInput,
): Promise<Types.ObjectId> {
  const [hours, minutes] = input.departure.split(':').map(Number) as [number, number];
  const departureAt = input.departureAt ?? indiaTime(input.travelDate, input.departure);
  const arrivalAt = new Date(departureAt.getTime() + input.durationMinutes * 60_000);
  const seats = input.seats ?? { total: 36, available: 20 };
  const [trip] = await model<Trip>(context, TRIP_MODEL).create([
    {
      operatorId: input.operatorId,
      routeId: new Types.ObjectId(),
      busId: new Types.ObjectId(),
      seatLayoutVersionId: new Types.ObjectId(),
      travelDate: input.travelDate,
      timezone: 'Asia/Kolkata',
      departureAt,
      arrivalAt,
      departureMinuteOfDay: hours * 60 + minutes,
      durationMinutes: input.durationMinutes,
      originCityId: input.originCityId,
      destinationCityId: input.destinationCityId,
      stopCityIds: input.stopCityIds ?? [],
      boardingPoints: [
        // Stored out of order on purpose: the API returns points by time
        point(input.originCityId, 'Second Stage', new Date(departureAt.getTime() + 20 * 60_000)),
        point(input.originCityId, 'Central Bus Stand', departureAt, {
          landmark: 'Opposite City Mall',
          instructions: 'Board at platform 4',
          contactPhone: '+918000000000',
          location: { type: 'Point', coordinates: [77.5946, 12.9716] },
        }),
      ],
      droppingPoints: [point(input.destinationCityId, 'Town Hall', arrivalAt)],
      bus: {
        name: input.busName ?? 'Abra Express',
        registrationNumber: 'KA01AB1234',
        busTypeKey: (input.busType ?? AC_SLEEPER).key,
        busTypeName: (input.busType ?? AC_SLEEPER).name,
        isAc: (input.busType ?? AC_SLEEPER).isAc,
        berthType: (input.busType ?? AC_SLEEPER).berthType as Trip['bus']['berthType'],
        amenities: input.amenities ?? [],
      },
      startingFarePaise: input.farePaise,
      currency: 'INR',
      status: input.status ?? 'SCHEDULED',
      publishedAt: new Date(),
      seatCounts: {
        total: seats.total,
        available: seats.available,
        locked: 0,
        booked: seats.total - seats.available,
        blocked: 0,
      },
    },
  ]);
  if (!trip) throw new Error('Trip was not created');
  return trip._id;
}

/** Removes everything this run seeded. */
export async function clearDiscoveryData(context: AuthTestContext): Promise<void> {
  for (const collection of ['trips', 'operators', 'cities']) {
    await context.connection.collection(collection).deleteMany({});
  }
}
