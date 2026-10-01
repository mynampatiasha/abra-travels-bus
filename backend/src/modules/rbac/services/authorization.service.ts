import { Injectable } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import {
  isAuthenticatedUserActor,
  type RequestActor,
} from '../../../common/request-context/request-actor';
import { isResourceWithinScope, type ResourceOwnership } from '../../../database/data-scope.policy';
import { PermissionRegistry } from '../permissions/permission-registry';
import { EffectivePermissionsService } from './effective-permissions.service';

export interface RequireOptions {
  /**
   * What an out-of-scope resource looks like to the caller. 'hide' (default) answers
   * RESOURCE_NOT_FOUND so ids of other tenants cannot be probed; 'forbid' answers
   * PERMISSION_DENIED, for writes where the caller named the tenant themselves.
   */
  outOfScope?: 'hide' | 'forbid';
}

/**
 * The one place that answers "may this actor do this?" (documentation/authorization.md).
 *
 *   permission held (roles ∪ ALLOW − DENY)  ∧  resource inside the actor's data scope
 *
 * Fail closed: an unknown permission key, an actor that is not an authenticated user, a user that
 * no longer exists, or a resource that does not state the facts the scope needs — all mean "no".
 * A SYSTEM actor (background jobs, set explicitly with a reason) is allowed; it never comes from
 * a request.
 *
 * List queries are scoped by ScopedRepository; `resource` here is for single records a service
 * has already loaded.
 */
@Injectable()
export class AuthorizationService {
  constructor(private readonly effectivePermissions: EffectivePermissionsService) {}

  async can(
    actor: RequestActor | undefined,
    permission: string,
    resource?: ResourceOwnership,
  ): Promise<boolean> {
    if (!PermissionRegistry.has(permission)) return false;
    if (actor?.actorType === 'SYSTEM') return true;
    if (!isAuthenticatedUserActor(actor)) return false;

    const effective = await this.effectivePermissions.forActor(actor);
    if (!effective.permissions.has(permission)) return false;
    return resource === undefined || isResourceWithinScope(actor, resource);
  }

  /** Throws PERMISSION_DENIED (403), or RESOURCE_NOT_FOUND (404) for a hidden resource. */
  async require(
    actor: RequestActor | undefined,
    permission: string,
    resource?: ResourceOwnership,
    options: RequireOptions = {},
  ): Promise<void> {
    const denied = new ApiException('PERMISSION_DENIED', 'You do not have permission to do this.');
    if (!actor || !(await this.can(actor, permission))) throw denied;
    if (resource === undefined || isResourceWithinScope(actor, resource)) return;
    if ((options.outOfScope ?? 'hide') === 'hide') {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
    }
    throw denied;
  }
}
