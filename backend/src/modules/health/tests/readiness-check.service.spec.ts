import { type Redis } from 'ioredis';
import { ConnectionStates, type Connection } from 'mongoose';
import { type AppConfigService } from '../../../config/app-config.service';
import { type OutboxRepository, type OutboxStats } from '../../../events/outbox.repository';
import { type QueueHealthService, type QueueStatus } from '../../../queues/queue-health.service';
import { ReadinessCheckService } from '../services/readiness-check.service';

function mongoConnection(connected: boolean): Connection {
  return {
    readyState: connected ? ConnectionStates.connected : ConnectionStates.disconnected,
    db: connected ? { command: jest.fn().mockResolvedValue({ ok: 1 }) } : undefined,
  } as unknown as Connection;
}

const healthyQueue: QueueStatus = {
  waiting: 0,
  active: 0,
  delayed: 0,
  failed: 0,
  oldestWaitingAgeMs: 0,
  lagging: false,
  workers: 1,
};
const healthyOutbox: OutboxStats = { pending: 0, failed: 0, oldestPendingAgeMs: 0 };

interface Overrides {
  mongoConnected?: boolean;
  redisPing?: () => Promise<string>;
  queueStatus?: () => Promise<Record<string, QueueStatus>>;
  outboxStats?: () => Promise<OutboxStats>;
}

function serviceWith(overrides: Overrides = {}): ReadinessCheckService {
  const redis = { ping: overrides.redisPing ?? (() => Promise.resolve('PONG')) };
  const queues = {
    status: overrides.queueStatus ?? (() => Promise.resolve({ 'domain-events': healthyQueue })),
  };
  const outbox = { stats: overrides.outboxStats ?? (() => Promise.resolve(healthyOutbox)) };
  const config = { get: () => 60_000 };
  return new ReadinessCheckService(
    mongoConnection(overrides.mongoConnected ?? true),
    redis as unknown as Redis,
    queues as unknown as QueueHealthService,
    outbox as unknown as OutboxRepository,
    config as unknown as AppConfigService,
  );
}

describe('ReadinessCheckService', () => {
  it('is ready when MongoDB, Redis, queues and outbox all answer', async () => {
    const report = await serviceWith().check();
    expect(report.ready).toBe(true);
    expect(report.warnings).toEqual([]);
    expect(report.checks.queues.details).toEqual({ 'domain-events': healthyQueue });
    expect(report.checks.outbox.details).toEqual({ ...healthyOutbox, lagging: false });
  });

  it('is not ready during a Redis outage (Redis and queue checks both down)', async () => {
    const closed = (): Promise<never> => Promise.reject(new Error('Connection is closed.'));
    const report = await serviceWith({ redisPing: closed, queueStatus: closed }).check();
    expect(report.ready).toBe(false);
    expect(report.checks.redis).toMatchObject({ status: 'down', reason: 'Connection is closed.' });
    expect(report.checks.queues).toMatchObject({ status: 'down' });
  });

  it('is not ready when the queue check alone fails', async () => {
    const report = await serviceWith({
      queueStatus: () => Promise.reject(new Error('NOSCRIPT')),
    }).check();
    expect(report.ready).toBe(false);
    expect(report.checks.redis.status).toBe('up');
  });

  it('is not ready when MongoDB is disconnected', async () => {
    const report = await serviceWith({ mongoConnected: false }).check();
    expect(report.ready).toBe(false);
    expect(report.checks.mongodb).toMatchObject({ status: 'down', reason: 'not connected' });
  });

  it('reports worker-side problems as warnings without failing readiness', async () => {
    const report = await serviceWith({
      queueStatus: () =>
        Promise.resolve({
          'domain-events': {
            ...healthyQueue,
            workers: 0,
            waiting: 12,
            oldestWaitingAgeMs: 90_000,
            lagging: true,
            failed: 2,
          },
        }),
      outboxStats: () => Promise.resolve({ pending: 4, failed: 1, oldestPendingAgeMs: 120_000 }),
    }).check();

    expect(report.ready).toBe(true);
    expect(report.checks.outbox.details?.lagging).toBe(true);
    expect(report.warnings).toEqual([
      'queue domain-events: no worker connected',
      'queue domain-events: oldest waiting job exceeds lag threshold',
      'queue domain-events: 2 failed job(s)',
      'outbox: oldest unpublished event exceeds lag threshold',
      'outbox: 1 FAILED event(s)',
    ]);
  });

  it('times out a hanging dependency instead of hanging the probe', async () => {
    jest.useFakeTimers();
    try {
      const pending = serviceWith({ queueStatus: () => new Promise(() => undefined) }).check();
      await jest.advanceTimersByTimeAsync(2_100);
      const report = await pending;
      expect(report.checks.queues).toMatchObject({ status: 'down', reason: 'timed out' });
    } finally {
      jest.useRealTimers();
    }
  });
});
