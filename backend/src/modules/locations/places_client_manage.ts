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
import { RequestContextService } from '../../common/request-context/request-context.service';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { PLACE_REQUEST_STATUSES, type PlaceRequestView } from './places_admin_manage.service';
import { type PlaceRequestCity, PlaceRequestsClientService } from './places_client_manage.service';

// ===== 1. REQUESTS AND ANSWERS =====
// The schema of `place_requests` is in places_admin_manage.ts (the admin feature owns it).

export class CreatePlaceRequestDto extends createZodDto(
  z.object({
    cityId: objectIdString,
    name: z.string().trim().min(2).max(120),
    address: z.string().trim().min(3).max(300),
    landmark: z.string().trim().min(2).max(160).optional(),
    /** Only for staff of several operators; left out, the request is for their one operator. */
    operatorId: objectIdString.optional(),
  }),
) {}

export class ClientPlaceRequestListQueryDto extends createZodDto(
  z.object({
    /** Part of the place, address or city. */
    query: z.string().trim().max(100).optional(),
    status: z.enum(PLACE_REQUEST_STATUSES).optional(),
    cityId: objectIdString.optional(),
    ...pagingShape,
  }),
) {}

export class ClientPlaceRequestIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

/** "Your requests" as a file: the operator's own requests only. */
export const CLIENT_PLACE_REQUESTS_EXPORT_KIND: ExportKind<PlaceRequestView> = {
  key: 'place_requests',
  columns: [
    { header: 'Place', value: (request) => request.name },
    { header: 'Address', value: (request) => request.address },
    { header: 'Landmark', value: (request) => request.landmark },
    { header: 'City', value: (request) => request.cityName },
    { header: 'Requested', value: (request) => timeOf(request.requestedAt) },
    { header: 'Status', value: (request) => readable(request.status) },
    { header: 'Reason', value: (request) => request.reason },
  ],
};

/** The signed-in person, for the export (the export controller passes only the service). */
function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

// ===== 2. CONTROLLER =====

/** `GET client/place-requests/export`. Registered before the controller below. */
export const PlaceRequestsClientExportController = exportController({
  base: 'client/place-requests',
  permission: 'routes.read',
  kind: CLIENT_PLACE_REQUESTS_EXPORT_KIND,
  service: PlaceRequestsClientService,
  query: ClientPlaceRequestListQueryDto,
  title: 'my place requests',
  load: (service, query) => service.list(currentActor(), query as never),
});

/** The client portal Places page: "Request a place" and "Your requests". */
@ApiTags('client portal')
@Controller('client/place-requests')
export class PlaceRequestsClientController {
  constructor(private readonly requests: PlaceRequestsClientService) {}

  // routes.read; operator staff only; their own requests
  @Get()
  @RequirePermission('routes.read')
  @ApiOperation({
    summary: 'My place requests',
    description:
      'Requires routes.read, operator staff only. The requests of the caller’s own operator, ' +
      'newest first, with the reason of a rejection. Filters: query, status, cityId. Paginated.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientPlaceRequestListQueryDto,
  ): Promise<PaginatedResult<PlaceRequestView>> {
    return this.requests.list(actor, query);
  }

  // routes.read; the City list of the request form and the filter
  @Get('cities')
  @RequirePermission('routes.read')
  @ApiOperation({
    summary: 'Cities a place can be asked for in',
    description: 'Requires routes.read. The active cities, by name.',
  })
  cities(): Promise<PlaceRequestCity[]> {
    return this.requests.cities();
  }

  // routes.read; another operator's request is not found
  @Get(':id')
  @RequirePermission('routes.read')
  @ApiOperation({
    summary: 'One of my place requests',
    description: 'Requires routes.read, operator staff only. Another operator’s request is 404.',
  })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientPlaceRequestIdParamDto,
  ): Promise<PlaceRequestView> {
    return this.requests.get(actor, params.id);
  }

  // routes.create; audit place-request.created; event place-request.created tells Abra staff
  @Post()
  @RequirePermission('routes.create')
  @ZodApiBody(CreatePlaceRequestDto)
  @ApiOperation({
    summary: 'Request a place',
    description:
      'Requires routes.create, operator staff only. Asks Abra to add a boarding or dropping ' +
      'place. Refused when the city is not active, the place already exists in that city, or ' +
      'the same place is already waiting for a decision. Abra staff are told. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreatePlaceRequestDto,
    @Req() request: Request,
  ): Promise<PlaceRequestView> {
    return this.requests.create(actor, body, clientRequestInfo(request));
  }
}
