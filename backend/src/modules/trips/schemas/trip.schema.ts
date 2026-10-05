import { Schema, type Types } from 'mongoose';
import { type GeoPoint } from '../../cities/schemas/city.schema';
import { BERTH_TYPES, type BerthType } from '../../bus-types/schemas/bus-type.schema';
import { BUS_AMENITIES, type BusAmenity } from '../../buses/schemas/bus.schema';

export const TRIP_MODEL = 'Trip';

/** state-machines.md §5. */
export const TRIP_STATUSES = [
  'DRAFT',
  'SCHEDULED',
  'BOARDING',
  'DEPARTED',
  'IN_TRANSIT',
  'ARRIVED',
  'DELAYED',
  'CANCELLED',
] as const;
export type TripStatus = (typeof TRIP_STATUSES)[number];

/** Trips customers can find and book. */
export const BOOKABLE_TRIP_STATUSES = ['SCHEDULED'] as const satisfies readonly TripStatus[];

/** A boarding or dropping point as it applies to this trip (copied from `locations`). */
export interface TripPoint {
  /** Stable id of the point within the trip; bookings refer to it. */
  pointId: Types.ObjectId;
  locationId?: Types.ObjectId;
  cityId: Types.ObjectId;
  name: string;
  address: string;
  landmark?: string;
  location?: GeoPoint;
  contactPhone?: string;
  instructions?: string;
  /** When the bus is at this point. */
  time: Date;
}

/** The bus as it was when the trip was published. */
export interface TripBusSnapshot {
  name: string;
  registrationNumber: string;
  busTypeKey: string;
  busTypeName: string;
  isAc: boolean;
  berthType: BerthType;
  amenities: BusAmenity[];
}

/** Seat totals, maintained by the seat inventory module together with every seat change. */
export interface TripSeatCounts {
  total: number;
  available: number;
  locked: number;
  booked: number;
  blocked: number;
}

/**
 * One departure of one bus on one date: the unit customers search and book.
 *
 * The trip carries copies of what customers see (bus, points, lowest fare) taken when it was
 * published, so search is one indexed query and later edits to a bus or a location cannot change
 * a trip that is already on sale. Seat-level inventory, fares per seat and the cancellation
 * policy belong to their own modules and attach to the trip by id.
 */
export interface Trip {
  operatorId: Types.ObjectId;
  scheduleId?: Types.ObjectId;
  routeId: Types.ObjectId;
  busId: Types.ObjectId;
  seatLayoutVersionId?: Types.ObjectId;
  /** Date of departure in the trip's timezone, `YYYY-MM-DD`. */
  travelDate: string;
  /** IANA timezone the travel date and local times are in. */
  timezone: string;
  departureAt: Date;
  arrivalAt: Date;
  /** Minutes after local midnight of the departure (0-1439); used for time-of-day filters. */
  departureMinuteOfDay: number;
  durationMinutes: number;
  originCityId: Types.ObjectId;
  destinationCityId: Types.ObjectId;
  stopCityIds: Types.ObjectId[];
  boardingPoints: TripPoint[];
  droppingPoints: TripPoint[];
  bus: TripBusSnapshot;
  /** Lowest fare of any seat on this trip, in paise. The fare module owns the full price list. */
  startingFarePaise: number;
  currency: 'INR';
  fareRuleSetVersionId?: Types.ObjectId;
  cancellationPolicyId?: Types.ObjectId;
  status: TripStatus;
  publishedAt?: Date;
  seatCounts: TripSeatCounts;
  createdAt?: Date;
  updatedAt?: Date;
}

const geoPoint = {
  type: { type: String, enum: ['Point'] },
  coordinates: { type: [Number], default: undefined },
};

const tripPointSchema = new Schema<TripPoint>(
  {
    pointId: { type: Schema.Types.ObjectId, required: true },
    locationId: { type: Schema.Types.ObjectId },
    cityId: { type: Schema.Types.ObjectId, required: true },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    address: { type: String, required: true, trim: true, maxlength: 300 },
    landmark: { type: String, trim: true, maxlength: 160 },
    location: geoPoint,
    contactPhone: { type: String, maxlength: 20 },
    instructions: { type: String, trim: true, maxlength: 300 },
    time: { type: Date, required: true },
  },
  { _id: false },
);

const nonNegativeInteger = { type: Number, required: true, min: 0, default: 0 };

/** `trips` (database-architecture.md §1). */
export const tripSchema = new Schema<Trip>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    scheduleId: { type: Schema.Types.ObjectId },
    routeId: { type: Schema.Types.ObjectId, required: true },
    busId: { type: Schema.Types.ObjectId, required: true },
    seatLayoutVersionId: { type: Schema.Types.ObjectId },
    travelDate: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
    timezone: { type: String, required: true, default: 'Asia/Kolkata' },
    departureAt: { type: Date, required: true },
    arrivalAt: { type: Date, required: true },
    departureMinuteOfDay: { type: Number, required: true, min: 0, max: 1439 },
    durationMinutes: { type: Number, required: true, min: 1 },
    originCityId: { type: Schema.Types.ObjectId, required: true },
    destinationCityId: { type: Schema.Types.ObjectId, required: true },
    stopCityIds: { type: [Schema.Types.ObjectId], default: [] },
    boardingPoints: { type: [tripPointSchema], default: [] },
    droppingPoints: { type: [tripPointSchema], default: [] },
    bus: {
      type: new Schema<TripBusSnapshot>(
        {
          name: { type: String, required: true, maxlength: 80 },
          registrationNumber: { type: String, required: true, maxlength: 20 },
          busTypeKey: { type: String, required: true, maxlength: 40 },
          busTypeName: { type: String, required: true, maxlength: 60 },
          isAc: { type: Boolean, required: true },
          berthType: { type: String, enum: BERTH_TYPES, required: true },
          amenities: { type: [String], enum: BUS_AMENITIES, default: [] },
        },
        { _id: false },
      ),
      required: true,
    },
    startingFarePaise: { type: Number, required: true, min: 0, validate: Number.isInteger },
    currency: { type: String, enum: ['INR'], required: true, default: 'INR' },
    fareRuleSetVersionId: { type: Schema.Types.ObjectId },
    cancellationPolicyId: { type: Schema.Types.ObjectId },
    status: { type: String, enum: TRIP_STATUSES, required: true, default: 'DRAFT' },
    publishedAt: { type: Date },
    seatCounts: {
      type: new Schema<TripSeatCounts>(
        {
          total: nonNegativeInteger,
          available: nonNegativeInteger,
          locked: nonNegativeInteger,
          booked: nonNegativeInteger,
          blocked: nonNegativeInteger,
        },
        { _id: false },
      ),
      required: true,
      default: () => ({}),
    },
  },
  { collection: 'trips', timestamps: true, versionKey: false },
);

// Customer search: one city pair on one date, bookable trips only
tripSchema.index({
  originCityId: 1,
  destinationCityId: 1,
  travelDate: 1,
  status: 1,
  departureAt: 1,
});
tripSchema.index({ operatorId: 1, travelDate: 1 });
tripSchema.index({ busId: 1, departureAt: 1 });
