/*
 * What a customer wants to be told, and where. Three kinds of message, three channels. The
 * in-app list always shows everything, and safety alerts (SOS, trip sharing) are never in these
 * settings: they cannot be turned off. The event router reads these before it sends.
 */

export const NOTIFICATION_TOPICS = ['bookings', 'trips', 'offers'] as const;
export type NotificationTopic = (typeof NOTIFICATION_TOPICS)[number];

export const NOTIFICATION_CHANNELS = ['whatsapp', 'email', 'push'] as const;
export type NotificationChannel = (typeof NOTIFICATION_CHANNELS)[number];

export type ChannelChoices = Record<NotificationChannel, boolean>;
export type NotificationSettings = Record<NotificationTopic, ChannelChoices>;

/** Booking and trip messages are on until the customer turns them off; offers are off until asked for. */
export function defaultNotificationSettings(): NotificationSettings {
  const on: ChannelChoices = { whatsapp: true, email: true, push: true };
  const off: ChannelChoices = { whatsapp: false, email: false, push: false };
  return { bookings: { ...on }, trips: { ...on }, offers: { ...off } };
}

/** Fills what is missing (a customer who never opened the screen) with the defaults. */
export function settingsFrom(stored: unknown): NotificationSettings {
  const result = defaultNotificationSettings();
  if (!stored || typeof stored !== 'object') return result;
  for (const topic of NOTIFICATION_TOPICS) {
    const choices = (stored as Record<string, unknown>)[topic];
    if (!choices || typeof choices !== 'object') continue;
    for (const channel of NOTIFICATION_CHANNELS) {
      const value = (choices as Record<string, unknown>)[channel];
      if (typeof value === 'boolean') result[topic][channel] = value;
    }
  }
  return result;
}

/** The topic of a message kind (messages log). */
export function topicOfMessageKind(kind: string): NotificationTopic | null {
  switch (kind) {
    case 'BOOKING_CONFIRMED':
    case 'BOOKING_CANCELLED':
    case 'PAYMENT_FAILED':
    case 'REFUND_PAID':
      return 'bookings';
    case 'TRIP_DELAYED':
    case 'BOARDING_STARTED':
      return 'trips';
    default:
      // Service announcements and general messages are not the customer's choice
      return null;
  }
}

/**
 * The topic of a domain event (`booking.confirmed`), or null when the customer has no say: a
 * message about safety, sign-in or the account itself is always sent.
 */
export function topicOfEvent(eventType: string): NotificationTopic | null {
  const area = eventType.split('.')[0];
  switch (area) {
    case 'booking':
    case 'payment':
    case 'refund':
    case 'ticket':
      return 'bookings';
    case 'trip':
      return 'trips';
    case 'offer':
    case 'announcement':
      return 'offers';
    default:
      return null;
  }
}

export function isOn(
  settings: NotificationSettings,
  topic: NotificationTopic,
  channel: NotificationChannel,
): boolean {
  return settings[topic][channel];
}
