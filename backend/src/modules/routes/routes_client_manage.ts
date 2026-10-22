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
  type ClientRouteView,
  RoutesClientManageService,
} from './routes_client_manage.service';

export const ClientRouteStopSchema = z.object({
  placeId: z.string().min(1),
  name: z.string().min(1),
  city: z.string().min(1),
  offset: z.coerce.number().min(0).default(0),
  type: z.enum(['BOARDING', 'DROPPING', 'BOTH']).default('BOTH'),
});

export const ClientCreateRouteSchema = z.object({
  from: z.string().trim().min(1, 'From city is required'),
  to: z.string().trim().min(1, 'To city is required'),
  name: z.string().trim().optional(),
  km: z.coerce.number().positive('Distance must be positive'),
  hours: z.coerce.number().positive('Duration must be positive'),
  stops: z.array(ClientRouteStopSchema).min(2, 'A route needs at least 2 stops'),
});

export const ClientUpdateRouteSchema = z.object({
  from: z.string().trim().min(1).optional(),
  to: z.string().trim().min(1).optional(),
  name: z.string().trim().optional(),
  km: z.coerce.number().positive().optional(),
  hours: z.coerce.number().positive().optional(),
  status: z.enum(['ACTIVE', 'INACTIVE']).optional(),
  stops: z.array(ClientRouteStopSchema).min(2).optional(),
});

export const ClientRouteListQuerySchema = z.object({
  status: z.string().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(50),
});

export class ClientCreateRouteDto extends createZodDto(ClientCreateRouteSchema) {}
export class ClientUpdateRouteDto extends createZodDto(ClientUpdateRouteSchema) {}
export class ClientRouteListQueryDto extends createZodDto(ClientRouteListQuerySchema) {}
export class ClientRouteIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const CLIENT_ROUTES_EXPORT_KIND: ExportKind<ClientRouteView> = {
  key: 'my_routes',
  columns: [
    { header: 'Route', value: (r) => r.name },
    { header: 'Distance', value: (r) => `${r.km} km` },
    { header: 'Duration', value: (r) => `${r.hours} h` },
    { header: 'Stops', value: (r) => `${r.stops.length}` },
    { header: 'Your Trips', value: (r) => `${r.tripsCount}` },
    { header: 'Status', value: (r) => readable(r.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const RoutesClientExportController = exportController({
  base: 'client/routes',
  permission: 'routes.read',
  kind: CLIENT_ROUTES_EXPORT_KIND,
  service: RoutesClientManageService,
  query: ClientRouteListQueryDto,
  title: 'routes and stops',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('Client Routes')
@Controller('client/routes')
export class RoutesClientController {
  constructor(private readonly service: RoutesClientManageService) {}

  @Get()
  @RequirePermission('routes.read')
  @ApiOperation({ summary: 'List operator routes and shared routes' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientRouteListQueryDto,
  ): Promise<PaginatedResult<ClientRouteView>> {
    return this.service.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('routes.read')
  @ApiOperation({ summary: 'Get single route details and stops' })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientRouteIdParamDto,
  ): Promise<ClientRouteView> {
    return this.service.get(actor, params.id);
  }

  @Post()
  @RequirePermission('routes.create')
  @ZodApiBody(ClientCreateRouteDto)
  @ApiOperation({ summary: 'Create a new route with stops' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ClientCreateRouteDto,
    @Req() request: Request,
  ): Promise<ClientRouteView> {
    return this.service.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('routes.update')
  @ZodApiBody(ClientUpdateRouteDto)
  @ApiOperation({ summary: 'Update an operator-owned route' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientRouteIdParamDto,
    @Body() body: ClientUpdateRouteDto,
    @Req() request: Request,
  ): Promise<ClientRouteView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/copy')
  @RequirePermission('routes.create')
  @ApiOperation({ summary: 'Copy a shared route as an operator route' })
  copy(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientRouteIdParamDto,
    @Req() request: Request,
  ): Promise<ClientRouteView> {
    return this.service.copy(actor, params.id, clientRequestInfo(request));
  }

  @Delete(':id')
  @RequirePermission('routes.update')
  @ApiOperation({ summary: 'Soft delete an operator route' })
  delete(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientRouteIdParamDto,
    @Req() request: Request,
  ): Promise<{ success: boolean }> {
    return this.service.deleteRoute(actor, params.id, clientRequestInfo(request));
  }
}
