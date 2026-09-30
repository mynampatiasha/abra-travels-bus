import { Global, Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AppConfigService } from '../config/app-config.service';
import { DatabaseStartupService } from './database-startup.service';
import { IndexBootstrapService } from './index-bootstrap.service';
import { MongoReplicaSetVerifier } from './mongo-replica-set.verifier';
import { TransactionRunner } from './transaction-runner.service';

/**
 * MongoDB connection (source of truth) and the transaction layer shared by all modules.
 * `autoIndex` is off: IndexBootstrapService builds indexes once, awaited, at start-up.
 * Tenant repositories extend ScopedRepository (scoped-repository.base.ts).
 */
@Global()
@Module({
  imports: [
    MongooseModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => ({
        uri: config.get('MONGODB_URI'),
        autoIndex: false,
        autoCreate: false,
        serverSelectionTimeoutMS: 10_000,
        appName: 'abra-travels-backend',
      }),
    }),
  ],
  providers: [
    MongoReplicaSetVerifier,
    IndexBootstrapService,
    DatabaseStartupService,
    TransactionRunner,
  ],
  exports: [TransactionRunner],
})
export class DatabaseModule {}
