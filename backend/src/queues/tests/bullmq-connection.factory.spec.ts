import { type AppConfigService } from '../../config/app-config.service';
import { bullmqConnectionOptions, defaultJobOptions } from '../bullmq-connection.factory';
import { ALL_QUEUE_NAMES, QUEUE_NAMES } from '../queue-names';

describe('bullmqConnectionOptions', () => {
  const url = 'redis://localhost:6379';

  it('lets producer commands fail after one reconnect attempt, keeping the offline queue', () => {
    const options = bullmqConnectionOptions(url, 'producer');
    expect(options).toEqual({
      url,
      connectionName: 'abra-travels-bullmq-producer',
      maxRetriesPerRequest: 1,
    });
    // enableOfflineQueue: false breaks BullMQ's initial INFO check (see factory comment)
    expect(options).not.toHaveProperty('enableOfflineQueue');
  });

  it('gives workers the blocking-safe settings BullMQ requires', () => {
    expect(bullmqConnectionOptions(url, 'worker')).toEqual({
      url,
      connectionName: 'abra-travels-bullmq-worker',
      maxRetriesPerRequest: null,
    });
  });
});

describe('defaultJobOptions', () => {
  it('uses the configured attempts and exponential back-off, and keeps job history bounded', () => {
    const values: Record<string, number> = {
      QUEUE_DEFAULT_ATTEMPTS: 5,
      QUEUE_BACKOFF_DELAY_MS: 5000,
    };
    const config = { get: (key: string) => values[key] } as unknown as AppConfigService;

    expect(defaultJobOptions(config)).toEqual({
      attempts: 5,
      backoff: { type: 'exponential', delay: 5000 },
      removeOnComplete: { age: 86_400, count: 10_000 },
      removeOnFail: { age: 604_800 },
    });
  });
});

describe('queue names', () => {
  it('are unique and never contain the BullMQ key separator', () => {
    expect(new Set(ALL_QUEUE_NAMES).size).toBe(ALL_QUEUE_NAMES.length);
    expect(ALL_QUEUE_NAMES.every((name) => !name.includes(':'))).toBe(true);
    expect(ALL_QUEUE_NAMES).toContain(QUEUE_NAMES.DOMAIN_EVENTS);
  });
});
