import { type Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type StoredBusType } from '../../bus-types/repositories/bus-type.repository';
import { type StoredBus } from '../../buses/repositories/bus.repository';
import { type StoredLocation } from '../../locations/repositories/location.repository';
import { type StoredRoute } from '../../routes/repositories/route.repository';
import { type StoredTrip } from '../repositories/trip.repository';
import { type Trip, type TripPoint } from '../schemas/trip.schema';
import { DEFAULT_TRIP_TIMEZONE } from './travel-date';

export interface PlannedPoint {
  locationId: string;
  offsetMinutes: number;
}

/** What an operator decides about a trip. Everything else on the trip is derived from it. */
export interface TripPlan {
  busId: string;
  routeId: string;
  travelDate: string;
  departureTime: string;
  durationMinutes?: number | undefined;
  startingFarePaise: number;
  boardingPoints: PlannedPoint[];
  droppingPoints: PlannedPoint[];
}

export interface TripPlanContext {
  bus: StoredBus;
  busType: StoredBusType;
  route: StoredRoute;
  /** The locations of every planned point, by id. */
  locations: ReadonlyMap<string, StoredLocation>;
  /** Point ids of the trip being rebuilt, by location id, so they stay stable. */
  existingPointIds?: ReadonlyMap<string, Types.ObjectId>;
  newPointId: () => Types.ObjectId;
}

function invalid(message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', message);
}

/** The instant of `time` (HH:mm) on `travelDate` in India (UTC+05:30, no daylight saving). */
export function indiaInstant(travelDate: string, time: string): Date {
  return new Date(`${travelDate}T${time}:00+05:30`);
}

/** The plan a stored trip was built from. */
export function planOf(trip: StoredTrip): TripPlan {
  const offset = (point: TripPoint) =>
    Math.round((point.time.getTime() - trip.departureAt.getTime()) / 60_000);
  const planned = (points: TripPoint[]): PlannedPoint[] =>
    points.map((point) => ({
      locationId: point.locationId?.toHexString() ?? '',
      offsetMinutes: offset(point),
    }));
  const minutes = trip.departureMinuteOfDay;
  return {
    busId: trip.busId.toHexString(),
    routeId: trip.routeId.toHexString(),
    travelDate: trip.travelDate,
    departureTime:
      trip.departureTimeLocal ??
      `${String(Math.floor(minutes / 60)).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`,
    durationMinutes: trip.durationMinutes,
    startingFarePaise: trip.startingFarePaise,
    boardingPoints: planned(trip.boardingPoints),
    droppingPoints: planned(trip.droppingPoints),
  };
}

/**
 * Builds the fields of a trip from its plan and checks that the plan is consistent:
 * bus and route belong to the same operator; boarding points lie in the origin or a stop city and
 * dropping points in a stop city or the destination; times fall inside the journey and every
 * dropping point comes after the first boarding point.
 */
export function tripFieldsOf(plan: TripPlan, context: TripPlanContext): Omit<Trip, 'status'> {
  const { bus, busType, route, locations } = context;
  if (!bus.operatorId.equals(route.operatorId)) {
    throw invalid('The bus and the route belong to different operators.');
  }
  const durationMinutes = plan.durationMinutes ?? route.estimatedDurationMinutes;
  const departureAt = indiaInstant(plan.travelDate, plan.departureTime);
  if (Number.isNaN(departureAt.getTime())) throw invalid('travelDate is not a real date.');
  const [hours, minutes] = plan.departureTime.split(':').map(Number) as [number, number];

  const stopCities = route.stops.map((stop) => stop.cityId.toHexString());
  const boardingCities = new Set([route.originCityId.toHexString(), ...stopCities]);
  const droppingCities = new Set([...stopCities, route.destinationCityId.toHexString()]);

  const build = (
    planned: readonly PlannedPoint[],
    allowedCities: ReadonlySet<string>,
    kind: 'boarding' | 'dropping',
  ): TripPoint[] => {
    if (new Set(planned.map((point) => point.locationId)).size !== planned.length) {
      throw invalid(`A location can be used once as a ${kind} point.`);
    }
    return planned.map((point) => {
      const location = locations.get(point.locationId);
      if (!location) {
        throw invalid(`A ${kind} point is not a location this operator can use.`);
      }
      if (!allowedCities.has(location.cityId.toHexString())) {
        throw invalid(`The ${kind} point "${location.name}" is not in a city of this route.`);
      }
      const withinJourney =
        kind === 'boarding'
          ? point.offsetMinutes < durationMinutes
          : point.offsetMinutes > 0 && point.offsetMinutes <= durationMinutes;
      if (!withinJourney) {
        throw invalid(`The time of the ${kind} point "${location.name}" is outside the journey.`);
      }
      return {
        pointId:
          context.existingPointIds?.get(`${kind}:${point.locationId}`) ?? context.newPointId(),
        locationId: location._id,
        cityId: location.cityId,
        name: location.name,
        address: location.address,
        ...(location.landmark ? { landmark: location.landmark } : {}),
        ...(location.location ? { location: location.location } : {}),
        ...(location.contactPhone ? { contactPhone: location.contactPhone } : {}),
        ...(location.instructions ? { instructions: location.instructions } : {}),
        time: new Date(departureAt.getTime() + point.offsetMinutes * 60_000),
      };
    });
  };

  const boardingPoints = build(plan.boardingPoints, boardingCities, 'boarding');
  const droppingPoints = build(plan.droppingPoints, droppingCities, 'dropping');
  const firstBoarding = Math.min(...plan.boardingPoints.map((point) => point.offsetMinutes));
  if (plan.droppingPoints.some((point) => point.offsetMinutes <= firstBoarding)) {
    throw invalid('Every dropping point must come after the first boarding point.');
  }

  return {
    operatorId: bus.operatorId,
    routeId: route._id,
    busId: bus._id,
    ...(bus.activeSeatLayoutVersionId
      ? { seatLayoutVersionId: bus.activeSeatLayoutVersionId }
      : {}),
    travelDate: plan.travelDate,
    timezone: DEFAULT_TRIP_TIMEZONE,
    departureTimeLocal: plan.departureTime,
    departureAt,
    arrivalAt: new Date(departureAt.getTime() + durationMinutes * 60_000),
    departureMinuteOfDay: hours * 60 + minutes,
    durationMinutes,
    originCityId: route.originCityId,
    destinationCityId: route.destinationCityId,
    stopCityIds: route.stops.map((stop) => stop.cityId),
    boardingPoints,
    droppingPoints,
    bus: {
      name: bus.name,
      registrationNumber: bus.registrationNumber,
      busTypeKey: busType.key,
      busTypeName: busType.name,
      isAc: busType.isAc,
      berthType: busType.berthType,
      amenities: [...bus.amenities],
    },
    startingFarePaise: plan.startingFarePaise,
    currency: 'INR',
    seatCounts: { total: 0, available: 0, locked: 0, booked: 0, blocked: 0 },
  };
}
