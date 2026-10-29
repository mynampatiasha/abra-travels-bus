import { Body, Controller, Get, HttpCode, Module, Param, Post, Query, Req } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Schema } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { NotificationsModule } from '../notifications/notifications.module';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import {
  BUS_TYPE_REQUEST_MODEL,
  BUS_TYPE_REQUEST_STATUSES,
  type BusTypeRequest,
  BusTypeRequestNotificationHandler,
  BusTypeRequestsAdminService,
  type BusTypeRequestView,
} from './bus_type_requests_admin_manage.service';
import { BusTypeRequestsClientController } from './bus_type_requests_client_manage';
import { BusTypeRequestsClientService } from './bus_type_requests_client_manage.service';
import { BERTH_TYPES } from './schemas/bus-type.schema';

// ===== BUS TYPE REQUESTS: schema, admin controller, module =====

/** `bus_type_requests`. Never deleted: requests stay for the record. */
export const busTypeRequestSchema = new Schema<BusTypeRequest>(
  {
    operatorId: { type: Schema.Types.ObjectId, required: true },
    operatorName: { type: String, required: true, trim: true, maxlength: 200 },
    name: { type: String, required: true, trim: true, maxlength: 60 },
    isAc: { type: Boolean, required: true },
    berthType: { type: String, enum: BERTH_TYPES, required: true },
    status: { type: String, enum: BUS_TYPE_REQUEST_STATUSES, required: true, default: 'PENDING' },
    reason: { type: String, trim: true, maxlength: 500 },
    requestedBy: { type: Schema.Types.ObjectId, required: true },
    decidedBy: { type: Schema.Types.ObjectId },
    decidedAt: { type: Date },
    busTypeId: { type: Schema.Types.ObjectId },
  },
  { collection: 'bus_type_requests', timestamps: true, versionKey: false },
);
busTypeRequestSchema.index({ status: 1, createdAt: -1 });
busTypeRequestSchema.index({ operatorId: 1, createdAt: -1 });

export class BusTypeRequestListQueryDto extends createZodDto(
  z.object({
    /** Part of the bus type name or the operator name. */
    query: z.string().trim().max(100).optional(),
    status: z.enum(BUS_TYPE_REQUEST_STATUSES).optional(),
    operatorId: objectIdString.optional(),
    ...pagingShape,
  }),
) {}

export class BusTypeRequestIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class RejectBusTypeRequestDto extends createZodDto(
  z.object({ reason: z.string().trim().min(3).max(500) }),
) {}

/** The Requests tab of the admin Bus types page. */
@ApiTags('catalogue')
@Controller('admin/bus-type-requests')
export class BusTypeRequestsAdminController {
  constructor(private readonly requests: BusTypeRequestsAdminService) {}

  // catalogue.read; read only, no audit
  @Get()
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'List bus type requests from operators',
    description:
      'Requires catalogue.read. Newest first. Filters: query (bus type, operator), status, ' +
      'operatorId. Paginated.',
  })
  list(@Query() query: BusTypeRequestListQueryDto): Promise<PaginatedResult<BusTypeRequestView>> {
    return this.requests.list(query);
  }

  // catalogue.read; the number on the tab
  @Get('pending-count')
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'How many bus type requests wait',
    description: 'Requires catalogue.read.',
  })
  pendingCount(): Promise<{ pending: number }> {
    return this.requests.pendingCount();
  }

  // catalogue.read; read only, no audit
  @Get(':id')
  @RequirePermission('catalogue.read')
  @ApiOperation({ summary: 'One bus type request', description: 'Requires catalogue.read.' })
  get(@Param() params: BusTypeRequestIdParamDto): Promise<BusTypeRequestView> {
    return this.requests.get(params.id);
  }

  // catalogue.manage; audit bus-type-request.approved; event tells the operator
  @Post(':id/approve')
  @HttpCode(200)
  @RequirePermission('catalogue.manage')
  @ApiOperation({
    summary: 'Approve a bus type request',
    description:
      'Requires catalogue.manage (platform staff). Adds the bus type to the list, so every ' +
      'operator can use it, and tells the operator. Refused when the request was already decided ' +
      'or a bus type with the same name exists. Audited.',
  })
  approve(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusTypeRequestIdParamDto,
    @Req() request: Request,
  ): Promise<BusTypeRequestView> {
    return this.requests.approve(actor, params.id, clientRequestInfo(request));
  }

  // catalogue.manage; audit bus-type-request.rejected with the reason; event tells the operator
  @Post(':id/reject')
  @HttpCode(200)
  @RequirePermission('catalogue.manage')
  @ZodApiBody(RejectBusTypeRequestDto)
  @ApiOperation({
    summary: 'Reject a bus type request',
    description:
      'Requires catalogue.manage (platform staff). The reason is shown to the operator and sent ' +
      'to them. Refused when the request was already decided. Audited.',
  })
  reject(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusTypeRequestIdParamDto,
    @Body() body: RejectBusTypeRequestDto,
    @Req() request: Request,
  ): Promise<BusTypeRequestView> {
    return this.requests.reject(actor, params.id, body.reason, clientRequestInfo(request));
  }
}

/**
 * Bus type requests: operators ask for a kind of bus that is not listed (client portal Add bus
 * form); Abra approves or rejects it (admin Bus types page, Requests tab). Imported by BusTypesModule.
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: BUS_TYPE_REQUEST_MODEL, schema: busTypeRequestSchema }]),
    RbacModule,
    UsersModule,
    NotificationsModule,
  ],
  controllers: [BusTypeRequestsAdminController, BusTypeRequestsClientController],
  providers: [
    BusTypeRequestsAdminService,
    BusTypeRequestsClientService,
    BusTypeRequestNotificationHandler,
  ],
})
export class BusTypeRequestsModule {}
