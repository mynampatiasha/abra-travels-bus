import { type ClientSession } from 'mongoose';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { type OutboxEvent } from '../outbox-event.schema';
import { type OutboxRepository } from '../outbox.repository';
import { OutboxService } from '../outbox.service';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function setup(inTransaction = true) {
  const insert = jest.fn<Promise<void>, [OutboxEvent, ClientSession]>().mockResolvedValue();
  const service = new OutboxService({ insert } as unknown as OutboxRepository);
  const session = { inTransaction: () => inTransaction } as unknown as ClientSession;
  return { service, insert, session };
}

const event = {
  type: 'test-probe.recorded',
  aggregateType: 'test-probe',
  aggregateId: 'probe-1',
  payload: { value: 1 },
};

describe('OutboxService.record', () => {
  it('stores a PENDING event for the domain-events queue in the given transaction', async () => {
    const { service, insert, session } = setup();
    const eventId = await RequestContextService.run({ requestId: 'req-42' }, () =>
      service.record(event, session),
    );

    expect(eventId).toMatch(UUID);
    const [stored, usedSession] = insert.mock.calls[0]!;
    expect(usedSession).toBe(session);
    expect(stored).toMatchObject({
      eventId,
      ...event,
      requestId: 'req-42',
      queueName: 'domain-events',
      status: 'PENDING',
      attempts: 0,
    });
    expect(stored.availableAt).toEqual(stored.occurredAt);
  });

  it('generates a new eventId for every event', async () => {
    const { service, session } = setup();
    const first = await service.record(event, session);
    const second = await service.record(event, session);
    expect(first).not.toBe(second);
  });

  it('refuses to record outside a transaction', async () => {
    const { service, insert, session } = setup(false);
    await expect(service.record(event, session)).rejects.toThrow(
      'inside the transaction of the state change',
    );
    expect(insert).not.toHaveBeenCalled();
  });

  it.each(['Booking.Confirmed', 'booking', 'booking.', 'booking confirmed', '.confirmed'])(
    'rejects the malformed event type %s',
    async (type) => {
      const { service, session } = setup();
      await expect(service.record({ ...event, type }, session)).rejects.toThrow(
        'Invalid domain event type',
      );
    },
  );

  it('requires an aggregate', async () => {
    const { service, session } = setup();
    await expect(service.record({ ...event, aggregateId: ' ' }, session)).rejects.toThrow(
      'aggregateType and aggregateId',
    );
  });
});
