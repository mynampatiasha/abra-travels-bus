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
  type ClientFare,
  type ClientFareView,
  FaresClientManageService,
} from './fares_client_manage.service';

export const fareSchema = new Schema<ClientFare>(
  {
    operatorId: { type: Schema.Types.ObjectId, ref: 'operators', required: true, index: true },
    routeId: { type: Schema.Types.ObjectId, ref: 'routes', required: true, index: true },
    route: { type: String, required: true, trim: true },
    seatType: { type: String, required: true, trim: true },
    weekday: { type: Number, required: true, min: 10000 },
    weekend: { type: Number, required: true, min: 10000 },
    festival: { type: Number, required: true, min: 10000 },
    from: { type: String, required: true },
    status: { type: String, enum: ['ACTIVE', 'INACTIVE'], default: 'ACTIVE', index: true },
    version: { type: Number, default: 1 },
    fareRuleSetVersionId: { type: Schema.Types.ObjectId, index: true },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date },
  },
  { collection: 'fares', timestamps: true, versionKey: false },
);

fareSchema.index({ operatorId: 1, isDeleted: 1 });
fareSchema.index({ operatorId: 1, routeId: 1, seatType: 1, status: 1 });

export const ClientCreateFareSchema = z.object({
  routeId: objectIdString,
  seatType: z.string().trim().min(1, 'Seat type is required'),
  weekday: z.coerce.number().min(10000, 'Weekday fare must be at least Rs 100'),
  weekend: z.coerce.number().min(5000, 'Weekend fare must be at least 50% of weekday'),
  festival: z.coerce.number().min(10000, 'Festival fare must be at least Rs 100'),
  from: z.string().min(1, 'Effective from date is required'),
  status: z.enum(['ACTIVE', 'INACTIVE']).default('ACTIVE'),
});

export const ClientUpdateFareSchema = z.object({
  routeId: objectIdString.optional(),
  seatType: z.string().trim().min(1).optional(),
  weekday: z.coerce.number().min(10000).optional(),
  weekend: z.coerce.number().min(5000).optional(),
  festival: z.coerce.number().min(10000).optional(),
  from: z.string().min(1).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
});

export const ClientFareListQuerySchema = z.object({
  routeId: objectIdString.optional(),
  status: z.string().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(50),
});

export class ClientCreateFareDto extends createZodDto(ClientCreateFareSchema) {}
export class ClientUpdateFareDto extends createZodDto(ClientUpdateFareSchema) {}
export class ClientFareListQueryDto extends createZodDto(ClientFareListQuerySchema) {}
export class ClientFareIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const CLIENT_FARES_EXPORT_KIND: ExportKind<ClientFareView> = {
  key: 'my_fares',
  columns: [
    { header: 'Route', value: (f) => f.route },
    { header: 'Seat Type', value: (f) => f.seatType },
    { header: 'Weekday', value: (f) => `₹${(f.weekday / 100).toFixed(2)}` },
    { header: 'Weekend', value: (f) => `₹${(f.weekend / 100).toFixed(2)}` },
    { header: 'Festival', value: (f) => `₹${(f.festival / 100).toFixed(2)}` },
    { header: 'Customer Pays (Weekday)', value: (f) => `₹${(f.customerPaysWeekday.total / 100).toFixed(2)}` },
    { header: 'Status', value: (f) => readable(f.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const FaresClientExportController = exportController({
  base: 'client/fares',
  permission: 'fares.read',
  kind: CLIENT_FARES_EXPORT_KIND,
  service: FaresClientManageService,
  query: ClientFareListQueryDto,
  title: 'fares',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('Client Fares')
@Controller('client/fares')
export class FaresClientController {
  constructor(private readonly service: FaresClientManageService) {}

  @Get()
  @RequirePermission('fares.read')
  @ApiOperation({ summary: 'List operator fares with customer pricing preview' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientFareListQueryDto,
  ): Promise<PaginatedResult<ClientFareView>> {
    return this.service.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('fares.read')
  @ApiOperation({ summary: 'Get single fare details' })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientFareIdParamDto,
  ): Promise<ClientFareView> {
    return this.service.get(actor, params.id);
  }

  @Post()
  @RequirePermission('fares.create')
  @ZodApiBody(ClientCreateFareDto)
  @ApiOperation({ summary: 'Create a new fare for a route and seat type' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ClientCreateFareDto,
    @Req() request: Request,
  ): Promise<ClientFareView> {
    return this.service.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('fares.update')
  @ZodApiBody(ClientUpdateFareDto)
  @ApiOperation({ summary: 'Update an existing fare' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientFareIdParamDto,
    @Body() body: ClientUpdateFareDto,
    @Req() request: Request,
  ): Promise<ClientFareView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Delete(':id')
  @RequirePermission('fares.update')
  @ApiOperation({ summary: 'Soft delete a fare' })
  delete(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientFareIdParamDto,
    @Req() request: Request,
  ): Promise<{ success: boolean }> {
    return this.service.deleteFare(actor, params.id, clientRequestInfo(request));
  }
}
