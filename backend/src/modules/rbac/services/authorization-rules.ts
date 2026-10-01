import { ApiException } from '../../../common/errors/api-exception';
import {
  type AuthenticatedUserActor,
  type DataScopeType,
  type UserType,
} from '../../../common/request-context/request-actor';
import { ALL_PERMISSIONS_WILDCARD, PermissionRegistry } from '../permissions/permission-registry';
import { ALLOWED_SCOPE_TYPES_BY_USER_TYPE } from '../roles/system-roles';
import { type OverrideEffect } from '../schemas/permission-override.schema';
import { type EffectivePermissions } from './effective-permissions';

/**
 * The rules that stop privilege escalation through the administration endpoints. Pure functions:
 * each throws an ApiException or returns. An administrator can never give away more than they
 * hold, never change their own access, and never act on someone more privileged.
 */

export function invalidInput(path: string, message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path, code: 'custom', message }],
  });
}

function denied(message: string): ApiException {
  return new ApiException('PERMISSION_DENIED', message);
}

/** Nobody changes their own roles, overrides or scope — not even a super administrator. */
export function assertNotSelf(actor: AuthenticatedUserActor, targetUserId: string): void {
  if (actor.userId === targetUserId) throw denied('You cannot change your own access.');
}

/**
 * The actor must be at least as privileged as the user they change: wildcard holders are changed
 * only by wildcard holders, and the target may not hold a permission the actor lacks.
 */
export function assertCanAdminister(
  actor: EffectivePermissions,
  target: EffectivePermissions,
): void {
  if (actor.hasWildcard) return;
  const outranked =
    target.hasWildcard || [...target.permissions].some((key) => !actor.permissions.has(key));
  if (outranked) throw denied('You cannot change the access of a user with more access than you.');
}

interface AssignableRole {
  key: string;
  userType: UserType;
  dataScopeType: DataScopeType;
  permissionKeys: readonly string[];
}

/** Roles must suit the target's kind of account, agree on one scope, and not exceed the actor. */
export function assertRolesAssignable(
  actor: EffectivePermissions,
  targetUserType: UserType,
  roles: readonly AssignableRole[],
): void {
  for (const role of roles) {
    if (role.userType !== targetUserType) {
      throw invalidInput('roleKeys', `role ${role.key} cannot be given to this kind of account`);
    }
  }
  if (new Set(roles.map((role) => role.dataScopeType)).size > 1) {
    throw invalidInput('roleKeys', 'the roles have different data scopes');
  }
  if (actor.hasWildcard) return;
  for (const role of roles) {
    const exceedsActor = role.permissionKeys.some(
      (key) =>
        key === ALL_PERMISSIONS_WILDCARD ||
        (PermissionRegistry.has(key) && !actor.permissions.has(key)),
    );
    if (exceedsActor) throw denied(`You cannot assign the role ${role.key}.`);
  }
}

/**
 * ALLOW: the permission must exist, be holdable by the target's kind of account, and be held by
 * the actor. DENY: any existing permission (taking access away is not an escalation).
 */
export function assertOverrideAllowed(
  actor: EffectivePermissions,
  targetUserType: UserType,
  permissionKey: string,
  effect: OverrideEffect,
): void {
  if (!PermissionRegistry.has(permissionKey)) {
    throw invalidInput('permissionKey', 'unknown permission');
  }
  if (effect === 'DENY') return;
  if (!PermissionRegistry.isGrantableTo(permissionKey, targetUserType)) {
    throw invalidInput('permissionKey', 'this permission cannot be given to this kind of account');
  }
  if (!actor.permissions.has(permissionKey)) {
    throw denied('You cannot grant a permission you do not have.');
  }
}

/** Removing a DENY gives a permission back, so the actor must hold it. */
export function assertOverrideRemovable(
  actor: EffectivePermissions,
  permissionKey: string,
  effect: OverrideEffect,
): void {
  if (effect === 'DENY' && PermissionRegistry.has(permissionKey)) {
    if (!actor.permissions.has(permissionKey)) {
      throw denied('You cannot restore a permission you do not have.');
    }
  }
}

export interface RequestedDataScope {
  type: DataScopeType;
  operatorIds: readonly string[];
}

/**
 * A new data scope must suit the target's kind of account, be well-formed, and stay inside the
 * actor's own scope: only an actor with scope ALL may hand out ALL or operators it cannot reach.
 */
export function assertDataScopeAssignable(
  actor: AuthenticatedUserActor,
  target: { userType: UserType; operatorId?: string },
  requested: RequestedDataScope,
): void {
  if (!ALLOWED_SCOPE_TYPES_BY_USER_TYPE[target.userType].includes(requested.type)) {
    throw invalidInput('type', 'this data scope cannot be given to this kind of account');
  }
  switch (requested.type) {
    case 'SELECTED_OPERATORS':
      if (requested.operatorIds.length === 0) {
        throw invalidInput('operatorIds', 'at least one operator is required');
      }
      break;
    case 'OWN_OPERATOR':
      if (
        !target.operatorId ||
        requested.operatorIds.length !== 1 ||
        requested.operatorIds[0] !== target.operatorId
      ) {
        throw invalidInput('operatorIds', "must be exactly the user's own operator");
      }
      break;
    default:
      if (requested.operatorIds.length > 0) {
        throw invalidInput('operatorIds', 'must be empty for this data scope');
      }
  }

  if (actor.dataScope.type === 'ALL') return;
  const withinActorScope =
    (actor.dataScope.type === 'OWN_OPERATOR' || actor.dataScope.type === 'SELECTED_OPERATORS') &&
    (requested.type === 'OWN_OPERATOR' || requested.type === 'SELECTED_OPERATORS') &&
    requested.operatorIds.every((operatorId) => actor.dataScope.operatorIds.includes(operatorId));
  if (!withinActorScope) throw denied('You cannot give a data scope wider than your own.');
}
