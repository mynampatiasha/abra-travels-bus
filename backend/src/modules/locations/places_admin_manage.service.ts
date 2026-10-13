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
import { type PlaceRequestListQueryDto } from './places_admin_manage';
import { LOCATION_MODEL, type Location } from './schemas/location.schema';

// ===== 1. TYPES =====

export const PLACE_REQUEST_MODEL = 'PlaceRequest';

export const PLACE_REQUEST_STATUSES = ['PENDING', 'APPROVED', 'REJECTED'] as const;
export type PlaceRequestStatus = (typeof PLACE_REQUEST_STATUSES)[number];

/**
 * An operator asking Abra to add a boarding or dropping place (`place_requests`). Approving it adds
 * the place to the shared list every operator uses; rejecting it keeps the reason for the operator.
 * Requests are never deleted: they stay for the record.
 */
export interface PlaceRequest {
  operatorId: Types.ObjectId;
  /** The company name when the request was sent, for lists and search. */
  operatorName: string;
  cityId: Types.ObjectId;
  cityName: string;
  name: string;
  address: string;
  landmark?: string;
  status: PlaceRequestStatus;
  /** Why it was rejected; the operator reads it. */
  reason?: string;
  requestedBy: Types.ObjectId;
  decidedBy?: Types.ObjectId;
  decidedAt?: Date;
  /** The place approval created. */
  placeId?: Types.ObjectId;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredPlaceRequest = PlaceRequest & { _id: Types.ObjectId };

export interface PlaceRequestView {
  id: string;
  operatorId: string;
  operatorName: string;
  cityId: string;
  cityName: string;
  name: string;
  address: string;
  landmark: string | null;
  status: PlaceRequestStatus;
  reason: string | null;
  requestedAt: string | null;
  decidedAt: string | null;
  placeId: string | null;
}

export function placeRequestViewOf(request: StoredPlaceRequest): PlaceRequestView {
  return {
    id: request._id.toHexString(),
    operatorId: request.operatorId.toHexString(),
    operatorName: request.operatorName,
    cityId: request.cityId.toHexString(),
    cityName: request.cityName,
    name: request.name,
    address: request.address,
    landmark: request.landmark ?? null,
    status: request.status,
    reason: request.reason ?? null,
    requestedAt: request.createdAt?.toISOString() ?? null,
    decidedAt: request.decidedAt?.toISOString() ?? null,
    placeId: request.placeId?.toHexString() ?? null,
  };
}

/** The filters both lists share; each audience adds its own scope. */
export function placeRequestMatch(query: {
  query?: string | undefined;
  status?: PlaceRequestStatus | undefined;
  cityId?: string | undefined;
}): QueryFilter<PlaceRequest> {
  const search = query.query ? new RegExp(escapeRegExp(query.query), 'i') : undefined;
  return {
    ...(query.status ? { status: query.status } : {}),
    ...(query.cityId ? { cityId: new Types.ObjectId(query.cityId) } : {}),
    ...(search
      ? {
          $or: [
            { name: search },
            { address: search },
            { landmark: search },
            { cityName: search },
            { operatorName: search },
          ],
        }
      : {}),
  };
}

/** One page of requests, newest first. */
export async function listPlaceRequests(
  model: Model<PlaceRequest>,
  match: QueryFilter<PlaceRequest>,
  page: { page: number; pageSize: number },
): Promise<PaginatedResult<PlaceRequestView>> {
  const [items, total] = await Promise.all([
    model
      .find(match)
      .sort({ createdAt: -1, _id: -1 })
      .skip(skipOf(page))
      .limit(page.pageSize)
      .lean<StoredPlaceRequest[]>()
      .exec(),
    model.countDocuments(match).exec(),
  ]);
  return new PaginatedResult(items.map(placeRequestViewOf), page.page, page.pageSize, total);
}

/** An active place with this name in this city (names compared without case), if there is one. */
export function existingPlace(
  connection: Connection,
  cityId: Types.ObjectId,
  name: string,
  session?: ClientSession,
): Promise<{ _id: Types.ObjectId } | null> {
  return connection
    .model<Location>(LOCATION_MODEL)
    .findOne({
      cityId,
      operatorId: null,
      name: new RegExp(`^${escapeRegExp(name.trim())}$`, 'i'),
    })
    .session(session ?? null)
    .lean<{ _id: Types.ObjectId }>()
    .exec();
}

// ===== 2. ADMIN: REVIEW THE REQUESTS =====

/**
 * The Operator requests tab of the admin Cities and places page. Approving adds the place to the
 * shared list (every operator can use it) in the same transaction as the decision, its audit
 * entry and the event that tells the operator.
 */
@Injectable()
export class PlaceRequestsAdminService {
  constructor(
    @InjectModel(PLACE_REQUEST_MODEL) private readonly requests: Model<PlaceRequest>,
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly outbox: OutboxService,
  ) {}

  list(query: PlaceRequestListQueryDto): Promise<PaginatedResult<PlaceRequestView>> {
    return listPlaceRequests(
      this.requests,
      {
        ...placeRequestMatch(query),
        ...(query.operatorId ? { operatorId: new Types.ObjectId(query.operatorId) } : {}),
      },
      query,
    );
  }

  async get(id: string): Promise<PlaceRequestView> {
    return placeRequestViewOf(await this.require(id));
  }

  /** How many requests wait for a decision (the number on the tab). */
  async pendingCount(): Promise<{ pending: number }> {
    return { pending: await this.requests.countDocuments({ status: 'PENDING' }).exec() };
  }

  async approve(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<PlaceRequestView> {
    assertStaff(actor);
    const before = await this.require(id);
    assertPending(before);
    const city = await this.connection
      .model<{ name: string; isActive: boolean }>('City')
      .findById(before.cityId)
      .lean<{ _id: Types.ObjectId; name: string; isActive: boolean }>()
      .exec();
    if (!city?.isActive) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `${before.cityName} is not an active city any more. Switch the city on first, or reject the request.`,
      );
    }
    const now = new Date();
    const updated = await this.changes.run<StoredPlaceRequest>({
      actor,
      client,
      action: 'place-request.approved',
      entityType: 'place_request',
      before: { status: before.status },
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        if (await existingPlace(this.connection, before.cityId, before.name, session)) {
          throw new ApiException(
            'VALIDATION_FAILED',
            `A place named "${before.name}" already exists in ${before.cityName}. Reject this request and tell the operator to use that place.`,
          );
        }
        const [place] = await this.connection.model<Location>(LOCATION_MODEL).create(
          [
            {
              cityId: before.cityId,
              name: before.name,
              address: before.address,
              ...(before.landmark ? { landmark: before.landmark } : {}),
              usedFor: 'BOTH',
              source: 'OPERATOR_REQUEST',
              isActive: true,
            },
          ],
          { session },
        );
        if (!place) throw new Error('The place was not created');
        const saved = await this.decide(
          before,
          {
            status: 'APPROVED',
            decidedAt: now,
            decidedBy: new Types.ObjectId(actor.userId),
            placeId: place._id,
          },
          session,
        );
        await this.outbox.record(eventOf('place-request.approved', saved), session);
        return saved;
      },
      describe: (record) => ({
        status: record.status,
        placeId: record.placeId?.toHexString(),
        name: record.name,
        city: record.cityName,
      }),
    });
    return placeRequestViewOf(updated);
  }

  async reject(
    actor: AuthenticatedUserActor,
    id: string,
    reason: string,
    client: ClientRequestInfo,
  ): Promise<PlaceRequestView> {
    assertStaff(actor);
    const before = await this.require(id);
    assertPending(before);
    const updated = await this.changes.run<StoredPlaceRequest>({
      actor,
      client,
      action: 'place-request.rejected',
      entityType: 'place_request',
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
        await this.outbox.record(eventOf('place-request.rejected', saved), session);
        return saved;
      },
      describe: (record) => ({ status: record.status, reason: record.reason }),
    });
    return placeRequestViewOf(updated);
  }

  /** Saves a decision only while the request is still pending, so two reviewers cannot both decide. */
  private async decide(
    before: StoredPlaceRequest,
    set: Partial<PlaceRequest>,
    session: ClientSession,
  ): Promise<StoredPlaceRequest> {
    const saved = await this.requests
      .findOneAndUpdate(
        { _id: before._id, status: 'PENDING' },
        { $set: set },
        { returnDocument: 'after', session },
      )
      .lean<StoredPlaceRequest>()
      .exec();
    if (!saved) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'Someone has already decided this request. Reload the list.',
      );
    }
    return saved;
  }

  private async require(id: string): Promise<StoredPlaceRequest> {
    const found = Types.ObjectId.isValid(id)
      ? await this.requests.findById(id).lean<StoredPlaceRequest>().exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This request was not found.');
    return found;
  }
}

function assertStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'STAFF') {
    throw new ApiException('PERMISSION_DENIED', 'Only Abra staff can decide place requests.');
  }
}

function assertPending(request: StoredPlaceRequest): void {
  if (request.status !== 'PENDING') {
    throw new ApiException(
      'INVALID_STATE_TRANSITION',
      `This request was already ${request.status === 'APPROVED' ? 'approved' : 'rejected'}.`,
    );
  }
}

/** The event of a request; the payload carries what the notification needs to say. */
export function eventOf(
  type: 'place-request.created' | 'place-request.approved' | 'place-request.rejected',
  request: StoredPlaceRequest,
): { type: string; aggregateType: string; aggregateId: string; payload: Record<string, unknown> } {
  return {
    type,
    aggregateType: 'place_request',
    aggregateId: request._id.toHexString(),
    payload: {
      requestId: request._id.toHexString(),
      operatorId: request.operatorId.toHexString(),
      operatorName: request.operatorName,
      requestedBy: request.requestedBy.toHexString(),
      name: request.name,
      cityName: request.cityName,
      ...(request.reason ? { reason: request.reason } : {}),
    },
  };
}

// ===== 3. NOTIFICATIONS =====

const text = (value: unknown): string => (typeof value === 'string' ? value : '');

interface PlaceRequestNotice {
  audience: 'REVIEWERS' | 'OPERATOR';
  title: string;
  body: string;
  route: string;
}

/** The words of the notification for a place-request event. */
export function placeRequestNotice(event: DomainEventMessage): PlaceRequestNotice | undefined {
  const payload = event.payload;
  const place = `${text(payload.name)}, ${text(payload.cityName)}`;
  switch (event.type) {
    case 'place-request.created':
      return {
        audience: 'REVIEWERS',
        title: 'Place request',
        body: `${text(payload.operatorName)} wants to add ${place}.`,
        route: '/places?tab=requests',
      };
    case 'place-request.approved':
      return {
        audience: 'OPERATOR',
        title: 'Place approved',
        body: `${place} has been added. Every operator can use it now.`,
        route: '/places',
      };
    case 'place-request.rejected': {
      const reason = text(payload.reason);
      return {
        audience: 'OPERATOR',
        title: 'Place request rejected',
        body: `${place} was not added.${reason ? ` Reason: ${reason}` : ''}`,
        route: '/places',
      };
    }
    default:
      return undefined;
  }
}

/**
 * Tells people about place requests: a new request goes to the staff who can approve it; the
 * decision goes to the operator's administrators and to whoever sent the request. Runs in the
 * worker after the change is stored, so a notification problem never affects the decision.
 */
@Injectable()
export class PlaceRequestNotificationHandler implements DomainEventHandler, OnModuleInit {
  readonly name = 'place-request-notifications';
  readonly eventTypes = [
    'place-request.created',
    'place-request.approved',
    'place-request.rejected',
  ];
  private readonly logger = new Logger(PlaceRequestNotificationHandler.name);

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
    const notice = placeRequestNotice(event);
    if (!notice) return;
    const recipients = await this.recipientsOf(notice.audience, event);
    if (recipients.length === 0) {
      this.logger.warn({ eventId: event.eventId }, 'Nobody to notify about a place request');
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
          {
            operatorId,
          },
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
