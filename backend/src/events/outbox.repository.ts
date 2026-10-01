import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import { OUTBOX_EVENT_MODEL, type OutboxEvent } from './outbox-event.schema';

export type StoredOutboxEvent = OutboxEvent & { _id: Types.ObjectId };

export interface OutboxStats {
  /** PENDING + PUBLISHING. */
  pending: number;
  failed: number;
  /** Age of the oldest event not yet published; 0 when none. */
  oldestPendingAgeMs: number;
}

const MAX_ERROR_LENGTH = 500;

/**
 * Platform-internal collection (not tenant data), so it is not a ScopedRepository. Only the
 * outbox service writes new events and only the relay changes their status. Every status change
 * is conditional on the relay still holding the lease, so two relays never both finish one event.
 */
@Injectable()
export class OutboxRepository {
  constructor(@InjectModel(OUTBOX_EVENT_MODEL) private readonly model: Model<OutboxEvent>) {}

  async insert(event: OutboxEvent, session: ClientSession): Promise<void> {
    await this.model.create([event], { session });
  }

  /** Atomically claims the next due event (or one whose lease expired) for `relayId`. */
  claimNext(relayId: string, leaseMs: number, now: Date): Promise<StoredOutboxEvent | null> {
    return this.model
      .findOneAndUpdate(
        {
          $or: [
            { status: 'PENDING', availableAt: { $lte: now } },
            { status: 'PUBLISHING', lockedUntil: { $lt: now } },
          ],
        },
        {
          $set: {
            status: 'PUBLISHING',
            lockedBy: relayId,
            lockedUntil: new Date(now.getTime() + leaseMs),
          },
          $inc: { attempts: 1 },
        },
        { sort: { availableAt: 1 }, returnDocument: 'after' },
      )
      .lean<StoredOutboxEvent>()
      .exec();
  }

  /** Returns false if the lease was lost (another relay reclaimed the event). */
  async markPublished(id: Types.ObjectId, relayId: string, now: Date): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, status: 'PUBLISHING', lockedBy: relayId },
      {
        $set: { status: 'PUBLISHED', publishedAt: now, lastError: null },
        $unset: { lockedBy: 1, lockedUntil: 1 },
      },
    );
    return result.modifiedCount === 1;
  }

  async scheduleRetry(
    id: Types.ObjectId,
    relayId: string,
    availableAt: Date,
    error: string,
  ): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, status: 'PUBLISHING', lockedBy: relayId },
      {
        $set: { status: 'PENDING', availableAt, lastError: error.slice(0, MAX_ERROR_LENGTH) },
        $unset: { lockedBy: 1, lockedUntil: 1 },
      },
    );
    return result.modifiedCount === 1;
  }

  async markFailed(id: Types.ObjectId, relayId: string, error: string): Promise<boolean> {
    const result = await this.model.updateOne(
      { _id: id, status: 'PUBLISHING', lockedBy: relayId },
      {
        $set: { status: 'FAILED', lastError: error.slice(0, MAX_ERROR_LENGTH) },
        $unset: { lockedBy: 1, lockedUntil: 1 },
      },
    );
    return result.modifiedCount === 1;
  }

  /** Operational recovery: puts a FAILED event back in line with a fresh attempt budget. */
  async requeueFailed(eventId: string, now: Date): Promise<boolean> {
    const result = await this.model.updateOne(
      { eventId, status: 'FAILED' },
      { $set: { status: 'PENDING', attempts: 0, availableAt: now } },
    );
    return result.modifiedCount === 1;
  }

  findByEventId(eventId: string): Promise<StoredOutboxEvent | null> {
    return this.model.findOne({ eventId }).lean<StoredOutboxEvent>().exec();
  }

  async stats(now: Date): Promise<OutboxStats> {
    const [pending, failed, oldest] = await Promise.all([
      this.model.countDocuments({ status: { $in: ['PENDING', 'PUBLISHING'] } }),
      this.model.countDocuments({ status: 'FAILED' }),
      this.model
        .findOne({ status: { $in: ['PENDING', 'PUBLISHING'] } }, { occurredAt: 1 })
        .sort({ occurredAt: 1 })
        .lean<{ occurredAt: Date }>()
        .exec(),
    ]);
    const oldestPendingAgeMs = oldest
      ? Math.max(0, now.getTime() - oldest.occurredAt.getTime())
      : 0;
    return { pending, failed, oldestPendingAgeMs };
  }
}
