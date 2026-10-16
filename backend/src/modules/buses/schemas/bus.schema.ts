import { Schema, type Types } from 'mongoose';
import { softDeletePlugin } from '../../../database/soft-delete.plugin';

export const BUS_MODEL = 'Bus';

/**
 * The amenities buses could have before the list became managed (`amenities` module, which starts
 * with these). Kept for the tests and for reference: a bus now refers to any key staff have added.
 */
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
/** The key of an amenity (`CHARGING_POINT`). Staff add amenities; see the `amenities` module. */
export type BusAmenity = string;

/**
 * PENDING_APPROVAL: added by a bus owner and not yet approved by platform staff (client
 * onboarding). It becomes ACTIVE only when its documents are approved. A bus can only have trips
 * published once it is ACTIVE.
 */
export const BUS_STATUSES = ['PENDING_APPROVAL', 'ACTIVE', 'MAINTENANCE', 'RETIRED'] as const;
export type BusStatus = (typeof BUS_STATUSES)[number];

/** What a person can change a bus to by hand; PENDING_APPROVAL only comes from creation. */
export const MANUAL_BUS_STATUSES = ['ACTIVE', 'MAINTENANCE', 'RETIRED'] as const;

/** A vehicle of an operator. Tenant-owned: managed through the operator's data scope. */
export interface Bus {
  operatorId: Types.ObjectId;
  registrationNumber: string;
  /** Name customers see, e.g. "Abra Express Volvo". */
  name: string;
  busTypeId: Types.ObjectId;
  amenities: BusAmenity[];
  /**
   * Number of seats and berths sold on this bus. Catalogue information until seat layouts exist;
   * then the active seat layout version is the authority.
   */
  seatCapacity?: number;
  /** Seat layout version used for new trips (seat inventory module). */
  activeSeatLayoutVersionId?: Types.ObjectId;
  insuranceExpiryDate?: Date;
  seatLayoutType?: string;
  statusReason?: string;
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
    amenities: { type: [String], match: /^[A-Z][A-Z0-9_]{1,39}$/, default: [] },
    seatCapacity: { type: Number, min: 1, max: 100, validate: Number.isInteger },
    activeSeatLayoutVersionId: { type: Schema.Types.ObjectId },
    insuranceExpiryDate: { type: Date },
    seatLayoutType: { type: String, trim: true, maxlength: 40, default: '2+2 Seater' },
    statusReason: { type: String, trim: true, maxlength: 500 },
    status: { type: String, enum: BUS_STATUSES, required: true, default: 'ACTIVE' },
  },
  { collection: 'buses', timestamps: true, versionKey: false },
);

busSchema.plugin(softDeletePlugin);
busSchema.index({ registrationNumber: 1 }, { unique: true });
busSchema.index({ operatorId: 1, status: 1 });
