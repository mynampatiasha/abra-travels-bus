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
  /** Which kinds of message the customer wants on WhatsApp, email and push (absent = the defaults). */
  notificationSettings?: Record<string, { whatsapp: boolean; email: boolean; push: boolean }> | null;
  /** Set while staff have blocked the account; the reason is kept for staff only. */
  blocked?: { reason: string; at: Date; by: Types.ObjectId } | null;
  /** Staff deleted the account (it can be brought back). */
  deletedAt?: Date | null;
  /** The customer deleted their own account: their personal data was removed for good. */
  anonymisedAt?: Date | null;
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
    notificationSettings: { type: Schema.Types.Mixed, default: null },
    blocked: {
      type: new Schema(
        {
          reason: { type: String, required: true, maxlength: 500 },
          at: { type: Date, required: true },
          by: { type: Schema.Types.ObjectId, required: true },
        },
        { _id: false },
      ),
      default: null,
    },
    deletedAt: { type: Date, default: null },
    anonymisedAt: { type: Date, default: null },
  },
  { collection: 'customers', timestamps: true, versionKey: false },
);

customerSchema.index({ userId: 1 }, { unique: true });
