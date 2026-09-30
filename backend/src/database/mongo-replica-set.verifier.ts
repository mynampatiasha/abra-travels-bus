import { Injectable, Logger } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection } from 'mongoose';

interface HelloResponse {
  setName?: string;
  isWritablePrimary?: boolean;
  logicalSessionTimeoutMinutes?: number;
}

/**
 * Seat locking and booking confirmation rely on multi-document transactions, which MongoDB only
 * supports on a replica set. Fail safe: refuse to start against a standalone server rather than
 * run without transactions.
 */
@Injectable()
export class MongoReplicaSetVerifier {
  private readonly logger = new Logger(MongoReplicaSetVerifier.name);

  constructor(@InjectConnection() private readonly connection: Connection) {}

  async verify(): Promise<void> {
    const database = this.connection.db;
    if (!database) throw new Error('MongoDB connection is not open');

    const hello = (await database.admin().command({ hello: 1 })) as HelloResponse;
    if (!hello.setName || hello.logicalSessionTimeoutMinutes === undefined) {
      throw new Error(
        'MongoDB is not running as a replica set; transactions are unavailable. ' +
          'Start infrastructure/docker-compose.development.yml (replica set rs0).',
      );
    }
    this.logger.log(
      { replicaSet: hello.setName, writablePrimary: hello.isWritablePrimary === true },
      'MongoDB replica set verified',
    );
  }
}
