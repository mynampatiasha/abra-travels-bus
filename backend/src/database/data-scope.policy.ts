import { ApiException } from '../common/errors/api-exception';
import { type RequestActor } from '../common/request-context/request-actor';

/**
 * Which fields of a collection carry tenant ownership. A repository declares only the fields its
 * collection has; a scope that needs a missing field matches nothing (fail closed).
 */
export interface ScopeFields {
  /** e.g. 'operatorId' — database-architecture.md: every tenant collection has it. */
  readonly operator?: string;
  /** e.g. 'partnerId' — partner users see only their partner's records. */
  readonly partner?: string;
  /** e.g. 'customerId' — customers see only their own records. */
  readonly owner?: string;
}

/** A filter no document can satisfy. */
export const MATCH_NOTHING: Readonly<Record<string, unknown>> = Object.freeze({
  _id: { $in: [] },
});

function isUnrestricted(actor: RequestActor): boolean {
  return actor.actorType === 'SYSTEM' || actor.dataScope.type === 'ALL';
}

/**
 * Tenant filter for reads and updates (authorization.md §4). `assignedRecordIds` is only used
 * for ASSIGNED_RECORDS (e.g. a driver's trips) and is resolved by the repository.
 */
export function scopeFilterFor(
  actor: RequestActor,
  fields: ScopeFields,
  assignedRecordIds: readonly string[] = [],
): Record<string, unknown> {
  if (isUnrestricted(actor)) return {};
  if (actor.actorType !== 'USER') return { ...MATCH_NOTHING };

  const scope = actor.dataScope;
  switch (scope.type) {
    case 'OWN_OPERATOR':
    case 'SELECTED_OPERATORS':
      return fields.operator
        ? { [fields.operator]: { $in: [...scope.operatorIds] } }
        : MATCH_NOTHING;
    case 'OWN_PARTNER':
      return fields.partner && actor.partnerId
        ? { [fields.partner]: actor.partnerId }
        : MATCH_NOTHING;
    case 'OWN_RECORDS':
      return fields.owner ? { [fields.owner]: actor.userId } : MATCH_NOTHING;
    case 'ASSIGNED_RECORDS':
      return { _id: { $in: [...assignedRecordIds] } };
    default:
      return MATCH_NOTHING;
  }
}

/** String ids and ObjectIds compare by hex string; anything else never matches. */
function idAsString(value: unknown): string | undefined {
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value !== null && 'toHexString' in value) {
    const toHexString = value.toHexString;
    if (typeof toHexString === 'function') return String(toHexString.call(value));
  }
  return undefined;
}

function sameId(value: unknown, expected: string): boolean {
  return idAsString(value) === expected;
}

/**
 * New documents must belong to the actor's scope. Rejected with PERMISSION_DENIED (creating is
 * not an id probe, so 403 is correct here; reads outside scope are 404).
 */
export function assertDocumentWithinScope(
  actor: RequestActor,
  fields: ScopeFields,
  document: Readonly<Record<string, unknown>>,
): void {
  if (isUnrestricted(actor) || actor.actorType !== 'USER') return;

  const scope = actor.dataScope;
  let allowed: boolean;
  switch (scope.type) {
    case 'OWN_OPERATOR':
    case 'SELECTED_OPERATORS': {
      const value = fields.operator ? document[fields.operator] : undefined;
      allowed = scope.operatorIds.some((operatorId) => sameId(value, operatorId));
      break;
    }
    case 'OWN_PARTNER':
      allowed =
        fields.partner !== undefined &&
        actor.partnerId !== undefined &&
        sameId(document[fields.partner], actor.partnerId);
      break;
    case 'OWN_RECORDS':
      allowed = fields.owner !== undefined && sameId(document[fields.owner], actor.userId);
      break;
    default:
      // ASSIGNED_RECORDS actors (drivers) change records through dedicated services only
      allowed = false;
  }
  if (!allowed) {
    throw new ApiException('PERMISSION_DENIED', 'The record is outside your data scope');
  }
}

/** Every field path an update document writes to, including rename targets. */
function writtenPaths(update: Readonly<Record<string, unknown>>): string[] {
  const paths: string[] = [];
  for (const [key, value] of Object.entries(update)) {
    if (!key.startsWith('$')) {
      paths.push(key); // Mongoose treats bare keys as $set
      continue;
    }
    if (typeof value !== 'object' || value === null) continue;
    for (const [path, target] of Object.entries(value)) {
      paths.push(path);
      if (key === '$rename' && typeof target === 'string') paths.push(target);
    }
  }
  return paths;
}

/**
 * A scoped actor may not move a record to another tenant by rewriting its ownership fields.
 * Aggregation-pipeline updates cannot be inspected and are rejected outright.
 */
export function assertUpdateKeepsScope(
  actor: RequestActor,
  fields: ScopeFields,
  update: unknown,
): void {
  if (Array.isArray(update)) {
    throw new Error('Aggregation pipeline updates are not supported by ScopedRepository');
  }
  if (isUnrestricted(actor) || typeof update !== 'object' || update === null) return;

  const protectedFields = [fields.operator, fields.partner, fields.owner].filter(
    (field): field is string => field !== undefined,
  );
  const touchesOwnership = writtenPaths(update as Record<string, unknown>).some((path) =>
    protectedFields.some((field) => path === field || path.startsWith(`${field}.`)),
  );
  if (touchesOwnership) {
    throw new ApiException('PERMISSION_DENIED', 'Ownership fields cannot be changed');
  }
}

/**
 * Ownership facts of one resource, for checks that are not a repository query (for example a
 * service deciding whether the actor may act on a record it has already loaded).
 */
export interface ResourceOwnership {
  readonly operatorId?: string | null;
  readonly partnerId?: string | null;
  /** The user the record belongs to (OWN_RECORDS). */
  readonly ownerUserId?: string | null;
  /** Users the record is assigned to (ASSIGNED_RECORDS), e.g. the crew of a trip. */
  readonly assignedUserIds?: readonly string[];
}

/**
 * Is this resource inside the actor's data scope? The same rules as `scopeFilterFor`, applied to
 * one resource. Fail closed: a fact the scope needs but the resource does not state means "no".
 */
export function isResourceWithinScope(actor: RequestActor, resource: ResourceOwnership): boolean {
  if (isUnrestricted(actor)) return true;
  if (actor.actorType !== 'USER') return false;

  const scope = actor.dataScope;
  switch (scope.type) {
    case 'OWN_OPERATOR':
    case 'SELECTED_OPERATORS':
      return (
        typeof resource.operatorId === 'string' && scope.operatorIds.includes(resource.operatorId)
      );
    case 'OWN_PARTNER':
      return (
        typeof resource.partnerId === 'string' &&
        actor.partnerId !== undefined &&
        resource.partnerId === actor.partnerId
      );
    case 'OWN_RECORDS':
      return resource.ownerUserId === actor.userId;
    case 'ASSIGNED_RECORDS':
      return resource.assignedUserIds?.includes(actor.userId) ?? false;
    default:
      return false;
  }
}
