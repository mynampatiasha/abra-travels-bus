import { Body, Controller, Delete, Get, Param, Patch, Post, Put, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import {
  AccessMatrixAdminManageService,
  type MatrixRoleView,
  type MatrixView,
} from './access_matrix_admin_manage.service';
import { RequirePermission } from './decorators/require-permission.decorator';
import { ACCESS_LEVELS } from './permissions/access-pages';

// ===== 1. REQUEST TYPES =============================================================
// The schema of the data lives in schemas/role.schema.ts (fields `pageLevels`, `operatorId`).

const audience = z.enum(['ADMIN', 'OPERATOR']);
const level = z.enum(ACCESS_LEVELS);
const roleKey = z.string().regex(/^[A-Z][A-Z_]{1,63}$/, 'must be a role key');
const reason = z.string().trim().min(3).max(300);

export class MatrixQueryDto extends createZodDto(
  z.object({ audience: audience.default('ADMIN') }),
) {}
export class RoleKeyParamDto extends createZodDto(z.object({ roleKey })) {}
export class RolePageParamDto extends createZodDto(
  z.object({ roleKey, pageId: z.string().regex(/^[a-z]{2,24}$/, 'must be a page id') }),
) {}
export class SetLevelDto extends createZodDto(z.object({ level, reason: reason.optional() })) {}
export class CreateRoleDto extends createZodDto(
  z.object({
    audience,
    name: z.string().trim().min(2).max(80),
    /** Start with the access of this role (same portal). Leave out to start with no access. */
    copyFromRoleKey: roleKey.optional(),
  }),
) {}
export class RenameRoleDto extends createZodDto(
  z.object({ name: z.string().trim().min(2).max(80) }),
) {}
export class DeleteRoleDto extends createZodDto(z.object({ reason: reason.optional() })) {}

// ===== 2. CONTROLLER ================================================================

const SUPER_ADMIN_ONLY =
  'Only the Super Admin can change access. The change is written to the audit trail and takes ' +
  "effect on the holders' next token refresh.";

/** The access matrix: None, View, Edit, Edit and delete per role per portal page. */
@ApiTags('authorization')
@Controller('access-matrix')
export class AccessMatrixAdminManageController {
  constructor(private readonly matrix: AccessMatrixAdminManageService) {}

  // permission: roles.read | audit: none | notifies: nobody
  @Get()
  @RequirePermission('roles.read')
  @ApiOperation({
    summary: 'The access matrix of a portal',
    description:
      'Requires roles.read. Every role of the admin or the operator portal with its level on ' +
      'every page. Roles whose permission keys do not match a level exactly list those pages in ' +
      '`inexactPages`.',
  })
  @ApiResponse({ status: 200, description: 'Levels, pages and roles' })
  show(@Query() query: MatrixQueryDto): Promise<MatrixView> {
    return this.matrix.matrix(query.audience);
  }

  // permission: roles.manage (+ Super Admin) | audit: role.access.changed | bumps permissionVersion of holders
  @Put('roles/:roleKey/pages/:pageId')
  @RequirePermission('roles.manage')
  @ZodApiBody(SetLevelDto)
  @ApiOperation({ summary: 'Set one page of one role', description: SUPER_ADMIN_ONLY })
  @ApiResponse({ status: 200, description: 'The role with its new levels' })
  setPage(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RolePageParamDto,
    @Body() body: SetLevelDto,
    @Req() request: Request,
  ): Promise<MatrixRoleView> {
    return this.matrix.setPageLevel(
      actor,
      params.roleKey,
      params.pageId,
      body.level,
      body.reason,
      clientRequestInfo(request),
    );
  }

  // permission: roles.manage (+ Super Admin) | audit: role.access.changed
  @Put('roles/:roleKey')
  @RequirePermission('roles.manage')
  @ZodApiBody(SetLevelDto)
  @ApiOperation({
    summary: 'Set every page of one role to one level',
    description: SUPER_ADMIN_ONLY,
  })
  @ApiResponse({ status: 200, description: 'The role with its new levels' })
  setAll(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RoleKeyParamDto,
    @Body() body: SetLevelDto,
    @Req() request: Request,
  ): Promise<MatrixRoleView> {
    return this.matrix.setAllLevels(
      actor,
      params.roleKey,
      body.level,
      body.reason,
      clientRequestInfo(request),
    );
  }

  // permission: roles.manage (+ Super Admin) | audit: role.created
  @Post('roles')
  @RequirePermission('roles.manage')
  @ZodApiBody(CreateRoleDto)
  @ApiOperation({
    summary: 'Add a role',
    description: `Optionally starts with the access of another role. ${SUPER_ADMIN_ONLY}`,
  })
  @ApiResponse({ status: 201, description: 'The new role' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateRoleDto,
    @Req() request: Request,
  ): Promise<MatrixRoleView> {
    return this.matrix.createRole(
      actor,
      { audience: body.audience, name: body.name, copyFromRoleKey: body.copyFromRoleKey },
      clientRequestInfo(request),
    );
  }

  // permission: roles.manage (+ Super Admin) | audit: role.renamed
  @Patch('roles/:roleKey')
  @RequirePermission('roles.manage')
  @ZodApiBody(RenameRoleDto)
  @ApiOperation({ summary: 'Rename a custom role', description: SUPER_ADMIN_ONLY })
  @ApiResponse({ status: 200, description: 'The renamed role' })
  rename(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RoleKeyParamDto,
    @Body() body: RenameRoleDto,
    @Req() request: Request,
  ): Promise<MatrixRoleView> {
    return this.matrix.renameRole(actor, params.roleKey, body.name, clientRequestInfo(request));
  }

  // permission: roles.manage (+ Super Admin) | audit: role.deleted
  @Delete('roles/:roleKey')
  @RequirePermission('roles.manage')
  @ZodApiBody(DeleteRoleDto)
  @ApiOperation({
    summary: 'Delete a custom role',
    description: `Refused while any user still holds the role. ${SUPER_ADMIN_ONLY}`,
  })
  @ApiResponse({ status: 200, description: '{ deleted: true }' })
  remove(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RoleKeyParamDto,
    @Body() body: DeleteRoleDto,
    @Req() request: Request,
  ): Promise<{ deleted: true }> {
    return this.matrix.deleteRole(actor, params.roleKey, body.reason, clientRequestInfo(request));
  }
}
