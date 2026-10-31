import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection, type Types } from 'mongoose';

/*
 * The short code people read and say aloud for a trip ("TRP-1042"). The database id is never shown
 * on a screen, in a message or in a file. Codes come from one running counter, so they never repeat.
 */

const COUNTER_ID = 'trip_code';
/** The first code is TRP-1001. */
const FIRST_NUMBER = 1000;

export const tripCodeOfNumber = (n: number): string => `TRP-${n}`;

/**
 * What to show for a trip that has no code yet (created before codes existed and not yet numbered).
 * The numbering at start-up normally leaves none of these.
 */
export function tripCodeOf(trip: { _id: Types.ObjectId; tripCode?: string | undefined }): string {
  return trip.tripCode ?? `TRP-${trip._id.toHexString().slice(-6).toUpperCase()}`;
}

/** Reserves `count` new codes, in order. */
export async function allocateTripCodes(connection: Connection, count: number): Promise<string[]> {
  if (count <= 0) return [];
  const counter = await connection
    .collection<{ _id: string; seq: number }>('counters')
    .findOneAndUpdate(
      { _id: COUNTER_ID },
      { $inc: { seq: count } },
      { upsert: true, returnDocument: 'after' },
    );
  const seq = (counter as unknown as { seq?: number } | null)?.seq;
  if (typeof seq !== 'number') throw new Error('The trip code counter did not answer');
  return Array.from({ length: count }, (_, i) => tripCodeOfNumber(FIRST_NUMBER + seq - count + 1 + i));
}

/** Gives a code to every trip saved before codes existed, oldest first. Runs at start-up. */
@Injectable()
export class TripCodeBackfill implements OnApplicationBootstrap {
  private readonly logger = new Logger(TripCodeBackfill.name);

  constructor(@InjectConnection() private readonly connection: Connection) {}

  async onApplicationBootstrap(): Promise<void> {
    const trips = this.connection.collection<{ _id: Types.ObjectId; tripCode?: string }>('trips');
    const filter = { tripCode: { $exists: false } };
    const missing = await trips.countDocuments(filter);
    if (missing === 0) return;
    const rows = await trips.find(filter, { projection: { _id: 1 } }).sort({ createdAt: 1, _id: 1 }).toArray();
    const codes = await allocateTripCodes(this.connection, rows.length);
    await trips.bulkWrite(
      rows.map((row, index) => ({
        updateOne: { filter: { _id: row._id, ...filter }, update: { $set: { tripCode: codes[index] as string } } },
      })),
    );
    this.logger.log({ numbered: rows.length }, 'Trips numbered');
  }
}
