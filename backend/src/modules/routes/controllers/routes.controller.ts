import { Body, Controller, Get, Param, Post, Put, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { CatalogueIdParamDto } from '../../cities/dto/city-admin.dto';
import {
  ChangeRouteStatusDto,
  CreateRouteDto,
  RouteListQueryDto,
  UpdateRouteDto,
} from '../dto/route.dto';
import { type RouteView, RoutesService } from '../services/routes.service';

const SCOPE =
  'Platform staff work across operators; operator staff only with their own. A record of another ' +
  'operator answers RESOURCE_NOT_FOUND.';

@ApiTags('catalogue')
@Controller('catalogue/routes')
export class RoutesController {
  constructor(private readonly routes: RoutesService) {}

  @Get()
  @RequirePermission('routes.read')
  @ApiOperation({
    summary: 'List routes',
    description:
      `Requires routes.read. ${SCOPE} Filter by operatorId, originCityId, destinationCityId ` +
      'and status. Paginated.',
  })
  list(@Query() query: RouteListQueryDto): Promise<PaginatedResult<RouteView>> {
    return this.routes.list(query);
  }

  @Get(':id')
  @RequirePermission('routes.read')
  @ApiOperation({ summary: 'One route', description: `Requires routes.read. ${SCOPE}` })
  get(@Param() params: CatalogueIdParamDto): Promise<RouteView> {
    return this.routes.get(params.id);
  }

  @Post()
  @RequirePermission('routes.create')
  @ZodApiBody(CreateRouteDto)
  @ApiOperation({
    summary: 'Add a route',
    description:
      `Requires routes.create. ${SCOPE} Origin, destination and stops must be active cities, ` +
      'each used once; stop times increase and fall within the journey time. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateRouteDto,
    @Req() request: Request,
  ): Promise<RouteView> {
    return this.routes.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('routes.update')
  @ZodApiBody(UpdateRouteDto)
  @ApiOperation({
    summary: 'Edit a route',
    description:
      `Requires routes.update. ${SCOPE} Origin, destination and operator cannot be changed. ` +
      'Trips already created are not changed. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateRouteDto,
    @Req() request: Request,
  ): Promise<RouteView> {
    return this.routes.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/status')
  @RequirePermission('routes.update')
  @ZodApiBody(ChangeRouteStatusDto)
  @ApiOperation({
    summary: 'Enable or disable a route',
    description:
      `Requires routes.update. ${SCOPE} ACTIVE or INACTIVE. A trip on an inactive route ` +
      'cannot be published. Audited.',
  })
  changeStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: ChangeRouteStatusDto,
    @Req() request: Request,
  ): Promise<RouteView> {
    return this.routes.changeStatus(actor, params.id, body, clientRequestInfo(request));
  }
}
