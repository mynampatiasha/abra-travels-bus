import { Body, Controller, Get, Param, Post, Put, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { CatalogueIdParamDto } from '../../cities/dto/city-admin.dto';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import {
  CancelTripDto,
  CreateTripDto,
  TripListQueryDto,
  UpdateTripDto,
} from '../dto/trip-management.dto';
import { type ManagedTripView, TripManagementService } from '../services/trip-management.service';

const SCOPE =
  'Platform staff work across operators; operator staff only with their own trips, buses and ' +
  'routes. A trip of another operator answers RESOURCE_NOT_FOUND.';

/** Trips for the people who run them. Customers use the public `/trips` endpoints. */
@ApiTags('catalogue')
@Controller('catalogue/trips')
export class TripManagementController {
  constructor(private readonly trips: TripManagementService) {}

  @Get()
  @RequirePermission('trips.read')
  @ApiOperation({
    summary: 'List trips',
    description:
      `Requires trips.read as platform or operator staff. ${SCOPE} All statuses including drafts; filter by operatorId, ` +
      'busId, routeId, travelDate and status. By departure time. Paginated.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: TripListQueryDto,
  ): Promise<PaginatedResult<ManagedTripView>> {
    return this.trips.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'One trip', description: `Requires trips.read. ${SCOPE}` })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
  ): Promise<ManagedTripView> {
    return this.trips.get(actor, params.id);
  }

  @Post()
  @RequirePermission('trips.create')
  @ZodApiBody(CreateTripDto)
  @ApiOperation({
    summary: 'Create a draft trip',
    description:
      `Requires trips.create. ${SCOPE} Bus and route must belong to the same operator; ` +
      'boarding points lie in the origin or a stop city and dropping points in a stop city or ' +
      'the destination; point times fall inside the journey. The travel date is from today to ' +
      '180 days ahead (India time). The trip is a DRAFT and invisible to customers. Audited.',
  })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateTripDto,
    @Req() request: Request,
  ): Promise<ManagedTripView> {
    return this.trips.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('trips.update')
  @ZodApiBody(UpdateTripDto)
  @ApiOperation({
    summary: 'Edit a draft trip',
    description:
      `Requires trips.update. ${SCOPE} Only a DRAFT can be edited (INVALID_STATE_TRANSITION ` +
      'otherwise); the same rules as creation apply to the result. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateTripDto,
    @Req() request: Request,
  ): Promise<ManagedTripView> {
    return this.trips.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/publish')
  @RequirePermission('trips.publish')
  @ApiOperation({
    summary: 'Publish a trip (put it on sale)',
    description:
      `Requires trips.publish. ${SCOPE} DRAFT to SCHEDULED. Refused with VALIDATION_FAILED ` +
      'unless the operator, bus, bus type, route, its end cities and every boarding and ' +
      'dropping location are active, the bus has a seat capacity, the departure is in the ' +
      'future and the bus is free at that time. From this moment customers can find the trip. ' +
      'Audited.',
  })
  @ApiResponse({ status: 409, description: 'INVALID_STATE_TRANSITION (not a draft)' })
  publish(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Req() request: Request,
  ): Promise<ManagedTripView> {
    return this.trips.publish(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/cancel')
  @RequirePermission('trips.cancel')
  @ZodApiBody(CancelTripDto)
  @ApiOperation({
    summary: 'Cancel a trip',
    description:
      `Requires trips.cancel. ${SCOPE} DRAFT or SCHEDULED to CANCELLED; the trip leaves ` +
      'customer search at once. A reason is required. Audited.',
  })
  @ApiResponse({ status: 409, description: 'INVALID_STATE_TRANSITION' })
  cancel(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: CancelTripDto,
    @Req() request: Request,
  ): Promise<ManagedTripView> {
    return this.trips.cancel(actor, params.id, body.reason, clientRequestInfo(request));
  }
}
