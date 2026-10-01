import { type Job, UnrecoverableError } from 'bullmq';
import {
  type DomainEventHandler,
  DomainEventHandlerRegistry,
} from '../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../events/domain-event.types';
import { DomainEventDispatchProcessor } from '../domain-event-dispatch.processor';

const message: DomainEventMessage = {
  eventId: 'evt-1',
  type: 'test-probe.recorded',
  aggregateType: 'test-probe',
  aggregateId: 'probe-1',
  payload: {},
  occurredAt: '2026-09-30T10:00:00.000Z',
};

function jobWith(data: unknown): Job {
  return { id: 'evt-1', data } as unknown as Job;
}

function handler(name: string, eventTypes: string[], handle = jest.fn(() => Promise.resolve())) {
  return { name, eventTypes, handle } satisfies DomainEventHandler;
}

describe('DomainEventDispatchProcessor', () => {
  it('runs every handler registered for the event type, in order', async () => {
    const registry = new DomainEventHandlerRegistry();
    const order: string[] = [];
    registry.register(
      handler(
        'first',
        [message.type],
        jest.fn(() => (order.push('first'), Promise.resolve())),
      ),
    );
    registry.register(handler('other', ['something.else']));
    registry.register(
      handler(
        'second',
        [message.type],
        jest.fn(() => (order.push('second'), Promise.resolve())),
      ),
    );

    const result = await new DomainEventDispatchProcessor(registry).process(jobWith(message));
    expect(result).toEqual({ eventId: 'evt-1', handledBy: ['first', 'second'] });
    expect(order).toEqual(['first', 'second']);
  });

  it('completes an event nobody subscribes to', async () => {
    const result = await new DomainEventDispatchProcessor(new DomainEventHandlerRegistry()).process(
      jobWith(message),
    );
    expect(result).toEqual({ eventId: 'evt-1', handledBy: [] });
  });

  it('fails the job when a handler fails, so BullMQ retries it', async () => {
    const registry = new DomainEventHandlerRegistry();
    registry.register(
      handler(
        'broken',
        [message.type],
        jest.fn(() => Promise.reject(new Error('provider down'))),
      ),
    );
    await expect(
      new DomainEventDispatchProcessor(registry).process(jobWith(message)),
    ).rejects.toThrow('provider down');
  });

  it('rejects malformed jobs as unrecoverable (no retries)', async () => {
    const processor = new DomainEventDispatchProcessor(new DomainEventHandlerRegistry());
    await expect(processor.process(jobWith({ type: 'x' }))).rejects.toBeInstanceOf(
      UnrecoverableError,
    );
  });
});

describe('DomainEventHandlerRegistry', () => {
  it('refuses duplicate handler names and supports unregistering', () => {
    const registry = new DomainEventHandlerRegistry();
    registry.register(handler('h', ['a.b']));
    expect(() => registry.register(handler('h', ['a.b']))).toThrow('already registered');
    registry.unregister('h');
    expect(registry.handlersFor('a.b')).toEqual([]);
  });
});
