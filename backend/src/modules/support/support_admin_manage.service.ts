import { Injectable } from '@nestjs/common';
import { ModuleRef } from '@nestjs/core';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, Schema, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { ProofFilesService, type ProofFileView } from '../files/files_core.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { UsersService } from '../users/services/users.service';

/*
 * Support tickets. A customer raises a ticket (category, message, optional proof files, optional
 * booking number kept as text), staff answer it, and the customer sees the status and the replies.
 * A ticket that staff have not answered within SUPPORT_RESPONSE_HOURS is flagged `overdue`.
 * Bookings are never read here: the booking number is only what the customer typed.
 */

export const SUPPORT_TICKET_MODEL = 'SupportTicket';
export const SUPPORT_REPLY_MODEL = 'SupportReply';
export const SUPPORT_CANNED_MODEL = 'SupportCannedReply';
export const SUPPORT_AGENT_MODEL = 'SupportAgent';

/** How many open tickets one agent holds before new ones go to somebody else (or wait). */
export const SUPPORT_AGENT_CAPACITY = 5;

export const TICKET_CATEGORIES = ['BOOKING', 'PAYMENT', 'REFUND', 'TRIP', 'SAFETY', 'ACCOUNT', 'OTHER'] as const;
export type TicketCategory = (typeof TICKET_CATEGORIES)[number];
export const TICKET_STATUSES = ['OPEN', 'IN_PROGRESS', 'RESOLVED'] as const;
export type TicketStatus = (typeof TICKET_STATUSES)[number];
export const TICKET_PRIORITIES = ['LOW', 'NORMAL', 'HIGH'] as const;
export type TicketPriority = (typeof TICKET_PRIORITIES)[number];

/** Staff have this long to answer a new ticket or a customer's new message. */
export const SUPPORT_RESPONSE_HOURS = 24;
export const MAX_MESSAGE_LENGTH = 2000;
export const PROOF_SUBJECT = 'support-ticket';

// ===== 1. STORED DOCUMENTS =====

export interface SupportTicket {
  shortId: string;
  seq: number;
  customerId: Types.ObjectId;
  customerName: string;
  category: TicketCategory;
  /** A short title; the first line of the message when the customer gave none. */
  subject: string;
  message: string;
  /** What the customer typed (a PNR); never looked up. */
  bookingRef: string;
  status: TicketStatus;
  priority: TicketPriority;
  assignedTo: Types.ObjectId | null;
  assignedToName: string;
  /** When staff must have answered by; null once they have. */
  respondBy: Date | null;
  lastReplyBy: 'CUSTOMER' | 'STAFF';
  lastReplyAt: Date;
  resolvedAt: Date | null;
  reopenedCount: number;
  /** The system gave this ticket to the agent (the least loaded one who was free). */
  autoAssigned: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}
export type StoredTicket = SupportTicket & { _id: Types.ObjectId };

export interface SupportReply {
  ticketId: Types.ObjectId;
  authorType: 'CUSTOMER' | 'STAFF';
  authorId: Types.ObjectId;
  authorName: string;
  body: string;
  createdAt?: Date;
}
export type StoredReply = SupportReply & { _id: Types.ObjectId };

export interface SupportCanned {
  title: string;
  body: string;
  createdBy: Types.ObjectId;
}
export type StoredCanned = SupportCanned & { _id: Types.ObjectId };

/** `support_tickets`. */
export const supportTicketSchema = new Schema<SupportTicket>(
  {
    shortId: { type: String, required: true },
    seq: { type: Number, required: true },
    customerId: { type: Schema.Types.ObjectId, required: true },
    customerName: { type: String, default: '', maxlength: 120 },
    category: { type: String, enum: TICKET_CATEGORIES, required: true },
    subject: { type: String, default: '', maxlength: 120 },
    message: { type: String, required: true, maxlength: MAX_MESSAGE_LENGTH },
    bookingRef: { type: String, default: '', maxlength: 40 },
    status: { type: String, enum: TICKET_STATUSES, required: true },
    priority: { type: String, enum: TICKET_PRIORITIES, default: 'NORMAL' },
    assignedTo: { type: Schema.Types.ObjectId, default: null },
    assignedToName: { type: String, default: '', maxlength: 120 },
    respondBy: { type: Date, default: null },
    lastReplyBy: { type: String, enum: ['CUSTOMER', 'STAFF'], required: true },
    lastReplyAt: { type: Date, required: true },
    resolvedAt: { type: Date, default: null },
    reopenedCount: { type: Number, default: 0 },
    autoAssigned: { type: Boolean, default: false },
  },
  { collection: 'support_tickets', timestamps: true, versionKey: false },
);
supportTicketSchema.index({ shortId: 1 }, { unique: true });
supportTicketSchema.index({ seq: 1 }, { unique: true });
supportTicketSchema.index({ customerId: 1, createdAt: -1 });
supportTicketSchema.index({ status: 1, respondBy: 1 });
supportTicketSchema.index({ assignedTo: 1, status: 1 });

/** `support_agents`: who is free to receive tickets. An agent turns themselves Available or not. */
export interface SupportAgent {
  userId: Types.ObjectId;
  available: boolean;
  lastAssignedAt: Date | null;
}
export type StoredAgent = SupportAgent & { _id: Types.ObjectId };

export const supportAgentSchema = new Schema<SupportAgent>(
  {
    userId: { type: Schema.Types.ObjectId, required: true },
    available: { type: Boolean, default: false },
    lastAssignedAt: { type: Date, default: null },
  },
  { collection: 'support_agents', timestamps: true, versionKey: false },
);
supportAgentSchema.index({ userId: 1 }, { unique: true });

/** `support_replies`. */
export const supportReplySchema = new Schema<SupportReply>(
  {
    ticketId: { type: Schema.Types.ObjectId, required: true },
    authorType: { type: String, enum: ['CUSTOMER', 'STAFF'], required: true },
    authorId: { type: Schema.Types.ObjectId, required: true },
    authorName: { type: String, default: '', maxlength: 120 },
    body: { type: String, required: true, maxlength: MAX_MESSAGE_LENGTH },
  },
  { collection: 'support_replies', timestamps: { createdAt: true, updatedAt: false }, versionKey: false },
);
supportReplySchema.index({ ticketId: 1, createdAt: 1 });

/** `support_canned_replies`: ready-made answers staff can paste. */
export const supportCannedSchema = new Schema<SupportCanned>(
  {
    title: { type: String, required: true, maxlength: 80 },
    body: { type: String, required: true, maxlength: MAX_MESSAGE_LENGTH },
    createdBy: { type: Schema.Types.ObjectId, required: true },
  },
  { collection: 'support_canned_replies', timestamps: true, versionKey: false },
);

// ===== 2. VIEWS =====

export interface ReplyView {
  id: string;
  authorType: 'CUSTOMER' | 'STAFF';
  authorName: string;
  body: string;
  at: string | null;
}

export interface TicketView {
  id: string;
  ticketNumber: string;
  customerId: string;
  customerName: string;
  category: TicketCategory;
  subject: string;
  message: string;
  bookingRef: string;
  status: TicketStatus;
  priority: TicketPriority;
  assignedToName: string;
  assignedToMe: boolean;
  /** Given automatically to the least loaded free agent. */
  autoAssigned: boolean;
  respondBy: string | null;
  /** Staff have not answered in time. */
  overdue: boolean;
  lastReplyBy: 'CUSTOMER' | 'STAFF';
  repliesCount: number;
  createdAt: string | null;
  updatedAt: string | null;
}

export interface TicketDetailView extends TicketView {
  replies: ReplyView[];
  proofs: ProofFileView[];
}

export function isOverdue(ticket: SupportTicket, now: Date = new Date()): boolean {
  return ticket.status !== 'RESOLVED' && ticket.respondBy !== null && ticket.respondBy.getTime() < now.getTime();
}

export function respondByFrom(now: Date): Date {
  return new Date(now.getTime() + SUPPORT_RESPONSE_HOURS * 60 * 60 * 1000);
}

export function replyViewOf(reply: StoredReply): ReplyView {
  return {
    id: reply._id.toHexString(),
    authorType: reply.authorType,
    authorName: reply.authorName,
    body: reply.body,
    at: reply.createdAt ? reply.createdAt.toISOString() : null,
  };
}

export function ticketViewOf(
  ticket: StoredTicket,
  options: { repliesCount?: number; viewerId?: string } = {},
): TicketView {
  return {
    id: ticket._id.toHexString(),
    ticketNumber: ticket.shortId,
    customerId: ticket.customerId.toHexString(),
    customerName: ticket.customerName,
    category: ticket.category,
    subject: ticket.subject || ticket.message.split('\n')[0]?.slice(0, 80) || '',
    message: ticket.message,
    bookingRef: ticket.bookingRef,
    status: ticket.status,
    priority: ticket.priority,
    assignedToName: ticket.assignedToName,
    assignedToMe: Boolean(options.viewerId && ticket.assignedTo?.toHexString() === options.viewerId),
    autoAssigned: Boolean(ticket.autoAssigned),
    respondBy: ticket.respondBy ? ticket.respondBy.toISOString() : null,
    overdue: isOverdue(ticket),
    lastReplyBy: ticket.lastReplyBy,
    repliesCount: options.repliesCount ?? 0,
    createdAt: ticket.createdAt ? ticket.createdAt.toISOString() : null,
    updatedAt: ticket.updatedAt ? ticket.updatedAt.toISOString() : null,
  };
}

export function fieldError(path: string, message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path, code: 'custom', message }],
  });
}

export interface TicketListQuery {
  search?: string | undefined;
  status?: TicketStatus | undefined;
  category?: TicketCategory | undefined;
  priority?: TicketPriority | undefined;
  overdue?: boolean | undefined;
  mine?: boolean | undefined;
  /** Waiting for an agent. */
  unassigned?: boolean | undefined;
  page: number;
  pageSize: number;
}

// ===== 3. THE ADMIN SERVICE =====

@Injectable()
export class SupportAdminService {
  constructor(
    @InjectModel(SUPPORT_TICKET_MODEL) readonly tickets: Model<SupportTicket>,
    @InjectModel(SUPPORT_REPLY_MODEL) readonly replies: Model<SupportReply>,
    @InjectModel(SUPPORT_CANNED_MODEL) private readonly canned: Model<SupportCanned>,
    @InjectModel(SUPPORT_AGENT_MODEL) private readonly agents: Model<SupportAgent>,
    private readonly changes: AuditedChangeRunner,
    private readonly users: UsersService,
    private readonly moduleRef: ModuleRef,
  ) {}

  /** Found when needed: importing the files module here would make the modules import each other. */
  get proofFiles(): ProofFilesService {
    return this.moduleRef.get(ProofFilesService, { strict: false });
  }

  // ----- reading -----

  async list(actor: AuthenticatedUserActor, query: TicketListQuery): Promise<PaginatedResult<TicketView>> {
    const filter: Record<string, unknown> = {};
    if (query.status) filter.status = query.status;
    if (query.category) filter.category = query.category;
    if (query.priority) filter.priority = query.priority;
    if (query.mine) filter.assignedTo = new Types.ObjectId(actor.userId);
    if (query.unassigned) {
      filter.assignedTo = null;
      filter.status = { $ne: 'RESOLVED' };
    }
    if (query.overdue) {
      filter.status = { $ne: 'RESOLVED' };
      filter.respondBy = { $lt: new Date() };
    }
    const text = query.search?.trim();
    if (text) {
      const pattern = { $regex: escapeRegExp(text), $options: 'i' };
      filter.$or = [
        { shortId: pattern },
        { customerName: pattern },
        { subject: pattern },
        { message: pattern },
        { bookingRef: pattern },
      ];
    }
    const [items, total] = await Promise.all([
      this.tickets
        .find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredTicket[]>()
        .exec(),
      this.tickets.countDocuments(filter).exec(),
    ]);
    const counts = await this.replyCounts(items.map((ticket) => ticket._id));
    return new PaginatedResult(
      items.map((ticket) => ticketViewOf(ticket, { repliesCount: counts.get(ticket._id.toHexString()) ?? 0, viewerId: actor.userId })),
      query.page,
      query.pageSize,
      total,
    );
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<TicketDetailView> {
    const ticket = await this.find(id);
    return this.detail(ticket, actor.userId);
  }

  async detail(ticket: StoredTicket, viewerId: string): Promise<TicketDetailView> {
    const [replies, proofs] = await Promise.all([
      this.replies.find({ ticketId: ticket._id }).sort({ createdAt: 1, _id: 1 }).lean<StoredReply[]>().exec(),
      this.proofFiles.listFor(PROOF_SUBJECT, ticket._id),
    ]);
    return { ...ticketViewOf(ticket, { repliesCount: replies.length, viewerId }), replies: replies.map(replyViewOf), proofs };
  }

  // ----- changing -----

  async setPriority(actor: AuthenticatedUserActor, id: string, priority: TicketPriority, client: ClientRequestInfo): Promise<TicketDetailView> {
    const before = await this.find(id);
    await this.change(actor, client, 'support.ticket.updated', before, (session) =>
      this.save(before._id, { $set: { priority } }, session),
    );
    return this.get(actor, id);
  }

  /** Staff take the ticket, or put it back (`assignToMe` false). */
  async assign(actor: AuthenticatedUserActor, id: string, assignToMe: boolean, client: ClientRequestInfo): Promise<TicketDetailView> {
    const before = await this.find(id);
    if (before.status === 'RESOLVED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This ticket is resolved. Reopen it before assigning it.');
    }
    const who = await this.whoIs(actor);
    await this.change(actor, client, 'support.ticket.assigned', before, (session) =>
      this.save(
        before._id,
        assignToMe
          ? { $set: { assignedTo: who.id, assignedToName: who.name, status: before.status === 'OPEN' ? 'IN_PROGRESS' : before.status } }
          : { $set: { assignedTo: null, assignedToName: '' } },
        session,
      ),
    );
    return this.get(actor, id);
  }

  async reply(actor: AuthenticatedUserActor, id: string, message: string, client: ClientRequestInfo): Promise<TicketDetailView> {
    const body = message.trim();
    if (!body) throw fieldError('message', 'Write your reply');
    const before = await this.find(id);
    if (before.status === 'RESOLVED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This ticket is resolved. Reopen it to reply.');
    }
    const who = await this.whoIs(actor);
    await this.change(actor, client, 'support.ticket.replied', before, async (session) => {
      await this.replies.create(
        [{ ticketId: before._id, authorType: 'STAFF', authorId: who.id, authorName: who.name, body }],
        { session },
      );
      return this.save(
        before._id,
        {
          $set: {
            status: 'IN_PROGRESS',
            respondBy: null,
            lastReplyBy: 'STAFF',
            lastReplyAt: new Date(),
            ...(before.assignedTo ? {} : { assignedTo: who.id, assignedToName: who.name }),
          },
        },
        session,
      );
    });
    return this.get(actor, id);
  }

  async resolve(actor: AuthenticatedUserActor, id: string, client: ClientRequestInfo): Promise<TicketDetailView> {
    const before = await this.find(id);
    if (before.status === 'RESOLVED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'This ticket is already resolved.');
    }
    await this.change(actor, client, 'support.ticket.resolved', before, (session) =>
      this.save(before._id, { $set: { status: 'RESOLVED', resolvedAt: new Date(), respondBy: null } }, session),
    );
    if (before.assignedTo) await this.fillAgent(before.assignedTo);
    return this.get(actor, id);
  }

  async reopen(actor: AuthenticatedUserActor, id: string, client: ClientRequestInfo): Promise<TicketDetailView> {
    const before = await this.find(id);
    if (before.status !== 'RESOLVED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'Only a resolved ticket can be reopened.');
    }
    await this.change(actor, client, 'support.ticket.reopened', before, (session) =>
      this.save(
        before._id,
        { $set: { status: 'OPEN', resolvedAt: null, respondBy: respondByFrom(new Date()) }, $inc: { reopenedCount: 1 } },
        session,
      ),
    );
    return this.get(actor, id);
  }

  // ----- canned replies -----

  async listCanned(): Promise<Array<{ id: string; title: string; body: string }>> {
    const found = await this.canned.find().sort({ title: 1 }).lean<StoredCanned[]>().exec();
    return found.map((item) => ({ id: item._id.toHexString(), title: item.title, body: item.body }));
  }

  async addCanned(actor: AuthenticatedUserActor, input: { title: string; body: string }, client: ClientRequestInfo) {
    const title = input.title.trim();
    const body = input.body.trim();
    if (!title) throw fieldError('title', 'Give the reply a short title');
    if (!body) throw fieldError('body', 'Write the reply');
    const who = await this.whoIs(actor);
    const created = await this.changes.run({
      actor,
      client,
      action: 'support.canned.created',
      entityType: 'support-canned-reply',
      before: {},
      apply: async (session) => {
        const [doc] = await this.canned.create([{ title, body, createdBy: who.id }], { session });
        if (!doc) throw new Error('Canned reply was not created');
        return doc.toObject() as StoredCanned;
      },
      describe: (item) => ({ name: item.title }),
    });
    return { id: created._id.toHexString(), title: created.title, body: created.body };
  }

  async removeCanned(actor: AuthenticatedUserActor, id: string, client: ClientRequestInfo): Promise<void> {
    const found = Types.ObjectId.isValid(id)
      ? await this.canned.findById(id).lean<StoredCanned>().exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This ready-made reply no longer exists.');
    await this.changes.run({
      actor,
      client,
      action: 'support.canned.deleted',
      entityType: 'support-canned-reply',
      before: { name: found.title },
      apply: async (session) => {
        await this.canned.deleteOne({ _id: found._id }, { session }).exec();
        return found;
      },
      describe: (item) => ({ name: item.title, deleted: true }),
    });
  }

  // ----- automatic assignment -----

  async availability(actor: AuthenticatedUserActor): Promise<{ available: boolean; capacity: number; open: number }> {
    const me = new Types.ObjectId(actor.userId);
    const agent = await this.agents.findOne({ userId: me }).lean<StoredAgent>().exec();
    return { available: agent?.available ?? false, capacity: SUPPORT_AGENT_CAPACITY, open: await this.openCount(me) };
  }

  /** An agent says they are free (or not). Becoming free hands them the waiting tickets, up to their limit. */
  async setAvailability(actor: AuthenticatedUserActor, available: boolean) {
    const me = new Types.ObjectId(actor.userId);
    await this.agents.updateOne({ userId: me }, { $set: { available } }, { upsert: true }).exec();
    if (available) await this.fillAgent(me);
    return this.availability(actor);
  }

  /**
   * Gives a waiting ticket to the free agent with the fewest open tickets (the one who was given a
   * ticket longest ago when they tie). Nobody free: the ticket stays in the waiting list.
   */
  async autoAssign(ticketId: Types.ObjectId): Promise<boolean> {
    for (const agent of await this.freeAgents()) {
      if (await this.claim(ticketId, agent.userId)) return true;
    }
    return false;
  }

  /** Hands the agent the most urgent waiting tickets until they hold as many as they may. */
  async fillAgent(agentId: Types.ObjectId): Promise<void> {
    const agent = await this.agents.findOne({ userId: agentId, available: true }).lean<StoredAgent>().exec();
    if (!agent) return;
    let open = await this.openCount(agentId);
    while (open < SUPPORT_AGENT_CAPACITY) {
      const waiting = await this.tickets
        .find({ assignedTo: null, status: { $ne: 'RESOLVED' } })
        .sort({ createdAt: 1 })
        .limit(50)
        .lean<StoredTicket[]>()
        .exec();
      const rank = { HIGH: 0, NORMAL: 1, LOW: 2 } as const;
      const next = [...waiting].sort(
        (a, b) =>
          Number(isOverdue(b)) - Number(isOverdue(a)) ||
          rank[a.priority] - rank[b.priority] ||
          (a.createdAt?.getTime() ?? 0) - (b.createdAt?.getTime() ?? 0),
      )[0];
      if (!next || !(await this.claim(next._id, agentId))) return;
      open += 1;
    }
  }

  private async freeAgents(): Promise<Array<StoredAgent & { load: number }>> {
    const agents = await this.agents.find({ available: true }).lean<StoredAgent[]>().exec();
    if (agents.length === 0) return [];
    const rows = await this.tickets
      .aggregate<{ _id: Types.ObjectId; n: number }>([
        { $match: { assignedTo: { $in: agents.map((a) => a.userId) }, status: { $ne: 'RESOLVED' } } },
        { $group: { _id: '$assignedTo', n: { $sum: 1 } } },
      ])
      .exec();
    const loads = new Map(rows.map((row) => [row._id.toHexString(), row.n]));
    return agents
      .map((agent) => ({ ...agent, load: loads.get(agent.userId.toHexString()) ?? 0 }))
      .filter((agent) => agent.load < SUPPORT_AGENT_CAPACITY)
      .sort(
        (a, b) =>
          a.load - b.load || (a.lastAssignedAt?.getTime() ?? 0) - (b.lastAssignedAt?.getTime() ?? 0),
      );
  }

  /** One atomic step: the ticket goes to this agent only if nobody has it yet. */
  private async claim(ticketId: Types.ObjectId, agentId: Types.ObjectId): Promise<boolean> {
    const [found] = await this.users.findNames([agentId]);
    const taken = await this.tickets
      .findOneAndUpdate(
        { _id: ticketId, assignedTo: null, status: { $ne: 'RESOLVED' } },
        { $set: { assignedTo: agentId, assignedToName: found?.name?.trim() || 'Support', status: 'IN_PROGRESS', autoAssigned: true } },
        { returnDocument: 'after' },
      )
      .lean<StoredTicket>()
      .exec();
    if (!taken) return false;
    await this.agents.updateOne({ userId: agentId }, { $set: { lastAssignedAt: new Date() } }).exec();
    return true;
  }

  private openCount(agentId: Types.ObjectId): Promise<number> {
    return this.tickets.countDocuments({ assignedTo: agentId, status: { $ne: 'RESOLVED' } }).exec();
  }

  // ----- helpers -----

  async find(id: string): Promise<StoredTicket> {
    const ticket = Types.ObjectId.isValid(id)
      ? await this.tickets.findById(id).lean<StoredTicket>().exec()
      : null;
    if (!ticket) throw new ApiException('RESOURCE_NOT_FOUND', 'This ticket no longer exists.');
    return ticket;
  }

  private async save(id: Types.ObjectId, update: Record<string, unknown>, session: ClientSession): Promise<StoredTicket> {
    const saved = await this.tickets
      .findOneAndUpdate({ _id: id }, update, { returnDocument: 'after', session })
      .lean<StoredTicket>()
      .exec();
    if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'This ticket no longer exists.');
    return saved;
  }

  private change(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    action: 'support.ticket.updated' | 'support.ticket.assigned' | 'support.ticket.replied' | 'support.ticket.resolved' | 'support.ticket.reopened',
    before: StoredTicket,
    apply: (session: ClientSession) => Promise<StoredTicket>,
  ): Promise<StoredTicket> {
    return this.changes.run({
      actor,
      client,
      action,
      entityType: 'support-ticket',
      before: this.describe(before),
      apply,
      describe: (ticket) => this.describe(ticket),
    });
  }

  /** What the audit trail keeps: the ticket number and its state, never what the customer wrote. */
  private describe(ticket: StoredTicket): Record<string, unknown> {
    return {
      name: ticket.shortId,
      status: ticket.status,
      priority: ticket.priority,
      assignedTo: ticket.assignedToName,
    };
  }

  private async replyCounts(ids: Types.ObjectId[]): Promise<Map<string, number>> {
    const result = new Map<string, number>();
    if (ids.length === 0) return result;
    const rows = await this.replies
      .aggregate<{ _id: Types.ObjectId; n: number }>([
        { $match: { ticketId: { $in: ids } } },
        { $group: { _id: '$ticketId', n: { $sum: 1 } } },
      ])
      .exec();
    for (const row of rows) result.set(row._id.toHexString(), row.n);
    return result;
  }

  private async whoIs(actor: AuthenticatedUserActor): Promise<{ id: Types.ObjectId; name: string }> {
    const id = new Types.ObjectId(actor.userId);
    const [found] = await this.users.findNames([id]);
    return { id, name: found?.name?.trim() || 'Support' };
  }
}
