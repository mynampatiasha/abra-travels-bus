/*
 * The customer message templates: every WhatsApp message, SMS and email Abra sends to a customer
 * about login, bookings, payments, trips, support and safety
 * (documentation/customer-message-templates.md, which is the source of the words).
 *
 * One text per template, written with `{field}` placeholders filled from the event payload. The
 * same text is the email body, the copy kept in the messages log, and the WhatsApp message. For
 * Meta and DLT the placeholders become `{{1}}, {{2}}` and `{#var#}` in the order they appear
 * (`metaTemplateBody`, `dltTemplateBody`), so the text submitted for approval and the parameters
 * sent always line up.
 *
 * The words are English; per-language versions are added later (multilingual.md).
 */

import { type MessageKind } from '../messages/messages_admin_manage.service';

// ===== 1. TYPES =====

export interface CustomerMessageTemplate {
  /** Also the Meta template name and the DLT template key, so it stays lowercase with `_`. */
  key: string;
  kind: MessageKind;
  /** The Meta category the WhatsApp template is submitted under. */
  category: 'AUTHENTICATION' | 'UTILITY';
  /** Email subject, and the title of the log copy. */
  subject: string;
  /** The full message: WhatsApp body, email body and log copy. Absent for SMS-only templates. */
  text?: string;
  /** The short SMS version (DLT). Absent when the template is never sent by SMS. */
  sms?: string;
  /** The payload field that fills the first WhatsApp URL button (`https://.../{{1}}`). */
  buttonField?: string;
}

// ===== 2. THE TEMPLATES =====

const SIGN_OFF = '– Team Abra Travels';

export const CUSTOMER_MESSAGE_TEMPLATES = [
  // ----- login (sent by otp-delivery, listed here so every template is in one place) -----
  {
    key: 'login_otp',
    kind: 'GENERAL',
    category: 'AUTHENTICATION',
    subject: 'Your Abra Travels code',
    text: '{code} is your Abra Travels verification code. Do not share it with anyone.',
    sms: '{code} is your Abra Travels login code. Valid for 5 minutes. Do not share it. -ABRA',
    buttonField: 'code',
  },

  // ----- booking and payment -----
  {
    key: 'booking_confirmed',
    kind: 'BOOKING_CONFIRMED',
    category: 'UTILITY',
    subject: 'Booking confirmed: {pnr}',
    text: [
      'Hi {contactName} 👋, great news! Your bus ticket is confirmed ✅',
      '',
      '🎫 PNR: {pnr}',
      '🚌 Route: {route}',
      '🕒 Departure: {departureText}',
      '💺 Seats: {seatsText}',
      '📍 Boarding: {boardingPoint}',
      '💳 Amount paid: {amountText}',
      '',
      'Please reach your boarding point 15 minutes early. Wishing you a safe and comfortable journey!',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Booking confirmed. PNR {pnr}, {route}, {departureText}, Seats {seatsText}. Ticket: {ticketUrl} -ABRA',
    buttonField: 'bookingId',
  },
  {
    key: 'payment_failed',
    kind: 'PAYMENT_FAILED',
    category: 'UTILITY',
    subject: 'Payment failed: please try again',
    text: [
      "Hi {contactName}, we couldn't complete your payment of {amountText} for {route}.",
      'Reason: {reason}',
      '',
      "Don't worry, your seats are held for the next {holdMinutes} minutes. Tap below to try again.",
      'If any amount was deducted, it will be refunded automatically within 5-7 working days.',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Payment of {amountText} failed. Seats held for {holdMinutes} min. Retry: {retryUrl} -ABRA',
    buttonField: 'bookingId',
  },
  {
    key: 'booking_cancelled',
    kind: 'BOOKING_CANCELLED',
    category: 'UTILITY',
    subject: 'Booking cancelled: {pnr}',
    text: [
      'Hi {contactName}, your booking {pnr} for {route} ({departureText}) has been cancelled as requested.',
      '',
      '💰 Refund amount: {refundAmountText}',
      'Your refund is on its way and will reach your original payment method in 5-7 working days.',
      '',
      'We hope to see you on board again soon!',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: PNR {pnr} cancelled. Refund {refundAmountText} in 5-7 working days. -ABRA',
    buttonField: 'bookingId',
  },
  {
    key: 'refund_processed',
    kind: 'REFUND_PAID',
    category: 'UTILITY',
    subject: 'Refund processed: {pnr}',
    text: [
      'Hi {contactName}, good news! 🎉 Your refund of {amountText} for PNR {pnr} has been processed.',
      'Reference no: {reference}',
      '',
      'It may take 1-3 working days to reflect in your account, depending on your bank.',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Refund {amountText} for PNR {pnr} processed. Ref {reference} -ABRA',
  },

  // ----- before the trip -----
  {
    key: 'travel_reminder_24h',
    kind: 'TRAVEL_REMINDER',
    category: 'UTILITY',
    subject: 'Your trip is tomorrow: {pnr}',
    text: [
      'Hi {contactName} 👋, just a friendly reminder: your trip is tomorrow!',
      '',
      '🚌 {route}',
      '🕒 Departure: {departureTime}',
      '🎫 PNR: {pnr}',
      '💺 Seats: {seatsText}',
      '📍 Boarding point: {boardingPoint}',
      '',
      'Please carry a valid photo ID. See you on board!',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Your bus {route} leaves tomorrow {departureTime}. PNR {pnr}. Boarding: {boardingPoint} -ABRA',
    buttonField: 'bookingId',
  },
  {
    key: 'travel_reminder_2h',
    kind: 'TRAVEL_REMINDER',
    category: 'UTILITY',
    subject: 'Your bus leaves in 2 hours: {pnr}',
    text: [
      'Hi {contactName}, your bus leaves in 2 hours, at {departureTime} 🕒',
      '',
      '🚌 Bus no: {busRegistration}',
      '👤 Driver: {driverName} ({driverPhone})',
      '📍 Boarding point: {boardingPoint}',
      '',
      'Please plan to reach 15 minutes early. Have a pleasant journey!',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Bus {busRegistration} leaves at {departureTime}. Driver {driverName} {driverPhone}. Boarding {boardingPoint} -ABRA',
    buttonField: 'tripId',
  },

  // ----- trip day -----
  {
    key: 'boarding_started',
    kind: 'BOARDING_STARTED',
    category: 'UTILITY',
    subject: 'Boarding now: {pnr}',
    text: [
      'Hi {contactName}, boarding has started! 🚌',
      'PNR {pnr}: bus {busRegistration} is now at {boardingPoint}.',
      '💺 Seats: {seatsText}',
      '',
      'Please make your way to the bus now. Enjoy your trip!',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Boarding started. Bus {busRegistration} at {boardingPoint}. PNR {pnr} -ABRA',
    buttonField: 'tripId',
  },
  {
    key: 'bus_delayed',
    kind: 'TRIP_DELAYED',
    category: 'UTILITY',
    subject: 'Bus delayed: {pnr}',
    text: [
      "Hi {contactName}, we're sorry, your bus on {route} (PNR {pnr}) is running about {minutes} minutes late.",
      'Reason: {reason}',
      '🕒 New expected time: {newDepartureTime}',
      '',
      'You can track your bus live below. Thank you for your patience.',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Bus for PNR {pnr} is {minutes} min late. New time {newDepartureTime} -ABRA',
    buttonField: 'tripId',
  },
  {
    key: 'trip_cancelled',
    kind: 'TRIP_CANCELLED',
    category: 'UTILITY',
    subject: 'Trip cancelled: {pnr}',
    text: [
      "Hi {contactName}, we're very sorry. Your trip {route} on {departureText} (PNR {pnr}) has been cancelled by the operator.",
      '',
      '💰 A full refund of {amountText} has been started and will reach you in 5-7 working days.',
      '',
      "We'd be glad to help you find another bus. Tap below to book again or contact our support team.",
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Trip PNR {pnr} on {departureText} cancelled by operator. Full refund {amountText} started -ABRA',
  },
  {
    key: 'bus_changed',
    kind: 'BUS_CHANGED',
    category: 'UTILITY',
    subject: 'Bus changed for your trip: {pnr}',
    text: [
      'Hi {contactName}, a quick update on your trip (PNR {pnr}): your bus has changed.',
      '',
      '🚌 New bus: {busRegistration} ({busTypeLabel})',
      '💺 Your seats: {seatsText}',
      '🕒 Departure (unchanged): {departureText}',
      '',
      'Everything else stays the same. Have a safe journey!',
      SIGN_OFF,
    ].join('\n'),
    sms: 'Abra Travels: Bus changed for PNR {pnr}. New bus {busRegistration}, seats {seatsText} -ABRA',
    buttonField: 'bookingId',
  },
  {
    key: 'trip_completed_feedback',
    kind: 'TRIP_FEEDBACK',
    category: 'UTILITY',
    subject: 'How was your trip?',
    text: [
      'Welcome to your destination, {contactName}! 🙏',
      "Thank you for travelling with Abra Travels on {route}. We'd love to hear how your trip went. It takes just one tap.",
    ].join('\n'),
    buttonField: 'bookingId',
  },

  // ----- support and safety -----
  {
    key: 'support_replied',
    kind: 'SUPPORT_REPLIED',
    category: 'UTILITY',
    subject: 'Reply to your ticket {ticketRef}',
    text: [
      'Hi {contactName}, our support team has replied to your ticket {ticketRef}:',
      '"{subject}"',
      '',
      "Tap below to read the full reply. We're here to help!",
      SIGN_OFF,
    ].join('\n'),
    buttonField: 'ticketId',
  },
  {
    key: 'sos_acknowledged',
    kind: 'SOS_ALERT',
    category: 'UTILITY',
    subject: 'We have your SOS alert',
    text: [
      'We have received your SOS alert. Our safety team is calling you right now. Please stay calm and keep your phone close.',
      'If you are in immediate danger, call 112.',
      '– Abra Travels Safety Team',
    ].join('\n'),
    sms: 'Abra Travels: We received your SOS. Our safety team is calling you now. In danger? Call 112. -ABRA',
  },
  {
    key: 'sos_emergency_contact',
    kind: 'SOS_ALERT',
    category: 'UTILITY',
    subject: 'SOS alert from {customerName}',
    // Sent to the customer's saved emergency contact, who has no Abra account: calm, no emojis
    text: [
      'Urgent: {customerName} has raised an SOS alert on their Abra Travels bus.',
      'Bus: {busRegistration}',
      'Route: {route}',
      'Live location: {trackingUrl}',
      '',
      'Our safety team is responding now. If you cannot reach them, call 112.',
      '– Abra Travels Safety Team',
    ].join('\n'),
    sms: 'ALERT: {customerName} raised an SOS on bus {busRegistration} ({route}). Live location: {trackingUrl}. Abra safety team is on it. -ABRA',
  },
  {
    key: 'trip_share',
    kind: 'TRIP_SHARED',
    category: 'UTILITY',
    subject: '{customerName} shared a bus trip with you',
    text: [
      'Hi! {customerName} is sharing their live bus trip with you 🚌',
      'Route: {route}',
      'Bus: {busRegistration}',
      'Follow the journey live here: {trackingUrl}',
    ].join('\n'),
    sms: 'Abra Travels: {customerName} is sharing their bus trip {route}, bus {busRegistration}. Track: {trackingUrl} -ABRA',
  },
] as const satisfies readonly CustomerMessageTemplate[];

export type CustomerTemplateKey = (typeof CUSTOMER_MESSAGE_TEMPLATES)[number]['key'];

const BY_KEY = new Map<string, CustomerMessageTemplate>(
  CUSTOMER_MESSAGE_TEMPLATES.map((template) => [template.key, template]),
);

export function customerTemplate(key: CustomerTemplateKey): CustomerMessageTemplate {
  const template = BY_KEY.get(key);
  if (!template) throw new Error(`No customer message template "${key}"`);
  return template;
}

// ===== 3. FILLING IN =====

const PLACEHOLDER = /\{([A-Za-z][A-Za-z0-9]*)\}/g;

const valueOf = (value: unknown): string =>
  typeof value === 'string' ? value.trim() : typeof value === 'number' ? String(value) : '';

/** The payload fields a text needs, in the order they first appear. */
export function fieldsOf(text: string): string[] {
  const fields: string[] = [];
  for (const [, field] of text.matchAll(PLACEHOLDER)) {
    if (field && !fields.includes(field)) fields.push(field);
  }
  return fields;
}

/** The text with every `{field}` filled from the payload; a missing value becomes `-`. */
export function fillTemplate(text: string, payload: Record<string, unknown>): string {
  return text
    .replace(PLACEHOLDER, (_match, field: string) => valueOf(payload[field]) || '-')
    .replace(/[ \t]+/g, ' ')
    .trim();
}

/** Text for the Meta template submission: `{field}` becomes `{{1}}`, `{{2}}`, ... in order. */
export function metaTemplateBody(text: string): string {
  const fields = fieldsOf(text);
  return text.replace(PLACEHOLDER, (_match, field: string) => `{{${fields.indexOf(field) + 1}}}`);
}

/** Text for the DLT registration: every `{field}` becomes `{#var#}`. */
export function dltTemplateBody(text: string): string {
  return text.replace(PLACEHOLDER, '{#var#}');
}

/** What is sent for one template and one event, on every channel the template has. */
export interface FilledCustomerMessage {
  key: string;
  kind: MessageKind;
  subject: string;
  /** Full text: email body, log copy, and the body of the general WhatsApp template. */
  text: string;
  /** The values of WhatsApp `{{1}}, {{2}}, ...` for the template's own approved version. */
  whatsAppParameters: string[];
  whatsAppButtonParameter?: string;
  /** The SMS text; empty when the template has no SMS version. */
  sms: string;
}

/** WhatsApp template parameters cannot hold line breaks, tabs or long runs of spaces. */
const forParameter = (value: string): string => value.replace(/\s+/g, ' ').trim().slice(0, 900);

export function fillCustomerMessage(
  key: CustomerTemplateKey,
  payload: Record<string, unknown>,
): FilledCustomerMessage {
  const template = customerTemplate(key);
  const text = template.text ?? template.sms ?? '';
  const button = template.buttonField ? valueOf(payload[template.buttonField]) : '';
  return {
    key: template.key,
    kind: template.kind,
    subject: fillTemplate(template.subject, payload).slice(0, 200),
    text: fillTemplate(text, payload),
    whatsAppParameters: fieldsOf(text).map(
      (field) => forParameter(valueOf(payload[field])) || '-',
    ),
    ...(button ? { whatsAppButtonParameter: button } : {}),
    sms: template.sms ? fillTemplate(template.sms, payload) : '',
  };
}
