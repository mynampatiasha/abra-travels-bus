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
import { BusListQueryDto, ChangeBusStatusDto, CreateBusDto, UpdateBusDto } from '../dto/bus.dto';
import { type BusView, BusesService } from '../services/buses.service';

const SCOPE =
  'Platform staff work across operators; operator staff only with their own. A record of another ' +
  'operator answers RESOURCE_NOT_FOUND.';

@ApiTags('catalogue')
@Controller('catalogue/buses')
export class BusesController {
  constructor(private readonly buses: BusesService) {}

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({
    summary: 'List buses',
    description: `Requires buses.read. ${SCOPE} Filter by operatorId and status. Paginated.`,
  })
  list(@Query() query: BusListQueryDto): Promise<PaginatedResult<BusView>> {
    return this.buses.list(query);
  }

  @Get(':id')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'One bus', description: `Requires buses.read. ${SCOPE}` })
  get(@Param() params: CatalogueIdParamDto): Promise<BusView> {
    return this.buses.get(params.id);
  }

  @Post()
  @RequirePermission('buses.create')
  @ZodApiBody(CreateBusDto)
  @ApiOperation({
    summary: 'Add a bus',
    description:
      `Requires buses.create. ${SCOPE} The bus type must be active and the registration ` +
      'number unique on the platform (ALREADY_REGISTERED otherwise). Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBusDto,
    @Req() request: Request,
  ): Promise<BusView> {
    return this.buses.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('buses.update')
  @ZodApiBody(UpdateBusDto)
  @ApiOperation({
    summary: 'Edit a bus',
    description:
      `Requires buses.update. ${SCOPE} Operator and registration number cannot be changed. ` +
      'Published trips keep the copy they took. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateBusDto,
    @Req() request: Request,
  ): Promise<BusView> {
    return this.buses.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/status')
  @RequirePermission('buses.update')
  @ZodApiBody(ChangeBusStatusDto)
  @ApiOperation({
    summary: 'Change the status of a bus',
    description:
      `Requires buses.update. ${SCOPE} ACTIVE, MAINTENANCE or RETIRED (final). Only an ACTIVE ` +
      'bus can have a trip published. Audited.',
  })
  changeStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: ChangeBusStatusDto,
    @Req() request: Request,
  ): Promise<BusView> {
    return this.buses.changeStatus(actor, params.id, body, clientRequestInfo(request));
  }
}
