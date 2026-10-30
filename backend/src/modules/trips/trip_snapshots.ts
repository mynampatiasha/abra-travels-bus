import { type Connection, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type BerthType } from '../bus-types/schemas/bus-type.schema';
import { type TripPoint } from './schemas/trip.schema';

/*
 * What a trip, a schedule and a route copy from the catalogue, in one place: the bus type of a bus
 * (air conditioning, seats or berths), the real cities of a route, and its boarding and dropping
 * points. Nothing here invents a value: when the catalogue cannot answer, the person is told what
 * to add first.
 */

export interface BusTypeInfo {
  id: Types.ObjectId;
  key: string;
  name: string;
  isAc: boolean;
  berthType: BerthType;
}

interface BusTypeRow {
  _id: Types.ObjectId;
  key: string;
  name: string;
  isAc: boolean;
  berthType: BerthType;
}

/** The bus type a bus belongs to, or null when the bus has none (or it was removed). */
export async function busTypeOfBus(
  connection: Connection,
  bus: { busTypeId?: Types.ObjectId | undefined },
): Promise<BusTypeInfo | null> {
  if (!bus.busTypeId) return null;
  const row = await connection
    .collection<BusTypeRow>('bus_types')
    .findOne({ _id: bus.busTypeId, isDeleted: { $ne: true } });
  if (!row) return null;
  return { id: row._id, key: row.key, name: row.name, isAc: row.isAc, berthType: row.berthType };
}

export async function requireBusType(
  connection: Connection,
  bus: { busTypeId?: Types.ObjectId | undefined; registrationNumber?: string | undefined },
): Promise<BusTypeInfo> {
  const type = await busTypeOfBus(connection, bus);
  if (!type) {
    throw new ApiException(
      'VALIDATION_FAILED',
      `Bus ${bus.registrationNumber ?? ''} has no bus type. Edit the bus and choose one.`.replace('  ', ' '),
    );
  }
  return type;
}

/** The bus as it is copied onto a trip. */
export function busSnapshotOf(
  bus: { name?: string | undefined; registrationNumber?: string | undefined; amenities?: string[] | undefined },
  type: BusTypeInfo,
) {
  const registration = bus.registrationNumber ?? bus.name ?? 'Bus';
  return {
    name: bus.name ?? registration,
    registrationNumber: registration,
    busTypeKey: type.key,
    busTypeName: type.name,
    isAc: type.isAc,
    berthType: type.berthType,
    amenities: bus.amenities ?? [],
  };
}

/** The active fare of a route for a bus type (the fare list names its seat type like the bus type). */
export async function activeFareFor(
  connection: Connection,
  operatorId: Types.ObjectId,
  routeId: Types.ObjectId,
  type: BusTypeInfo,
): Promise<{ weekday: number; weekend: number; festival?: number; fareRuleSetVersionId?: Types.ObjectId; _id: Types.ObjectId } | null> {
  return connection.collection<{
    _id: Types.ObjectId;
    weekday: number;
    weekend: number;
    festival?: number;
    fareRuleSetVersionId?: Types.ObjectId;
  }>('fares').findOne({
    operatorId,
    routeId,
    seatType: type.name,
    status: 'ACTIVE',
    isDeleted: { $ne: true },
  });
}

export function missingFareMessage(routeName: string, type: BusTypeInfo): string {
  return `Add a fare for ${routeName} and ${type.name} first. A trip cannot be priced without one.`;
}

// ===== Routes: real cities and places =====

interface CityRow {
  _id: Types.ObjectId;
  name: string;
}

interface LocationRow {
  _id: Types.ObjectId;
  cityId: Types.ObjectId;
  name: string;
  address?: string;
  landmark?: string;
  location?: { type?: string; coordinates?: number[] };
  contactPhone?: string;
  instructions?: string;
}

export interface RouteStopInput {
  placeId?: string | undefined;
  name?: string | undefined;
  city?: string | undefined;
  offset?: number | undefined;
  offsetMinutes?: number | undefined;
  type?: string | undefined;
  cityId?: Types.ObjectId | undefined;
}

const escapeRegex = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

async function cityByName(connection: Connection, name: string): Promise<CityRow | null> {
  return connection.collection<CityRow>('cities').findOne({
    name: { $regex: `^${escapeRegex(name.trim())}$`, $options: 'i' },
    isActive: true,
    isDeleted: { $ne: true },
  });
}

function cityNotFound(name: string): ApiException {
  return new ApiException(
    'VALIDATION_FAILED',
    `The city "${name}" is not in Abra's list of cities. Pick a listed city, or ask Abra to add it.`,
  );
}

/**
 * The real city of the route's two ends and of each stop. A stop picked from the list of approved
 * places brings its own city; a stop typed by name must match a city Abra lists.
 */
export async function resolveRouteCities(
  connection: Connection,
  from: string,
  to: string,
  stops: readonly RouteStopInput[],
): Promise<{
  originCityId: Types.ObjectId;
  destinationCityId: Types.ObjectId;
  stopCityIds: Types.ObjectId[];
}> {
  const origin = await cityByName(connection, from);
  if (!origin) throw cityNotFound(from);
  const destination = await cityByName(connection, to);
  if (!destination) throw cityNotFound(to);

  const stopCityIds: Types.ObjectId[] = [];
  for (const stop of stops) {
    let cityId: Types.ObjectId | undefined;
    if (stop.placeId && Types.ObjectId.isValid(stop.placeId)) {
      const place = await connection
        .collection<LocationRow>('locations')
        .findOne({ _id: new Types.ObjectId(stop.placeId), isActive: true, isDeleted: { $ne: true } });
      cityId = place?.cityId;
    }
    if (!cityId && stop.city) {
      const city = await cityByName(connection, stop.city);
      if (!city) throw cityNotFound(stop.city);
      cityId = city._id;
    }
    if (!cityId) throw cityNotFound(stop.city ?? stop.name ?? 'stop');
    stopCityIds.push(cityId);
  }
  return { originCityId: origin._id, destinationCityId: destination._id, stopCityIds };
}

/** True when the id is a city Abra lists. */
export async function cityExists(connection: Connection, id: Types.ObjectId | undefined): Promise<boolean> {
  if (!id) return false;
  return (await connection.collection('cities').countDocuments({ _id: id })) > 0;
}

/**
 * Repairs a route saved before cities were checked: its origin, destination and stop cities were
 * random ids. Finds the real ones by name and stores them, so trips and search can use the route.
 */
export async function healRouteCities(
  connection: Connection,
  route: {
    _id: Types.ObjectId;
    from?: string;
    to?: string;
    originCityId?: Types.ObjectId;
    destinationCityId?: Types.ObjectId;
    stops?: unknown[];
  },
): Promise<{ originCityId: Types.ObjectId; destinationCityId: Types.ObjectId; stops: RouteStopInput[] }> {
  const stops = (route.stops ?? []) as RouteStopInput[];
  const originOk = await cityExists(connection, route.originCityId);
  const destinationOk = await cityExists(connection, route.destinationCityId);
  const stopsOk = (
    await Promise.all(stops.map((stop) => cityExists(connection, stop.cityId)))
  ).every(Boolean);
  if (originOk && destinationOk && stopsOk && route.originCityId && route.destinationCityId) {
    return { originCityId: route.originCityId, destinationCityId: route.destinationCityId, stops };
  }
  if (!route.from || !route.to) {
    throw new ApiException('VALIDATION_FAILED', 'The route has no From and To city. Edit the route first.');
  }
  const cities = await resolveRouteCities(connection, route.from, route.to, stops);
  const healed = stops.map((stop, index) => ({ ...stop, cityId: cities.stopCityIds[index] }));
  await connection.collection('routes').updateOne(
    { _id: route._id },
    {
      $set: {
        originCityId: cities.originCityId,
        destinationCityId: cities.destinationCityId,
        stops: healed,
      },
    },
  );
  return { originCityId: cities.originCityId, destinationCityId: cities.destinationCityId, stops: healed };
}

/**
 * The boarding and dropping points of a trip, copied from the route's stops: each stop picked
 * from the approved places brings its address and map position; the time is the departure plus the
 * stop's minutes from the start.
 */
export async function routePointsOf(
  connection: Connection,
  stops: readonly RouteStopInput[],
  departureAt: Date,
): Promise<{ boardingPoints: TripPoint[]; droppingPoints: TripPoint[]; stopCityIds: Types.ObjectId[] }> {
  const boardingPoints: TripPoint[] = [];
  const droppingPoints: TripPoint[] = [];
  const stopCityIds: Types.ObjectId[] = [];
  for (const stop of stops) {
    if (!stop.cityId) continue;
    const place =
      stop.placeId && Types.ObjectId.isValid(stop.placeId)
        ? await connection
            .collection<LocationRow>('locations')
            .findOne({ _id: new Types.ObjectId(stop.placeId) })
        : null;
    const minutes = Number(stop.offsetMinutes ?? stop.offset ?? 0);
    const coordinates = place?.location?.coordinates;
    const point: TripPoint = {
      pointId: new Types.ObjectId(),
      ...(place ? { locationId: place._id } : {}),
      cityId: place?.cityId ?? stop.cityId,
      name: place?.name ?? stop.name ?? stop.city ?? 'Stop',
      address: place?.address ?? stop.name ?? stop.city ?? 'Stop',
      ...(place?.landmark ? { landmark: place.landmark } : {}),
      ...(coordinates && coordinates.length === 2
        ? { location: { type: 'Point' as const, coordinates: [coordinates[0] ?? 0, coordinates[1] ?? 0] } }
        : {}),
      ...(place?.contactPhone ? { contactPhone: place.contactPhone } : {}),
      ...(place?.instructions ? { instructions: place.instructions } : {}),
      time: new Date(departureAt.getTime() + minutes * 60_000),
    };
    stopCityIds.push(point.cityId);
    if (stop.type !== 'DROPPING') boardingPoints.push(point);
    if (stop.type !== 'BOARDING') droppingPoints.push({ ...point, pointId: new Types.ObjectId() });
  }
  return { boardingPoints, droppingPoints, stopCityIds };
}

// ===== The bus's usual driver and conductor =====

export interface CrewPerson {
  id: Types.ObjectId;
  name: string;
  licenseExpiryDate?: Date | undefined;
}

/**
 * The driver and conductor set on the bus, when they are still active. A new trip starts with them;
 * the owner can change any single trip. A person who is no longer active is simply left out.
 */
export async function defaultCrewOf(
  connection: Connection,
  bus: { defaultDriverId?: Types.ObjectId | undefined; defaultConductorId?: Types.ObjectId | undefined },
): Promise<{ driver?: CrewPerson; conductor?: CrewPerson }> {
  const load = async (id: Types.ObjectId | undefined, role: 'DRIVER' | 'CONDUCTOR'): Promise<CrewPerson | undefined> => {
    if (!id) return undefined;
    const person = await connection
      .collection<{ _id: Types.ObjectId; name: string; licenseExpiryDate?: Date }>('operator_crew')
      .findOne({ _id: id, role, status: 'ACTIVE', isDeleted: { $ne: true } } as object);
    return person ? { id: person._id, name: person.name, licenseExpiryDate: person.licenseExpiryDate } : undefined;
  };
  const [driver, conductor] = await Promise.all([
    load(bus.defaultDriverId, 'DRIVER'),
    load(bus.defaultConductorId, 'CONDUCTOR'),
  ]);
  return { ...(driver ? { driver } : {}), ...(conductor ? { conductor } : {}) };
}

/** The crew fields of a new trip: the bus's usual people (a driver whose licence ends first is left out). */
export function crewFieldsFor(
  crew: { driver?: CrewPerson; conductor?: CrewPerson },
  departureAt: Date,
): Record<string, unknown> {
  const driverFit =
    crew.driver && (!crew.driver.licenseExpiryDate || new Date(crew.driver.licenseExpiryDate) >= departureAt);
  return {
    ...(driverFit && crew.driver ? { driverId: crew.driver.id, driverName: crew.driver.name } : {}),
    ...(crew.conductor ? { conductorId: crew.conductor.id, conductorName: crew.conductor.name } : {}),
  };
}
