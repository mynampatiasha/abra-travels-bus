import { Global, Inject, Logger, Module, type OnApplicationShutdown } from '@nestjs/common';
import { Redis } from 'ioredis';
import { AppConfigService } from '../config/app-config.service';
import { closeRedisClient } from './close-redis-client';

/** Injection token for the shared ioredis client (cache, rate limits; BullMQ gets its own). */
export const REDIS_CLIENT = Symbol('REDIS_CLIENT');

/**
 * Redis is cache / rate limits / queues only — never the source of truth for seats or bookings
 * (architecture.md §3). BullMQ connections are configured in Phase 2 step 6.
 */
@Global()
@Module({
  providers: [
    {
      provide: REDIS_CLIENT,
      inject: [AppConfigService],
      useFactory: (config: AppConfigService): Redis => {
        const logger = new Logger('Redis');
        const client = new Redis(config.get('REDIS_URL'), {
          connectionName: 'abra-travels-backend',
          maxRetriesPerRequest: null,
          enableOfflineQueue: false,
          lazyConnect: false,
        });
        // Without a listener ioredis would print raw errors; connection details stay out of logs
        client.on('error', (error: NodeJS.ErrnoException) =>
          logger.warn({ code: error.code, message: error.message }, 'Redis error'),
        );
        return client;
      },
    },
  ],
  exports: [REDIS_CLIENT],
})
export class RedisModule implements OnApplicationShutdown {
  constructor(@Inject(REDIS_CLIENT) private readonly client: Redis) {}

  /** Also safe while Redis is down or the client is reconnecting (see closeRedisClient). */
  onApplicationShutdown(): Promise<void> {
    return closeRedisClient(this.client);
  }
}
