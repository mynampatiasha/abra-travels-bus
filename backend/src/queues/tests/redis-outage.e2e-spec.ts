import { execSync } from 'node:child_process';
import { getConnectionToken } from '@nestjs/mongoose';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import { Worker } from 'bullmq';
import { Redis } from 'ioredis';
import { type Connection } from 'mongoose';
import request from 'supertest';
import { type App } from 'supertest/types';
import { AppModule } from '../../app.module';
import { validTestEnvironment } from '../../config/tests/valid-test-environment';
import { configureHttpApplication } from '../../configure-http-application';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { OutboxRelayService } from '../../events/outbox-relay.service';
import { OutboxRepository } from '../../events/outbox.repository';
import { OutboxService } from '../../events/outbox.service';
import { bullmqConnectionOptions } from '../bullmq-connection.factory';
import { QueueHealthService } from '../queue-health.service';
import { QUEUE_NAMES } from '../queue-names';
import { QUEUE_RECREATE_INTERVAL_MS, QueueRegistry } from '../queue-registry.service';
import { deleteQueueKeys, testConfig, uniqueQueuePrefix, waitFor } from './queue-test-support';

/**
 * Real outage: stops and restarts the local Docker Redis container (abra-redis). Redis data is
 * persisted (AOF volume), and afterAll always brings Redis back. Runs serially (--runInBand).
 */
const REDIS_CONTAINER = 'abra-redis';
const REDIS_URL = 'redis://localhost:6379';

// execSync blocks the event loop, so Jest's own timeout cannot interrupt a stuck docker call:
// every docker command gets a hard timeout and fails loudly instead of hanging the run
const DOCKER_COMMAND_TIMEOUT_MS = 60_000;

function docker(args: string): void {
  execSync(`docker ${args}`, { stdio: 'ignore', timeout: DOCKER_COMMAND_TIMEOUT_MS });
}

function stopRedis(): void {
  docker(`stop --time 5 ${REDIS_CONTAINER}`);
}

async function startRedis(): Promise<void> {
  docker(`start ${REDIS_CONTAINER}`);
  const probe = new Redis(REDIS_URL, { maxRetriesPerRequest: 1, lazyConnect: true });
  probe.on('error', () => undefined);
  try {
    await waitFor(async () => (await probe.ping().catch(() => '')) === 'PONG', 30_000, 200);
  } finally {
    probe.disconnect();
  }
}

describe('Redis outage and recovery (e2e, real Docker Redis restart)', () => {
  const prefix = uniqueQueuePrefix();
  let app: NestExpressApplication;
  let server: App;
  let registry: QueueRegistry;

  beforeAll(async () => {
    Object.assign(
      process.env,
      validTestEnvironment({ QUEUE_PREFIX: prefix, LOG_LEVEL: 'fatal', API_DOCS_ENABLED: 'false' }),
    );
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestExpressApplication>({ logger: false });
    configureHttpApplication(app);
    await app.init();
    server = app.getHttpServer();
    registry = app.get(QueueRegistry);
  }, 60_000);

  afterAll(async () => {
    await startRedis(); // never leave the shared Redis stopped
    await app?.get<Connection>(getConnectionToken()).dropDatabase();
    await app?.close();
    await deleteQueueKeys(REDIS_URL, prefix);
  }, 60_000);

  it('A: queue initialises normally and readiness is 200 while Redis is up', async () => {
    await registry.get(QUEUE_NAMES.DOMAIN_EVENTS).waitUntilReady();
    await request(server).get('/health/ready').expect(200);
  });

  it('C/D: Redis down → readiness 503, liveness 200, fail-fast enqueue; Redis back → recovers', async () => {
    const queue = registry.get(QUEUE_NAMES.DOMAIN_EVENTS);
    stopRedis();
    try {
      const notReady = await request(server).get('/health/ready').expect(503);
      expect(notReady.body).toMatchObject({
        error: {
          code: 'SERVICE_UNAVAILABLE',
          details: { checks: { redis: { status: 'down' }, queues: { status: 'down' } } },
        },
      });
      await request(server).get('/health/live').expect(200);

      const started = Date.now();
      await expect(queue.add('test-probe.recorded', {})).rejects.toThrow();
      expect(Date.now() - started).toBeLessThan(5_000);
    } finally {
      await startRedis();
    }

    // Same (already initialised) queue instance reconnects by itself
    await waitFor(
      async () => (await request(server).get('/health/ready')).status === 200,
      30_000,
      250,
    );
    expect(registry.get(QUEUE_NAMES.DOMAIN_EVENTS)).toBe(queue);
    await expect(queue.add('test-probe.recorded', {})).resolves.toBeDefined();
  });

  it('B/E/F: queue created while Redis is down fails cleanly, is recreated after recovery, without churn', async () => {
    const fresh = new QueueRegistry(testConfig({ QUEUE_PREFIX: prefix }));
    stopRedis();
    const outageStart = Date.now();
    try {
      // B: creation itself does not throw; initialisation fails cleanly in the background
      const broken = fresh.get(QUEUE_NAMES.DOMAIN_EVENTS);
      await expect(broken.waitUntilReady()).rejects.toThrow();

      // F: a relay-like caller hammering the registry for ~3 s of outage
      while (Date.now() - outageStart < 3_000) {
        await fresh
          .get(QUEUE_NAMES.DOMAIN_EVENTS)
          .add('test-probe.recorded', {})
          .catch(() => undefined);
        expect(fresh.size).toBe(1);
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    } finally {
      await startRedis();
    }
    const downFor = Date.now() - outageStart;
    // At most one recreation per interval (plus the original), no matter how many calls
    expect(fresh.instancesCreated).toBeLessThanOrEqual(
      Math.ceil(downFor / QUEUE_RECREATE_INTERVAL_MS) + 2,
    );

    // E: after Redis returns, the registry replaces the broken instance and enqueue works
    await waitFor(
      async () =>
        fresh
          .get(QUEUE_NAMES.DOMAIN_EVENTS)
          .add('test-probe.recorded', { recovered: true })
          .then(() => true)
          .catch(() => false),
      30_000,
      250,
    );
    expect(fresh.size).toBe(1);
    await fresh.onApplicationShutdown();
  });

  it('readiness queue check recovers through registry recreation', async () => {
    const config = testConfig({ QUEUE_PREFIX: prefix });
    const fresh = new QueueRegistry(config);
    const health = new QueueHealthService(fresh, config);
    stopRedis();
    try {
      await expect(health.status()).rejects.toThrow();
      // The queue was created during the outage and its initialisation has failed
      await expect(fresh.get(QUEUE_NAMES.DOMAIN_EVENTS).waitUntilReady()).rejects.toThrow();
    } finally {
      await startRedis();
    }
    await waitFor(
      () =>
        health.status().then(
          () => true,
          () => false,
        ),
      30_000,
      250,
    );
    expect(fresh.instancesCreated).toBeGreaterThanOrEqual(2); // recovered by recreation
    expect(fresh.size).toBe(1);
    await fresh.onApplicationShutdown();
  });

  it('a worker started while Redis is down processes jobs once Redis returns', async () => {
    stopRedis();
    let processed = 0;
    const worker = new Worker(QUEUE_NAMES.DOMAIN_EVENTS, () => Promise.resolve(processed++), {
      connection: bullmqConnectionOptions(REDIS_URL, 'worker'),
      prefix,
    });
    worker.on('error', () => undefined);
    try {
      await new Promise((resolve) => setTimeout(resolve, 1_500));
    } finally {
      await startRedis();
    }
    const queue = registry.get(QUEUE_NAMES.DOMAIN_EVENTS);
    await waitFor(
      () =>
        queue.add('test-probe.recorded', {}).then(
          () => true,
          () => false,
        ),
      30_000,
      250,
    );
    await waitFor(() => processed > 0, 30_000, 100);
    await worker.close();
  });

  it('an event recorded during the outage stays PENDING with the error, then is published after recovery', async () => {
    const runner = app.get(TransactionRunner);
    const outbox = app.get(OutboxService);
    const relay = app.get(OutboxRelayService);
    const repository = app.get(OutboxRepository);

    stopRedis();
    let eventId = '';
    try {
      // MongoDB is unaffected: the event is committed even though Redis is down
      eventId = await runner.run((session) =>
        outbox.record(
          {
            type: 'test-probe.recorded',
            aggregateType: 'test-probe',
            aggregateId: 'outage',
            payload: {},
          },
          session,
        ),
      );
      const result = await relay.relayBatch();
      expect(result.retried).toBeGreaterThanOrEqual(1);
      const pending = await repository.findByEventId(eventId);
      expect(pending).toMatchObject({ status: 'PENDING', attempts: 1 });
      expect(pending?.lastError).toEqual(expect.any(String));
    } finally {
      await startRedis();
    }

    // Make the scheduled retry due now, then relay again
    await app
      .get<Connection>(getConnectionToken())
      .collection('outbox_events')
      .updateOne({ eventId }, { $set: { availableAt: new Date() } });
    await waitFor(
      async () => {
        await relay.relayBatch().catch(() => undefined);
        return (await repository.findByEventId(eventId))?.status === 'PUBLISHED';
      },
      30_000,
      250,
    );
    expect(await registry.get(QUEUE_NAMES.DOMAIN_EVENTS).getJob(eventId)).toBeDefined();
  });
});
