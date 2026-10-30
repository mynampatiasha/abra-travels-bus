import { Types } from 'mongoose';
import { type DomainEventMessage } from '../../../events/domain-event.types';
import {
  defaultNotificationSettings,
  settingsFrom,
  topicOfEvent,
  topicOfMessageKind,
  type NotificationSettings,
} from '../../customers/notification_settings';
import { EventRouter } from '../event_router_core.service';

const customerId = new Types.ObjectId();
const staffId = new Types.ObjectId();

function setup(settings: NotificationSettings | undefined) {
  const dispatcher = { deliver: jest.fn().mockResolvedValue(true) };
  const messages = { send: jest.fn().mockResolvedValue({ status: 'SENT' }) };
  const users = {
    findContacts: jest.fn((ids: Types.ObjectId[]) =>
      Promise.resolve(ids.map((id) => ({ _id: id, email: 'a@example.com', phone: '+919876543210' }))),
    ),
    findActiveByRoleIds: jest.fn().mockResolvedValue([]),
  };
  const preferences = {
    forUsers: jest.fn((ids: Types.ObjectId[]) =>
      Promise.resolve(
        new Map(
          ids
            .filter((id) => settings && id.equals(customerId))
            .map((id) => [id.toHexString(), settings as NotificationSettings]),
        ),
      ),
    ),
  };
  const router = new EventRouter(
    { register: jest.fn() } as never,
    dispatcher as never,
    {} as never,
    messages as never,
    { findAll: jest.fn().mockResolvedValue([]) } as never,
    users as never,
    preferences as never,
  );
  router.addRules([
    {
      event: 'booking.confirmed',
      notices: [{ to: [{ kind: 'user', field: 'userId' }], title: 'Booked', body: 'Seat {seat}', goTo: '/trips' }],
      messages: [
        {
          channels: ['WHATSAPP', 'EMAIL'],
          kind: 'BOOKING_CONFIRMED',
          subject: 'Booked',
          body: 'Seat {seat}',
          contact: { userField: 'userId', nameField: 'name', phoneField: 'phone', emailField: 'email' },
        },
      ],
    },
    {
      event: 'sos.raised',
      notices: [{ to: [{ kind: 'user', field: 'userId' }], title: 'SOS', body: 'Help', goTo: '/sos' }],
    },
  ]);
  return { router, dispatcher, messages };
}

const event = (type: string, userId: Types.ObjectId): DomainEventMessage =>
  ({
    eventId: `${type}-1`,
    type,
    payload: {
      userId: userId.toHexString(),
      name: 'Asha',
      phone: '+919876543210',
      email: 'a@example.com',
      seat: '12',
    },
  }) as unknown as DomainEventMessage;

describe('what the customer wants to be told', () => {
  it('starts with bookings and trips on and offers off, and fills gaps with that', () => {
    const defaults = defaultNotificationSettings();
    expect(defaults.bookings).toEqual({ whatsapp: true, email: true, push: true });
    expect(defaults.offers).toEqual({ whatsapp: false, email: false, push: false });
    expect(settingsFrom(null)).toEqual(defaults);
    expect(settingsFrom({ bookings: { whatsapp: false }, trips: 'nonsense' }).bookings).toEqual({
      whatsapp: false,
      email: true,
      push: true,
    });
  });

  it('puts events and messages under a kind, and leaves safety and account events out', () => {
    expect(topicOfEvent('booking.confirmed')).toBe('bookings');
    expect(topicOfEvent('refund.updated')).toBe('bookings');
    expect(topicOfEvent('trip.delayed')).toBe('trips');
    expect(topicOfEvent('sos.raised')).toBeNull();
    expect(topicOfEvent('auth.otp')).toBeNull();
    expect(topicOfMessageKind('REFUND_PAID')).toBe('bookings');
    expect(topicOfMessageKind('TRIP_DELAYED')).toBe('trips');
    expect(topicOfMessageKind('ANNOUNCEMENT')).toBeNull();
  });
});

describe('event router with customer settings', () => {
  it('sends on every channel when the customer left the defaults', async () => {
    const { router, dispatcher, messages } = setup(defaultNotificationSettings());
    await router.handle(event('booking.confirmed', customerId));
    const [, , options] = dispatcher.deliver.mock.calls[0] as [unknown, unknown, { off: Set<string> }];
    expect(options.off.size).toBe(0);
    expect(messages.send).toHaveBeenCalledTimes(2);
  });

  it('skips WhatsApp when it is off for bookings, and sends email', async () => {
    const settings = defaultNotificationSettings();
    settings.bookings.whatsapp = false;
    const { router, dispatcher, messages } = setup(settings);
    await router.handle(event('booking.confirmed', customerId));

    const [, , options] = dispatcher.deliver.mock.calls[0] as [unknown, unknown, { off: Set<string> }];
    expect([...options.off]).toEqual(['WHATSAPP']);
    const channels = (messages.send.mock.calls as Array<[{ channel: string }]>).map(([m]) => m.channel);
    expect(channels).toEqual(['EMAIL']);
  });

  it('sends nothing outside the app when every channel is off, but the app list still gets it', async () => {
    const settings = defaultNotificationSettings();
    settings.bookings = { whatsapp: false, email: false, push: false };
    const { router, dispatcher, messages } = setup(settings);
    await router.handle(event('booking.confirmed', customerId));

    const [, , options] = dispatcher.deliver.mock.calls[0] as [unknown, unknown, { off: Set<string> }];
    expect([...options.off].sort()).toEqual(['EMAIL', 'PUSH', 'WHATSAPP']);
    expect(dispatcher.deliver).toHaveBeenCalledTimes(1);
    expect(messages.send).not.toHaveBeenCalled();
  });

  it('never filters a safety event, whatever the customer chose', async () => {
    const settings = defaultNotificationSettings();
    for (const topic of ['bookings', 'trips', 'offers'] as const) {
      settings[topic] = { whatsapp: false, email: false, push: false };
    }
    const { router, dispatcher } = setup(settings);
    await router.handle(event('sos.raised', customerId));
    const [, , options] = dispatcher.deliver.mock.calls[0] as [unknown, unknown, { off: Set<string> }];
    expect(options.off.size).toBe(0);
  });

  it('tells a person with no customer profile (staff) everything', async () => {
    const settings = defaultNotificationSettings();
    settings.bookings = { whatsapp: false, email: false, push: false };
    const { router, dispatcher, messages } = setup(settings);
    await router.handle(event('booking.confirmed', staffId));
    const [, , options] = dispatcher.deliver.mock.calls[0] as [unknown, unknown, { off: Set<string> }];
    expect(options.off.size).toBe(0);
    expect(messages.send).toHaveBeenCalledTimes(2);
  });
});
