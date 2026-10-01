import { Body, Controller, Delete, Get, Param, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../decorators/require-permission.decorator';
import {
  AssignRolesDto,
  ChangeDataScopeDto,
  RemovePermissionOverrideDto,
  SetPermissionOverrideDto,
  UserIdParamDto,
  UserPermissionParamDto,
} from '../dto/authorization-administration.dto';
import { AuthorizationAdministrationService } from '../services/authorization-administration.service';
import { type UserAuthorizationView } from '../services/authorization-views';

const TARGET_RULES =
  "The target must be inside the caller's data scope (otherwise RESOURCE_NOT_FOUND), must not " +
  'be the caller, and must not hold more access than the caller. The change takes effect ' +
  'immediately and is written to the audit trail.';

/** Administration of another user's roles, permission overrides and data scope. */
@ApiTags('authorization')
@Controller('users/:userId')
export class UserAuthorizationController {
  constructor(private readonly administration: AuthorizationAdministrationService) {}

  @Get('permissions')
  @RequirePermission('users.permissions.read')
  @ApiOperation({
    summary: "A user's roles, overrides and effective permissions",
    description:
      'Requires users.permissions.read. Each effective permission is marked ROLE or ' +
      'ALLOW_OVERRIDE; permissions removed by a DENY override are listed separately. A user ' +
      "outside the caller's data scope answers RESOURCE_NOT_FOUND.",
  })
  @ApiResponse({ status: 200, description: 'Roles, data scope, overrides, effective permissions' })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  describe(@Param() params: UserIdParamDto): Promise<UserAuthorizationView> {
    return this.administration.describe(params.userId);
  }

  @Put('roles')
  @RequirePermission('users.roles.assign')
  @ZodApiBody(AssignRolesDto)
  @ApiOperation({
    summary: "Replace a user's roles",
    description:
      "Requires users.roles.assign. Roles must suit the user's kind of account and may not " +
      `contain a permission the caller lacks. An empty list removes every role. ${TARGET_RULES}`,
  })
  @ApiResponse({ status: 200, description: "The user's authorization after the change" })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  assignRoles(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: UserIdParamDto,
    @Body() body: AssignRolesDto,
    @Req() request: Request,
  ): Promise<UserAuthorizationView> {
    return this.administration.assignRoles(
      actor,
      params.userId,
      { roleKeys: body.roleKeys, ...(body.reason ? { reason: body.reason } : {}) },
      clientRequestInfo(request),
    );
  }

  @Put('permissions/:permissionKey')
  @RequirePermission('users.permissions.manage')
  @ZodApiBody(SetPermissionOverrideDto)
  @ApiOperation({
    summary: 'Grant or deny one permission for a user',
    description:
      "Requires users.permissions.manage. effect ALLOW adds the permission to what the user's " +
      "roles give (the caller must hold it and the user's kind of account must be able to " +
      `hold it); DENY removes it and always wins. A reason is required. ${TARGET_RULES}`,
  })
  @ApiResponse({ status: 200, description: "The user's authorization after the change" })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  setOverride(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: UserPermissionParamDto,
    @Body() body: SetPermissionOverrideDto,
    @Req() request: Request,
  ): Promise<UserAuthorizationView> {
    return this.administration.setOverride(
      actor,
      params.userId,
      { permissionKey: params.permissionKey, effect: body.effect, reason: body.reason },
      clientRequestInfo(request),
    );
  }

  @Delete('permissions/:permissionKey')
  @RequirePermission('users.permissions.manage')
  @ZodApiBody(RemovePermissionOverrideDto)
  @ApiOperation({
    summary: 'Remove a permission override',
    description:
      "Requires users.permissions.manage. The permission goes back to what the user's roles " +
      `give. ${TARGET_RULES}`,
  })
  @ApiResponse({ status: 200, description: "The user's authorization after the change" })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND (user or override)' })
  removeOverride(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: UserPermissionParamDto,
    @Body() body: RemovePermissionOverrideDto,
    @Req() request: Request,
  ): Promise<UserAuthorizationView> {
    return this.administration.removeOverride(
      actor,
      params.userId,
      { permissionKey: params.permissionKey, ...(body.reason ? { reason: body.reason } : {}) },
      clientRequestInfo(request),
    );
  }

  @Put('data-scope')
  @RequirePermission('users.data-scope.manage')
  @ZodApiBody(ChangeDataScopeDto)
  @ApiOperation({
    summary: "Change a user's data scope",
    description:
      "Requires users.data-scope.manage. The scope must suit the user's kind of account and " +
      `cannot be wider than the caller's own. A reason is required. ${TARGET_RULES}`,
  })
  @ApiResponse({ status: 200, description: "The user's authorization after the change" })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  changeDataScope(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: UserIdParamDto,
    @Body() body: ChangeDataScopeDto,
    @Req() request: Request,
  ): Promise<UserAuthorizationView> {
    return this.administration.changeDataScope(
      actor,
      params.userId,
      { type: body.type, operatorIds: body.operatorIds, reason: body.reason },
      clientRequestInfo(request),
    );
  }
}
