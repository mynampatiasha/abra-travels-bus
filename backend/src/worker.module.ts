import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';
import { createLoggerOptions } from './common/logging/logger-options.factory';
import { AppConfigModule } from './config/app-config.module';
import { AppConfigService } from './config/app-config.service';
import { DatabaseModule } from './database/database.module';
import { EventsModule } from './events/events.module';
import { DOMAIN_MODULES } from './modules/domain-modules';
import { QueueModule } from './queues/queue.module';
import { RedisModule } from './redis/redis.module';
import { WorkersModule } from './workers/workers.module';

/**
 * Root module of the worker process (`node dist/worker.js`): same codebase and image as the API,
 * no HTTP server. Domain modules are imported so they can register their event handlers.
 */
@Module({
  imports: [
    AppConfigModule,
    LoggerModule.forRootAsync({ inject: [AppConfigService], useFactory: createLoggerOptions }),
    DatabaseModule,
    RedisModule,
    QueueModule,
    EventsModule,
    WorkersModule,
    ...DOMAIN_MODULES,
  ],
})
export class WorkerModule {}
