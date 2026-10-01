import { type AppConfigService } from '../../config/app-config.service';
import { QueueHealthService } from '../queue-health.service';
import { type QueueRegistry } from '../queue-registry.service';

function fakeQueue(
  counts: Record<string, number>,
  oldestTimestamp: number | undefined,
  workers: number,
) {
  return {
    getJobCounts: jest.fn().mockResolvedValue(counts),
    getWaiting: jest
      .fn()
      .mockResolvedValue(oldestTimestamp ? [{ timestamp: oldestTimestamp }] : []),
    getWorkersCount: jest.fn().mockResolvedValue(workers),
  };
}

function serviceFor(queue: ReturnType<typeof fakeQueue>): QueueHealthService {
  const registry = { all: () => [{ name: 'domain-events', queue }] } as unknown as QueueRegistry;
  const config = { get: () => 60_000 } as unknown as AppConfigService;
  return new QueueHealthService(registry, config);
}

describe('QueueHealthService', () => {
  const now = 1_000_000_000;

  it('reports depth, workers and no lag for an idle queue', async () => {
    const status = await serviceFor(
      fakeQueue({ waiting: 0, active: 0, delayed: 0, failed: 0 }, undefined, 2),
    ).status(now);
    expect(status['domain-events']).toEqual({
      waiting: 0,
      active: 0,
      delayed: 0,
      failed: 0,
      oldestWaitingAgeMs: 0,
      lagging: false,
      workers: 2,
    });
  });

  it('measures lag from the oldest waiting job and flags it past the threshold', async () => {
    const queue = fakeQueue({ waiting: 3, active: 1, delayed: 0, failed: 1 }, now - 90_000, 0);
    const status = await serviceFor(queue).status(now);
    expect(status['domain-events']).toMatchObject({
      waiting: 3,
      oldestWaitingAgeMs: 90_000,
      lagging: true,
      workers: 0,
    });
    expect(queue.getWaiting).toHaveBeenCalledWith(0, 0);
  });

  it('propagates Redis errors so readiness marks queues down', async () => {
    const queue = fakeQueue({}, undefined, 0);
    queue.getJobCounts.mockRejectedValue(new Error('Connection is closed.'));
    await expect(serviceFor(queue).status(now)).rejects.toThrow('Connection is closed.');
  });
});
