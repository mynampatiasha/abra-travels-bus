import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, type Types } from 'mongoose';
import { settingsFrom, type NotificationSettings } from './notification_settings';
import { CUSTOMER_MODEL, type Customer } from './schemas/customer.schema';

/**
 * What customers want to be told. Read by the event router before it sends: a person who has no
 * customer profile (staff, drivers) is not in the answer and is told everything.
 */
@Injectable()
export class CustomerPreferenceService {
  constructor(@InjectModel(CUSTOMER_MODEL) private readonly customers: Model<Customer>) {}

  /** Settings by user id (hex), for the customers among `userIds`. */
  async forUsers(userIds: readonly Types.ObjectId[]): Promise<Map<string, NotificationSettings>> {
    const result = new Map<string, NotificationSettings>();
    if (userIds.length === 0) return result;
    const found = await this.customers
      .find({ userId: { $in: [...userIds] } }, { userId: 1, notificationSettings: 1 })
      .lean<Array<{ userId: Types.ObjectId; notificationSettings?: unknown }>>()
      .exec();
    for (const customer of found) {
      result.set(customer.userId.toHexString(), settingsFrom(customer.notificationSettings));
    }
    return result;
  }

  async forUser(userId: Types.ObjectId): Promise<NotificationSettings> {
    return (await this.forUsers([userId])).get(userId.toHexString()) ?? settingsFrom(null);
  }

  /** Saves the whole set of choices; creates the profile if the customer has none yet. */
  async save(userId: Types.ObjectId, settings: NotificationSettings): Promise<void> {
    await this.customers
      .updateOne(
        { userId },
        {
          $set: { notificationSettings: settings },
          $setOnInsert: { marketingConsent: { granted: false, at: new Date() } },
        },
        { upsert: true },
      )
      .exec();
  }
}
