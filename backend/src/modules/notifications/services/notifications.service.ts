import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import {
  NotificationRepository,
  PushTokenRepository,
  type StoredNotification,
} from '../repositories/notification.repository';
import { type PushPlatform } from '../schemas/notification.schema';

export interface NotificationView {
  id: string;
  type: string;
  title: string;
  body: string;
  data: Record<string, string>;
  read: boolean;
  createdAt: string;
}

export function notificationViewOf(notification: StoredNotification): NotificationView {
  return {
    id: notification._id.toHexString(),
    type: notification.type,
    title: notification.title,
    body: notification.body,
    data: notification.data,
    read: notification.readAt != null,
    createdAt: (notification.createdAt ?? new Date()).toISOString(),
  };
}

/** A person's own notifications and devices. Nobody reaches another person's. */
@Injectable()
export class NotificationsService {
  constructor(
    private readonly notifications: NotificationRepository,
    private readonly pushTokens: PushTokenRepository,
  ) {}

  async list(
    actor: AuthenticatedUserActor,
    query: { unreadOnly: boolean; page: number; pageSize: number },
  ): Promise<PaginatedResult<NotificationView>> {
    const { items, total } = await this.notifications.list(
      new Types.ObjectId(actor.userId),
      { unreadOnly: query.unreadOnly },
      { skip: skipOf(query), limit: query.pageSize },
    );
    return new PaginatedResult(items.map(notificationViewOf), query.page, query.pageSize, total);
  }

  async unreadCount(actor: AuthenticatedUserActor): Promise<{ count: number }> {
    return { count: await this.notifications.countUnread(new Types.ObjectId(actor.userId)) };
  }

  async markRead(actor: AuthenticatedUserActor, id: string): Promise<{ count: number }> {
    const userId = new Types.ObjectId(actor.userId);
    if (!(await this.notifications.markRead(userId, id))) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Notification not found');
    }
    return { count: await this.notifications.countUnread(userId) };
  }

  async markAllRead(actor: AuthenticatedUserActor): Promise<{ count: number }> {
    await this.notifications.markAllRead(new Types.ObjectId(actor.userId));
    return { count: 0 };
  }

  /** Remembers a browser or phone that allowed push. Signing in as someone else moves the device. */
  async registerDevice(
    actor: AuthenticatedUserActor,
    token: string,
    platform: PushPlatform,
  ): Promise<void> {
    await this.pushTokens.upsert(new Types.ObjectId(actor.userId), token, platform);
  }

  /** Called at sign-out, so a shared computer stops receiving the previous person's messages. */
  async removeDevice(actor: AuthenticatedUserActor, token: string): Promise<void> {
    await this.pushTokens.remove(new Types.ObjectId(actor.userId), token);
  }
}
