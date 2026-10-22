import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  type PortalMatrixPageRow,
  type PortalMatrixView,
  type PortalUserView,
  StaffClientManageService,
} from './staff_client_manage.service';

export type { PortalMatrixPageRow, PortalMatrixView };

// ===== 1. REQUEST DTOS ===============================================================

export class PortalUserListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().optional(),
    role: z.string().optional(),
    status: z.enum(['ACTIVE', 'INVITED', 'DEACTIVATED', 'ALL']).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
  }),
) {}

export class InvitePortalUserDto extends createZodDto(
  z.object({
    name: z.string().trim().min(2).max(120),
    email: z.string().trim().toLowerCase().email(),
    role: z.string().trim().min(1),
  }),
) {}

export class UpdatePortalUserDto extends createZodDto(
  z.object({
    name: z.string().trim().min(2).max(120).optional(),
    role: z.string().trim().min(1).optional(),
  }),
) {}

export class PortalUserReasonDto extends createZodDto(
  z.object({
    reason: z.string().trim().max(300).optional(),
  }),
) {}

export class PortalUserIdParamDto extends createZodDto(
  z.object({
    id: z.string().min(1),
  }),
) {}

// ===== 2. EXPORT CONTROLLER =========================================================

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const PORTAL_USERS_EXPORT_KIND: ExportKind<PortalUserView> = {
  key: 'portal_users',
  columns: [
    { header: 'ID', value: (s) => s.id },
    { header: 'Name', value: (s) => s.name },
    { header: 'Email', value: (s) => s.email },
    { header: 'Role', value: (s) => s.roleName },
    { header: 'Status', value: (s) => readable(s.status) },
    { header: 'Last seen', value: (s) => timeOf(s.lastSeen) },
  ],
};

export const PortalUsersExportController = exportController({
  base: 'client/users',
  permission: 'users.read',
  kind: PORTAL_USERS_EXPORT_KIND,
  service: StaffClientManageService,
  query: PortalUserListQueryDto,
  title: 'portal users',
  load: (service, query) => service.list(currentActor(), query as never),
});

// ===== 3. CLIENT CONTROLLER =========================================================

@ApiTags('client/users')
@Controller('client/users')
export class StaffClientManageController {
  constructor(private readonly clientStaffService: StaffClientManageService) {}

  @Get()
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'List operator portal users',
    description: 'Requires users.read. Paginated, filterable by role, status, and search.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: PortalUserListQueryDto,
  ): Promise<PaginatedResult<PortalUserView>> {
    return this.clientStaffService.list(actor, query);
  }

  @Get('roles')
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'List assignable portal roles',
    description: 'Returns available portal roles and their display names.',
  })
  roles(): Promise<Array<{ key: string; name: string }>> {
    return this.clientStaffService.roles();
  }

  @Get('matrix')
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'Get operator portal permission matrix',
    description: 'Requires users.read. Returns real page permission levels derived from system roles.',
  })
  matrix(): Promise<PortalMatrixView> {
    return this.clientStaffService.permissionMatrix();
  }

  @Get(':id')
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'One operator portal user',
    description: 'Requires users.read.',
  })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PortalUserIdParamDto,
  ): Promise<PortalUserView> {
    return this.clientStaffService.get(actor, params.id);
  }

  @Post()
  @RequirePermission('users.create')
  @ZodApiBody(InvitePortalUserDto)
  @ApiOperation({
    summary: 'Invite portal user',
    description: 'Requires users.create. Creates an invited operator user and sends email invitation.',
  })
  invite(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: InvitePortalUserDto,
    @Req() request: Request,
  ): Promise<PortalUserView> {
    return this.clientStaffService.invite(actor, body, clientRequestInfo(request));
  }

  @Patch(':id')
  @RequirePermission('users.update')
  @ZodApiBody(UpdatePortalUserDto)
  @ApiOperation({
    summary: 'Update portal user',
    description: 'Requires users.update. Updates name and/or role.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PortalUserIdParamDto,
    @Body() body: UpdatePortalUserDto,
    @Req() request: Request,
  ): Promise<PortalUserView> {
    return this.clientStaffService.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/deactivate')
  @HttpCode(200)
  @RequirePermission('users.delete')
  @ZodApiBody(PortalUserReasonDto)
  @ApiOperation({
    summary: 'Deactivate portal user',
    description: 'Requires users.delete. Revokes active sessions.',
  })
  deactivate(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PortalUserIdParamDto,
    @Body() body: PortalUserReasonDto,
    @Req() request: Request,
  ): Promise<PortalUserView> {
    return this.clientStaffService.deactivate(actor, params.id, body.reason, clientRequestInfo(request));
  }

  @Post(':id/activate')
  @HttpCode(200)
  @RequirePermission('users.update')
  @ZodApiBody(PortalUserReasonDto)
  @ApiOperation({
    summary: 'Activate portal user',
    description: 'Requires users.update.',
  })
  activate(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PortalUserIdParamDto,
    @Body() body: PortalUserReasonDto,
    @Req() request: Request,
  ): Promise<PortalUserView> {
    return this.clientStaffService.activate(actor, params.id, body.reason, clientRequestInfo(request));
  }
}
