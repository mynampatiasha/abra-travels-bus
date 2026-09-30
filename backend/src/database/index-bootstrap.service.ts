import { Injectable, Logger } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection } from 'mongoose';

export interface IndexBootstrapReport {
  models: string[];
  /** Indexes present in MongoDB but not declared in a schema. Reported, never dropped. */
  undeclaredIndexes: Record<string, string[]>;
}

/**
 * Creates every index declared on the registered Mongoose schemas at start-up
 * (database-architecture.md). Mongoose `autoIndex` is off so this is the single, awaited place
 * where indexes are built.
 *
 * Fail safe: unique indexes are part of the double-booking defence (trip_seat_inventory
 * tripId+seatKey, booking_seats partial tripId+seatKey), so if any index cannot be created —
 * for example existing duplicate data blocks a unique index — start-up fails instead of serving
 * traffic without the guarantee. Indexes are never dropped automatically.
 */
@Injectable()
export class IndexBootstrapService {
  private readonly logger = new Logger(IndexBootstrapService.name);

  constructor(@InjectConnection() private readonly connection: Connection) {}

  async ensureIndexes(): Promise<IndexBootstrapReport> {
    const report: IndexBootstrapReport = { models: [], undeclaredIndexes: {} };

    for (const model of Object.values(this.connection.models)) {
      try {
        await model.createIndexes();
      } catch (error) {
        const reason = error instanceof Error ? error.message : String(error);
        throw new Error(`Index creation failed for model ${model.modelName}: ${reason}`, {
          cause: error,
        });
      }

      const diff = await model.diffIndexes();
      const toDrop = (diff.toDrop as unknown[]).filter(
        (name): name is string => typeof name === 'string',
      );
      if (toDrop.length > 0) {
        report.undeclaredIndexes[model.modelName] = toDrop;
        this.logger.warn(
          { model: model.modelName, indexes: toDrop },
          'Indexes exist in MongoDB but are not declared in the schema (left in place)',
        );
      }
      report.models.push(model.modelName);
    }

    this.logger.log({ models: report.models.length }, 'MongoDB indexes ensured');
    return report;
  }
}
