import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Schema } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { RequestContextService } from '../../common/request-context/request-context.service';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
} from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  type ClientSchedule,
  type ClientScheduleView,
  type GenerateTripsResult,
  SchedulesClientManageService,
  WEEKDAYS,
} from './schedules_client_manage.service';

export const scheduleSchema = new Schema<ClientSchedule>(
  {
    operatorId: { type: Schema.Types.ObjectId, ref: 'operators', required: true, index: true },
    routeId: { type: Schema.Types.ObjectId, ref: 'routes', required: true, index: true },
    route: { type: String, required: true, trim: true },
    busId: { type: Schema.Types.ObjectId, ref: 'buses', required: true, index: true },
    bus: { type: String, required: true, trim: true },
    time: { type: String, required: true, trim: true },
    days: { type: [String], required: true },
    from: { type: String, required: true },
    to: { type: String, required: true },
    status: { type: String, enum: ['ACTIVE', 'INACTIVE'], default: 'ACTIVE', index: true },
    fare: { type: Number, default: 100000 },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date },
  },
  { collection: 'schedules', timestamps: true, versionKey: false },
);

scheduleSchema.index({ operatorId: 1, isDeleted: 1 });
scheduleSchema.index({ operatorId: 1, status: 1 });

export const ClientCreateScheduleSchema = z.object({
  routeId: objectIdString,
  busId: objectIdString,
  time: z.string().trim().regex(/^\d{1,2}:\d{2}$/, 'Invalid departure time format (HH:mm)'),
  days: z.array(z.enum(WEEKDAYS)).min(1, 'Pick at least one day'),
  from: z.string().min(1, 'Valid from date required'),
  to: z.string().min(1, 'Valid till date required'),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
});

export const ClientUpdateScheduleSchema = z.object({
  routeId: objectIdString.optional(),
  busId: objectIdString.optional(),
  time: z.string().trim().regex(/^\d{1,2}:\d{2}$/).optional(),
  days: z.array(z.enum(WEEKDAYS)).min(1).optional(),
  from: z.string().min(1).optional(),
  to: z.string().min(1).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
});

export const ClientScheduleListQuerySchema = z.object({
  status: z.string().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(50),
});

export class ClientCreateScheduleDto extends createZodDto(ClientCreateScheduleSchema) {}
export class ClientUpdateScheduleDto extends createZodDto(ClientUpdateScheduleSchema) {}
export class ClientScheduleListQueryDto extends createZodDto(ClientScheduleListQuerySchema) {}
export class ClientScheduleIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const CLIENT_SCHEDULES_EXPORT_KIND: ExportKind<ClientScheduleView> = {
  key: 'my_schedules',
  columns: [
    { header: 'Route', value: (s) => s.route },
    { header: 'Bus', value: (s) => s.bus },
    { header: 'Departs', value: (s) => s.time },
    { header: 'Days', value: (s) => (s.days.length === 7 ? 'Every day' : s.days.join(', ')) },
    { header: 'Valid Till', value: (s) => s.to },
    { header: 'Status', value: (s) => readable(s.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const SchedulesClientExportController = exportController({
  base: 'client/schedules',
  permission: 'trips.read',
  kind: CLIENT_SCHEDULES_EXPORT_KIND,
  service: SchedulesClientManageService,
  query: ClientScheduleListQueryDto,
  title: 'schedules',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('Client Schedules')
@Controller('client/schedules')
export class SchedulesClientController {
  constructor(private readonly service: SchedulesClientManageService) {}

  @Get()
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'List operator schedules with frequency and status' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientScheduleListQueryDto,
  ): Promise<PaginatedResult<ClientScheduleView>> {
    return this.service.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'Get single schedule details' })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientScheduleIdParamDto,
  ): Promise<ClientScheduleView> {
    return this.service.get(actor, params.id);
  }

  @Post()
  @RequirePermission('trips.create')
  @ZodApiBody(ClientCreateScheduleDto)
  @ApiOperation({ summary: 'Create a new recurring schedule' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ClientCreateScheduleDto,
    @Req() request: Request,
  ): Promise<ClientScheduleView> {
    return this.service.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('trips.update')
  @ZodApiBody(ClientUpdateScheduleDto)
  @ApiOperation({ summary: 'Update an existing schedule' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientScheduleIdParamDto,
    @Body() body: ClientUpdateScheduleDto,
    @Req() request: Request,
  ): Promise<ClientScheduleView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Delete(':id')
  @RequirePermission('trips.update')
  @ApiOperation({ summary: 'Soft delete a schedule' })
  delete(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientScheduleIdParamDto,
    @Req() request: Request,
  ): Promise<{ success: boolean }> {
    return this.service.deleteSchedule(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/generate-trips')
  @RequirePermission('trips.create')
  @ApiOperation({ summary: 'Generate draft trips for the next 14 days from schedule' })
  generateTrips(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientScheduleIdParamDto,
    @Req() request: Request,
  ): Promise<GenerateTripsResult> {
    return this.service.generateTrips(actor, params.id, clientRequestInfo(request));
  }
}
