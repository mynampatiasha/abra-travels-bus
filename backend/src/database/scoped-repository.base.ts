import {
  type ClientSession,
  isValidObjectId,
  type Model,
  type QueryFilter,
  type Types,
  type UpdateQuery,
} from 'mongoose';
import { ApiException } from '../common/errors/api-exception';
import { type RequestActor, type UserActor } from '../common/request-context/request-actor';
import { RequestContextService } from '../common/request-context/request-context.service';
import {
  assertDocumentWithinScope,
  assertUpdateKeepsScope,
  type ScopeFields,
  scopeFilterFor,
} from './data-scope.policy';

export type StoredDocument<T> = T & { _id: Types.ObjectId };

export interface RepositoryOptions {
  /** Pass the TransactionRunner session to take part in a transaction. */
  session?: ClientSession;
}

export interface FindManyOptions extends RepositoryOptions {
  sort?: Record<string, 1 | -1>;
  skip?: number;
  limit?: number;
}

export interface UpdateOutcome {
  matchedCount: number;
  modifiedCount: number;
}

/**
 * Base class for repositories of tenant-owned collections (authorization.md §4, architecture.md
 * rule 4: data scope is applied in the repository layer, not in controllers).
 *
 * - Every read and update is AND-ed with the actor's scope filter, so a caller-supplied filter
 *   can never widen it (e.g. `{ operatorId: other }` still returns nothing).
 * - Records outside scope behave as missing: `getById` throws RESOURCE_NOT_FOUND, not 403.
 * - Inserts must belong to the actor's scope; updates may not rewrite ownership fields.
 * - No actor in the request context = error. There is no implicit unscoped mode; background work
 *   runs as an explicit SYSTEM actor.
 *
 * Repositories are the only code that touches a module's collections; other modules call the
 * owning module's service.
 */
export abstract class ScopedRepository<TSchema extends object> {
  protected abstract readonly scopeFields: ScopeFields;

  protected constructor(protected readonly model: Model<TSchema>) {}

  /**
   * Ids of records an ASSIGNED_RECORDS actor (driver, conductor) may see. Collections with
   * assignments override this; the default grants nothing.
   */
  protected assignedRecordIds(_actor: UserActor, _session?: ClientSession): Promise<string[]> {
    return Promise.resolve([]);
  }

  protected currentActor(): RequestActor {
    const actor = RequestContextService.actor();
    if (!actor) {
      throw new Error('No actor in the request context; scoped repositories never run unscoped');
    }
    return actor;
  }

  protected async scopedFilter(
    filter: QueryFilter<TSchema> = {},
    session?: ClientSession,
  ): Promise<QueryFilter<TSchema>> {
    const actor = this.currentActor();
    const assigned =
      actor.actorType === 'USER' && actor.dataScope.type === 'ASSIGNED_RECORDS'
        ? await this.assignedRecordIds(actor, session)
        : [];
    const scope = scopeFilterFor(actor, this.scopeFields, assigned);
    if (Object.keys(scope).length === 0) return filter;
    return { $and: [scope, filter] } as QueryFilter<TSchema>;
  }

  async findOne(
    filter: QueryFilter<TSchema>,
    options: RepositoryOptions = {},
  ): Promise<StoredDocument<TSchema> | null> {
    return this.model
      .findOne(await this.scopedFilter(filter, options.session), null, {
        session: options.session,
      })
      .lean<StoredDocument<TSchema>>()
      .exec();
  }

  /** Invalid ids and out-of-scope ids both return null. */
  async findById(
    id: string,
    options: RepositoryOptions = {},
  ): Promise<StoredDocument<TSchema> | null> {
    if (!isValidObjectId(id)) return null;
    return this.findOne({ _id: id }, options);
  }

  /** Throws RESOURCE_NOT_FOUND when missing or outside scope (ids of other tenants cannot be probed). */
  async getById(id: string, options: RepositoryOptions = {}): Promise<StoredDocument<TSchema>> {
    const document = await this.findById(id, options);
    if (!document) throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
    return document;
  }

  async findMany(
    filter: QueryFilter<TSchema> = {},
    options: FindManyOptions = {},
  ): Promise<StoredDocument<TSchema>[]> {
    return this.model
      .find(await this.scopedFilter(filter, options.session), null, {
        session: options.session,
        sort: options.sort,
        skip: options.skip,
        limit: options.limit,
      })
      .lean<StoredDocument<TSchema>[]>()
      .exec();
  }

  async count(filter: QueryFilter<TSchema> = {}, options: RepositoryOptions = {}): Promise<number> {
    return this.model
      .countDocuments(await this.scopedFilter(filter, options.session))
      .session(options.session ?? null)
      .exec();
  }

  async insertOne(
    document: Partial<TSchema>,
    options: RepositoryOptions = {},
  ): Promise<StoredDocument<TSchema>> {
    assertDocumentWithinScope(this.currentActor(), this.scopeFields, document);
    const created = new this.model(document);
    await created.save({ session: options.session });
    return created.toObject() as StoredDocument<TSchema>;
  }

  async updateOne(
    filter: QueryFilter<TSchema>,
    update: UpdateQuery<TSchema>,
    options: RepositoryOptions = {},
  ): Promise<UpdateOutcome> {
    assertUpdateKeepsScope(this.currentActor(), this.scopeFields, update);
    const result = await this.model
      .updateOne(await this.scopedFilter(filter, options.session), update, {
        session: options.session,
        runValidators: true,
      })
      .exec();
    return { matchedCount: result.matchedCount, modifiedCount: result.modifiedCount };
  }

  /** Conditional atomic update returning the updated document, or null if nothing matched. */
  async findOneAndUpdate(
    filter: QueryFilter<TSchema>,
    update: UpdateQuery<TSchema>,
    options: RepositoryOptions = {},
  ): Promise<StoredDocument<TSchema> | null> {
    assertUpdateKeepsScope(this.currentActor(), this.scopeFields, update);
    return this.model
      .findOneAndUpdate(await this.scopedFilter(filter, options.session), update, {
        session: options.session,
        returnDocument: 'after',
        runValidators: true,
      })
      .lean<StoredDocument<TSchema>>()
      .exec();
  }
}
