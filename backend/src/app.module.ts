import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';
import { createLoggerOptions } from './common/logging/logger-options.factory';
import { AppConfigModule } from './config/app-config.module';
import { AppConfigService } from './config/app-config.service';
import { DatabaseModule } from './database/database.module';
import { DOMAIN_MODULES } from './modules/domain-modules';
import { HealthModule } from './modules/health/health.module';
import { RedisModule } from './redis/redis.module';

@Module({
  imports: [
    AppConfigModule,
    LoggerModule.forRootAsync({ inject: [AppConfigService], useFactory: createLoggerOptions }),
    DatabaseModule,
    RedisModule,
    HealthModule,
    ...DOMAIN_MODULES,
  ],
})
export class AppModule {}
