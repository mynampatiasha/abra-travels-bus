import { Injectable } from '@nestjs/common';
import { type ClientSession, type Types } from 'mongoose';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { type AuditAction } from '../../audit-logs/schemas/audit-log.schema';
import { AuditLogService } from '../../audit-logs/services/audit-log.service';
import { EffectivePermissionsService } from './effective-permissions.service';

export interface AuditedChange<T extends { _id: Types.ObjectId }> {
  actor: AuthenticatedUserActor;
  client: ClientRequestInfo;
  action: AuditAction;
  /** Collection-like name of what changed, e.g. `bus`. */
  entityType: string;
  /** State before the change as written to the audit trail ({} for a creation). */
  before: Record<string, unknown>;
  reason?: string | undefined;
  /** Makes the change inside the transaction and returns the record as it is afterwards. */
  apply: (session: ClientSession) => Promise<T>;
  /** State after the change as written to the audit trail. Never credentials. */
  describe: (record: T) => Record<string, unknown>;
  /** Operator the record belongs to, so operator administrators see their own audit entries. */
  operatorIdOf?: (record: T) => Types.ObjectId | undefined;
}

/**
 * Runs a change and its audit entry in one transaction: either both are stored or neither
 * (authorization.md §7). Used by every module whose changes must be traceable.
 */
@Injectable()
export class AuditedChangeRunner {
  constructor(
    private readonly transactions: TransactionRunner,
    private readonly audit: AuditLogService,
    private readonly effectivePermissions: EffectivePermissionsService,
  ) {}

  async run<T extends { _id: Types.ObjectId }>(change: AuditedChange<T>): Promise<T> {
    const actorRoleKeys = (await this.effectivePermissions.forActor(change.actor)).roleKeys;
    return this.transactions.run(async (session) => {
      const record = await change.apply(session);
      const operatorId = change.operatorIdOf?.(record);
      await this.audit.record(
        {
          actor: change.actor,
          actorRoleKeys,
          action: change.action,
          entityType: change.entityType,
          entityId: record._id,
          ...(operatorId ? { operatorId } : {}),
          before: change.before,
          after: change.describe(record),
          ...(change.reason ? { reason: change.reason } : {}),
          client: change.client,
        },
        session,
      );
      return record;
    });
  }
}
