import { type CityView } from '../../cities/services/cities.service';
import { type DepartureWindow } from '../dto/trip-search.dto';
import { type CatalogueTrip } from '../repositories/trip-catalogue.repository';
import { type TripPoint } from '../schemas/trip.schema';

export interface PlaceView {
  id: string;
  name: string;
}

export interface TripPointSummaryView {
  id: string;
  name: string;
  /** ISO 8601 instant the bus is at the point. */
  time: string;
}

export interface TripPointView extends TripPointSummaryView {
  city: PlaceView;
  address: string;
  landmark: string | null;
  instructions: string | null;
  contactPhone: string | null;
  location: { latitude: number; longitude: number } | null;
}

/** One search result. Everything in it is safe to show to anyone. */
export interface TripSummaryView {
  id: string;
  operator: PlaceView;
  bus: {
    name: string;
    typeKey: string;
    typeName: string;
    isAc: boolean;
    berthType: string;
    amenities: string[];
  };
  origin: PlaceView;
  destination: PlaceView;
  travelDate: string;
  timezone: string;
  departureAt: string;
  arrivalAt: string;
  durationMinutes: number;
  /** Lowest fare of any seat. The amount to pay is always calculated by the backend at booking. */
  fare: { startingPaise: number; currency: string };
  seats: { total: number; available: number; isSoldOut: boolean };
  boardingPoints: TripPointSummaryView[];
  droppingPoints: TripPointSummaryView[];
}

/** `GET /trips/:tripId`. */
export interface TripDetailView extends Omit<
  TripSummaryView,
  'bus' | 'boardingPoints' | 'droppingPoints'
> {
  status: string;
  bus: TripSummaryView['bus'] & { registrationNumber: string };
  /** Cities the bus passes through between origin and destination, in order. */
  stops: PlaceView[];
  boardingPoints: TripPointView[];
  droppingPoints: TripPointView[];
}

export interface TripSearchFiltersView {
  total: number;
  busTypes: { key: string; name: string; isAc: boolean; berthType: string; count: number }[];
  operators: { id: string; name: string; count: number }[];
  amenities: { key: string; count: number }[];
  departureWindows: { key: DepartureWindow; fromMinute: number; toMinute: number; count: number }[];
  fare: { minPaise: number; maxPaise: number; currency: string } | null;
}

export type CityNames = ReadonlyMap<string, CityView>;

export function operatorName(operator: CatalogueTrip['operator']): string {
  return operator.displayName || operator.companyName;
}

function placeOf(cities: CityNames, id: { toHexString(): string }): PlaceView {
  const key = id.toHexString();
  return { id: key, name: cities.get(key)?.name ?? '' };
}

function pointSummary(point: TripPoint): TripPointSummaryView {
  return { id: point.pointId.toHexString(), name: point.name, time: point.time.toISOString() };
}

function pointDetail(point: TripPoint, cities: CityNames): TripPointView {
  const coordinates = point.location?.coordinates;
  return {
    ...pointSummary(point),
    city: placeOf(cities, point.cityId),
    address: point.address,
    landmark: point.landmark ?? null,
    instructions: point.instructions ?? null,
    contactPhone: point.contactPhone ?? null,
    location:
      coordinates?.length === 2 ? { latitude: coordinates[1], longitude: coordinates[0] } : null,
  };
}

const byTime = (a: TripPoint, b: TripPoint) => a.time.getTime() - b.time.getTime();

export function tripSummaryOf(trip: CatalogueTrip, cities: CityNames): TripSummaryView {
  return {
    id: trip._id.toHexString(),
    operator: { id: trip.operator._id.toHexString(), name: operatorName(trip.operator) },
    bus: {
      name: trip.bus.name,
      typeKey: trip.bus.busTypeKey,
      typeName: trip.bus.busTypeName,
      isAc: trip.bus.isAc,
      berthType: trip.bus.berthType,
      amenities: [...trip.bus.amenities],
    },
    origin: placeOf(cities, trip.originCityId),
    destination: placeOf(cities, trip.destinationCityId),
    travelDate: trip.travelDate,
    timezone: trip.timezone,
    departureAt: trip.departureAt.toISOString(),
    arrivalAt: trip.arrivalAt.toISOString(),
    durationMinutes: trip.durationMinutes,
    fare: { startingPaise: trip.startingFarePaise, currency: trip.currency },
    seats: {
      total: trip.seatCounts.total,
      available: trip.seatCounts.available,
      isSoldOut: trip.seatCounts.available <= 0,
    },
    boardingPoints: [...trip.boardingPoints].sort(byTime).map(pointSummary),
    droppingPoints: [...trip.droppingPoints].sort(byTime).map(pointSummary),
  };
}

export function tripDetailOf(trip: CatalogueTrip, cities: CityNames): TripDetailView {
  const summary = tripSummaryOf(trip, cities);
  return {
    ...summary,
    status: trip.status,
    bus: { ...summary.bus, registrationNumber: trip.bus.registrationNumber },
    stops: trip.stopCityIds.map((cityId) => placeOf(cities, cityId)),
    boardingPoints: [...trip.boardingPoints].sort(byTime).map((p) => pointDetail(p, cities)),
    droppingPoints: [...trip.droppingPoints].sort(byTime).map((p) => pointDetail(p, cities)),
  };
}
