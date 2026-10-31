/* eslint-disable max-lines -- the routing rules are one data table, plan Appendix B */
import { Injectable, Module, type OnModuleInit } from '@nestjs/common';
import { MessagesModule } from '../messages/messages_admin_manage';
import { TicketsModule } from '../tickets/tickets.module';
import { RbacModule } from '../rbac/rbac.module';
import { RealtimeModule } from '../realtime/live_updates_channel';
import { UsersModule } from '../users/users.module';
import {
  EventRouter,
  type AudienceSpec,
  type EventRule,
  type EventText,
} from './event_router_core.service';
import { NotificationsModule } from './notifications.module';

/*
 * The rules of the event router: plan Appendix B, one rule per event. The feature that owns an
 * event records it in the outbox with the payload named here; nothing else is needed to tell the
 * right people. The words are English; the plan's per-language templates replace them later.
 *
 * Payload fields (ids as text; the texts are written by the feature, because only it knows them):
 *   operatorId, operatorName, tripId, driverId, driverName, customerId, customerIds (list),
 *   bookingId, settlementId, ticketId, reportId, busId, sosId, route ("Hyderabad to Bengaluru"),
 *   departureText ("12 Jan, 10:30 pm"), busRegistration, pnr, seatsText, amountText ("Rs 1,250"),
 *   statusLabel, reason, minutes, contactName, contactPhone, contactEmail.
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
    messages: [
      {
        channels: ['WHATSAPP', 'EMAIL'],
        kind: 'BOOKING_CONFIRMED',
        attachTicketPdf: true,
        subject: 'Booking confirmed: {pnr}',
        body: '{route}, {departureText}. Seats {seatsText}. Boarding at {boardingPoint}. Amount {amountText}. Track your bus and see your ticket in the Abra app.',
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
          bookingField: 'bookingId',
        },
      },
    ],
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
    messages: [
      {
        channels: ['WHATSAPP', 'EMAIL'],
        kind: 'BOOKING_CANCELLED',
        subject: 'Booking cancelled: {pnr}',
        body: 'Your booking {pnr} on {route} is cancelled. The refund has started and arrives in 5 to 7 working days.',
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
          bookingField: 'bookingId',
        },
      },
    ],
  },
  {
    event: 'booking.trip-delayed',
    messages: [
      {
        channels: ['WHATSAPP', 'EMAIL'],
        kind: 'TRIP_DELAYED',
        subject: 'Bus delayed: {pnr}',
        body: 'Your bus on {route} is about {minutes} minutes late. {reason} Track it live in the app.',
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
          bookingField: 'bookingId',
        },
      },
    ],
  },
  {
    event: 'booking.boarding-started',
    messages: [
      {
        channels: ['WHATSAPP', 'EMAIL'],
        kind: 'BOARDING_STARTED',
        subject: 'Boarding now: {pnr}',
        body: 'Bus {busRegistration} is boarding. Please reach your boarding point.',
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
          bookingField: 'bookingId',
        },
      },
    ],
  },
  {
    event: 'payment.failed',
    messages: [
      {
        channels: ['WHATSAPP', 'EMAIL'],
        kind: 'PAYMENT_FAILED',
        subject: 'Payment failed',
        body: 'Your payment of {amountText} did not go through. {reason} Your seats are held for a short time: please try again.',
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
          bookingField: 'bookingId',
        },
      },
    ],
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
        channels: ['WHATSAPP', 'EMAIL'],
        kind: 'REFUND_PAID',
        subject: 'Refund processed: {pnr}',
        body: 'Your refund of {amountText} for {pnr} has been processed. Reference: {reference}.',
        contact: {
          userField: 'customerId',
          nameField: 'contactName',
          phoneField: 'contactPhone',
          emailField: 'contactEmail',
          bookingField: 'bookingId',
        },
        when: (payload) => payload.status === 'PAID',
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
  imports: [NotificationsModule, MessagesModule, RealtimeModule, RbacModule, UsersModule, TicketsModule],
  providers: [EventRouter, CoreEventRulesRegistration],
  exports: [EventRouter],
})
export class EventRouterModule {}
