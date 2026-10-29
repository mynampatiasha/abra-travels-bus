import { Inject, Injectable, type INestApplicationContext } from '@nestjs/common';
import { IoAdapter } from '@nestjs/platform-socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { Emitter } from '@socket.io/redis-emitter';
import { Redis } from 'ioredis';
import { REDIS_CLIENT } from '../../../redis/redis.module';

/** The room every connection of one person joins. */
export const userRoom = (userId: string): string => `user:${userId}`;

/** Name of the event a client listens to. */
export const NOTIFICATION_EVENT = 'notification';

/**
 * Tells people who have the app open, instantly. It publishes to Redis, so it works from the worker
 * process (which handles domain events) as well as from the API: the API's sockets receive it
 * through the Redis adapter. It is only a nudge: the notification is already stored, so nothing is
 * lost for someone who is offline.
 */
@Injectable()
export class RealtimeEmitter {
  private readonly emitter: Emitter;

  constructor(@Inject(REDIS_CLIENT) redis: Redis) {
    this.emitter = new Emitter(redis);
  }

  emitToUser(userId: string, payload: Record<string, unknown>): void {
    this.emitter.to(userRoom(userId)).emit(NOTIFICATION_EVENT, payload);
  }
}

/**
 * Socket.IO for the API: only the configured web origins may connect, and several API instances
 * share their rooms through Redis, so a message published by the worker reaches the right browser
 * whichever instance it is connected to.
 */
export class RedisIoAdapter extends IoAdapter {
  private readonly clients: Redis[] = [];

  constructor(
    app: INestApplicationContext,
    private readonly redisUrl: string,
    private readonly origins: readonly string[],
  ) {
    super(app);
  }

  override createIOServer(
    port: number,
    options?: Parameters<IoAdapter['createIOServer']>[1],
  ): ReturnType<IoAdapter['createIOServer']> {
    const server = super.createIOServer(port, {
      ...options,
      cors: { origin: [...this.origins], credentials: true },
    } as never);
    const publisher = new Redis(this.redisUrl, {
      connectionName: 'abra-socket-pub',
      maxRetriesPerRequest: null,
    });
    const subscriber = publisher.duplicate({
      connectionName: 'abra-socket-sub',
      maxRetriesPerRequest: null,
    });
    for (const client of [publisher, subscriber]) {
      client.on('error', () => undefined);
      this.clients.push(client);
    }
    server.adapter(createAdapter(publisher, subscriber) as never);
    return server;
  }

  override async close(server: Parameters<IoAdapter['close']>[0]): Promise<void> {
    await super.close(server);
    await Promise.all(this.clients.map((client) => client.quit().catch(() => 'closed')));
  }
}
