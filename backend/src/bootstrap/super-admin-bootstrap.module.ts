import { Module } from '@nestjs/common';
import { LoggerModule } from 'nestjs-pino';
import { CryptoModule } from '../common/crypto/crypto.module';
import { createLoggerOptions } from '../common/logging/logger-options.factory';
import { AppConfigModule } from '../config/app-config.module';
import { AppConfigService } from '../config/app-config.service';
import { DatabaseModule } from '../database/database.module';
import { AuditLogsModule } from '../modules/audit-logs/audit-logs.module';
import { PasswordHasher } from '../modules/authentication/services/password-hasher.service';
import { RbacModule } from '../modules/rbac/rbac.module';
import { UsersModule } from '../modules/users/users.module';
import { SuperAdminBootstrapService } from './super-admin-bootstrap.service';

/**
 * What the bootstrap command needs and nothing more: configuration, the database, users, roles
 * (which also synchronises the system roles at start-up) and the audit trail. No HTTP server, no
 * Redis, no queues.
 */
@Module({
  imports: [
    AppConfigModule,
    LoggerModule.forRootAsync({ inject: [AppConfigService], useFactory: createLoggerOptions }),
    DatabaseModule,
    CryptoModule,
    UsersModule,
    AuditLogsModule,
    RbacModule,
  ],
  providers: [PasswordHasher, SuperAdminBootstrapService],
  exports: [SuperAdminBootstrapService],
})
export class SuperAdminBootstrapModule {}
