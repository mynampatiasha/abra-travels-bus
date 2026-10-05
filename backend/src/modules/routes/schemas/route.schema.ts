import { Schema, type Types } from 'mongoose';

export const ROUTE_MODEL = 'Route';

export const ROUTE_STATUSES = ['ACTIVE', 'INACTIVE'] as const;
export type RouteStatus = (typeof ROUTE_STATUSES)[number];

/** A city the bus passes through between origin and destination. */
export interface RouteStop {
  cityId: Types.ObjectId;
  /** Position on the route, starting at 1 after the origin. */
  sequence: number;
  /** Minutes after departure from the origin. */
  offsetMinutes: number;
  distanceFromOriginKm?: number;
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
  distanceKm?: number;
  estimatedDurationMinutes: number;
  stops: RouteStop[];
  status: RouteStatus;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `routes`, with its `route_stops` embedded (database-architecture.md §1). */
export const routeSchema = new Schema<Route>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    originCityId: { type: Schema.Types.ObjectId, required: true },
    destinationCityId: { type: Schema.Types.ObjectId, required: true },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    distanceKm: { type: Number, min: 0 },
    estimatedDurationMinutes: { type: Number, required: true, min: 1 },
    stops: {
      type: [
        new Schema<RouteStop>(
          {
            cityId: { type: Schema.Types.ObjectId, required: true },
            sequence: { type: Number, required: true, min: 1 },
            offsetMinutes: { type: Number, required: true, min: 0 },
            distanceFromOriginKm: { type: Number, min: 0 },
          },
          { _id: false },
        ),
      ],
      default: [],
    },
    status: { type: String, enum: ROUTE_STATUSES, required: true, default: 'ACTIVE' },
  },
  { collection: 'routes', timestamps: true, versionKey: false },
);

routeSchema.index({ operatorId: 1 });
routeSchema.index({ originCityId: 1, destinationCityId: 1 });
