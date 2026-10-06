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
import { SetActiveDto } from '../../cities/dto/city-admin.dto';
import { CreateLocationDto, LocationListQueryDto, UpdateLocationDto } from '../dto/location.dto';
import { type LocationView, LocationsService } from '../services/locations.service';

const SCOPE =
  'Operator staff see the shared locations and their own, and can change only their own; ' +
  'platform staff see and change all.';

@ApiTags('catalogue')
@Controller('catalogue/locations')
export class LocationsController {
  constructor(private readonly locations: LocationsService) {}

  @Get()
  @RequirePermission('routes.read')
  @ApiOperation({
    summary: 'List boarding and dropping locations',
    description: `Requires routes.read. ${SCOPE} Filter by cityId and active. Paginated.`,
  })
  list(@Query() query: LocationListQueryDto): Promise<PaginatedResult<LocationView>> {
    return this.locations.list(query);
  }

  @Get(':id')
  @RequirePermission('routes.read')
  @ApiOperation({ summary: 'One location', description: `Requires routes.read. ${SCOPE}` })
  get(@Param() params: CatalogueIdParamDto): Promise<LocationView> {
    return this.locations.get(params.id);
  }

  @Post()
  @RequirePermission('routes.create')
  @ZodApiBody(CreateLocationDto)
  @ApiOperation({
    summary: 'Add a location',
    description:
      'Requires routes.create. The city must be active. Platform staff may leave operatorId ' +
      'out to create a location every operator can use; operator staff create for their own ' +
      'operator. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateLocationDto,
    @Req() request: Request,
  ): Promise<LocationView> {
    return this.locations.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('routes.update')
  @ZodApiBody(UpdateLocationDto)
  @ApiOperation({
    summary: 'Edit a location',
    description:
      `Requires routes.update. ${SCOPE} null clears an optional field. Published trips keep ` +
      'the copy they took. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateLocationDto,
    @Req() request: Request,
  ): Promise<LocationView> {
    return this.locations.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/active')
  @RequirePermission('routes.update')
  @ZodApiBody(SetActiveDto)
  @ApiOperation({
    summary: 'Enable or disable a location',
    description:
      `Requires routes.update. ${SCOPE} A trip that uses a disabled location cannot be ` +
      'published. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: SetActiveDto,
    @Req() request: Request,
  ): Promise<LocationView> {
    return this.locations.update(
      actor,
      params.id,
      { isActive: body.active },
      clientRequestInfo(request),
    );
  }
}
