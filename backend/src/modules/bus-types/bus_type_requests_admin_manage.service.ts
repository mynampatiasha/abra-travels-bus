import { Injectable, Logger, type OnModuleInit } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type Model, type QueryFilter, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import {
  type DomainEventHandler,
  DomainEventHandlerRegistry,
} from '../../events/domain-event-handler.registry';
import { type DomainEventMessage } from '../../events/domain-event.types';
import { OutboxService } from '../../events/outbox.service';
import {
  NotificationDispatcher,
  type Recipient,
} from '../notifications/services/notification-dispatcher.service';
import { ALL_PERMISSIONS_WILDCARD } from '../rbac/permissions/permission-registry';
import { RoleRepository } from '../rbac/repositories/role.repository';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { UsersService } from '../users/services/users.service';
import { type BusTypeRequestListQueryDto } from './bus_type_requests_admin_manage';
import { BUS_TYPE_MODEL, type BerthType, type BusType } from './schemas/bus-type.schema';

// ===== 1. TYPES =====

export const BUS_TYPE_REQUEST_MODEL = 'BusTypeRequest';

export const BUS_TYPE_REQUEST_STATUSES = ['PENDING', 'APPROVED', 'REJECTED'] as const;
export type BusTypeRequestStatus = (typeof BUS_TYPE_REQUEST_STATUSES)[number];

/**
 * An operator asking Abra to add a kind of bus that is not listed (`bus_type_requests`). Approving
 * it adds the bus type to the list every operator uses; rejecting it keeps the reason for the
 * operator. Requests are never deleted: they stay for the record.
 */
export interface BusTypeRequest {
  operatorId: Types.ObjectId;
  /** The company name when the request was sent, for lists and search. */
  operatorName: string;
  name: string;
  isAc: boolean;
  berthType: BerthType;
  status: BusTypeRequestStatus;
  /** Why it was rejected; the operator reads it. */
  reason?: string;
  requestedBy: Types.ObjectId;
  decidedBy?: Types.ObjectId;
  decidedAt?: Date;
  /** The bus type approval created. */
  busTypeId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredBusTypeRequest = BusTypeRequest & { _id: Types.ObjectId };

export interface BusTypeRequestView {
  id: string;
  operatorId: string;
  operatorName: string;
  name: string;
  isAc: boolean;
  berthType: BerthType;
  status: BusTypeRequestStatus;
  reason: string | null;
  requestedAt: string | null;
  decidedAt: string | null;
  busTypeId: string | null;
}

export function busTypeRequestViewOf(request: StoredBusTypeRequest): BusTypeRequestView {
  return {
    id: request._id.toHexString(),
    operatorId: request.operatorId.toHexString(),
    operatorName: request.operatorName,
    name: request.name,
    isAc: request.isAc,
    berthType: request.berthType,
    status: request.status,
    reason: request.reason ?? null,
    requestedAt: request.createdAt?.toISOString() ?? null,
    decidedAt: request.decidedAt?.toISOString() ?? null,
    busTypeId: request.busTypeId?.toHexString() ?? null,
  };
}

/** The filters both lists share; each audience adds its own scope. */
export function busTypeRequestMatch(query: {
  query?: string | undefined;
  status?: BusTypeRequestStatus | undefined;
}): QueryFilter<BusTypeRequest> {
  const search = query.query ? new RegExp(escapeRegExp(query.query), 'i') : undefined;
  return {
    ...(query.status ? { status: query.status } : {}),
    ...(search ? { $or: [{ name: search }, { operatorName: search }] } : {}),
  };
}

/** One page of requests, newest first. */
export async function listBusTypeRequests(
  model: Model<BusTypeRequest>,
  match: QueryFilter<BusTypeRequest>,
  page: { page: number; pageSize: number },
): Promise<PaginatedResult<BusTypeRequestView>> {
  const [items, total] = await Promise.all([
    model
      .find(match)
      .sort({ createdAt: -1, _id: -1 })
      .skip(skipOf(page))
      .limit(page.pageSize)
      .lean<StoredBusTypeRequest[]>()
      .exec(),
    model.countDocuments(match).exec(),
  ]);
  return new PaginatedResult(items.map(busTypeRequestViewOf), page.page, page.pageSize, total);
}

/** A bus type with this name (compared without case), if there is one. */
export function existingBusType(
  connection: Connection,
  name: string,
  session?: ClientSession,
): Promise<{ _id: Types.ObjectId } | null> {
  return connection
    .model<BusType>(BUS_TYPE_MODEL)
    .findOne({ name: new RegExp(`^${escapeRegExp(name.trim())}$`, 'i') })
    .session(session ?? null)
    .lean<{ _id: Types.ObjectId }>()
    .exec();
}

/** `Mini Coach` as `MINI_COACH`: the stable key of a bus type made from a request. */
export function busTypeKeyOf(name: string): string {
  const key = name
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return (/^[A-Z]/.test(key) ? key : `T_${key}`).slice(0, 40);
}

// ===== 2. ADMIN: REVIEW THE REQUESTS =====

/**
 * The Requests tab of the admin Bus types page. Approving adds the bus type to the list (every
 * operator can use it) in the same transaction as the decision, its audit entry and the event that
 * tells the operator.
 */
@Injectable()
export class BusTypeRequestsAdminService {
  constructor(
    @InjectModel(BUS_TYPE_REQUEST_MODEL) private readonly requests: Model<BusTypeRequest>,
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly outbox: OutboxService,
  ) {}

  list(query: BusTypeRequestListQueryDto): Promise<PaginatedResult<BusTypeRequestView>> {
    return listBusTypeRequests(
      this.requests,
      {
        ...busTypeRequestMatch(query),
        ...(query.operatorId ? { operatorId: new Types.ObjectId(query.operatorId) } : {}),
      },
      query,
    );
  }

  async get(id: string): Promise<BusTypeRequestView> {
    return busTypeRequestViewOf(await this.require(id));
  }

  /** How many requests wait for a decision (the number on the tab). */
  async pendingCount(): Promise<{ pending: number }> {
    return { pending: await this.requests.countDocuments({ status: 'PENDING' }).exec() };
  }

  async approve(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<BusTypeRequestView> {
    assertStaff(actor);
    const before = await this.require(id);
    assertPending(before);
    const now = new Date();
    const updated = await this.changes.run<StoredBusTypeRequest>({
      actor,
      client,
      action: 'bus-type-request.approved',
      entityType: 'bus_type_request',
      before: { status: before.status },
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        if (await existingBusType(this.connection, before.name, session)) {
          throw new ApiException(
            'VALIDATION_FAILED',
            `A bus type named "${before.name}" already exists. Reject this request and tell the operator to use that bus type.`,
          );
        }
        const key = busTypeKeyOf(before.name);
        const keyTaken = await this.connection
          .model<BusType>(BUS_TYPE_MODEL)
          .exists({ key })
          .session(session)
          .exec();
        if (keyTaken) {
          throw new ApiException(
            'VALIDATION_FAILED',
            `The name "${before.name}" is too close to a bus type that already exists. Reject this request and tell the operator to use that bus type.`,
          );
        }
        const [busType] = await this.connection.model<BusType>(BUS_TYPE_MODEL).create(
          [
            {
              key,
              name: before.name,
              isAc: before.isAc,
              berthType: before.berthType,
              isActive: true,
            },
          ],
          { session },
        );
        if (!busType) throw new Error('The bus type was not created');
        const saved = await this.decide(
          before,
          {
            status: 'APPROVED',
            decidedAt: now,
            decidedBy: new Types.ObjectId(actor.userId),
            busTypeId: (busType as unknown as { _id: Types.ObjectId })._id,
          },
          session,
        );
        await this.outbox.record(busTypeRequestEventOf('bus-type-request.approved', saved), session);
        return saved;
      },
      describe: (record) => ({
        status: record.status,
        busTypeId: record.busTypeId?.toHexString(),
        name: record.name,
      }),
    });
    return busTypeRequestViewOf(updated);
  }

  async reject(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string,
    client: ClientRequestInfo,
  ): Promise<BusTypeRequestView> {
    assertStaff(actor);
    const before = await this.require(id);
    assertPending(before);
    const updated = await this.changes.run<StoredBusTypeRequest>({
      actor,
      client,
      action: 'bus-type-request.rejected',
      entityType: 'bus_type_request',
      before: { status: before.status },
      reason,
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        const saved = await this.decide(
          before,
          {
            status: 'REJECTED',
            reason,
            decidedAt: new Date(),
            decidedBy: new Types.ObjectId(actor.userId),
          },
          session,
        );
        await this.outbox.record(busTypeRequestEventOf('bus-type-request.rejected', saved), session);
        return saved;
      },
      describe: (record) => ({ status: record.status, reason: record.reason }),
    });
    return busTypeRequestViewOf(updated);
  }

  /** Saves a decision only while the request is still pending, so two reviewers cannot both decide. */
  private async decide(
    before: StoredBusTypeRequest,
    set: Partial<BusTypeRequest>,
    session: ClientSession,
  ): Promise<StoredBusTypeRequest> {
    const saved = await this.requests
      .findOneAndUpdate(
        { _id: before._id, status: 'PENDING' },
        { $set: set },
        { returnDocument: 'after', session },
      )
      .lean<StoredBusTypeRequest>()
      .exec();
    if (!saved) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Someone has already decided this request. Reload the list.',
      );
    }
    return saved;
  }

  private async require(id: string): Promise<StoredBusTypeRequest> {
    const found = Types.ObjectId.isValid(id)
      ? await this.requests.findById(id).lean<StoredBusTypeRequest>().exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This request was not found.');
    return found;
  }
}

function assertStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'Only Abra staff can decide bus type requests.');
  }
}

function assertPending(request: StoredBusTypeRequest): void {
  if (request.status !== 'PENDING') {
    throw new ApiException(
      'INVALID_STATE_TRANSITION',
      `This request was already ${request.status === 'APPROVED' ? 'approved' : 'rejected'}.`,
    );
  }
}

/** The event of a request; the payload carries what the notification needs to say. */
export function busTypeRequestEventOf(
  type: 'bus-type-request.created' | 'bus-type-request.approved' | 'bus-type-request.rejected',
  request: StoredBusTypeRequest,
): { type: string; aggregateType: string; aggregateId: string; payload: Record<string, unknown> } {
  return {
    type,
    aggregateType: 'bus_type_request',
    aggregateId: request._id.toHexString(),
    payload: {
      requestId: request._id.toHexString(),
      operatorId: request.operatorId.toHexString(),
      operatorName: request.operatorName,
      requestedBy: request.requestedBy.toHexString(),
      name: request.name,
      ...(request.reason ? { reason: request.reason } : {}),
    },
  };
}

// ===== 3. NOTIFICATIONS =====

const text = (value: unknown): string => (typeof value === 'string' ? value : '');

interface BusTypeRequestNotice {
  audience: 'REVIEWERS' | 'OPERATOR';
  title: string;
  body: string;
  route: string;
}

/** The words of the notification for a bus-type-request event. */
export function busTypeRequestNotice(event: DomainEventMessage): BusTypeRequestNotice | undefined {
  const payload = event.payload;
  const name = text(payload.name);
  switch (event.type) {
    case 'bus-type-request.created':
      return {
        audience: 'REVIEWERS',
        title: 'Bus type request',
        body: `${text(payload.operatorName)} wants to add the bus type ${name}.`,
        route: '/bus-types?tab=requests',
      };
    case 'bus-type-request.approved':
      return {
        audience: 'OPERATOR',
        title: 'Bus type approved',
        body: `${name} has been added. You can choose it when you add a bus.`,
        route: '/buses',
      };
    case 'bus-type-request.rejected': {
      const reason = text(payload.reason);
      return {
        audience: 'OPERATOR',
        title: 'Bus type request rejected',
        body: `${name} was not added.${reason ? ` Reason: ${reason}` : ''}`,
        route: '/buses',
      };
    }
    default:
      return undefined;
  }
}

/**
 * Tells people about bus type requests: a new request goes to the staff who can approve it; the
 * decision goes to the operator's administrators and to whoever sent the request. Runs in the
 * worker after the change is stored, so a notification problem never affects the decision.
 */
@Injectable()
export class BusTypeRequestNotificationHandler implements DomainEventHandler, OnModuleInit {
  readonly name = 'bus-type-request-notifications';
  readonly eventTypes = [
    'bus-type-request.created',
    'bus-type-request.approved',
    'bus-type-request.rejected',
  ];
  private readonly logger = new Logger(BusTypeRequestNotificationHandler.name);

  constructor(
    private readonly registry: DomainEventHandlerRegistry,
    private readonly dispatcher: NotificationDispatcher,
    private readonly roles: RoleRepository,
    private readonly users: UsersService,
  ) {}

  onModuleInit(): void {
    this.registry.register(this);
  }

  async handle(event: DomainEventMessage): Promise<void> {
    const notice = busTypeRequestNotice(event);
    if (!notice) return;
    const recipients = await this.recipientsOf(notice.audience, event);
    if (recipients.length === 0) {
      this.logger.warn({ eventId: event.eventId }, 'Nobody to notify about a bus type request');
      return;
    }
    let failed = 0;
    for (const recipient of recipients) {
      const ok = await this.dispatcher.deliver(recipient, {
        eventId: event.eventId,
        type: event.type,
        title: notice.title,
        body: notice.body,
        data: { requestId: text(event.payload.requestId), route: notice.route },
      });
      if (!ok) failed += 1;
    }
    if (failed > 0) throw new Error(`${failed} recipient(s) had a channel that failed; will retry`);
  }

  private async recipientsOf(
    audience: 'REVIEWERS' | 'OPERATOR',
    event: DomainEventMessage,
  ): Promise<Recipient[]> {
    const roles = await this.roles.findAll();
    if (audience === 'REVIEWERS') {
      const reviewers = await this.users.findActiveByRoleIds(
        roles
          .filter(
            (role) =>
              role.permissionKeys.includes(ALL_PERMISSIONS_WILDCARD) ||
              role.permissionKeys.includes('catalogue.manage'),
          )
          .map((role) => role._id),
      );
      return reviewers
        .filter((user) => user.userType === 'STAFF')
        .map((user) => ({ userId: user._id, email: user.email, phone: user.phone }));
    }
    const operatorId = new Types.ObjectId(text(event.payload.operatorId));
    const owners = await this.users.findActiveByRoleIds(
      roles.filter((role) => role.key === 'OPERATOR_ADMIN').map((role) => role._id),
      { operatorId },
    );
    const requester = text(event.payload.requestedBy);
    const people = new Map(owners.map((user) => [user._id.toHexString(), user]));
    if (requester && !people.has(requester)) {
      const sender = (
        await this.users.findActiveByRoleIds(
          roles.map((role) => role._id),
          { operatorId },
        )
      ).find((user) => user._id.toHexString() === requester);
      if (sender) people.set(requester, sender);
    }
    return [...people.values()].map((user) => ({
      userId: user._id,
      email: user.email,
      phone: user.phone,
    }));
  }
}
