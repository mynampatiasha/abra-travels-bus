import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { UsersService } from '../users/services/users.service';
import {
  fieldError,
  MAX_MESSAGE_LENGTH,
  PROOF_SUBJECT,
  respondByFrom,
  SUPPORT_REPLY_MODEL,
  SUPPORT_TICKET_MODEL,
  SupportAdminService,
  ticketViewOf,
  type SupportReply,
  type SupportTicket,
  type StoredTicket,
  type TicketCategory,
  type TicketDetailView,
  type TicketView,
} from './support_admin_manage.service';

export interface NewTicketInput {
  category: TicketCategory;
  subject?: string | undefined;
  message: string;
  bookingRef?: string | undefined;
  proofFileIds?: string[] | undefined;
}

/** What a customer does with tickets: raise one, follow it, answer. Always their own. */
@Injectable()
export class SupportCustomerService {
  constructor(
    @InjectModel(SUPPORT_TICKET_MODEL) private readonly tickets: Model<SupportTicket>,
    @InjectModel(SUPPORT_REPLY_MODEL) private readonly replies: Model<SupportReply>,
    private readonly admin: SupportAdminService,
    private readonly transactions: TransactionRunner,
    private readonly users: UsersService,
  ) {}

  async create(actor: AuthenticatedUserActor, input: NewTicketInput): Promise<TicketDetailView> {
    const me = this.customer(actor);
    const message = input.message.trim();
    if (!message) throw fieldError('message', 'Tell us what went wrong');
    if (message.length > MAX_MESSAGE_LENGTH) {
      throw fieldError('message', `Your message can be up to ${MAX_MESSAGE_LENGTH} characters`);
    }
    const [found] = await this.users.findNames([me]);
    const name = found?.name?.trim() || 'Customer';

    for (let attempt = 0; attempt < 4; attempt += 1) {
      const last = await this.tickets.findOne().sort({ seq: -1 }).lean<StoredTicket>().exec();
      const seq = (last?.seq ?? 0) + 1;
      try {
        const now = new Date();
        const created = await this.transactions.run(async (session) => {
          const [doc] = await this.tickets.create(
            [
              {
                shortId: `TK-${seq}`,
                seq,
                customerId: me,
                customerName: name,
                category: input.category,
                subject: (input.subject ?? '').trim().slice(0, 120),
                message,
                bookingRef: (input.bookingRef ?? '').trim().toUpperCase(),
                status: 'OPEN',
                priority: 'NORMAL',
                assignedTo: null,
                assignedToName: '',
                respondBy: respondByFrom(now),
                lastReplyBy: 'CUSTOMER',
                lastReplyAt: now,
                resolvedAt: null,
                reopenedCount: 0,
              },
            ],
            { session },
          );
          if (!doc) throw new Error('Ticket was not created');
          // The proof stays unattached (and the ticket is not stored) if it is already used elsewhere
          await this.admin.proofFiles.attach(
            input.proofFileIds,
            { type: PROOF_SUBJECT, id: doc._id, shareWith: [me] },
            session,
          );
          return doc.toObject() as StoredTicket;
        });
        // A free agent takes it at once; if nobody is free it waits in the unassigned list
        await this.admin.autoAssign(created._id).catch(() => false);
        const latest = await this.tickets.findById(created._id).lean<StoredTicket>().exec();
        return this.admin.detail(latest ?? created, me.toHexString());
      } catch (error) {
        if (!isDuplicateKeyError(error)) throw error;
        // another customer took that number at the same moment: try the next one
      }
    }
    throw new ApiException('ALREADY_REGISTERED', 'Another ticket was raised at the same time. Try again.');
  }

  async list(actor: AuthenticatedUserActor): Promise<TicketView[]> {
    const me = this.customer(actor);
    const items = await this.tickets.find({ customerId: me }).sort({ createdAt: -1, _id: -1 }).limit(100).lean<StoredTicket[]>().exec();
    return items.map((ticket) => ticketViewOf(ticket, { viewerId: me.toHexString() }));
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<TicketDetailView> {
    const ticket = await this.mine(actor, id);
    return this.admin.detail(ticket, actor.userId);
  }

  /** A reply on a resolved ticket opens it again, and staff have a day to answer. */
  async reply(actor: AuthenticatedUserActor, id: string, message: string): Promise<TicketDetailView> {
    const ticket = await this.mine(actor, id);
    const body = message.trim();
    if (!body) throw fieldError('message', 'Write your message');
    if (body.length > MAX_MESSAGE_LENGTH) {
      throw fieldError('message', `Your message can be up to ${MAX_MESSAGE_LENGTH} characters`);
    }
    const [found] = await this.users.findNames([ticket.customerId]);
    const now = new Date();
    await this.transactions.run(async (session) => {
      await this.replies.create(
        [{ ticketId: ticket._id, authorType: 'CUSTOMER', authorId: ticket.customerId, authorName: found?.name?.trim() || 'Customer', body }],
        { session },
      );
      await this.tickets
        .updateOne(
          { _id: ticket._id },
          {
            $set: {
              status: ticket.status === 'RESOLVED' ? 'OPEN' : ticket.status,
              respondBy: respondByFrom(now),
              lastReplyBy: 'CUSTOMER',
              lastReplyAt: now,
              resolvedAt: null,
            },
            ...(ticket.status === 'RESOLVED' ? { $inc: { reopenedCount: 1 } } : {}),
          },
          { session },
        )
        .exec();
    });
    return this.get(actor, id);
  }

  /** Only the customer's own ticket; another person's reads the same as one that does not exist. */
  private async mine(actor: AuthenticatedUserActor, id: string): Promise<StoredTicket> {
    const me = this.customer(actor);
    const ticket = Types.ObjectId.isValid(id)
      ? await this.tickets.findOne({ _id: new Types.ObjectId(id), customerId: me }).lean<StoredTicket>().exec()
      : null;
    if (!ticket) throw new ApiException('RESOURCE_NOT_FOUND', 'This ticket does not exist.');
    return ticket;
  }

  private customer(actor: AuthenticatedUserActor): Types.ObjectId {
    if (actor.userType !== 'CUSTOMER') {
      throw new ApiException('PERMISSION_DENIED', 'Only a customer account can raise support tickets.');
    }
    return new Types.ObjectId(actor.userId);
  }
}

