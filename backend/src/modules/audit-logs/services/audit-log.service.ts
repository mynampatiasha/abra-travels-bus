import { Injectable } from '@nestjs/common';
import { type ClientSession, isValidObjectId, type QueryFilter, Types } from 'mongoose';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import { AuditLogRepository } from '../repositories/audit-log.repository';
import { type AuditAction, type AuditLog } from '../schemas/audit-log.schema';

export interface AuditEntryInput {
  actor: AuthenticatedUserActor;
  /** Role keys of the actor at the time of the action. */
  actorRoleKeys: readonly string[];
  action: AuditAction;
  entityType: string;
  entityId: Types.ObjectId;
  operatorId?: Types.ObjectId;
  partnerId?: Types.ObjectId;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  reason?: string;
  client?: ClientRequestInfo;
}

export interface AuditLogView {
  id: string;
  at: string;
  action: AuditAction;
  actor: { userId: string; userType: string; roleKeys: string[] };
  entityType: string;
  entityId: string;
  operatorId: string | null;
  partnerId: string | null;
  before: Record<string, unknown>;
  after: Record<string, unknown>;
  reason: string | null;
  requestId: string | null;
  ip: string | null;
  userAgent: string | null;
}

export interface AuditLogQuery {
  action?: AuditAction;
  entityId?: string;
  actorUserId?: string;
  operatorId?: string;
  page: number;
  pageSize: number;
}

/**
 * The audit trail (documentation/authorization.md §7). `record` must be called inside the
 * transaction of the change it describes, so an entry exists if and only if the change committed.
 */
@Injectable()
export class AuditLogService {
  constructor(private readonly repository: AuditLogRepository) {}

  async record(input: AuditEntryInput, session: ClientSession): Promise<void> {
    if (!session.inTransaction()) {
      throw new Error('Audit entries must be recorded inside the transaction of the change');
    }
    const requestId = RequestContextService.requestId();
    const entry: AuditLog = {
      actor: {
        userId: new Types.ObjectId(input.actor.userId),
        userType: input.actor.userType,
        roleKeys: [...input.actorRoleKeys],
      },
      action: input.action,
      entityType: input.entityType,
      entityId: input.entityId,
      ...(input.operatorId ? { operatorId: input.operatorId } : {}),
      ...(input.partnerId ? { partnerId: input.partnerId } : {}),
      before: input.before,
      after: input.after,
      ...(input.reason ? { reason: input.reason } : {}),
      ...(requestId ? { requestId } : {}),
      ...(input.client?.ip ? { ip: input.client.ip } : {}),
      ...(input.client?.userAgent ? { userAgent: input.client.userAgent } : {}),
      at: new Date(),
    };
    await this.repository.append(entry, session);
  }

  /**
   * Entries visible to the current actor, newest first. Filters only narrow the result; the
   * actor's data scope is applied by the repository and cannot be widened by a filter.
   */
  async search(query: AuditLogQuery): Promise<PaginatedResult<AuditLogView>> {
    const filter: QueryFilter<AuditLog> = {};
    if (query.action) filter.action = query.action;
    for (const [field, value] of [
      ['entityId', query.entityId],
      ['actor.userId', query.actorUserId],
      ['operatorId', query.operatorId],
    ] as const) {
      if (value === undefined) continue;
      // An id that cannot exist matches nothing instead of being ignored
      (filter as Record<string, unknown>)[field] = isValidObjectId(value)
        ? new Types.ObjectId(value)
        : { $in: [] };
    }

    const [entries, total] = await Promise.all([
      this.repository.search(filter, {
        skip: (query.page - 1) * query.pageSize,
        limit: query.pageSize,
      }),
      this.repository.count(filter),
    ]);
    return new PaginatedResult(
      entries.map((entry) => ({
        id: entry._id.toHexString(),
        at: entry.at.toISOString(),
        action: entry.action,
        actor: {
          userId: entry.actor.userId.toHexString(),
          userType: entry.actor.userType,
          roleKeys: entry.actor.roleKeys,
        },
        entityType: entry.entityType,
        entityId: entry.entityId.toHexString(),
        operatorId: entry.operatorId?.toHexString() ?? null,
        partnerId: entry.partnerId?.toHexString() ?? null,
        before: entry.before,
        after: entry.after,
        reason: entry.reason ?? null,
        requestId: entry.requestId ?? null,
        ip: entry.ip ?? null,
        userAgent: entry.userAgent ?? null,
      })),
      query.page,
      query.pageSize,
      total,
    );
  }
}
