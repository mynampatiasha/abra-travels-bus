import {
  Body,
  Controller,
  Get,
  HttpCode,
  Module,
  Param,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { MongooseModule } from '@nestjs/mongoose';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuthenticationModule } from '../authentication/authentication.module';
import { newPasswordSchema } from '../authentication/services/password-policy';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { MessagesModule } from '../messages/messages_admin_manage';
import { AUTH_SESSION_MODEL, authSessionSchema } from '../sessions/schemas/auth-session.schema';
import { SessionsModule } from '../sessions/sessions.module';
import { USER_MODEL, userSchema } from '../users/schemas/user.schema';
import { UsersModule } from '../users/users.module';
import { RequirePermission } from './decorators/require-permission.decorator';
import { RbacModule } from './rbac.module';
import {
  STAFF_INVITATION_MODEL,
  staffInvitationSchema,
  StaffAdminManageService,
  type StaffInvitationPreview,
  type StaffView,
} from './staff_admin_manage.service';

// ===== 1. REQUEST DTOS ===============================================================

export class StaffListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().optional(),
    role: z.string().optional(),
    status: z.enum(['ACTIVE', 'INVITED', 'DEACTIVATED', 'ALL']).optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(15),
    sort: z.string().optional(),
  }),
) {}

export class InviteStaffDto extends createZodDto(
  z.object({
    name: z.string().trim().min(2).max(120),
    email: z.string().trim().toLowerCase().email(),
    role: z.string().trim().min(1),
  }),
) {}

export class UpdateStaffDto extends createZodDto(
  z.object({
    name: z.string().trim().min(2).max(120).optional(),
    role: z.string().trim().min(1).optional(),
  }),
) {}

export class StaffReasonDto extends createZodDto(
  z.object({
    reason: z.string().trim().max(300).optional(),
  }),
) {}

export class StaffIdParamDto extends createZodDto(
  z.object({
    id: z.string().min(1),
  }),
) {}

export class InspectStaffInvitationDto extends createZodDto(
  z.object({
    token: z.string().trim().min(1),
  }),
) {}

export class AcceptStaffInvitationDto extends createZodDto(
  z.object({
    token: z.string().trim().min(1),
    password: newPasswordSchema,
  }),
) {}

// ===== 2. EXPORT CONTROLLER =========================================================

export const STAFF_EXPORT_KIND: ExportKind<StaffView> = {
  key: 'staff',
  columns: [
    { header: 'Name', value: (s) => s.name },
    { header: 'Email', value: (s) => s.email },
    { header: 'Role', value: (s) => s.roleName },
    { header: 'Two-step', value: (s) => (s.mfa ? 'On' : 'Off') },
    { header: 'Status', value: (s) => readable(s.status) },
    { header: 'Overrides', value: (s) => (s.overrides > 0 ? `${s.overrides} custom` : '-') },
    { header: 'Last seen', value: (s) => timeOf(s.lastSeen) },
  ],
};

export const StaffExportController = exportController({
  base: 'admin/staff',
  permission: 'users.read',
  kind: STAFF_EXPORT_KIND,
  service: StaffAdminManageService,
  query: StaffListQueryDto,
  title: 'staff',
  load: (service, query) => service.list(query as never),
});

// ===== 3. ADMIN CONTROLLER ==========================================================

@ApiTags('staff')
@Controller('admin/staff')
export class StaffAdminManageController {
  constructor(private readonly staffService: StaffAdminManageService) {}

  @Get()
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'List platform staff',
    description: 'Requires users.read. Paginated, filterable by role, status, and search.',
  })
  list(@Query() query: StaffListQueryDto): Promise<PaginatedResult<StaffView>> {
    return this.staffService.list(query);
  }

  @Get('roles')
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'List assignable staff roles',
    description: 'Returns available staff roles and their display names matching the demo specification.',
  })
  roles(): Promise<Array<{ key: string; name: string }>> {
    return this.staffService.roles();
  }

  @Get(':id')
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'One staff member',
    description: 'Requires users.read.',
  })
  get(@Param() params: StaffIdParamDto): Promise<StaffView> {
    return this.staffService.get(params.id);
  }

  @Post()
  @RequirePermission('users.create')
  @ZodApiBody(InviteStaffDto)
  @ApiOperation({
    summary: 'Invite staff member',
    description: 'Requires users.create. Creates an invited user and sends email invitation.',
  })
  invite(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: InviteStaffDto,
    @Req() request: Request,
  ): Promise<StaffView> {
    return this.staffService.invite(actor, body, clientRequestInfo(request));
  }

  @Patch(':id')
  @RequirePermission('users.update')
  @ZodApiBody(UpdateStaffDto)
  @ApiOperation({
    summary: 'Update staff member',
    description: 'Requires users.update. Updates name and/or role. Refuses to remove the last Super Admin.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: StaffIdParamDto,
    @Body() body: UpdateStaffDto,
    @Req() request: Request,
  ): Promise<StaffView> {
    return this.staffService.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/resend')
  @HttpCode(200)
  @RequirePermission('users.create')
  @ApiOperation({
    summary: 'Resend staff invitation',
    description: 'Requires users.create. Invalidates previous link and emails a fresh invitation.',
  })
  resend(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: StaffIdParamDto,
    @Req() request: Request,
  ): Promise<{ resent: boolean; inviteUrl?: string }> {
    return this.staffService.resend(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/deactivate')
  @HttpCode(200)
  @RequirePermission('users.delete')
  @ZodApiBody(StaffReasonDto)
  @ApiOperation({
    summary: 'Deactivate staff member',
    description: 'Requires users.delete. Revokes all active sessions at once.',
  })
  deactivate(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: StaffIdParamDto,
    @Body() body: StaffReasonDto,
    @Req() request: Request,
  ): Promise<StaffView> {
    return this.staffService.deactivate(actor, params.id, body.reason, clientRequestInfo(request));
  }

  @Post(':id/activate')
  @HttpCode(200)
  @RequirePermission('users.update')
  @ZodApiBody(StaffReasonDto)
  @ApiOperation({
    summary: 'Activate staff member',
    description: 'Requires users.update.',
  })
  activate(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: StaffIdParamDto,
    @Body() body: StaffReasonDto,
    @Req() request: Request,
  ): Promise<StaffView> {
    return this.staffService.activate(actor, params.id, body.reason, clientRequestInfo(request));
  }
}

// ===== 4. PUBLIC INVITATIONS CONTROLLER =============================================

@ApiTags('staff-invitations')
@Controller('staff-invitations')
export class StaffPublicInvitationsController {
  constructor(private readonly staffService: StaffAdminManageService) {}

  @Post('inspect')
  @HttpCode(200)
  @PublicEndpoint()
  @ZodApiBody(InspectStaffInvitationDto)
  @ApiOperation({
    summary: 'Inspect staff invitation link',
    description: 'Public. Returns the staff member name, email and role. Returns 404 if invalid or expired.',
  })
  inspect(@Body() body: InspectStaffInvitationDto): Promise<StaffInvitationPreview> {
    return this.staffService.inspectInvitation(body.token);
  }

  @Post('accept')
  @HttpCode(200)
  @PublicEndpoint()
  @ZodApiBody(AcceptStaffInvitationDto)
  @ApiOperation({
    summary: 'Accept staff invitation and set password',
    description: 'Public. Sets the staff password and activates account.',
  })
  accept(@Body() body: AcceptStaffInvitationDto): Promise<{ email: string }> {
    return this.staffService.acceptInvitation(body);
  }
}

// ===== 5. MODULE ====================================================================

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: STAFF_INVITATION_MODEL, schema: staffInvitationSchema },
      { name: USER_MODEL, schema: userSchema },
      { name: AUTH_SESSION_MODEL, schema: authSessionSchema },
    ]),
    UsersModule,
    RbacModule,
    AuditLogsModule,
    SessionsModule,
    MessagesModule,
    CatalogueSharedModule,
    AuthenticationModule,
  ],
  controllers: [StaffExportController, StaffAdminManageController, StaffPublicInvitationsController],
  providers: [StaffAdminManageService],
  exports: [StaffAdminManageService],
})
export class StaffAdminManageModule {}
