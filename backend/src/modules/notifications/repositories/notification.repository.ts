import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, type Model, type QueryFilter, Types } from 'mongoose';
import { isDuplicateKeyError } from '../../../common/errors/duplicate-key';
import {
  NOTIFICATION_MODEL,
  PUSH_TOKEN_MODEL,
  type Notification,
  type NotificationDelivery,
  type PushPlatform,
  type PushToken,
} from '../schemas/notification.schema';

export type StoredNotification = Notification & { _id: Types.ObjectId };

/** `notifications`. Every read and write is for one person (`userId`); nobody lists another's. */
@Injectable()
export class NotificationRepository {
  constructor(@InjectModel(NOTIFICATION_MODEL) private readonly model: Model<Notification>) {}

  /** Stores the notification, or returns the one already stored for this event and person. */
  async insertOnce(
    notification: Omit<Notification, 'deliveries' | 'readAt'>,
  ): Promise<{ notification: StoredNotification; created: boolean }> {
    try {
      const [created] = await this.model.create([{ ...notification, deliveries: [] }]);
      if (!created) throw new Error('Notification was not created');
      return { notification: created.toObject(), created: true };
    } catch (error) {
      if (!isDuplicateKeyError(error)) throw error;
      const existing = await this.model
        .findOne({ userId: notification.userId, eventId: notification.eventId })
        .lean<StoredNotification>()
        .exec();
      if (!existing) throw error;
      return { notification: existing, created: false };
    }
  }

  async list(
    userId: Types.ObjectId,
    filter: { unreadOnly: boolean },
    page: { skip: number; limit: number },
  ): Promise<{ items: StoredNotification[]; total: number }> {
    const match: QueryFilter<Notification> = {
      userId,
      ...(filter.unreadOnly ? { readAt: null } : {}),
    };
    const [items, total] = await Promise.all([
      this.model
        .find(match)
        .sort({ createdAt: -1 })
        .skip(page.skip)
        .limit(page.limit)
        .lean<StoredNotification[]>()
        .exec(),
      this.model.countDocuments(match).exec(),
    ]);
    return { items, total };
  }

  countUnread(userId: Types.ObjectId): Promise<number> {
    return this.model.countDocuments({ userId, readAt: null }).exec();
  }

  async markRead(userId: Types.ObjectId, id: string): Promise<boolean> {
    if (!isValidObjectId(id)) return false;
    const result = await this.model
      .updateOne({ _id: id, userId }, { $set: { readAt: new Date() } })
      .exec();
    return result.matchedCount > 0;
  }

  async markAllRead(userId: Types.ObjectId): Promise<number> {
    const result = await this.model
      .updateMany({ userId, readAt: null }, { $set: { readAt: new Date() } })
      .exec();
    return result.modifiedCount;
  }

  /** Replaces the delivery record of each channel named in `deliveries`, keeping the others. */
  async recordDeliveries(
    id: Types.ObjectId,
    deliveries: readonly NotificationDelivery[],
  ): Promise<void> {
    const channels = deliveries.map((delivery) => delivery.channel);
    await this.model
      .updateOne({ _id: id }, { $pull: { deliveries: { channel: { $in: channels } } } })
      .exec();
    await this.model
      .updateOne({ _id: id }, { $push: { deliveries: { $each: [...deliveries] } } })
      .exec();
  }
}

export type StoredPushToken = PushToken & { _id: Types.ObjectId };

/** `push_tokens`. */
@Injectable()
export class PushTokenRepository {
  constructor(@InjectModel(PUSH_TOKEN_MODEL) private readonly model: Model<PushToken>) {}

  /** Saves a device for a person; a token already known moves to this person. */
  async upsert(userId: Types.ObjectId, token: string, platform: PushPlatform): Promise<void> {
    await this.model
      .updateOne(
        { token },
        { $set: { userId, platform, lastSeenAt: new Date() }, $setOnInsert: { token } },
        { upsert: true },
      )
      .exec();
  }

  async tokensOf(userId: Types.ObjectId): Promise<string[]> {
    const rows = await this.model
      .find({ userId })
      .select({ token: 1 })
      .lean<Array<{ token: string }>>()
      .exec();
    return rows.map((row) => row.token);
  }

  async remove(userId: Types.ObjectId, token: string): Promise<void> {
    await this.model.deleteOne({ userId, token }).exec();
  }

  async removeMany(tokens: readonly string[]): Promise<void> {
    if (tokens.length === 0) return;
    await this.model.deleteMany({ token: { $in: [...tokens] } }).exec();
  }
}
