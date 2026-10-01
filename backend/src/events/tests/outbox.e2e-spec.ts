import { type INestApplication, Logger, Module } from '@nestjs/common';
import { getConnectionToken } from '@nestjs/mongoose';
import { Test } from '@nestjs/testing';
import { type Connection } from 'mongoose';
import { AppConfigModule } from '../../config/app-config.module';
import { AppConfigService } from '../../config/app-config.service';
import { validTestEnvironment } from '../../config/tests/valid-test-environment';
import { DatabaseModule } from '../../database/database.module';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { QUEUE_NAMES } from '../../queues/queue-names';
import { QueueRegistry } from '../../queues/queue-registry.service';
import { QueueModule } from '../../queues/queue.module';
import {
  deleteQueueKeys,
  testConfig,
  uniqueQueuePrefix,
  UNREACHABLE_REDIS_URL,
} from '../../queues/tests/queue-test-support';
import { type DomainEvent } from '../domain-event.types';
import { EventsModule } from '../events.module';
import { OutboxRelayService } from '../outbox-relay.service';
import { OutboxRepository } from '../outbox.repository';
import { OutboxService } from '../outbox.service';

@Module({ imports: [AppConfigModule, DatabaseModule, QueueModule, EventsModule] })
class OutboxTestModule {}

/** Test-only event type; not a business event. */
const probeEvent = (aggregateId: string): DomainEvent => ({
  type: 'test-probe.recorded',
  aggregateType: 'test-probe',
  aggregateId,
  payload: { aggregateId },
});

/** Outbox + relay against the real MongoDB replica set and Redis (abra_travels_test database). */
describe('Event outbox and relay (e2e, real MongoDB + Redis)', () => {
  const prefix = uniqueQueuePrefix();
  let app: INestApplication;
  let connection: Connection;
  let runner: TransactionRunner;
  let outbox: OutboxService;
  let repository: OutboxRepository;
  let relay: OutboxRelayService;
  let registry: QueueRegistry;
  let config: AppConfigService;

  const record = (aggregateId: string): Promise<string> =>
    runner.run((session) => outbox.record(probeEvent(aggregateId), session));
  const queue = () => registry.get(QUEUE_NAMES.DOMAIN_EVENTS);

  beforeAll(async () => {
    Object.assign(
      process.env,
      validTestEnvironment({
        QUEUE_PREFIX: prefix,
        OUTBOX_LEASE_MS: '300',
        OUTBOX_MAX_PUBLISH_ATTEMPTS: '2',
      }),
    );
    Logger.overrideLogger(false);
    const moduleRef = await Test.createTestingModule({ imports: [OutboxTestModule] }).compile();
    app = moduleRef.createNestApplication();
    await app.init();
    connection = app.get<Connection>(getConnectionToken());
    runner = app.get(TransactionRunner);
    outbox = app.get(OutboxService);
    repository = app.get(OutboxRepository);
    relay = app.get(OutboxRelayService);
    registry = app.get(QueueRegistry);
    config = app.get(AppConfigService);
  });

  beforeEach(async () => {
    await connection.collection('outbox_events').deleteMany({});
    await queue().obliterate({ force: true });
  });

  afterAll(async () => {
    await connection?.dropDatabase();
    await app?.close();
    await deleteQueueKeys(config.get('REDIS_URL'), prefix);
  });

  it('created the outbox indexes at start-up', async () => {
    const names = (await connection.collection('outbox_events').indexes()).map(
      (index) => index.name,
    );
    expect(names).toEqual(
      expect.arrayContaining(['eventId_1', 'status_1_availableAt_1', 'status_1_lockedUntil_1']),
    );
  });

  it('persists a PENDING event when the transaction commits', async () => {
    const eventId = await record('commit');
    const stored = await repository.findByEventId(eventId);
    expect(stored).toMatchObject({
      eventId,
      type: 'test-probe.recorded',
      status: 'PENDING',
      attempts: 0,
      queueName: 'domain-events',
      lockedBy: null,
      publishedAt: null,
    });
    expect(stored?.occurredAt).toBeInstanceOf(Date);
    expect(stored?.createdAt).toBeInstanceOf(Date);
  });

  it('persists nothing when the transaction rolls back', async () => {
    await expect(
      runner.run(async (session) => {
        await outbox.record(probeEvent('rollback'), session);
        throw new Error('state change failed');
      }),
    ).rejects.toThrow('state change failed');
    expect(await connection.collection('outbox_events').countDocuments()).toBe(0);
  });

  it('PENDING → PUBLISHING → PUBLISHED: enqueues with jobId = eventId, then records publication', async () => {
    const eventId = await record('publish');
    await expect(relay.relayBatch()).resolves.toEqual({
      published: 1,
      retried: 0,
      failed: 0,
      leaseLost: 0,
    });

    const job = await queue().getJob(eventId);
    expect(job?.name).toBe('test-probe.recorded');
    expect(job?.data).toMatchObject({
      eventId,
      aggregateId: 'publish',
      type: 'test-probe.recorded',
    });

    const stored = await repository.findByEventId(eventId);
    expect(stored).toMatchObject({ status: 'PUBLISHED', attempts: 1, lastError: null });
    expect(stored?.publishedAt).toBeInstanceOf(Date);
    expect(stored).not.toHaveProperty('lockedBy');

    // Nothing left to do on the next pass
    await expect(relay.relayBatch()).resolves.toMatchObject({ published: 0 });
  });

  it('claims atomically: a claimed event is invisible to other relays until its lease expires', async () => {
    const eventId = await record('lease');
    const claimed = await repository.claimNext('relay-a', 300, new Date());
    expect(claimed).toMatchObject({
      eventId,
      status: 'PUBLISHING',
      lockedBy: 'relay-a',
      attempts: 1,
    });
    expect(await repository.claimNext('relay-b', 300, new Date())).toBeNull();

    await new Promise((resolve) => setTimeout(resolve, 350));
    const reclaimed = await repository.claimNext('relay-b', 300, new Date());
    expect(reclaimed).toMatchObject({ eventId, lockedBy: 'relay-b', attempts: 2 });
    // The original holder can no longer finish it
    expect(await repository.markPublished(claimed!._id, 'relay-a', new Date())).toBe(false);
  });

  it('recovers a relay crash after the enqueue: re-publication is deduplicated by jobId', async () => {
    const eventId = await record('crash');
    // Simulate a relay that claimed and enqueued, then died before marking PUBLISHED
    await repository.claimNext('crashed-relay', 300, new Date());
    await queue().add('test-probe.recorded', { eventId }, { jobId: eventId });

    await new Promise((resolve) => setTimeout(resolve, 350));
    await expect(relay.relayBatch()).resolves.toMatchObject({ published: 1 });

    expect(await queue().getJobCountByTypes('waiting', 'active', 'completed')).toBe(1);
    expect(await repository.findByEventId(eventId)).toMatchObject({
      status: 'PUBLISHED',
      attempts: 2,
    });
  });

  it('two relays running concurrently publish every event exactly once', async () => {
    const eventIds = await runner.run(async (session) => {
      const ids: string[] = [];
      for (let index = 0; index < 40; index++) {
        ids.push(await outbox.record(probeEvent(`bulk-${index}`), session));
      }
      return ids;
    });
    const secondRelay = new OutboxRelayService(repository, registry, config);
    expect(secondRelay.relayId).not.toBe(relay.relayId);

    const [first, second] = await Promise.all([relay.relayBatch(), secondRelay.relayBatch()]);
    expect(first.published + second.published).toBe(40);
    expect(first.leaseLost + second.leaseLost).toBe(0);

    expect(await queue().getWaitingCount()).toBe(40);
    const stored = await connection
      .collection('outbox_events')
      .find({ eventId: { $in: eventIds } })
      .toArray();
    expect(stored.every((event) => event.status === 'PUBLISHED' && event.attempts === 1)).toBe(
      true,
    );
  });

  it('failed publish → PENDING with error and back-off → FAILED at the limit → requeue → PUBLISHED', async () => {
    const eventId = await record('failure');
    const deadRegistry = new QueueRegistry(
      testConfig({ QUEUE_PREFIX: prefix, REDIS_URL: UNREACHABLE_REDIS_URL }),
    );
    const failingRelay = new OutboxRelayService(repository, deadRegistry, config);
    const events = connection.collection('outbox_events');
    try {
      const before = Date.now();
      await expect(failingRelay.relayBatch()).resolves.toMatchObject({ retried: 1, published: 0 });
      const retrying = await repository.findByEventId(eventId);
      expect(retrying).toMatchObject({ status: 'PENDING', attempts: 1, publishedAt: null });
      expect(retrying?.lastError).toEqual(expect.any(String));
      expect(retrying!.availableAt.getTime()).toBeGreaterThanOrEqual(before + 1_000); // back-off

      // Not due yet: the back-off is respected
      await expect(failingRelay.relayBatch()).resolves.toMatchObject({ retried: 0, failed: 0 });

      await events.updateOne({ eventId }, { $set: { availableAt: new Date() } });
      await expect(failingRelay.relayBatch()).resolves.toMatchObject({ failed: 1 });
      expect(await repository.findByEventId(eventId)).toMatchObject({
        status: 'FAILED',
        attempts: 2,
      });
      expect((await repository.stats(new Date())).failed).toBe(1);
    } finally {
      await deadRegistry.onApplicationShutdown();
    }

    // Never lost: an operator requeues it and the healthy relay publishes it
    expect(await repository.requeueFailed(eventId, new Date())).toBe(true);
    await expect(relay.relayBatch()).resolves.toMatchObject({ published: 1 });
    expect(await repository.findByEventId(eventId)).toMatchObject({ status: 'PUBLISHED' });
    expect(await queue().getJob(eventId)).toBeDefined();
  });

  it('reports the backlog for readiness', async () => {
    await record('stats-1');
    await record('stats-2');
    await new Promise((resolve) => setTimeout(resolve, 20));
    const stats = await repository.stats(new Date());
    expect(stats.pending).toBe(2);
    expect(stats.failed).toBe(0);
    expect(stats.oldestPendingAgeMs).toBeGreaterThanOrEqual(20);
  });

  it('rejects a duplicate eventId at the database level', async () => {
    const eventId = await record('duplicate');
    const original = await repository.findByEventId(eventId);
    await expect(
      runner.run((session) =>
        repository.insert({ ...original!, _id: undefined } as never, session),
      ),
    ).rejects.toMatchObject({ code: 11000 });
  });
});
