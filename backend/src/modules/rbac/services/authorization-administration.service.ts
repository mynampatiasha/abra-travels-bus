import { Injectable, Logger } from '@nestjs/common';
import { type ClientSession, Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { AuditLogService } from '../../audit-logs/services/audit-log.service';
import { type AuditAction } from '../../audit-logs/schemas/audit-log.schema';
import { UserDirectoryRepository } from '../../users/repositories/user-directory.repository';
import { type StoredUser } from '../../users/repositories/user.repository';
import { type User } from '../../users/schemas/user.schema';
import { UsersService } from '../../users/services/users.service';
import { PermissionOverrideRepository } from '../repositories/permission-override.repository';
import { RoleRepository, type StoredRole } from '../repositories/role.repository';
import { type OverrideEffect } from '../schemas/permission-override.schema';
import {
  assertCanAdminister,
  assertDataScopeAssignable,
  assertNotSelf,
  assertOverrideAllowed,
  assertOverrideRemovable,
  assertRolesAssignable,
  invalidInput,
  type RequestedDataScope,
} from './authorization-rules';
import {
  dataScopeView,
  toUserAuthorizationView,
  type UserAuthorizationView,
} from './authorization-views';
import { type EffectivePermissions } from './effective-permissions';
import { EffectivePermissionsService } from './effective-permissions.service';

interface AdministrationContext {
  target: StoredUser;
  actorPermissions: EffectivePermissions;
}

/**
 * Changing other users' roles, permission overrides and data scope.
 *
 * Every change: (1) is refused for the actor's own account, (2) only reaches users inside the
 * actor's data scope — others look like they do not exist, (3) cannot hand out more than the
 * actor holds or touch a more privileged user, (4) bumps the target's `permissionVersion`, so
 * their current access tokens stop working and the next refresh carries the new access, and
 * (5) writes an audit entry — all in one MongoDB transaction.
 *
 * The permission needed to call each method is enforced by PermissionGuard on the endpoint.
 */
@Injectable()
export class AuthorizationAdministrationService {
  private readonly logger = new Logger(AuthorizationAdministrationService.name);

  constructor(
    private readonly directory: UserDirectoryRepository,
    private readonly users: UsersService,
    private readonly roles: RoleRepository,
    private readonly overrides: PermissionOverrideRepository,
    private readonly effectivePermissions: EffectivePermissionsService,
    private readonly audit: AuditLogService,
    private readonly transactions: TransactionRunner,
  ) {}

  /** Roles, overrides and effective permissions of a user inside the actor's data scope. */
  async describe(targetUserId: string): Promise<UserAuthorizationView> {
    return this.view(await this.directory.getById(targetUserId));
  }

  async assignRoles(
    actor: AuthenticatedUserActor,
    targetUserId: string,
    input: { roleKeys: readonly string[]; reason?: string },
    client: ClientRequestInfo,
  ): Promise<UserAuthorizationView> {
    const { target, actorPermissions } = await this.prepare(actor, targetUserId);

    const roleKeys = [...new Set(input.roleKeys)];
    const newRoles = await this.roles.findByKeys(roleKeys);
    const unknown = roleKeys.filter((key) => !newRoles.some((role) => role.key === key));
    if (unknown.length > 0) throw invalidInput('roleKeys', `unknown role: ${unknown.join(', ')}`);
    assertRolesAssignable(actorPermissions, target.userType, newRoles);

    const dataScope = this.scopeAfterRoleChange(target, newRoles);
    const before = {
      roleKeys: (await this.effectivePermissions.rolesOf(target)).map((role) => role.key).sort(),
      dataScope: dataScopeView(target),
    };
    await this.commit(actor, target, client, {
      action: 'user.roles.changed',
      before,
      after: {
        roleKeys: newRoles.map((role) => role.key).sort(),
        dataScope: {
          type: dataScope.type,
          operatorIds: dataScope.operatorIds.map((operatorId) => operatorId.toHexString()),
        },
      },
      reason: input.reason,
      apply: (session) =>
        this.users.applyAuthorizationChange(
          target._id,
          { roleIds: newRoles.map((role) => role._id), dataScope },
          session,
        ),
    });
    return this.describe(targetUserId);
  }

  async setOverride(
    actor: AuthenticatedUserActor,
    targetUserId: string,
    input: { permissionKey: string; effect: OverrideEffect; reason: string },
    client: ClientRequestInfo,
  ): Promise<UserAuthorizationView> {
    const { target, actorPermissions } = await this.prepare(actor, targetUserId);
    assertOverrideAllowed(actorPermissions, target.userType, input.permissionKey, input.effect);

    const existing = (await this.overrides.findForUser(target._id)).find(
      (override) => override.permissionKey === input.permissionKey,
    );
    await this.commit(actor, target, client, {
      action: 'user.permission-override.set',
      before: { permissionKey: input.permissionKey, effect: existing?.effect ?? null },
      after: { permissionKey: input.permissionKey, effect: input.effect },
      reason: input.reason,
      apply: async (session) => {
        await this.overrides.set(
          {
            userId: target._id,
            permissionKey: input.permissionKey,
            effect: input.effect,
            reason: input.reason,
            grantedBy: new Types.ObjectId(actor.userId),
          },
          session,
        );
        await this.users.applyAuthorizationChange(target._id, {}, session);
      },
    });
    return this.describe(targetUserId);
  }

  async removeOverride(
    actor: AuthenticatedUserActor,
    targetUserId: string,
    input: { permissionKey: string; reason?: string },
    client: ClientRequestInfo,
  ): Promise<UserAuthorizationView> {
    const { target, actorPermissions } = await this.prepare(actor, targetUserId);
    const existing = (await this.overrides.findForUser(target._id)).find(
      (override) => override.permissionKey === input.permissionKey,
    );
    if (!existing) throw new ApiException('RESOURCE_NOT_FOUND', 'Override not found');
    assertOverrideRemovable(actorPermissions, existing.permissionKey, existing.effect);

    await this.commit(actor, target, client, {
      action: 'user.permission-override.removed',
      before: { permissionKey: existing.permissionKey, effect: existing.effect },
      after: { permissionKey: existing.permissionKey, effect: null },
      reason: input.reason,
      apply: async (session) => {
        await this.overrides.remove(targetUserId, existing.permissionKey, session);
        await this.users.applyAuthorizationChange(target._id, {}, session);
      },
    });
    return this.describe(targetUserId);
  }

  async changeDataScope(
    actor: AuthenticatedUserActor,
    targetUserId: string,
    input: RequestedDataScope & { reason: string },
    client: ClientRequestInfo,
  ): Promise<UserAuthorizationView> {
    const { target } = await this.prepare(actor, targetUserId);
    const operatorIds = [...new Set(input.operatorIds)];
    assertDataScopeAssignable(
      actor,
      {
        userType: target.userType,
        ...(target.operatorId ? { operatorId: target.operatorId.toHexString() } : {}),
      },
      { type: input.type, operatorIds },
    );

    await this.commit(actor, target, client, {
      action: 'user.data-scope.changed',
      before: { dataScope: dataScopeView(target) },
      after: { dataScope: { type: input.type, operatorIds } },
      reason: input.reason,
      apply: (session) =>
        this.users.applyAuthorizationChange(
          target._id,
          {
            dataScope: {
              type: input.type,
              operatorIds: operatorIds.map((operatorId) => new Types.ObjectId(operatorId)),
            },
          },
          session,
        ),
    });
    return this.describe(targetUserId);
  }

  /** Common checks before any change: not self, target visible, actor not outranked. */
  private async prepare(
    actor: AuthenticatedUserActor,
    targetUserId: string,
  ): Promise<AdministrationContext> {
    assertNotSelf(actor, targetUserId);
    // Scoped lookup: a user outside the actor's data scope answers RESOURCE_NOT_FOUND
    const target = await this.directory.getById(targetUserId);
    const [actorPermissions, targetPermissions] = await Promise.all([
      this.effectivePermissions.forActor(actor),
      this.effectivePermissions.forUser(target),
    ]);
    assertCanAdminister(actorPermissions, targetPermissions);
    return { target, actorPermissions };
  }

  /**
   * Assigning roles sets the scope the roles are built for. A scope an administrator narrowed on
   * purpose (SELECTED_OPERATORS) is kept, so re-assigning a role never widens it silently.
   */
  private scopeAfterRoleChange(
    target: StoredUser,
    roles: readonly StoredRole[],
  ): User['dataScope'] {
    const roleScope = roles[0]?.dataScopeType;
    if (!roleScope || target.dataScope.type === 'SELECTED_OPERATORS') return target.dataScope;

    switch (roleScope) {
      case 'OWN_OPERATOR':
        if (!target.operatorId) {
          throw invalidInput('roleKeys', 'the user does not belong to an operator');
        }
        return { type: roleScope, operatorIds: [target.operatorId] };
      case 'OWN_PARTNER':
        if (!target.partnerId) {
          throw invalidInput('roleKeys', 'the user does not belong to a partner');
        }
        return { type: roleScope, operatorIds: [] };
      default:
        return { type: roleScope, operatorIds: [] };
    }
  }

  private async commit(
    actor: AuthenticatedUserActor,
    target: StoredUser,
    client: ClientRequestInfo,
    change: {
      action: AuditAction;
      before: Record<string, unknown>;
      after: Record<string, unknown>;
      reason?: string | undefined;
      apply: (session: ClientSession) => Promise<unknown>;
    },
  ): Promise<void> {
    const actorRoleKeys = (await this.effectivePermissions.forActor(actor)).roleKeys;
    await this.transactions.run(async (session) => {
      await change.apply(session);
      await this.audit.record(
        {
          actor,
          actorRoleKeys,
          action: change.action,
          entityType: 'user',
          entityId: target._id,
          ...(target.operatorId ? { operatorId: target.operatorId } : {}),
          ...(target.partnerId ? { partnerId: target.partnerId } : {}),
          before: change.before,
          after: change.after,
          ...(change.reason ? { reason: change.reason } : {}),
          client,
        },
        session,
      );
    });
    this.logger.log(
      { action: change.action, actorUserId: actor.userId, targetUserId: target._id.toHexString() },
      'Authorization changed',
    );
  }

  private async view(user: StoredUser): Promise<UserAuthorizationView> {
    const [roles, overrides, effective] = await Promise.all([
      this.effectivePermissions.rolesOf(user),
      this.overrides.findForUser(user._id),
      this.effectivePermissions.forUser(user),
    ]);
    return toUserAuthorizationView(user, roles, overrides, effective);
  }
}
