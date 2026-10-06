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
  ChangeOperatorStatusDto,
  CreateOperatorDto,
  OperatorListQueryDto,
  UpdateOperatorDto,
} from '../dto/operator.dto';
import { type OperatorView, OperatorsService } from '../services/operators.service';

const SCOPE =
  'Platform staff see every operator; operator staff only their own. An operator outside the ' +
  "caller's data scope answers RESOURCE_NOT_FOUND.";

@ApiTags('catalogue')
@Controller('catalogue/operators')
export class OperatorsController {
  constructor(private readonly operators: OperatorsService) {}

  @Get()
  @RequirePermission('operators.read')
  @ApiOperation({
    summary: 'List operators',
    description: `Requires operators.read. ${SCOPE} Paginated.`,
  })
  list(@Query() query: OperatorListQueryDto): Promise<PaginatedResult<OperatorView>> {
    return this.operators.list(query);
  }

  @Get(':id')
  @RequirePermission('operators.read')
  @ApiOperation({ summary: 'One operator', description: `Requires operators.read. ${SCOPE}` })
  get(@Param() params: CatalogueIdParamDto): Promise<OperatorView> {
    return this.operators.get(params.id);
  }

  @Post()
  @RequirePermission('operators.create')
  @ZodApiBody(CreateOperatorDto)
  @ApiOperation({
    summary: 'Register an operator',
    description:
      'Requires operators.create (platform staff). The operator starts as PENDING_APPROVAL. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateOperatorDto,
    @Req() request: Request,
  ): Promise<OperatorView> {
    return this.operators.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('operators.update')
  @ZodApiBody(UpdateOperatorDto)
  @ApiOperation({
    summary: 'Edit an operator profile',
    description: `Requires operators.update. ${SCOPE} The status is not changed here. Audited.`,
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateOperatorDto,
    @Req() request: Request,
  ): Promise<OperatorView> {
    return this.operators.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/status')
  @RequirePermission('operators.approve')
  @ZodApiBody(ChangeOperatorStatusDto)
  @ApiOperation({
    summary: 'Approve, reject, suspend or reactivate an operator',
    description:
      'Requires operators.approve (platform staff). Allowed: PENDING_APPROVAL to ACTIVE or ' +
      'REJECTED, ACTIVE to SUSPENDED, SUSPENDED to ACTIVE; anything else answers ' +
      'INVALID_STATE_TRANSITION. A suspended operator disappears from customer search at once. ' +
      'A reason is required. Audited.',
  })
  changeStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: ChangeOperatorStatusDto,
    @Req() request: Request,
  ): Promise<OperatorView> {
    return this.operators.changeStatus(actor, params.id, body, clientRequestInfo(request));
  }
}
