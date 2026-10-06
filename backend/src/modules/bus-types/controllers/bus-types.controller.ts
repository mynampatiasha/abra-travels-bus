import { Body, Controller, Get, Param, Post, Put, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { CatalogueIdParamDto, SetActiveDto } from '../../cities/dto/city-admin.dto';
import { BusTypeListQueryDto, CreateBusTypeDto, UpdateBusTypeDto } from '../dto/bus-type.dto';
import { type BusTypeView, BusTypesService } from '../services/bus-types.service';

@ApiTags('catalogue')
@Controller('catalogue/bus-types')
export class BusTypesController {
  constructor(private readonly busTypes: BusTypesService) {}

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({
    summary: 'List bus types',
    description:
      'Requires buses.read (operator staff choose a type when adding a bus). `active` filters ' +
      'by state. Paginated.',
  })
  list(@Query() query: BusTypeListQueryDto): Promise<PaginatedResult<BusTypeView>> {
    return this.busTypes.list(query);
  }

  @Post()
  @RequirePermission('catalogue.manage')
  @ZodApiBody(CreateBusTypeDto)
  @ApiOperation({
    summary: 'Add a bus type',
    description: 'Requires catalogue.manage. The key is unique and permanent. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBusTypeDto,
    @Req() request: Request,
  ): Promise<BusTypeView> {
    return this.busTypes.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('catalogue.manage')
  @ZodApiBody(UpdateBusTypeDto)
  @ApiOperation({
    summary: 'Edit a bus type',
    description:
      'Requires catalogue.manage. Trips already created keep the values they copied. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateBusTypeDto,
    @Req() request: Request,
  ): Promise<BusTypeView> {
    return this.busTypes.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/active')
  @RequirePermission('catalogue.manage')
  @ZodApiBody(SetActiveDto)
  @ApiOperation({
    summary: 'Enable or disable a bus type',
    description:
      'Requires catalogue.manage. A disabled type cannot be given to a bus and a trip of a bus ' +
      'with a disabled type cannot be published. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: SetActiveDto,
    @Req() request: Request,
  ): Promise<BusTypeView> {
    return this.busTypes.update(
      actor,
      params.id,
      { isActive: body.active },
      clientRequestInfo(request),
    );
  }
}
