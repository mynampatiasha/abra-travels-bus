import { Schema, type Types } from 'mongoose';
import { type GeoPoint } from '../../cities/schemas/city.schema';
import { softDeletePlugin } from '../../../database/soft-delete.plugin';

export const LOCATION_MODEL = 'Location';

/**
 * A place in a city where passengers board or get off (a stop, an office, a bus stand). Shared
 * platform locations have no operatorId; an operator's own pick-up offices carry it. A trip
 * copies the locations it uses into its boarding and dropping points when it is published.
 */
export interface Location {
  operatorId?: Types.ObjectId;
  cityId: Types.ObjectId;
  name: string;
  address: string;
  landmark?: string;
  location?: GeoPoint;
  contactPhone?: string;
  /** What the passenger should know, e.g. "Board at platform 4". */
  instructions?: string;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `locations` (database-architecture.md §1). */
export const locationSchema = new Schema<Location>(
  {
    operatorId: { type: Schema.Types.ObjectId },
    cityId: { type: Schema.Types.ObjectId, required: true },
    name: { type: String, required: true, trim: true, maxlength: 120 },
    address: { type: String, required: true, trim: true, maxlength: 300 },
    landmark: { type: String, trim: true, maxlength: 160 },
    location: {
      type: { type: String, enum: ['Point'] },
      coordinates: { type: [Number], default: undefined },
    },
    contactPhone: { type: String, maxlength: 20 },
    instructions: { type: String, trim: true, maxlength: 300 },
    isActive: { type: Boolean, required: true, default: true },
  },
  { collection: 'locations', timestamps: true, versionKey: false },
);

locationSchema.plugin(softDeletePlugin);
locationSchema.index({ cityId: 1, isActive: 1 });
locationSchema.index({ operatorId: 1 }, { sparse: true });
locationSchema.index({ location: '2dsphere' }, { sparse: true });
