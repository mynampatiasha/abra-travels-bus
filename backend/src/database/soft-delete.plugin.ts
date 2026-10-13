import { Schema } from 'mongoose';

/*
 * Soft delete for catalogue records (Phase 1). No imports of the application on purpose: schemas
 * use it, and the permission catalogue imports schemas.
 */

/** Pass `.setOptions({ withDeleted: true })` to a query to see deleted records too. */
export const WITH_DELETED = 'withDeleted';

const QUERY_OPERATIONS = [
  'find',
  'findOne',
  'findOneAndUpdate',
  'findOneAndReplace',
  'findOneAndDelete',
  'countDocuments',
  'updateOne',
  'updateMany',
  'deleteOne',
  'deleteMany',
  'distinct',
] as const;

interface FilterableQuery {
  getOptions(): Record<string, unknown>;
  where(conditions: Record<string, unknown>): unknown;
}

/**
 * Soft delete for a schema. A record without `deletedAt` (everything stored before this plugin)
 * counts as not deleted, so no migration is needed.
 */
export function softDeletePlugin(schema: Schema): void {
  schema.add({
    deletedAt: { type: Date, default: null },
    deletedBy: { type: Schema.Types.ObjectId, default: null },
  });
  schema.pre(QUERY_OPERATIONS as unknown as 'find', function (this: unknown) {
    const query = this as FilterableQuery;
    if (query.getOptions()[WITH_DELETED] === true) return;
    query.where({ deletedAt: null });
  });
  schema.pre('aggregate', function (this: unknown) {
    const aggregate = this as {
      options?: Record<string, unknown>;
      pipeline(): Record<string, unknown>[];
    };
    if (aggregate.options?.[WITH_DELETED] === true) return;
    const pipeline = aggregate.pipeline();
    // $geoNear must stay the first stage
    const at = pipeline[0] && '$geoNear' in pipeline[0] ? 1 : 0;
    pipeline.splice(at, 0, { $match: { deletedAt: null } });
  });
}
