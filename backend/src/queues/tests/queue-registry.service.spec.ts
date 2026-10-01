import { Logger } from '@nestjs/common';
import { type AppConfigService } from '../../config/app-config.service';
import { QUEUE_NAMES } from '../queue-names';
import { QUEUE_RECREATE_INTERVAL_MS, QueueRegistry } from '../queue-registry.service';

/**
 * BullMQ's Queue is replaced by a controllable fake so initialisation success / failure and
 * recreation timing can be driven exactly. Real-Redis behaviour is covered by the e2e suites.
 */
interface FakeQueue {
  name: string;
  options: Record<string, unknown>;
  closed: boolean;
  listeners: Record<string, number>;
  resolveReady: () => void;
  rejectReady: (error: Error) => void;
}

const created: FakeQueue[] = [];

jest.mock('bullmq', () => ({
  Queue: jest.fn().mockImplementation((name: string, options: Record<string, unknown>) => {
    let resolveReady!: () => void;
    let rejectReady!: (error: Error) => void;
    const ready = new Promise<void>((resolve, reject) => {
      resolveReady = resolve;
      rejectReady = reject;
    });
    const fake: FakeQueue & Record<string, unknown> = {
      name,
      options,
      closed: false,
      listeners: {},
      resolveReady,
      rejectReady,
      on(event: string) {
        fake.listeners[event] = (fake.listeners[event] ?? 0) + 1;
        return fake;
      },
      waitUntilReady: () => ready,
      close: jest.fn(() => {
        fake.closed = true;
        return Promise.resolve();
      }),
    };
    created.push(fake);
    return fake;
  }),
}));

const flush = (): Promise<void> => new Promise((resolve) => setImmediate(resolve));

/** Moves the registry's clock (Date.now) without faking timers used by the test itself. */
function setNow(ms: number): void {
  jest.spyOn(Date, 'now').mockReturnValue(ms);
}

function registry(): QueueRegistry {
  const values: Record<string, unknown> = {
    QUEUE_PREFIX: 'abra',
    REDIS_URL: 'redis://localhost:6379',
    QUEUE_DEFAULT_ATTEMPTS: 5,
    QUEUE_BACKOFF_DELAY_MS: 5000,
  };
  return new QueueRegistry({ get: (key: string) => values[key] } as unknown as AppConfigService);
}

describe('QueueRegistry', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  beforeEach(() => {
    created.length = 0;
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('A: creates one queue per name with prefix, defaults and a fail-fast producer connection', () => {
    const queues = registry();
    const first = queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
    expect(queues.get(QUEUE_NAMES.DOMAIN_EVENTS)).toBe(first);
    expect(created).toHaveLength(1);
    expect(created[0]!.options).toMatchObject({
      prefix: 'abra',
      skipWaitingForReady: true,
      connection: { url: 'redis://localhost:6379', maxRetriesPerRequest: 1 },
      defaultJobOptions: { attempts: 5 },
    });
    expect(created[0]!.listeners.error).toBe(1);
  });

  it('keeps a successfully initialised queue (it reconnects by itself after an outage)', async () => {
    const queues = registry();
    const queue = queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
    created[0]!.resolveReady();
    await flush();
    setNow(Date.now() + 60_000);
    expect(queues.get(QUEUE_NAMES.DOMAIN_EVENTS)).toBe(queue);
    expect(queues.instancesCreated).toBe(1);
  });

  it('B/E: replaces a queue whose initialisation failed, closing the broken instance', async () => {
    const queues = registry();
    const broken = queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
    created[0]!.rejectReady(new Error('Reached the max retries per request limit'));
    await flush();

    setNow(Date.now() + QUEUE_RECREATE_INTERVAL_MS);
    const fresh = queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
    expect(fresh).not.toBe(broken);
    expect(created[0]!.closed).toBe(true);
    expect(queues.size).toBe(1);
    expect(queues.instancesCreated).toBe(2);
  });

  it('does not recreate a failed queue more than once per interval', async () => {
    const queues = registry();
    const broken = queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
    created[0]!.rejectReady(new Error('down'));
    await flush();

    // Immediately after the failure: still the same instance (calls fail fast, no churn)
    for (let call = 0; call < 50; call++)
      expect(queues.get(QUEUE_NAMES.DOMAIN_EVENTS)).toBe(broken);
    expect(queues.instancesCreated).toBe(1);
  });

  it('F: repeated failed recoveries never hold more than one live instance per queue', async () => {
    const queues = registry();
    let now = Date.now();
    for (let round = 0; round < 10; round++) {
      queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
      created.at(-1)!.rejectReady(new Error('still down'));
      await flush();
      now += QUEUE_RECREATE_INTERVAL_MS;
      setNow(now);
    }
    queues.get(QUEUE_NAMES.DOMAIN_EVENTS);
    created.at(-1)!.resolveReady();
    await flush();

    expect(queues.size).toBe(1);
    expect(queues.instancesCreated).toBe(11);
    // Every replaced instance was closed; only the current one is open
    expect(created.filter((queue) => !queue.closed)).toHaveLength(1);
    // One error listener per instance (no accumulation on a shared object)
    expect(created.every((queue) => queue.listeners.error === 1)).toBe(true);
  });

  it('closes every queue on shutdown and refuses new queues afterwards', async () => {
    const queues = registry();
    queues.all();
    await queues.onApplicationShutdown();
    expect(created.every((queue) => queue.closed)).toBe(true);
    expect(queues.size).toBe(0);
    expect(() => queues.get(QUEUE_NAMES.DOMAIN_EVENTS)).toThrow('shut down');
  });
});
