import { Schema } from 'mongoose';

export const CITY_MODEL = 'City';

export interface GeoPoint {
  type: 'Point';
  /** [longitude, latitude] */
  coordinates: [number, number];
}

/**
 * A city customers travel between. Platform catalogue: maintained by platform staff, read by
 * everyone, not owned by an operator.
 */
export interface City {
  /** Name in English. */
  name: string;
  /** URL-safe unique key, e.g. `bengaluru`. */
  slug: string;
  state: string;
  /** Names in other languages by language code (`kn`, `hi`, ...). Missing = English name. */
  translations?: Record<string, string>;
  location?: GeoPoint;
  /** Shown as a suggestion before the customer types anything. */
  isPopular: boolean;
  /** Order among popular cities; lower first. */
  sortOrder: number;
  /** False hides the city from selection and search without deleting history. */
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `cities` (database-architecture.md §1). */
export const citySchema = new Schema<City>(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    slug: { type: String, required: true, lowercase: true, match: /^[a-z0-9-]+$/, maxlength: 80 },
    state: { type: String, required: true, trim: true, maxlength: 80 },
    translations: { type: Map, of: String, default: undefined },
    location: {
      type: { type: String, enum: ['Point'] },
      coordinates: { type: [Number], default: undefined },
    },
    isPopular: { type: Boolean, required: true, default: false },
    sortOrder: { type: Number, required: true, default: 0 },
    isActive: { type: Boolean, required: true, default: true },
  },
  { collection: 'cities', timestamps: true, versionKey: false },
);

citySchema.index({ slug: 1 }, { unique: true });
citySchema.index({ isActive: 1, name: 1 });
citySchema.index({ isActive: 1, isPopular: 1, sortOrder: 1 });
