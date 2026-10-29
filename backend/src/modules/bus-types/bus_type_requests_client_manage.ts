import { Body, Controller, Get, Param, Post, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  BUS_TYPE_REQUEST_STATUSES,
  type BusTypeRequestView,
} from './bus_type_requests_admin_manage.service';
import { BusTypeRequestsClientService } from './bus_type_requests_client_manage.service';
import { BERTH_TYPES } from './schemas/bus-type.schema';

// ===== 1. REQUESTS AND ANSWERS =====
// The schema of `bus_type_requests` is in bus_type_requests_admin_manage.ts (the admin feature owns it).

export class CreateBusTypeRequestDto extends createZodDto(
  z.object({
    name: z.string().trim().min(2).max(60),
    isAc: z.boolean(),
    berthType: z.enum(BERTH_TYPES),
    /** Only for staff of several operators; left out, the request is for their one operator. */
    operatorId: objectIdString.optional(),
  }),
) {}

export class ClientBusTypeRequestListQueryDto extends createZodDto(
  z.object({
    /** Part of the bus type name. */
    query: z.string().trim().max(100).optional(),
    status: z.enum(BUS_TYPE_REQUEST_STATUSES).optional(),
    ...pagingShape,
  }),
) {}

export class ClientBusTypeRequestIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

// ===== 2. CONTROLLER =====

/** The "My bus type isn't listed" request and "Your requests" of the client portal. */
@ApiTags('client portal')
@Controller('client/bus-type-requests')
export class BusTypeRequestsClientController {
  constructor(private readonly requests: BusTypeRequestsClientService) {}

  // buses.read; operator staff only; their own requests
  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({
    summary: 'My bus type requests',
    description:
      'Requires buses.read, operator staff only. The requests of the caller’s own operator, ' +
      'newest first, with the reason of a rejection. Filters: query, status. Paginated.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientBusTypeRequestListQueryDto,
  ): Promise<PaginatedResult<BusTypeRequestView>> {
    return this.requests.list(actor, query);
  }

  // buses.read; another operator's request is not found
  @Get(':id')
  @RequirePermission('buses.read')
  @ApiOperation({
    summary: 'One of my bus type requests',
    description: 'Requires buses.read, operator staff only. Another operator’s request is 404.',
  })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientBusTypeRequestIdParamDto,
  ): Promise<BusTypeRequestView> {
    return this.requests.get(actor, params.id);
  }

  // buses.create; audit bus-type-request.created; event tells Abra staff
  @Post()
  @RequirePermission('buses.create')
  @ZodApiBody(CreateBusTypeRequestDto)
  @ApiOperation({
    summary: 'Ask for a bus type that is not listed',
    description:
      'Requires buses.create, operator staff only. Asks Abra to add a kind of bus (name, AC or ' +
      'not, seater / sleeper / semi-sleeper / mixed). Refused when the bus type exists already or ' +
      'is already waiting for a decision. Abra staff are told. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBusTypeRequestDto,
    @Req() request: Request,
  ): Promise<BusTypeRequestView> {
    return this.requests.create(actor, body, clientRequestInfo(request));
  }
}
