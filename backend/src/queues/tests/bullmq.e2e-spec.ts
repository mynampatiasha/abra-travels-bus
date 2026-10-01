import { Logger } from '@nestjs/common';
import { type Job, type Processor, UnrecoverableError, Worker } from 'bullmq';
import { Redis } from 'ioredis';
import { bullmqConnectionOptions } from '../bullmq-connection.factory';
import { QueueHealthService } from '../queue-health.service';
import { QUEUE_NAMES } from '../queue-names';
import { QueueRegistry } from '../queue-registry.service';
import {
  deleteQueueKeys,
  testConfig,
  uniqueQueuePrefix,
  UNREACHABLE_REDIS_URL,
  waitFor,
} from './queue-test-support';

/** BullMQ behaviour against the real Docker Redis, through the project's own queue layer. */
describe('BullMQ queues (e2e, real Redis)', () => {
  const prefix = uniqueQueuePrefix();
  const config = testConfig({
    QUEUE_PREFIX: prefix,
    QUEUE_DEFAULT_ATTEMPTS: '2',
    QUEUE_BACKOFF_DELAY_MS: '50',
  });
  const registry = new QueueRegistry(config);
  const queue = registry.get(QUEUE_NAMES.DOMAIN_EVENTS);
  let worker: Worker | undefined;

  function startWorker(processor: Processor): Worker {
    worker = new Worker(QUEUE_NAMES.DOMAIN_EVENTS, processor, {
      connection: bullmqConnectionOptions(config.get('REDIS_URL'), 'worker'),
      prefix,
      concurrency: 2,
    });
    return worker;
  }

  async function finalState(job: Job): Promise<string> {
    let state = '';
    await waitFor(async () => {
      state = await queue.getJobState(job.id!);
      return state === 'completed' || state === 'failed';
    });
    return state;
  }

  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  afterEach(async () => {
    await worker?.close();
    worker = undefined;
    await queue.obliterate({ force: true });
  });

  afterAll(async () => {
    await registry.onApplicationShutdown();
    await deleteQueueKeys(config.get('REDIS_URL'), prefix);
  });

  it('connects to Redis and namespaces keys with QUEUE_PREFIX', async () => {
    await queue.waitUntilReady();
    await queue.add('test-probe.recorded', { n: 1 }, { jobId: 'prefix-check' });
    const redis = new Redis(config.get('REDIS_URL'));
    try {
      expect(await redis.exists(`${prefix}:${QUEUE_NAMES.DOMAIN_EVENTS}:prefix-check`)).toBe(1);
    } finally {
      redis.disconnect();
    }
  });

  it('creates each queue once and applies the default job options', async () => {
    expect(registry.get(QUEUE_NAMES.DOMAIN_EVENTS)).toBe(queue);
    const job = await queue.add('test-probe.recorded', {});
    expect(job.opts).toMatchObject({ attempts: 2, backoff: { type: 'exponential', delay: 50 } });
  });

  it('enqueues a job and a worker processes it', async () => {
    startWorker((job: Job<{ n: number }>) => Promise.resolve({ doubled: job.data.n * 2 }));
    const job = await queue.add('test-probe.recorded', { n: 21 });

    expect(await finalState(job)).toBe('completed');
    expect((await queue.getJob(job.id!))?.returnvalue).toEqual({ doubled: 42 });
  });

  it('retries a failed job with back-off and completes on the next attempt', async () => {
    let calls = 0;
    startWorker(() => {
      calls++;
      return calls === 1 ? Promise.reject(new Error('transient')) : Promise.resolve('ok');
    });
    const job = await queue.add('test-probe.recorded', {});

    expect(await finalState(job)).toBe('completed');
    expect(calls).toBe(2);
  });

  it('marks a job failed after the attempt limit and keeps it for inspection', async () => {
    let calls = 0;
    startWorker(() => {
      calls++;
      return Promise.reject(new Error('permanent problem'));
    });
    const job = await queue.add('test-probe.recorded', {});

    expect(await finalState(job)).toBe('failed');
    expect(calls).toBe(2);
    const failed = await queue.getJob(job.id!);
    expect(failed?.failedReason).toBe('permanent problem');
    expect(failed?.attemptsMade).toBe(2);
  });

  it('does not retry an UnrecoverableError', async () => {
    let calls = 0;
    startWorker(() => {
      calls++;
      return Promise.reject(new UnrecoverableError('malformed'));
    });
    const job = await queue.add('test-probe.recorded', {});
    expect(await finalState(job)).toBe('failed');
    expect(calls).toBe(1);
  });

  it('ignores a second add with the same jobId (idempotent enqueue)', async () => {
    const first = await queue.add('test-probe.recorded', { v: 1 }, { jobId: 'evt-same' });
    const second = await queue.add('test-probe.recorded', { v: 2 }, { jobId: 'evt-same' });

    expect(second.id).toBe(first.id);
    expect(await queue.getWaitingCount()).toBe(1);
    expect((await queue.getJob('evt-same'))?.data).toEqual({ v: 1 });

    let calls = 0;
    startWorker(() => Promise.resolve(calls++));
    await waitFor(async () => (await queue.getCompletedCount()) === 1);
    expect(calls).toBe(1);
  });

  it('reports depth, lag and connected workers for readiness', async () => {
    const health = new QueueHealthService(registry, config);
    await queue.add('test-probe.recorded', {});
    await queue.add('test-probe.recorded', {});
    await new Promise((resolve) => setTimeout(resolve, 30));

    const idle = (await health.status())[QUEUE_NAMES.DOMAIN_EVENTS];
    expect(idle).toMatchObject({ waiting: 2, workers: 0, lagging: false });
    expect(idle.oldestWaitingAgeMs).toBeGreaterThanOrEqual(30);

    const lagConfig = testConfig({ QUEUE_PREFIX: prefix, QUEUE_LAG_ALERT_MS: '10' });
    const lagging = (await new QueueHealthService(registry, lagConfig).status())[
      QUEUE_NAMES.DOMAIN_EVENTS
    ];
    expect(lagging.lagging).toBe(true);

    startWorker(() => Promise.resolve());
    await worker!.waitUntilReady();
    await waitFor(async () => (await health.status())[QUEUE_NAMES.DOMAIN_EVENTS].workers >= 1);
  });

  it('fails fast (no hang, no in-memory buffering) when Redis is unreachable', async () => {
    const deadRegistry = new QueueRegistry(
      testConfig({ QUEUE_PREFIX: prefix, REDIS_URL: UNREACHABLE_REDIS_URL }),
    );
    try {
      const started = Date.now();
      await expect(
        deadRegistry.get(QUEUE_NAMES.DOMAIN_EVENTS).add('test-probe.recorded', {}),
      ).rejects.toThrow();
      expect(Date.now() - started).toBeLessThan(2_000);

      const deadHealth = new QueueHealthService(deadRegistry, config);
      await expect(deadHealth.status()).rejects.toThrow();
    } finally {
      await deadRegistry.onApplicationShutdown();
    }
  });
});
