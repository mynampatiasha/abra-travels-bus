import { Body, Controller, Get, Param, Post, Put, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import {
  CatalogueIdParamDto,
  CityListQueryDto,
  CreateCityDto,
  SetActiveDto,
  UpdateCityDto,
} from '../dto/city-admin.dto';
import { type CityAdminView, CitiesAdminService } from '../services/cities-admin.service';

/** City catalogue for platform staff. Customers use the public `GET /cities`. */
@ApiTags('catalogue')
@Controller('catalogue/cities')
export class CitiesAdminController {
  constructor(private readonly cities: CitiesAdminService) {}

  @Get()
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'List cities',
    description:
      'Requires catalogue.read. All cities including inactive ones, by name; `query` matches ' +
      'the start of the name, `active` filters by state. Paginated.',
  })
  list(@Query() query: CityListQueryDto): Promise<PaginatedResult<CityAdminView>> {
    return this.cities.list(query);
  }

  @Get(':id')
  @RequirePermission('catalogue.read')
  @ApiOperation({ summary: 'One city', description: 'Requires catalogue.read.' })
  get(@Param() params: CatalogueIdParamDto): Promise<CityAdminView> {
    return this.cities.get(params.id);
  }

  @Post()
  @RequirePermission('catalogue.manage')
  @ZodApiBody(CreateCityDto)
  @ApiOperation({
    summary: 'Add a city',
    description:
      'Requires catalogue.manage. The slug is made from the name when left out and must be ' +
      'unique (ALREADY_REGISTERED otherwise). The city is active at once. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateCityDto,
    @Req() request: Request,
  ): Promise<CityAdminView> {
    return this.cities.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('catalogue.manage')
  @ZodApiBody(UpdateCityDto)
  @ApiOperation({
    summary: 'Edit a city',
    description:
      'Requires catalogue.manage. Only the fields sent change; the slug cannot be changed. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateCityDto,
    @Req() request: Request,
  ): Promise<CityAdminView> {
    return this.cities.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/active')
  @RequirePermission('catalogue.manage')
  @ZodApiBody(SetActiveDto)
  @ApiOperation({
    summary: 'Enable or disable a city',
    description:
      'Requires catalogue.manage. A disabled city cannot be chosen by customers or used for ' +
      'new routes; trips already on sale are not changed. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: SetActiveDto,
    @Req() request: Request,
  ): Promise<CityAdminView> {
    return this.cities.setActive(actor, params.id, body, clientRequestInfo(request));
  }
}
