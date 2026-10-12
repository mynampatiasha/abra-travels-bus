import { Schema } from 'mongoose';
import { softDeletePlugin } from '../../../database/soft-delete.plugin';

export const BUS_TYPE_MODEL = 'BusType';

export const BERTH_TYPES = ['SEATER', 'SLEEPER', 'SEMI_SLEEPER', 'MIXED'] as const;
export type BerthType = (typeof BERTH_TYPES)[number];

/** A kind of bus customers filter by, e.g. `AC_SLEEPER`. Platform catalogue. */
export interface BusType {
  /** Stable key, upper snake case. Apps translate it; `name` is the English label. */
  key: string;
  name: string;
  isAc: boolean;
  berthType: BerthType;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `bus_types` (database-architecture.md §1). */
export const busTypeSchema = new Schema<BusType>(
  {
    key: { type: String, required: true, match: /^[A-Z][A-Z0-9_]*$/, maxlength: 40 },
    name: { type: String, required: true, trim: true, maxlength: 60 },
    isAc: { type: Boolean, required: true },
    berthType: { type: String, enum: BERTH_TYPES, required: true },
    isActive: { type: Boolean, required: true, default: true },
  },
  { collection: 'bus_types', timestamps: true, versionKey: false },
);

busTypeSchema.plugin(softDeletePlugin);
busTypeSchema.index({ key: 1 }, { unique: true });
