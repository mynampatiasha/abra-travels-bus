import { Injectable, type OnApplicationBootstrap } from '@nestjs/common';
import { IndexBootstrapService } from './index-bootstrap.service';
import { MongoReplicaSetVerifier } from './mongo-replica-set.verifier';

/**
 * Start-up order matters: confirm transactions are available, then build indexes. Runs after all
 * modules are initialised, so every module's schemas are registered. Any failure stops start-up.
 */
@Injectable()
export class DatabaseStartupService implements OnApplicationBootstrap {
  constructor(
    private readonly replicaSetVerifier: MongoReplicaSetVerifier,
    private readonly indexBootstrap: IndexBootstrapService,
  ) {}

  async onApplicationBootstrap(): Promise<void> {
    await this.replicaSetVerifier.verify();
    await this.indexBootstrap.ensureIndexes();
  }
}
