import { Logger } from '@nestjs/common';
import { getConnectionToken } from '@nestjs/mongoose';
import { Test, type TestingModule } from '@nestjs/testing';
import { type Connection } from 'mongoose';
import { validTestEnvironment } from '../../config/tests/valid-test-environment';
import { TransactionRunner } from '../../database/transaction-runner.service';
import {
  type DomainEventHandler,
  DomainEventHandlerRegistry,
} from '../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../events/domain-event.types';
import { OutboxRepository } from '../../events/outbox.repository';
import { OutboxService } from '../../events/outbox.service';
import { QueueHealthService } from '../../queues/queue-health.service';
import { QUEUE_NAMES } from '../../queues/queue-names';
import { QueueRegistry } from '../../queues/queue-registry.service';
import { deleteQueueKeys, uniqueQueuePrefix, waitFor } from '../../queues/tests/queue-test-support';
import { WorkerModule } from '../../worker.module';
import { OutboxRelayWorker } from '../outbox-relay.worker';
import { QueueWorkerHost } from '../queue-worker-host.service';

/**
 * Boots the real WorkerModule (what `node dist/worker.js` runs: no HTTP server) against Docker
 * MongoDB + Redis, with a test-only event handler. Exercises outbox → relay → queue → dispatcher
 * → handler, retries, and graceful shutdown.
 */
describe('Worker process (e2e, real MongoDB + Redis)', () => {
  const prefix = uniqueQueuePrefix();
  const redisUrl = 'redis://localhost:6379';
  let worker: TestingModule;
  let closed = false;
  const received: DomainEventMessage[] = [];
  let failNext = 0;
  let slowJob: { started: boolean; finished: boolean } = { started: false, finished: false };

  const testHandler: DomainEventHandler = {
    name: 'test-probe-handler',
    eventTypes: ['test-probe.recorded'],
    async handle(event) {
      if (event.aggregateId === 'slow') {
        slowJob.started = true;
        await new Promise((resolve) => setTimeout(resolve, 700));
        slowJob.finished = true;
      }
      if (failNext > 0) {
        failNext--;
        throw new Error('simulated handler failure');
      }
      received.push(event);
    },
  };

  const record = (aggregateId: string): Promise<string> =>
    worker
      .get(TransactionRunner)
      .run((session) =>
        worker
          .get(OutboxService)
          .record(
            { type: 'test-probe.recorded', aggregateType: 'test-probe', aggregateId, payload: {} },
            session,
          ),
      );

  beforeAll(async () => {
    Object.assign(
      process.env,
      validTestEnvironment({
        QUEUE_PREFIX: prefix,
        LOG_LEVEL: 'fatal',
        OUTBOX_POLL_INTERVAL_MS: '50',
        QUEUE_DEFAULT_ATTEMPTS: '3',
        QUEUE_BACKOFF_DELAY_MS: '50',
      }),
    );
    Logger.overrideLogger(false);
    worker = await Test.createTestingModule({ imports: [WorkerModule] }).compile();
    worker.get(DomainEventHandlerRegistry).register(testHandler);
    await worker.init(); // runs onApplicationBootstrap: DB checks, indexes, workers, relay loop
  }, 60_000);

  afterAll(async () => {
    if (!closed) await worker?.close();
    // A fresh module only to drop the test database. Closing the module (not just its MongoDB
    // connection) runs every provider's shutdown hook, so the Redis client it opened is released.
    const cleanup = await Test.createTestingModule({ imports: [WorkerModule] }).compile();
    try {
      await cleanup.get<Connection>(getConnectionToken()).dropDatabase();
    } finally {
      await cleanup.close();
    }
    await deleteQueueKeys(redisUrl, prefix);
  }, 60_000);

  it('starts without an HTTP server and connects its BullMQ worker and outbox relay', async () => {
    expect(worker.get(OutboxRelayWorker).isRunning).toBe(true);
    await waitFor(() => worker.get(QueueWorkerHost).runningWorkers === 1);
    await waitFor(
      async () =>
        (await worker.get(QueueHealthService).status())[QUEUE_NAMES.DOMAIN_EVENTS].workers >= 1,
    );
  });

  it('delivers a committed outbox event to its handler exactly once', async () => {
    const eventId = await record('delivery');
    await waitFor(() => received.some((event) => event.eventId === eventId));
    await waitFor(
      async () =>
        (await worker.get(OutboxRepository).findByEventId(eventId))?.status === 'PUBLISHED',
    );

    const job = await worker.get(QueueRegistry).get(QUEUE_NAMES.DOMAIN_EVENTS).getJob(eventId);
    await waitFor(async () => (await job!.getState()) === 'completed');
    const completed = await worker
      .get(QueueRegistry)
      .get(QUEUE_NAMES.DOMAIN_EVENTS)
      .getJob(eventId);
    expect(completed?.returnvalue).toEqual({ eventId, handledBy: ['test-probe-handler'] });

    await new Promise((resolve) => setTimeout(resolve, 300)); // a duplicate would arrive by now
    expect(received.filter((event) => event.eventId === eventId)).toHaveLength(1);
    expect(received.find((event) => event.eventId === eventId)).toMatchObject({
      type: 'test-probe.recorded',
      aggregateId: 'delivery',
      occurredAt: expect.any(String) as unknown,
    });
  });

  it('retries a failing handler with back-off until it succeeds', async () => {
    failNext = 2;
    const eventId = await record('retry');
    await waitFor(() => received.some((event) => event.eventId === eventId), 15_000);
    const job = await worker.get(QueueRegistry).get(QUEUE_NAMES.DOMAIN_EVENTS).getJob(eventId);
    await waitFor(async () => (await job!.getState()) === 'completed');
    const done = await worker.get(QueueRegistry).get(QUEUE_NAMES.DOMAIN_EVENTS).getJob(eventId);
    expect(done?.attemptsMade).toBe(3);
  });

  it('shuts down gracefully: finishes the in-flight job, stops relay and workers, closes queues', async () => {
    slowJob = { started: false, finished: false };
    await record('slow');
    await waitFor(() => slowJob.started);

    await worker.close(); // what SIGTERM triggers via enableShutdownHooks
    closed = true;

    expect(slowJob.finished).toBe(true);
    expect(worker.get(OutboxRelayWorker).isRunning).toBe(false);
    expect(worker.get(QueueWorkerHost).runningWorkers).toBe(0);
    expect(worker.get(QueueRegistry).size).toBe(0);
  });
});
