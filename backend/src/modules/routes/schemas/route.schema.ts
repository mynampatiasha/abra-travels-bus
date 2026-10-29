import { Schema, type Types } from 'mongoose';

export const ROUTE_MODEL = 'Route';

export const ROUTE_STATUSES = ['ACTIVE', 'INACTIVE'] as const;
export type RouteStatus = (typeof ROUTE_STATUSES)[number];

export const STOP_TYPES = ['BOARDING', 'DROPPING', 'BOTH'] as const;
export type StopType = (typeof STOP_TYPES)[number];

/** A city the bus passes through between origin and destination. */
export interface RouteStop {
  cityId: Types.ObjectId;
  /** Position on the route, starting at 1 after the origin. */
  sequence: number;
  /** Minutes after departure from the origin. */
  offsetMinutes: number;
  distanceFromOriginKm?: number;
  placeId?: string;
  name?: string;
  city?: string;
  offset?: number;
  type?: StopType;
}

/**
 * The path an operator runs between two cities. Tenant-owned. A trip copies origin, destination
 * and stop cities from its route when it is created, so later route edits do not change trips
 * that are already on sale.
 */
export interface Route {
  operatorId: Types.ObjectId;
  originCityId: Types.ObjectId;
  destinationCityId: Types.ObjectId;
  name: string;
  from?: string;
  to?: string;
  km?: number;
  hours?: number;
  distanceKm?: number;
  estimatedDurationMinutes: number;
  stops: RouteStop[];
  status: RouteStatus;
  isDeleted?: boolean;
  deletedAt?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `routes`, with its `route_stops` embedded (database-architecture.md §1). */
export const routeSchema = new Schema<Route>(
  {
    operatorId: { type: Schema.Types.ObjectId, ref: 'operators', default: null, index: true },
    originCityId: { type: Schema.Types.ObjectId },
    destinationCityId: { type: Schema.Types.ObjectId },
    from: { type: String, trim: true },
    to: { type: String, trim: true },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    km: { type: Number, min: 0 },
    hours: { type: Number, min: 0 },
    distanceKm: { type: Number, min: 0 },
    estimatedDurationMinutes: { type: Number, required: true, min: 1, default: 60 },
    stops: {
      type: [
        new Schema<RouteStop>(
          {
            cityId: { type: Schema.Types.ObjectId },
            sequence: { type: Number, default: 1 },
            offsetMinutes: { type: Number, default: 0 },
            distanceFromOriginKm: { type: Number, min: 0 },
            placeId: { type: String },
            name: { type: String, trim: true },
            city: { type: String, trim: true },
            offset: { type: Number, min: 0, default: 0 },
            type: { type: String, enum: STOP_TYPES, default: 'BOTH' },
          },
          { _id: false },
        ),
      ],
      default: [],
    },
    status: { type: String, enum: ROUTE_STATUSES, required: true, default: 'ACTIVE' },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date },
  },
  { collection: 'routes', timestamps: true, versionKey: false },
);

routeSchema.index({ operatorId: 1, isDeleted: 1 });
routeSchema.index({ originCityId: 1, destinationCityId: 1 });
