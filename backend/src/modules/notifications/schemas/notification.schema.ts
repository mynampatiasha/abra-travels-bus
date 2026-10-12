import { Schema, type Types } from 'mongoose';

export const NOTIFICATION_MODEL = 'Notification';
export const PUSH_TOKEN_MODEL = 'PushToken';

export const DELIVERY_CHANNELS = ['REALTIME', 'PUSH', 'EMAIL', 'WHATSAPP'] as const;
export type DeliveryChannel = (typeof DELIVERY_CHANNELS)[number];

/** SENT: the provider accepted it. SKIPPED: nothing to send to (no device, no template). FAILED: will be retried. */
export type DeliveryStatus = 'SENT' | 'SKIPPED' | 'FAILED';

export interface NotificationDelivery {
  channel: DeliveryChannel;
  status: DeliveryStatus;
  /** Why it was skipped or failed. Never message content or credentials. */
  detail?: string;
  at: Date;
}

/**
 * A message for one person. The in-app list is the record: realtime, push, email and WhatsApp are
 * only ways of telling the person it exists, so a failed channel never loses the notification.
 */
export interface Notification {
  userId: Types.ObjectId;
  /** The domain event it came from; with `userId` it makes delivery safe to repeat. */
  eventId: string;
  type: string;
  title: string;
  body: string;
  /** Small string values for the app to open the right screen. Never secrets. */
  data: Record<string, string>;
  readAt?: Date | null;
  deliveries: NotificationDelivery[];
  createdAt?: Date;
  updatedAt?: Date;
}

const deliverySchema = new Schema<NotificationDelivery>(
  {
    channel: { type: String, enum: DELIVERY_CHANNELS, required: true },
    status: { type: String, enum: ['SENT', 'SKIPPED', 'FAILED'], required: true },
    detail: { type: String, maxlength: 300 },
    at: { type: Date, required: true },
  },
  { _id: false },
);

/** `notifications`. */
export const notificationSchema = new Schema<Notification>(
  {
    userId: { type: Schema.Types.ObjectId, required: true },
    eventId: { type: String, required: true },
    type: { type: String, required: true, maxlength: 80 },
    title: { type: String, required: true, maxlength: 160 },
    body: { type: String, required: true, maxlength: 1000 },
    data: { type: Schema.Types.Mixed, default: {} },
    readAt: { type: Date, default: null },
    deliveries: { type: [deliverySchema], default: [] },
  },
  { collection: 'notifications', timestamps: true, versionKey: false, minimize: false },
);

notificationSchema.index({ userId: 1, eventId: 1 }, { unique: true });
notificationSchema.index({ userId: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, readAt: 1 });

export const PUSH_PLATFORMS = ['WEB', 'ANDROID', 'IOS'] as const;
export type PushPlatform = (typeof PUSH_PLATFORMS)[number];

/** A browser or phone a person allowed push notifications on. */
export interface PushToken {
  userId: Types.ObjectId;
  token: string;
  platform: PushPlatform;
  lastSeenAt: Date;
  createdAt?: Date;
}

/** `push_tokens`. A token belongs to one person: signing in as someone else moves it. */
export const pushTokenSchema = new Schema<PushToken>(
  {
    userId: { type: Schema.Types.ObjectId, required: true },
    token: { type: String, required: true, maxlength: 4096 },
    platform: { type: String, enum: PUSH_PLATFORMS, required: true },
    lastSeenAt: { type: Date, required: true },
  },
  {
    collection: 'push_tokens',
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false,
  },
);

pushTokenSchema.index({ token: 1 }, { unique: true });
pushTokenSchema.index({ userId: 1 });
