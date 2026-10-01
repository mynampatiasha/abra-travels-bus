import { Logger } from '@nestjs/common';
import { Types } from 'mongoose';
import { type AppConfigService } from '../../config/app-config.service';
import { type QueueRegistry } from '../../queues/queue-registry.service';
import { OutboxRelayService, outboxRetryDelayMs } from '../outbox-relay.service';
import { type OutboxRepository, type StoredOutboxEvent } from '../outbox.repository';

function storedEvent(overrides: Partial<StoredOutboxEvent> = {}): StoredOutboxEvent {
  const occurredAt = new Date('2026-09-30T10:00:00.000Z');
  return {
    _id: new Types.ObjectId(),
    eventId: '0b8f9d1e-4c1a-4c7e-9a55-3f0f2f7e1a11',
    type: 'test-probe.recorded',
    aggregateType: 'test-probe',
    aggregateId: 'probe-1',
    payload: { value: 1 },
    occurredAt,
    requestId: 'req-1',
    queueName: 'domain-events',
    status: 'PUBLISHING',
    attempts: 1,
    availableAt: occurredAt,
    ...overrides,
  };
}

function setup(options: { events?: StoredOutboxEvent[]; add?: jest.Mock; marked?: boolean } = {}) {
  const pending = [...(options.events ?? [storedEvent()])];
  const calls: string[] = [];
  const repository = {
    claimNext: jest.fn(() => Promise.resolve(pending.shift() ?? null)),
    markPublished: jest.fn(
      () => (calls.push('markPublished'), Promise.resolve(options.marked ?? true)),
    ),
    scheduleRetry: jest.fn(() => Promise.resolve(true)),
    markFailed: jest.fn(() => Promise.resolve(true)),
  };
  const add = options.add ?? jest.fn(() => (calls.push('add'), Promise.resolve({ id: 'job' })));
  const queues = { get: jest.fn(() => ({ add })) };
  const values: Record<string, number> = {
    OUTBOX_BATCH_SIZE: 10,
    OUTBOX_LEASE_MS: 30_000,
    OUTBOX_MAX_PUBLISH_ATTEMPTS: 3,
  };
  const config = { get: (key: string) => values[key] };
  const relay = new OutboxRelayService(
    repository as unknown as OutboxRepository,
    queues as unknown as QueueRegistry,
    config as unknown as AppConfigService,
  );
  return { relay, repository, add, calls, queues };
}

describe('OutboxRelayService', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('enqueues with jobId = eventId, then marks PUBLISHED (in that order)', async () => {
    const event = storedEvent();
    const { relay, repository, add, calls } = setup({ events: [event] });

    await expect(relay.relayBatch()).resolves.toEqual({
      published: 1,
      retried: 0,
      failed: 0,
      leaseLost: 0,
    });
    expect(add).toHaveBeenCalledWith(
      'test-probe.recorded',
      {
        eventId: event.eventId,
        type: event.type,
        aggregateType: 'test-probe',
        aggregateId: 'probe-1',
        payload: { value: 1 },
        occurredAt: '2026-09-30T10:00:00.000Z',
        requestId: 'req-1',
      },
      { jobId: event.eventId },
    );
    expect(calls).toEqual(['add', 'markPublished']);
    expect(repository.markPublished).toHaveBeenCalledWith(
      event._id,
      relay.relayId,
      expect.any(Date),
    );
  });

  it('claims with its relay id and the configured lease', async () => {
    const { relay, repository } = setup({ events: [] });
    await relay.relayBatch();
    expect(repository.claimNext).toHaveBeenCalledWith(relay.relayId, 30_000, expect.any(Date));
  });

  it('does not mark PUBLISHED when the enqueue fails; schedules a retry with back-off', async () => {
    const add = jest.fn(() => Promise.reject(new Error("Stream isn't writeable")));
    const event = storedEvent({ attempts: 2 });
    const { relay, repository } = setup({ events: [event], add });

    const before = Date.now();
    await expect(relay.relayBatch()).resolves.toMatchObject({ published: 0, retried: 1 });
    expect(repository.markPublished).not.toHaveBeenCalled();
    const [id, relayId, retryAt, reason] = repository.scheduleRetry.mock.calls[0] as unknown as [
      Types.ObjectId,
      string,
      Date,
      string,
    ];
    expect([id, relayId, reason]).toEqual([event._id, relay.relayId, "Stream isn't writeable"]);
    expect(retryAt.getTime()).toBeGreaterThanOrEqual(before + outboxRetryDelayMs(2));
  });

  it('parks the event as FAILED at the attempt limit (kept, not dropped)', async () => {
    const add = jest.fn(() => Promise.reject(new Error('Connection is closed.')));
    const event = storedEvent({ attempts: 3 });
    const { relay, repository } = setup({ events: [event], add });

    await expect(relay.relayBatch()).resolves.toMatchObject({ failed: 1, retried: 0 });
    expect(repository.markFailed).toHaveBeenCalledWith(
      event._id,
      relay.relayId,
      'Connection is closed.',
    );
    expect(repository.scheduleRetry).not.toHaveBeenCalled();
  });

  it('reports a lost lease when the event was reclaimed by another relay', async () => {
    const { relay } = setup({ marked: false });
    await expect(relay.relayBatch()).resolves.toMatchObject({ published: 0, leaseLost: 1 });
  });

  it('treats an unknown queue name as a publish failure', async () => {
    const { relay, add, repository } = setup({ events: [storedEvent({ queueName: 'nope' })] });
    await expect(relay.relayBatch()).resolves.toMatchObject({ retried: 1 });
    expect(add).not.toHaveBeenCalled();
    expect(repository.scheduleRetry).toHaveBeenCalledWith(
      expect.anything(),
      relay.relayId,
      expect.any(Date),
      'Unknown queue "nope"',
    );
  });

  it('stops at the batch size', async () => {
    const events = Array.from({ length: 15 }, (_, index) =>
      storedEvent({ _id: new Types.ObjectId(), eventId: `event-${index}` }),
    );
    const { relay, repository } = setup({ events });
    await expect(relay.relayBatch()).resolves.toMatchObject({ published: 10 });
    expect(repository.claimNext).toHaveBeenCalledTimes(10);
  });

  it('lets a MongoDB error after the enqueue propagate (lease expiry recovers the event)', async () => {
    const { relay, repository } = setup();
    repository.markPublished.mockRejectedValueOnce(new Error('not primary'));
    await expect(relay.relayBatch()).rejects.toThrow('not primary');
  });
});

describe('outboxRetryDelayMs', () => {
  it('backs off exponentially from 1 s and caps at 60 s', () => {
    expect([1, 2, 3, 4, 7, 20].map(outboxRetryDelayMs)).toEqual([
      1_000, 2_000, 4_000, 8_000, 60_000, 60_000,
    ]);
  });
});
