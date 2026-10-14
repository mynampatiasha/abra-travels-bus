import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import { AUDIT_LOG_MODEL, type AuditLog } from '../schemas/audit-log.schema';

/**
 * `audit_logs`, read through the actor's data scope: an operator administrator sees only entries
 * about their own operator's records. Entries are written by AuditLogService inside the
 * transaction of the change they describe, and are never updated or deleted.
 */
@Injectable()
export class AuditLogRepository extends ScopedRepository<AuditLog> {
  protected readonly scopeFields: ScopeFields = {
    operator: 'operatorId',
    partner: 'partnerId',
    owner: 'actor.userId',
  };

  constructor(@InjectModel(AUDIT_LOG_MODEL) model: Model<AuditLog>) {
    super(model);
  }

  /**
   * Appends an entry. Not routed through the scope check for inserts: the entry describes a
   * change the caller has already been authorised to make, and it must be written even when the
   * affected record carries no tenant field (for example a platform user).
   */
  async append(entry: AuditLog, session: ClientSession): Promise<void> {
    await this.model.create([entry], { session });
  }

  search(
    filter: QueryFilter<AuditLog>,
    page: { skip: number; limit: number },
  ): Promise<StoredDocument<AuditLog>[]> {
    return this.findMany(filter, { sort: { at: -1 }, ...page });
  }

  /** Same as [search], with the order chosen by the caller (`_id` keeps equal times stable). */
  searchSorted(
    filter: QueryFilter<AuditLog>,
    options: { sort: Record<string, 1 | -1>; skip: number; limit: number },
  ): Promise<StoredDocument<AuditLog>[]> {
    return this.findMany(filter, options);
  }

  /** The distinct values of one field among the entries the caller may read (scope applied). */
  async distinctInScope<T>(field: 'actor.userId' | 'action'): Promise<T[]> {
    return (await this.model.distinct(field, await this.scopedFilter({}))) as T[];
  }
}
