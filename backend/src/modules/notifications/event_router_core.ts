/* eslint-disable max-lines -- the routing rules are one data table, plan Appendix B */
import { Injectable, Module, type OnModuleInit } from '@nestjs/common';
import { MessagesModule } from '../messages/messages_admin_manage';
import { RbacModule } from '../rbac/rbac.module';
import { RealtimeModule } from '../realtime/live_updates_channel';
import { UsersModule } from '../users/users.module';
import {
  EventRouter,
  type AudienceSpec,
  type EventRule,
  type EventText,
  type MessageRule,
} from './event_router_core.service';
import { NotificationsModule } from './notifications.module';

/*
 * The rules of the event router: plan Appendix B, one rule per event. The feature that owns an
 * event records it in the outbox with the payload named here; nothing else is needed to tell the
 * right people. Customer messages (WhatsApp, SMS, email) take their words from
 * customer_message_templates.ts; the app notices keep theirs here. The words are English; the
 * plan's per-language templates replace them later.
 *
 * Payload fields (ids as text; the texts are written by the feature, because only it knows them):
 *   operatorId, operatorName, tripId, driverId, driverName, customerId, customerIds (list),
 *   bookingId, settlementId, ticketId, reportId, busId, sosId, route ("Hyderabad to Bengaluru"),
 *   departureText ("12 Jan, 10:30 pm"), busRegistration, pnr, seatsText, amountText ("Rs 1,250"),
 *   statusLabel, reason, minutes, contactName, contactPhone, contactEmail.
 *   Customer messages also use: boardingPoint, ticketUrl, retryUrl, holdMinutes, refundAmountText,
 *   reference, departureTime, newDepartureTime, driverPhone, busTypeLabel, reminder ('24H' | '2H'),
 *   ticketRef, subject, customerName, trackingUrl, emergencyContactName, emergencyContactPhone,
 *   sharedWithName, sharedWithPhone (customer_message_templates.ts names each template's fields).
 *
 * Not here on purpose: the onboarding and place-request events, which keep their own handlers
 * (onboarding-notification.handler, PlaceRequestNotificationHandler).
 */

// Who is told: the usual groups
const OWNERS: AudienceSpec = { kind: 'operator-owners' };
const CUSTOMERS: AudienceSpec = { kind: 'users', field: 'customerIds' };
const CUSTOMER: AudienceSpec = { kind: 'user', field: 'customerId' };
const DRIVER: AudienceSpec = { kind: 'user', field: 'driverId' };
const staff = (permission: string): AudienceSpec => ({ kind: 'staff', permission });

const text = (value: unknown): string => (typeof value === 'string' ? value : '');
const raisedByDriver = (payload: Record<string, unknown>) => payload.raisedBy === 'DRIVER';
const isTwoHourReminder = (payload: Record<string, unknown>) => payload.reminder === '2H';

// Customer messages: SMS is sent only when WhatsApp did not reach the person
const ALL_CHANNELS = ['WHATSAPP', 'SMS', 'EMAIL'] as const;
const PHONE_CHANNELS = ['WHATSAPP', 'SMS'] as const;
/** The booking's contact, who may not be the account holder. */
const BOOKING_CONTACT: MessageRule['contact'] = {
  userField: 'customerId',
  nameField: 'contactName',
  phoneField: 'contactPhone',
  emailField: 'contactEmail',
  bookingField: 'bookingId',
};

/** `Trip title` choices that depend on the event's own words. */
const tripLabel: EventText = '{route}, {departureText}';

/** The rules of every event the platform routes today. */
export const CORE_EVENT_RULES: readonly EventRule[] = [
  // ----- operators -----
  {
    event: 'operator.signed-up',
    notices: [
      {
        to: [staff('operators.read')],
        title: 'New operator signed up',
        body: '{companyName} accepted the invitation.',
        goTo: '/operators/{operatorId}',
      },
    ],
  },
  {
    event: 'operator.status-changed',
    notices: [
      {
        to: [OWNERS],
        title: (p) => (p.status === 'SUSPENDED' ? 'Account suspended' : 'Account status changed'),
        body: (p) =>
          p.status === 'SUSPENDED'
            ? 'Your trips are hidden from customers. Contact Abra support.'
            : `Your account is now ${text(p.statusLabel).toLowerCase()}.`,
        goTo: '/dashboard',
      },
    ],
  },
  {
    event: 'bus.maintenance-started',
    notices: [
      {
        to: [OWNERS],
        title: 'Bus marked for maintenance',
        body: '{busRegistration} cannot be used for trips until it returns to service.',
        goTo: '/buses',
      },
    ],
  },

  // ----- settlements -----
  {
    event: 'settlement.status-changed',
    notices: [
      {
        to: [OWNERS],
        title: 'Settlement {statusLabel}',
        body: '{settlementRef} for {cycle}.',
        goTo: '/earnings',
      },
    ],
    live: [
      { type: 'settlement.updated', to: ['operator', 'staff'], data: ['settlementId', 'status'] },
    ],
  },
  {
    event: 'settlement.query-raised',
    notices: [
      {
        to: [staff('settlements.read')],
        title: 'Settlement query',
        body: '{operatorName}: {query}',
        goTo: '/settlements/{settlementId}',
      },
    ],
    live: [
      { type: 'settlement.updated', to: ['operator', 'staff'], data: ['settlementId', 'status'] },
    ],
  },
  {
    event: 'settlement.query-answered',
    notices: [
      {
        to: [OWNERS],
        title: 'Query answered',
        body: 'Abra replied to your query on {settlementRef}.',
        goTo: '/earnings',
      },
    ],
    live: [
      { type: 'settlement.updated', to: ['operator', 'staff'], data: ['settlementId', 'status'] },
    ],
  },

  // ----- trips -----
  {
    event: 'trip.driver-assigned',
    notices: [
      { to: [DRIVER], title: 'New trip assigned', body: tripLabel, goTo: '/trips/{tripId}' },
    ],
  },
  {
    event: 'trip.driver-changed',
    notices: [
      { to: [DRIVER], title: 'New trip assigned', body: tripLabel, goTo: '/trips/{tripId}' },
      {
        to: [OWNERS],
        title: 'Driver changed',
        body: '{driverName} now drives {route}, {departureText}.',
        goTo: '/trips/{tripId}',
      },
    ],
  },
  {
    event: 'trip.cancelled',
    notices: [
      {
        to: [CUSTOMERS],
        title: 'Trip cancelled',
        body: '{route} on {departureText} was cancelled. Your full refund has started.',
        goTo: '/my-trips',
      },
      {
        to: [DRIVER],
        title: 'Trip cancelled',
        body: '{route} on {departureText} was cancelled.',
        goTo: '/trips',
      },
      {
        to: [OWNERS],
        title: 'Trip cancelled',
        body: '{route} on {departureText} was cancelled.',
        goTo: '/trips/{tripId}',
      },
    ],
    live: [
      {
        type: 'trip.status-changed',
        to: [{ topic: 'trip', idField: 'tripId' }, 'staff', 'operator'],
        data: ['tripId', 'status'],
      },
    ],
  },
  {
    event: 'trip.delayed',
    notices: [
      {
        to: [CUSTOMERS],
        title: 'Bus running late',
        body: '{route}: about {minutes} minutes late. {reason}',
        goTo: '/my-trips',
      },
      {
        to: [staff('trips.read')],
        title: 'Trip delayed',
        body: '{route}: {minutes} minutes. {reason}',
        goTo: '/tracking',
      },
      {
        to: [OWNERS],
        title: 'Trip delayed',
        body: '{route}: {minutes} minutes. {reason}',
        goTo: '/trips/{tripId}',
      },
    ],
    live: [
      {
        type: 'trip.delayed',
        to: [{ topic: 'trip', idField: 'tripId' }, 'staff', 'operator'],
        data: ['tripId', 'minutes'],
      },
    ],
  },
  {
    event: 'trip.boarding-started',
    notices: [
      {
        to: [CUSTOMERS],
        title: 'Boarding started',
        body: 'Your bus {busRegistration} is boarding now.',
        goTo: '/my-trips',
      },
    ],
    live: [
      {
        type: 'trip.status-changed',
        to: [{ topic: 'trip', idField: 'tripId' }, 'staff', 'operator'],
        data: ['tripId', 'status'],
      },
    ],
  },
  {
    event: 'trip.started',
    notices: [
      {
        to: [CUSTOMERS],
        title: 'Your trip has started',
        body: 'Track your bus live.',
        goTo: '/my-trips',
      },
    ],
    live: [
      {
        type: 'trip.status-changed',
        to: [{ topic: 'trip', idField: 'tripId' }, 'staff', 'operator'],
        data: ['tripId', 'status'],
      },
    ],
  },
  {
    event: 'trip.arrived',
    notices: [
      {
        to: [CUSTOMERS],
        title: 'You have arrived',
        body: 'Thanks for travelling. Please rate your trip.',
        goTo: '/my-trips',
      },
    ],
    live: [
      {
        type: 'trip.status-changed',
        to: [{ topic: 'trip', idField: 'tripId' }, 'staff', 'operator'],
        data: ['tripId', 'status'],
      },
    ],
  },
  {
    event: 'trip-check.override',
    notices: [
      {
        to: [OWNERS, staff('trips.read')],
        title: 'Trip started with a failed check',
        body: '{driverName} started {route} after overriding: {checks}',
        goTo: '/driver-reports',
      },
    ],
    live: [{ type: 'trip-check.warning', to: ['operator', 'staff'], data: ['checkId'] }],
  },
  {
    event: 'trip-check.warning',
    notices: [
      {
        to: [OWNERS],
        title: 'Trip checklist has warnings',
        body: '{driverName} started {route} with: {checks}',
        goTo: '/driver-reports',
      },
    ],
    live: [{ type: 'trip-check.warning', to: ['operator', 'staff'], data: ['checkId'] }],
  },

  // ----- bookings, payments and refunds -----
  // The trips feature sends one `booking.*` event per booking for what happens to the whole trip
  // (delay, boarding, cancellation, bus change, arrival), so each customer gets their own message.
  {
    event: 'booking.created',
    notices: [
      {
        to: [OWNERS],
        title: 'New booking',
        body: '{pnr} - {seatsText} on {route}',
        goTo: '/bookings',
      },
    ],
    live: [
      {
        type: 'booking.created',
        to: ['operator', 'staff', { user: 'customerId' }],
        data: ['bookingId'],
      },
    ],
  },
  {
    event: 'booking.confirmed',
    notices: [
      {
        to: [CUSTOMER],
        title: 'Booking confirmed',
        body: '{pnr}: {route}, {departureText}',
        goTo: '/my-trips',
      },
    ],
    messages: [{ template: 'booking_confirmed', channels: ALL_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    event: 'booking.cancelled',
    notices: [
      { to: [OWNERS], title: 'Booking cancelled', body: '{pnr} on {route}.', goTo: '/bookings' },
      {
        to: [CUSTOMER],
        title: 'Booking cancelled',
        body: '{pnr} on {route}. Your refund has started.',
        goTo: '/my-trips',
      },
    ],
    live: [
      {
        type: 'booking.cancelled',
        to: ['operator', 'staff', { user: 'customerId' }],
        data: ['bookingId'],
      },
    ],
    messages: [{ template: 'booking_cancelled', channels: ALL_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    // Sent by the reminder job 24 hours (`reminder: '24H'`) and 2 hours (`'2H'`) before departure
    event: 'booking.reminder',
    notices: [
      {
        to: [CUSTOMER],
        title: (p) => (isTwoHourReminder(p) ? 'Your bus leaves in 2 hours' : 'Your trip is tomorrow'),
        body: (p) =>
          isTwoHourReminder(p)
            ? `Bus ${text(p.busRegistration)} from ${text(p.boardingPoint)}`
            : `${text(p.route)} at ${text(p.departureTime)}`,
        goTo: '/my-trips',
      },
    ],
    messages: [
      {
        template: 'travel_reminder_24h',
        channels: PHONE_CHANNELS,
        contact: BOOKING_CONTACT,
        when: (p) => !isTwoHourReminder(p),
      },
      {
        template: 'travel_reminder_2h',
        channels: PHONE_CHANNELS,
        contact: BOOKING_CONTACT,
        when: isTwoHourReminder,
      },
    ],
  },
  {
    event: 'booking.trip-delayed',
    messages: [{ template: 'bus_delayed', channels: ALL_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    event: 'booking.boarding-started',
    messages: [{ template: 'boarding_started', channels: PHONE_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    // The app notices come from `trip.cancelled`; this is the message to each booking's contact
    event: 'booking.trip-cancelled',
    messages: [{ template: 'trip_cancelled', channels: ALL_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    event: 'booking.bus-changed',
    notices: [
      {
        to: [CUSTOMER],
        title: 'Your bus has changed',
        body: 'New bus {busRegistration}. Seats {seatsText}.',
        goTo: '/my-trips',
      },
    ],
    messages: [{ template: 'bus_changed', channels: ALL_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    // The app notice comes from `trip.arrived`; this asks each booking's contact for a rating
    event: 'booking.trip-arrived',
    messages: [
      { template: 'trip_completed_feedback', channels: ['WHATSAPP'], contact: BOOKING_CONTACT },
    ],
  },
  {
    event: 'payment.failed',
    notices: [
      {
        to: [CUSTOMER],
        title: 'Payment failed',
        body: 'Seats held for {holdMinutes} min. Tap to retry.',
        goTo: '/my-trips',
      },
    ],
    messages: [{ template: 'payment_failed', channels: ALL_CHANNELS, contact: BOOKING_CONTACT }],
  },
  {
    event: 'refund.updated',
    notices: [
      {
        to: [CUSTOMER],
        title: 'Refund {statusLabel}',
        body: 'Refund of {amountText} is {statusLabel}.',
        goTo: '/my-trips',
      },
    ],
    live: [
      {
        type: 'refund.updated',
        to: [{ user: 'customerId' }, 'staff'],
        data: ['refundId', 'status'],
      },
    ],
    messages: [
      {
        template: 'refund_processed',
        channels: ALL_CHANNELS,
        contact: BOOKING_CONTACT,
        when: (payload) => payload.status === 'PAID',
      },
    ],
  },
  {
    // A customer shares their live trip with someone (women safety); only that person is told
    event: 'trip.shared',
    messages: [
      {
        template: 'trip_share',
        channels: PHONE_CHANNELS,
        contact: { nameField: 'sharedWithName', phoneField: 'sharedWithPhone' },
      },
    ],
  },

  // ----- safety -----
  {
    event: 'sos.raised',
    notices: [
      {
        to: [staff('safety.read')],
        title: (p) =>
          raisedByDriver(p) ? 'SOS from Driver {raisedByName}' : 'SOS from {raisedByName}',
        body: '{note} {route}',
        goTo: '/sos',
      },
      {
        to: [OWNERS],
        title: (p) => (raisedByDriver(p) ? 'SOS from Driver ' : 'SOS on your bus'),
        body: '{note} {route}',
        goTo: '/live',
      },
      {
        to: [DRIVER],
        title: 'SOS on your bus',
        body: 'A passenger raised an SOS. Stop safely and check. The Abra safety team is calling.',
        goTo: '/trip',
        when: (p) => !raisedByDriver(p),
      },
    ],
    live: [
      {
        type: 'sos.raised',
        to: ['staff', 'operator', { user: 'driverId' }],
        data: ['sosId', 'tripId'],
      },
    ],
    messages: [
      {
        template: 'sos_emergency_contact',
        channels: ['SMS'],
        contact: { nameField: 'emergencyContactName', phoneField: 'emergencyContactPhone' },
        when: (p) => !raisedByDriver(p),
      },
    ],
  },
  {
    event: 'sos.updated',
    notices: [
      {
        to: [{ kind: 'user', field: 'raisedById' }],
        title: 'SOS {statusLabel}',
        body: (p) =>
          p.status === 'ACKNOWLEDGED'
            ? 'Our safety team has your alert and is calling you.'
            : `Your SOS is now ${text(p.statusLabel).toLowerCase()}.`,
        goTo: '/sos',
      },
    ],
    live: [
      {
        type: 'sos.updated',
        to: ['staff', 'operator', { user: 'raisedById' }],
        data: ['sosId', 'status'],
      },
    ],
    messages: [
      {
        template: 'sos_acknowledged',
        channels: PHONE_CHANNELS,
        contact: { userField: 'raisedById', nameField: 'contactName', phoneField: 'contactPhone' },
        when: (p) => p.status === 'ACKNOWLEDGED' && !raisedByDriver(p),
      },
    ],
  },

  // ----- support, offers and driver reports -----
  {
    event: 'ticket.created',
    notices: [
      {
        to: [staff('support.read')],
        title: 'New support ticket',
        body: '{ticketRef} - {subject}',
        goTo: '/tickets/{ticketId}',
      },
    ],
  },
  {
    event: 'ticket.agent-replied',
    notices: [{ to: [CUSTOMER], title: 'Support replied', body: '{subject}', goTo: '/support' }],
    live: [{ type: 'ticket.replied', to: [{ user: 'customerId' }, 'staff'], data: ['ticketId'] }],
    messages: [
      {
        template: 'support_replied',
        channels: ['WHATSAPP', 'EMAIL'],
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
        },
      },
    ],
  },
  {
    event: 'ticket.customer-replied',
    notices: [
      {
        to: [staff('support.read')],
        title: 'Customer replied',
        body: '{subject}',
        goTo: '/tickets/{ticketId}',
      },
    ],
    live: [{ type: 'ticket.replied', to: [{ user: 'customerId' }, 'staff'], data: ['ticketId'] }],
  },
  {
    event: 'offer.requested',
    notices: [
      {
        to: [staff('offers.read')],
        title: 'Offer request',
        body: '{code} from an operator needs approval.',
        goTo: '/offers',
      },
    ],
  },
  {
    event: 'report.submitted',
    notices: [
      {
        to: [OWNERS],
        title: 'Driver report received',
        body: (p) =>
          `${text(p.driverName)} sent the ${text(p.reportType)} for ${text(p.period)}${p.late === true ? ' (late)' : ''}.`,
        goTo: '/driver-reports',
      },
    ],
    live: [{ type: 'report.submitted', to: ['operator'], data: ['reportId'] }],
  },
  {
    event: 'report.resubmitted',
    notices: [
      {
        to: [OWNERS],
        title: 'Driver report sent again',
        body: '{driverName} fixed the {reportType}.',
        goTo: '/driver-reports',
      },
    ],
    live: [{ type: 'report.submitted', to: ['operator'], data: ['reportId'] }],
  },
  {
    event: 'report.reviewed',
    notices: [
      {
        to: [DRIVER],
        title: (p) => (p.status === 'APPROVED' ? 'Report approved' : 'Report sent back'),
        body: (p) =>
          p.status === 'APPROVED'
            ? `${text(p.reportType)} for ${text(p.period)}.`
            : `${text(p.note)}`,
        goTo: '/reports',
      },
    ],
    live: [{ type: 'report.reviewed', to: [{ user: 'driverId' }], data: ['reportId', 'status'] }],
  },
  {
    event: 'report.reminder',
    notices: [
      {
        to: [{ kind: 'user', field: 'driverId' }],
        title: 'Please send your report',
        body: '{reportType} for {period}.',
        goTo: '/reports',
        when: (p) => p.target === 'DRIVER',
      },
      {
        to: [OWNERS],
        title: 'Driver report missing',
        body: '{driverName}: {reportType} for {period}.',
        goTo: '/driver-reports',
        when: (p) => p.target !== 'DRIVER',
      },
    ],
  },
];

/** Gives the router the core rules when the application starts. Features add their own the same way. */
@Injectable()
export class CoreEventRulesRegistration implements OnModuleInit {
  constructor(private readonly router: EventRouter) {}

  onModuleInit(): void {
    this.router.addRules(CORE_EVENT_RULES);
  }
}

/**
 * The event router (plan Appendix B and B.3). Loaded in the API and the worker; it handles events
 * only in the worker, where the outbox relay runs. A feature adds its own rules by injecting
 * EventRouter and calling addRules in its onModuleInit.
 */
@Module({
  imports: [NotificationsModule, MessagesModule, RealtimeModule, RbacModule, UsersModule],
  providers: [EventRouter, CoreEventRulesRegistration],
  exports: [EventRouter],
})
export class EventRouterModule {}
