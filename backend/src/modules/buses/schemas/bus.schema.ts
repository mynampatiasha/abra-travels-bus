import { Schema, type Types } from 'mongoose';

export const BUS_MODEL = 'Bus';

/** What a bus offers on board. Apps translate the keys; search can filter by them. */
export const BUS_AMENITIES = [
  'WIFI',
  'CHARGING_POINT',
  'BLANKET',
  'PILLOW',
  'WATER_BOTTLE',
  'READING_LIGHT',
  'CCTV',
  'GPS_TRACKING',
  'TOILET',
  'ENTERTAINMENT',
  'SNACKS',
  'EMERGENCY_EXIT',
  'FIRST_AID',
] as const;
export type BusAmenity = (typeof BUS_AMENITIES)[number];

export const BUS_STATUSES = ['ACTIVE', 'MAINTENANCE', 'RETIRED'] as const;
export type BusStatus = (typeof BUS_STATUSES)[number];

/** A vehicle of an operator. Tenant-owned: managed through the operator's data scope. */
export interface Bus {
  operatorId: Types.ObjectId;
  registrationNumber: string;
  /** Name customers see, e.g. "Abra Express Volvo". */
  name: string;
  busTypeId: Types.ObjectId;
  amenities: BusAmenity[];
  /** Seat layout version used for new trips (seat inventory module). */
  activeSeatLayoutVersionId?: Types.ObjectId;
  status: BusStatus;
  createdAt?: Date;
  updatedAt?: Date;
}

/** `buses` (database-architecture.md §1). */
export const busSchema = new Schema<Bus>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    registrationNumber: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
      maxlength: 20,
    },
    name: { type: String, required: true, trim: true, maxlength: 80 },
    busTypeId: { type: Schema.Types.ObjectId, required: true },
    amenities: { type: [String], enum: BUS_AMENITIES, default: [] },
    activeSeatLayoutVersionId: { type: Schema.Types.ObjectId },
    status: { type: String, enum: BUS_STATUSES, required: true, default: 'ACTIVE' },
  },
  { collection: 'buses', timestamps: true, versionKey: false },
);

busSchema.index({ registrationNumber: 1 }, { unique: true });
busSchema.index({ operatorId: 1, status: 1 });
