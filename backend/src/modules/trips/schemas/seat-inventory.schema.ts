import { Schema, type Types } from 'mongoose';

export const SEAT_INVENTORY_MODEL = 'SeatInventory';

export const SEAT_STATUSES = ['AVAILABLE', 'BLOCKED', 'LOCKED', 'BOOKED'] as const;
export type SeatStatus = (typeof SEAT_STATUSES)[number];

export interface SeatInventoryItem {
  _id: Types.ObjectId;
  tripId: Types.ObjectId;
  operatorId: Types.ObjectId;
  seatNumber: string;
  deck: 'LOWER' | 'UPPER';
  seatType: string;
  status: SeatStatus;
  blockReason?: string;
  blockedBy?: {
    userId: Types.ObjectId;
    userType: string;
  };
  blockedAt?: Date;
  pricePaise: number;
  createdAt: Date;
  updatedAt: Date;
}

export const seatInventorySchema = new Schema<SeatInventoryItem>(
  {
    tripId: { type: Schema.Types.ObjectId, required: true, index: true },
    operatorId: { type: Schema.Types.ObjectId, required: true, index: true },
    seatNumber: { type: String, required: true, trim: true },
    deck: { type: String, enum: ['LOWER', 'UPPER'], default: 'LOWER' },
    seatType: { type: String, required: true, trim: true, default: 'SEATER' },
    status: { type: String, enum: SEAT_STATUSES, required: true, default: 'AVAILABLE', index: true },
    blockReason: { type: String, trim: true, maxlength: 300 },
    blockedBy: {
      userId: { type: Schema.Types.ObjectId },
      userType: { type: String },
    },
    blockedAt: { type: Date },
    pricePaise: { type: Number, required: true, min: 0 },
  },
  { collection: 'seat_inventory', timestamps: true, versionKey: false },
);

seatInventorySchema.index({ tripId: 1, seatNumber: 1 }, { unique: true });
seatInventorySchema.index({ tripId: 1, status: 1 });
