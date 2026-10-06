import { Types } from 'mongoose';
import { ApiException } from '../errors/api-exception';
import { type UserActor } from './request-actor';

/** True when the actor works across all operators (platform staff). */
export function hasPlatformScope(actor: UserActor): boolean {
  return actor.dataScope.type === 'ALL';
}

/**
 * The operator a new record belongs to.
 *
 * - Platform staff name the operator (`requested`); it is required.
 * - Operator staff create for their own operator: `requested` may be left out when their scope
 *   holds exactly one operator, and an operator outside their scope is refused as not found.
 */
export function operatorForNewRecord(
  actor: UserActor,
  requested: string | undefined,
): Types.ObjectId {
  if (hasPlatformScope(actor)) {
    if (!requested) throw new ApiException('VALIDATION_FAILED', 'operatorId is required.');
    return new Types.ObjectId(requested);
  }
  const own = actor.dataScope.operatorIds;
  if (requested) {
    if (!own.includes(requested)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Operator not found');
    }
    return new Types.ObjectId(requested);
  }
  const [only, ...others] = own;
  if (!only || others.length > 0) {
    throw new ApiException('VALIDATION_FAILED', 'operatorId is required.');
  }
  return new Types.ObjectId(only);
}
