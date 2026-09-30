import { type Redis } from 'ioredis';
import { ConnectionStates, type Connection } from 'mongoose';
import { ReadinessCheckService } from '../services/readiness-check.service';

function mongoConnection(connected: boolean): Connection {
  return {
    readyState: connected ? ConnectionStates.connected : ConnectionStates.disconnected,
    db: connected ? { command: jest.fn().mockResolvedValue({ ok: 1 }) } : undefined,
  } as unknown as Connection;
}

function redisClient(ping: () => Promise<string>): Redis {
  return { ping } as unknown as Redis;
}

describe('ReadinessCheckService', () => {
  it('is ready when MongoDB and Redis both answer', async () => {
    const service = new ReadinessCheckService(
      mongoConnection(true),
      redisClient(() => Promise.resolve('PONG')),
    );
    const report = await service.check();
    expect(report.ready).toBe(true);
    expect(report.checks.mongodb.status).toBe('up');
    expect(report.checks.redis.status).toBe('up');
  });

  it('is not ready when Redis fails, and reports why', async () => {
    const service = new ReadinessCheckService(
      mongoConnection(true),
      redisClient(() => Promise.reject(new Error('Connection is closed.'))),
    );
    const report = await service.check();
    expect(report.ready).toBe(false);
    expect(report.checks.redis).toMatchObject({ status: 'down', reason: 'Connection is closed.' });
  });

  it('is not ready when MongoDB is disconnected', async () => {
    const service = new ReadinessCheckService(
      mongoConnection(false),
      redisClient(() => Promise.resolve('PONG')),
    );
    const report = await service.check();
    expect(report.ready).toBe(false);
    expect(report.checks.mongodb).toMatchObject({ status: 'down', reason: 'not connected' });
  });
});
