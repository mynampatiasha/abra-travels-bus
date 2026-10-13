import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type QueryFilter, isValidObjectId, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import {
  MESSAGE_MODEL,
  type Message,
  type MessageChannel,
  type MessageKind,
} from './messages_admin_manage.service';

// ===== 1. VIEWS =====================================================================

/** What a customer sees of a message: the text and where it went, nothing internal. */
export interface CustomerMessageView {
  id: string;
  at: string;
  channel: MessageChannel;
  kind: MessageKind;
  subject: string;
  body: string;
  /** Where it was sent: their own number or email. */
  address: string;
  bookingId: string | null;
}

type StoredMessage = Message & { _id: Types.ObjectId; createdAt: Date };

function toCustomerView(message: StoredMessage): CustomerMessageView {
  return {
    id: message._id.toHexString(),
    at: message.createdAt.toISOString(),
    channel: message.channel,
    kind: message.kind,
    subject: message.subject,
    body: message.body,
    address: message.address,
    bookingId: message.bookingId ? message.bookingId.toHexString() : null,
  };
}

// ===== 2. SERVICE ===================================================================

/**
 * "Messages sent to me": copies of the WhatsApp messages and emails the platform sent to the
 * signed-in customer. A customer only ever reaches messages that belong to their own account, and
 * only the ones that were actually sent (a failed or skipped message is not shown).
 */
@Injectable()
export class MessagesCustomerService {
  constructor(@InjectModel(MESSAGE_MODEL) private readonly model: Model<Message>) {}

  async list(
    actor: AuthenticatedUserActor,
    query: { channel?: MessageChannel | undefined; page: number; pageSize: number },
  ): Promise<PaginatedResult<CustomerMessageView>> {
    const filter: QueryFilter<Message> = {
      userId: new Types.ObjectId(actor.userId),
      status: 'SENT',
      ...(query.channel ? { channel: query.channel } : {}),
    };
    const [items, total] = await Promise.all([
      this.model
        .find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredMessage[]>()
        .exec(),
      this.model.countDocuments(filter).exec(),
    ]);
    return new PaginatedResult(items.map(toCustomerView), query.page, query.pageSize, total);
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<CustomerMessageView> {
    const message = isValidObjectId(id)
      ? await this.model
          .findOne({ _id: id, userId: new Types.ObjectId(actor.userId), status: 'SENT' })
          .lean<StoredMessage>()
          .exec()
      : null;
    // Someone else's message looks exactly like one that does not exist
    if (!message) throw new ApiException('RESOURCE_NOT_FOUND', 'That message was not found');
    return toCustomerView(message);
  }
}
