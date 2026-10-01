import { closeRedisClient } from '../close-redis-client';

type Status = 'wait' | 'connecting' | 'connect' | 'ready' | 'reconnecting' | 'close' | 'end';

function fakeClient(status: Status, quit: () => Promise<'OK'>) {
  const client = {
    status,
    quit: jest.fn(async () => {
      const reply = await quit();
      client.status = 'end';
      return reply;
    }),
    disconnect: jest.fn(() => {
      client.status = 'end';
    }),
  };
  return client;
}

describe('closeRedisClient', () => {
  it('closes a connected client gracefully with QUIT', async () => {
    const client = fakeClient('ready', () => Promise.resolve('OK'));
    await closeRedisClient(client);
    expect(client.quit).toHaveBeenCalledTimes(1);
    expect(client.disconnect).not.toHaveBeenCalled();
    expect(client.status).toBe('end');
  });

  it.each<Status>(['reconnecting', 'connecting', 'connect', 'wait', 'close'])(
    'disconnects (cancelling reconnection) a client that is %s instead of sending QUIT',
    async (status) => {
      const client = fakeClient(status, () => Promise.resolve('OK'));
      await closeRedisClient(client);
      expect(client.quit).not.toHaveBeenCalled();
      expect(client.disconnect).toHaveBeenCalledTimes(1);
    },
  );

  it('disconnects when QUIT is rejected', async () => {
    const client = fakeClient('ready', () =>
      Promise.reject(new Error("Stream isn't writeable and enableOfflineQueue options is false")),
    );
    await closeRedisClient(client);
    expect(client.disconnect).toHaveBeenCalledTimes(1);
  });

  it('disconnects when QUIT does not answer in time', async () => {
    const client = fakeClient('ready', () => new Promise(() => undefined));
    const started = Date.now();
    await closeRedisClient(client, 50);
    expect(Date.now() - started).toBeLessThan(1_000);
    expect(client.disconnect).toHaveBeenCalledTimes(1);
  });

  it('does nothing for a client that is already closed', async () => {
    const client = fakeClient('end', () => Promise.resolve('OK'));
    await closeRedisClient(client);
    expect(client.quit).not.toHaveBeenCalled();
    expect(client.disconnect).not.toHaveBeenCalled();
  });
});
