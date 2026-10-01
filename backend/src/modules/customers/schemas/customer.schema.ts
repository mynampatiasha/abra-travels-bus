import { Schema, type Types } from 'mongoose';

export const CUSTOMER_MODEL = 'Customer';

export interface NotificationPreferences {
  email: boolean;
  sms: boolean;
  whatsapp: boolean;
  push: boolean;
  /** Promotional messages; transactional messages are not affected by this. */
  marketing: boolean;
}

export interface Customer {
  userId: Types.ObjectId;
  notificationPreferences: NotificationPreferences;
  /** Marketing consent as given at sign-up; `at` records when it was last changed. */
  marketingConsent: { granted: boolean; at: Date };
  createdAt?: Date;
  updatedAt?: Date;
}

/**
 * `customers` (database-architecture.md §1): the customer profile that belongs to a user of type
 * CUSTOMER. Emergency contacts and safety preferences are added with their features.
 */
export const customerSchema = new Schema<Customer>(
  {
    userId: { type: Schema.Types.ObjectId, required: true },
    notificationPreferences: {
      email: { type: Boolean, default: true },
      sms: { type: Boolean, default: true },
      whatsapp: { type: Boolean, default: true },
      push: { type: Boolean, default: true },
      marketing: { type: Boolean, default: false },
    },
    marketingConsent: {
      granted: { type: Boolean, required: true, default: false },
      at: { type: Date, required: true },
    },
  },
  { collection: 'customers', timestamps: true, versionKey: false },
);

customerSchema.index({ userId: 1 }, { unique: true });
