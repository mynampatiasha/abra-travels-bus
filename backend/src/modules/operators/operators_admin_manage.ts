import { Body, Controller, Get, HttpCode, Module, Param, Post, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { changeReason, objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { MessagesModule } from '../messages/messages_admin_manage';
import { NotificationsModule } from '../notifications/notifications.module';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import { OperatorListQueryDto } from './dto/operator.dto';
import {
  type AdminOperatorDetail,
  type AdminOperatorRow,
  OperatorNotificationHandler,
  OperatorsAdminService,
} from './operators_admin_manage.service';
import { OPERATOR_STATUSES } from './schemas/operator.schema';
import { type OperatorView, OperatorsService } from './services/operators.service';

/** The operators list as a file. */
export const OPERATORS_EXPORT_KIND: ExportKind<OperatorView> = {
  key: 'operators',
  columns: [
    { header: 'ID', value: (operator) => operator.id },
    { header: 'Operator', value: (operator) => operator.companyName },
    { header: 'Display name', value: (operator) => operator.displayName },
    { header: 'Status', value: (operator) => readable(operator.status) },
    { header: 'Updated', value: (operator) => timeOf(operator.updatedAt) },
  ],
};

/** `GET catalogue/operators/export`. Register it before the module's other controllers. */
export const OperatorsExportController = exportController({
  base: 'catalogue/operators',
  permission: 'operators.export',
  kind: OPERATORS_EXPORT_KIND,
  service: OperatorsService,
  query: OperatorListQueryDto,
  title: 'operators',
  load: (service, query) => service.list(query as never),
});

// ===== OPERATOR DETAIL (Phase 1 step 6): requests, controller, module =====

export class AdminOperatorListQueryDto extends createZodDto(
  z.object({
    /** Part of the company or display name. */
    query: z.string().trim().max(100).optional(),
    status: z.enum(OPERATOR_STATUSES).optional(),
    ...pagingShape,
  }),
) {}

export class AdminOperatorIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class SuspendOperatorDto extends createZodDto(
  z.object({
    /** Shown to the owner. */
    reason: changeReason,
    /** What Abra saw (a note as proof); kept for staff only. */
    proofNote: z.string().trim().min(3).max(1000).optional(),
    /** Proof files from POST /files/proofs (stored now; checked once proof uploads exist). */
    proofFileIds: z.array(objectIdString).max(5).optional(),
  }),
) {}

export class ReactivateOperatorDto extends createZodDto(
  z.object({ note: z.string().trim().min(3).max(300).optional() }),
) {}

export class MessageOwnerDto extends createZodDto(
  z.object({ message: z.string().trim().min(2).max(1000) }),
) {}

/** The admin Operators list as a file (the columns of the demo). */
export const ADMIN_OPERATORS_EXPORT_KIND: ExportKind<AdminOperatorRow> = {
  key: 'operators',
  columns: [
    { header: 'Operator', value: (row) => row.displayName ?? row.companyName },
    { header: 'Company', value: (row) => row.companyName },
    { header: 'Owner', value: (row) => row.owner.name },
    { header: 'Email', value: (row) => row.owner.email },
    { header: 'Status', value: (row) => readable(row.status) },
    { header: 'KYC', value: (row) => readable(row.kycStatus) },
    { header: 'Buses', value: (row) => row.buses },
    { header: 'Trips', value: (row) => row.trips },
    { header: 'Joined', value: (row) => timeOf(row.joinedAt) },
  ],
};

/** `GET admin/operators/export`. Registered before the controller below. */
export const OperatorsAdminExportController = exportController({
  base: 'admin/operators',
  permission: 'operators.export',
  kind: ADMIN_OPERATORS_EXPORT_KIND,
  service: OperatorsAdminService,
  query: AdminOperatorListQueryDto,
  title: 'operators',
  load: (service, query) => service.list(query as never),
});

/** The admin Operators list and the operator detail page (#/operators/:id). */
@ApiTags('operators')
@Controller('admin/operators')
export class OperatorsAdminController {
  constructor(private readonly operators: OperatorsAdminService) {}

  // operators.read; read only
  @Get()
  @RequirePermission('operators.read')
  @ApiOperation({
    summary: 'Operators with owner, KYC and counts',
    description:
      'Requires operators.read. Newest first. Filters: query (company or display name), ' +
      'status. Each row has the owner, the company KYC state, and the number of buses and trips.',
  })
  list(@Query() query: AdminOperatorListQueryDto): Promise<PaginatedResult<AdminOperatorRow>> {
    return this.operators.list(query);
  }

  // operators.read; read only
  @Get(':id')
  @RequirePermission('operators.read')
  @ApiOperation({
    summary: 'One operator for the detail page',
    description:
      'Requires operators.read. Company, owner, KYC state, the numbers (buses, trips; bookings ' +
      'and sales are 0 until the booking journey exists), what a suspension leaves running, ' +
      'and the last suspension.',
  })
  detail(@Param() params: AdminOperatorIdParamDto): Promise<AdminOperatorDetail> {
    return this.operators.detail(params.id);
  }

  // operators.approve; audit operator.suspended (reason); event tells the owner
  @Post(':id/suspend')
  @HttpCode(200)
  @RequirePermission('operators.approve')
  @ZodApiBody(SuspendOperatorDto)
  @ApiOperation({
    summary: 'Suspend an operator',
    description:
      'Requires operators.approve (platform staff). Only an ACTIVE operator. New sales stop ' +
      'at once (its trips leave customer search); trips already sold still run. The reason is ' +
      'shown to the owner; the proof note stays with Abra. Audited; the owner is told.',
  })
  suspend(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminOperatorIdParamDto,
    @Body() body: SuspendOperatorDto,
    @Req() request: Request,
  ): Promise<AdminOperatorDetail> {
    return this.operators.suspend(actor, params.id, body, clientRequestInfo(request));
  }

  // operators.approve; audit operator.reactivated; event tells the owner
  @Post(':id/reactivate')
  @HttpCode(200)
  @RequirePermission('operators.approve')
  @ZodApiBody(ReactivateOperatorDto)
  @ApiOperation({
    summary: 'Reactivate a suspended operator',
    description:
      'Requires operators.approve (platform staff). Only a SUSPENDED operator. Its trips can ' +
      'be sold again. Audited; the owner is told.',
  })
  reactivate(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminOperatorIdParamDto,
    @Body() body: ReactivateOperatorDto,
    @Req() request: Request,
  ): Promise<AdminOperatorDetail> {
    return this.operators.reactivate(actor, params.id, body.note, clientRequestInfo(request));
  }

  // operators.approve; audit operator.messaged (the text); in-app, email and WhatsApp to the owner
  @Post(':id/messages')
  @HttpCode(200)
  @RequirePermission('operators.approve')
  @ZodApiBody(MessageOwnerDto)
  @ApiOperation({
    summary: 'Message the owner',
    description:
      'Requires operators.approve (platform staff). The owner (every administrator of the ' +
      'operator) gets it as a notification in the portal and by email and WhatsApp. Audited.',
  })
  message(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminOperatorIdParamDto,
    @Body() body: MessageOwnerDto,
    @Req() request: Request,
  ): Promise<{ sent: true }> {
    return this.operators.messageOwner(actor, params.id, body.message, clientRequestInfo(request));
  }
}

/** The admin Operators list and detail page: suspend, reactivate, message the owner. */
@Module({
  imports: [RbacModule, UsersModule, NotificationsModule, MessagesModule, CatalogueSharedModule],
  controllers: [OperatorsAdminExportController, OperatorsAdminController],
  providers: [OperatorsAdminService, OperatorNotificationHandler],
})
export class OperatorsAdminModule {}
