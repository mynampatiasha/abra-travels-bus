import { Types } from 'mongoose';
import { type DomainEventMessage } from '../../../events/domain-event.types';
import { CORE_EVENT_RULES, CoreEventRulesRegistration } from '../event_router_core';
import { EventRouter, noticeData, renderText } from '../event_router_core.service';
import { type SendMessageInput } from '../../messages/messages_admin_manage.service';
import {
  type NotificationContent,
  type Recipient,
} from '../services/notification-dispatcher.service';

const id = () => new Types.ObjectId();
const OWNER_ROLE = { _id: id(), key: 'OPERATOR_ADMIN', permissionKeys: ['trips.read'] };
const SUPPORT_ROLE = { _id: id(), key: 'SUPPORT', permissionKeys: ['trips.read'] };
const SUPER_ROLE = { _id: id(), key: 'SUPER_ADMIN', permissionKeys: ['*'] };

const operatorId = id();
const owner = { _id: id(), email: 'owner@alpha.test', phone: '+919800000001' };
const staffMember = { _id: id(), userType: 'STAFF', email: 'staff@abra.test' };
const customerA = { _id: id(), email: 'a@mail.test', phone: '+919800000002' };
const customerB = { _id: id(), email: 'b@mail.test' };
const driver = { _id: id(), phone: '+919800000003' };

function event(type: string, payload: Record<string, unknown>): DomainEventMessage {
  return {
    eventId: `evt-${type}`,
    type,
    aggregateType: 'test',
    aggregateId: 'x1',
    payload,
    occurredAt: '2026-10-13T10:00:00.000Z',
  };
}

function setup() {
  const registry = { register: jest.fn() };
  const dispatcher = { deliver: jest.fn().mockResolvedValue(true) };
  const live = { toStaff: jest.fn(), toOperator: jest.fn(), toUser: jest.fn(), toTopic: jest.fn() };
  const messages = { send: jest.fn().mockResolvedValue({ status: 'SENT' }) };
  const roles = { findAll: jest.fn().mockResolvedValue([OWNER_ROLE, SUPPORT_ROLE, SUPER_ROLE]) };
  const users = {
    findActiveByRoleIds: jest.fn(
      (roleIds: Types.ObjectId[], filter?: { operatorId?: Types.ObjectId }) => {
        const keys = roleIds.map(String);
        if (filter?.operatorId) {
          // Owners of the operator; an operator's people are never platform staff
          return Promise.resolve(
            keys.includes(String(OWNER_ROLE._id)) && filter.operatorId.equals(operatorId)
              ? [owner]
              : [],
          );
        }
        return Promise.resolve(
          keys.includes(String(SUPPORT_ROLE._id)) || keys.includes(String(SUPER_ROLE._id))
            ? [staffMember, { ...owner, userType: 'OPERATOR_STAFF' }]
            : [],
        );
      },
    ),
    findContacts: jest.fn((ids: Types.ObjectId[]) =>
      Promise.resolve(
        [customerA, customerB, driver, owner].filter((user) => ids.some((x) => x.equals(user._id))),
      ),
    ),
  };
  const router = new EventRouter(
    registry as never,
    dispatcher as never,
    live as never,
    messages as never,
    roles as never,
    users as never,
  );
  new CoreEventRulesRegistration(router).onModuleInit();
  const delivered = () => dispatcher.deliver.mock.calls as Array<[Recipient, NotificationContent]>;
  const sent = () => messages.send.mock.calls as Array<[SendMessageInput]>;
  return { router, registry, dispatcher, live, messages, users, delivered, sent };
}

const tripCancelled = () =>
  event('trip.cancelled', {
    tripId: 'trip1',
    operatorId: operatorId.toHexString(),
    driverId: driver._id.toHexString(),
    customerIds: [customerA._id.toHexString(), customerB._id.toHexString()],
    route: 'Hyderabad to Bengaluru',
    departureText: '12 Jan, 10:30 pm',
    status: 'CANCELLED',
  });

describe('event router: words', () => {
  it('fills {field} from the payload and leaves no double spaces when a field is missing', () => {
    expect(renderText('{route} on {departureText}.', { route: 'A to B' })).toBe('A to B on .');
    expect(renderText('Late by {minutes}  minutes', { minutes: 15 })).toBe('Late by 15 minutes');
    expect(renderText((p) => `x${String(p.n)}`, { n: 2 })).toBe('x2');
  });

  it('gives the app only the place to go and the ids, never the whole payload', () => {
    expect(
      noticeData(
        { tripId: 't1', reason: 'secret note', contactPhone: '+91', bookingId: 'b1' },
        '/trips/t1',
      ),
    ).toEqual({ route: '/trips/t1', tripId: 't1', bookingId: 'b1' });
  });
});

describe('event router: rules', () => {
  it('has one rule per event, and registers itself for exactly those events', () => {
    const { router, registry } = setup();
    const events = CORE_EVENT_RULES.map((rule) => rule.event);
    expect(new Set(events).size).toBe(events.length);
    router.onModuleInit();
    expect(registry.register).toHaveBeenCalledWith(router);
    expect([...router.eventTypes].sort()).toEqual([...events].sort());
  });

  it('refuses a second rule for an event that already has one', () => {
    const { router } = setup();
    expect(() => router.addRules([{ event: 'trip.cancelled' }])).toThrow(/already has a rule/);
  });

  it('leaves alone the events that keep their own handlers (onboarding, place requests)', () => {
    const events = CORE_EVENT_RULES.map((rule) => rule.event);
    expect(events.filter((name) => /^(onboarding|place-request)\./.test(name))).toEqual([]);
  });

  it('does nothing for an event without a rule', async () => {
    const { router, dispatcher, live, messages } = setup();
    await router.handle(event('something.happened', { operatorId: operatorId.toHexString() }));
    expect(dispatcher.deliver).not.toHaveBeenCalled();
    expect(messages.send).not.toHaveBeenCalled();
    expect(live.toStaff).not.toHaveBeenCalled();
  });
});

describe('event router: a cancelled trip', () => {
  it('tells each customer, the driver and the owner once, with the event id for safe retries', async () => {
    const { router, delivered } = setup();
    await router.handle(tripCancelled());
    const told = delivered().map(([recipient]) => String(recipient.userId));
    expect(told.sort()).toEqual(
      [customerA, customerB, driver, owner].map((user) => String(user._id)).sort(),
    );
    const [recipient, content] = delivered().find(
      ([r]) => String(r.userId) === String(customerA._id),
    )!;
    expect(recipient).toMatchObject({ email: customerA.email, phone: customerA.phone });
    expect(content).toEqual({
      eventId: 'evt-trip.cancelled',
      type: 'trip.cancelled',
      title: 'Trip cancelled',
      body: 'Hyderabad to Bengaluru on 12 Jan, 10:30 pm was cancelled. Your full refund has started.',
      data: {
        route: '/my-trips',
        tripId: 'trip1',
        operatorId: operatorId.toHexString(),
        driverId: driver._id.toHexString(),
      },
    });
  });

  it('sends the live update to the trip topic, the staff and the operator, with ids and state only', async () => {
    const { router, live } = setup();
    await router.handle(tripCancelled());
    const data = { tripId: 'trip1', status: 'CANCELLED' };
    expect(live.toTopic).toHaveBeenCalledWith('trip', 'trip1', 'trip.status-changed', data);
    expect(live.toStaff).toHaveBeenCalledWith('trip.status-changed', data);
    expect(live.toOperator).toHaveBeenCalledWith(
      operatorId.toHexString(),
      'trip.status-changed',
      data,
    );
  });

  it('throws when a delivery failed, so the worker retries only what failed', async () => {
    const { router, dispatcher } = setup();
    dispatcher.deliver.mockResolvedValueOnce(false);
    await expect(router.handle(tripCancelled())).rejects.toThrow(/will retry/);
  });

  it('finds no owner for an event without an operator, and does not fail for it', async () => {
    const { router, dispatcher } = setup();
    await router.handle(event('bus.maintenance-started', { busRegistration: 'KA01AB1234' }));
    expect(dispatcher.deliver).not.toHaveBeenCalled();
  });
});

describe('event router: who is staff', () => {
  it('tells only platform staff whose role holds the permission (or everything)', async () => {
    const { router, delivered } = setup();
    await router.handle(
      event('trip.delayed', {
        tripId: 't1',
        route: 'A to B',
        minutes: 20,
        reason: 'Traffic.',
        customerIds: [],
      }),
    );
    const told = delivered().map(([recipient]) => String(recipient.userId));
    // The owner is not told here (no operatorId) and an operator account never counts as staff
    expect(told).toEqual([String(staffMember._id)]);
  });
});

describe('event router: messages', () => {
  const confirmed = (extra: Record<string, unknown> = {}) =>
    event('booking.confirmed', {
      bookingId: id().toHexString(),
      customerId: customerA._id.toHexString(),
      contactName: 'Asha',
      contactPhone: '+919800000002',
      contactEmail: 'asha@mail.test',
      pnr: 'ABR123',
      route: 'A to B',
      departureText: '12 Jan, 10:30 pm',
      seatsText: 'L1, L2',
      boardingPoint: 'Ameerpet',
      amountText: 'Rs 1,250',
      ...extra,
    });

  it('sends the booking confirmation by WhatsApp and email, logged with the event id', async () => {
    const { router, messages, sent } = setup();
    await router.handle(confirmed());
    expect(messages.send).toHaveBeenCalledTimes(2);
    expect(sent().map(([input]) => [input.channel, input.address])).toEqual([
      ['WHATSAPP', '+919800000002'],
      ['EMAIL', 'asha@mail.test'],
    ]);
    expect(sent()[0]![0]).toMatchObject({
      kind: 'BOOKING_CONFIRMED',
      recipientName: 'Asha',
      subject: 'Booking confirmed: ABR123',
      eventId: 'evt-booking.confirmed',
    });
  });

  it('skips a channel the contact has no address for (a guest gave only a phone)', async () => {
    const { router, sent } = setup();
    await router.handle(confirmed({ contactEmail: undefined }));
    expect(sent().map(([input]) => input.channel)).toEqual(['WHATSAPP']);
  });

  it('sends the refund message only once the refund is paid', async () => {
    const { router, messages, dispatcher } = setup();
    const refund = (status: string) =>
      event('refund.updated', {
        refundId: 'r1',
        customerId: customerA._id.toHexString(),
        contactName: 'Asha',
        contactPhone: '+919800000002',
        status,
        statusLabel: status === 'PAID' ? 'paid' : 'approved',
        amountText: 'Rs 500',
        pnr: 'ABR123',
        reference: 'RFND9',
      });
    await router.handle(refund('APPROVED'));
    expect(messages.send).not.toHaveBeenCalled();
    expect(dispatcher.deliver).toHaveBeenCalledTimes(1);
    await router.handle(refund('PAID'));
    expect(messages.send).toHaveBeenCalledWith(
      expect.objectContaining({ kind: 'REFUND_PAID', channel: 'WHATSAPP' }),
    );
  });

  it('counts a failed message as a failure to retry', async () => {
    const { router, messages } = setup();
    messages.send.mockResolvedValueOnce({ status: 'FAILED' });
    await expect(router.handle(confirmed())).rejects.toThrow(/will retry/);
  });

  it('takes the words from the template: friendly text, Meta parameters and the button', async () => {
    const { router, sent } = setup();
    const booking = confirmed();
    await router.handle(booking);
    const [whatsApp] = sent()[0]!;
    expect(whatsApp.body).toContain('Hi Asha 👋, great news! Your bus ticket is confirmed ✅');
    expect(whatsApp.body).toContain('📍 Boarding: Ameerpet');
    expect(whatsApp.body).toContain('– Team Abra Travels');
    expect(whatsApp.template).toEqual({
      key: 'booking_confirmed',
      parameters: ['Asha', 'ABR123', 'A to B', '12 Jan, 10:30 pm', 'L1, L2', 'Ameerpet', 'Rs 1,250'],
      buttonParameter: booking.payload.bookingId,
    });
  });

  it('sends no SMS (switched off for now), even when WhatsApp is not set up', async () => {
    const { router, messages, sent } = setup();
    messages.send.mockResolvedValueOnce({ status: 'SKIPPED' });
    await router.handle(confirmed());
    expect(sent().map(([input]) => input.channel)).toEqual(['WHATSAPP', 'EMAIL']);
  });
});

describe('event router: trip-day and reminder messages', () => {
  const booking = (type: string, extra: Record<string, unknown> = {}) =>
    event(type, {
      bookingId: id().toHexString(),
      tripId: 'trip1',
      customerId: customerA._id.toHexString(),
      contactName: 'Asha',
      contactPhone: '+919800000002',
      contactEmail: 'asha@mail.test',
      pnr: 'ABR123',
      route: 'A to B',
      ...extra,
    });

  it('picks the 24-hour or the 2-hour reminder, by WhatsApp only', async () => {
    const { router, sent } = setup();
    await router.handle(booking('booking.reminder', { reminder: '24H', departureTime: '10:30 pm' }));
    await router.handle(booking('booking.reminder', { reminder: '2H', driverName: 'Ravi' }));
    expect(sent().map(([input]) => [input.channel, input.template?.key])).toEqual([
      ['WHATSAPP', 'travel_reminder_24h'],
      ['WHATSAPP', 'travel_reminder_2h'],
    ]);
    expect(sent()[1]![0].body).toContain('👤 Driver: Ravi (-)');
  });

  it('tells each booking of a cancelled trip by WhatsApp and email, with an apology', async () => {
    const { router, sent } = setup();
    await router.handle(booking('booking.trip-cancelled', { amountText: 'Rs 900' }));
    expect(sent().map(([input]) => input.channel)).toEqual(['WHATSAPP', 'EMAIL']);
    expect(sent()[0]![0]).toMatchObject({
      kind: 'TRIP_CANCELLED',
      subject: 'Trip cancelled: ABR123',
    });
    expect(sent()[0]![0].body).toContain("we're very sorry");
  });

  it('tells the customer in the app and by message when the bus changes', async () => {
    const { router, sent, delivered } = setup();
    await router.handle(booking('booking.bus-changed', { busRegistration: 'TS09AB1234' }));
    expect(delivered()[0]![1].title).toBe('Your bus has changed');
    expect(sent()[0]![0]).toMatchObject({ kind: 'BUS_CHANGED' });
  });

  it("tells the customer's emergency contact on WhatsApp, never for a driver's SOS", async () => {
    const { router, sent } = setup();
    const sos = (raisedBy: string) =>
      event('sos.raised', {
        sosId: 's1',
        raisedBy,
        raisedByName: 'Asha',
        customerName: 'Asha',
        emergencyContactName: 'Meena',
        emergencyContactPhone: '+919800000009',
        busRegistration: 'TS09AB1234',
        route: 'A to B',
        trackingUrl: 'https://abra.test/live/s1',
      });
    await router.handle(sos('DRIVER'));
    expect(sent()).toHaveLength(0);
    await router.handle(sos('CUSTOMER'));
    expect(sent().map(([input]) => [input.channel, input.address, input.kind])).toEqual([
      ['WHATSAPP', '+919800000009', 'SOS_ALERT'],
    ]);
    const [message] = sent()[0]!;
    expect(message.recipientName).toBe('Meena');
    expect(message.userId).toBeUndefined();
    expect(message.body).toContain('Urgent: Asha has raised an SOS alert on their Abra Travels bus.');
    expect(message.body).toContain('Live location: https://abra.test/live/s1');
    expect(message.template).toMatchObject({
      key: 'sos_emergency_contact',
      parameters: ['Asha', 'TS09AB1234', 'A to B', 'https://abra.test/live/s1'],
    });
  });

  it('still tells staff, the owner and the driver about an SOS when the contact gets a message', async () => {
    const { router, delivered } = setup();
    await router.handle(
      event('sos.raised', {
        sosId: 's1',
        raisedBy: 'CUSTOMER',
        raisedByName: 'Asha',
        operatorId: operatorId.toHexString(),
        driverId: driver._id.toHexString(),
        emergencyContactName: 'Meena',
        emergencyContactPhone: '+919800000009',
      }),
    );
    expect(delivered().map(([recipient]) => String(recipient.userId)).sort()).toEqual(
      [staffMember, owner, driver].map((user) => String(user._id)).sort(),
    );
  });
});
