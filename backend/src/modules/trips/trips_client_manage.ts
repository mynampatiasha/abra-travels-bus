import {
  Body,
  Controller,
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
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  type ClientTripKpis,
  type ClientTripView,
  TripsClientManageService,
} from './trips_client_manage.service';
import { type SeatInventoryItem } from './schemas/seat-inventory.schema';

export const ClientCreateTripSchema = z.object({
  routeId: objectIdString,
  busId: objectIdString,
  travelDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD'),
  departureTime: z.string().regex(/^\d{1,2}:\d{2}$/, 'Departure time must be HH:mm'),
  startingFarePaise: z.coerce.number().min(10000, 'Lowest fare must be at least Rs 100'),
  publish: z.boolean().optional(),
  driverId: objectIdString.optional(),
  conductorId: objectIdString.optional(),
});

export const ClientUpdateTripSchema = z.object({
  travelDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  departureTime: z.string().regex(/^\d{1,2}:\d{2}$/).optional(),
  startingFarePaise: z.coerce.number().min(10000).optional(),
  busId: objectIdString.optional(),
  routeId: objectIdString.optional(),
});

export const ClientTripCancelSchema = z.object({
  reason: z.string().min(1, 'Reason is required').max(300),
  proofFileIds: z.array(objectIdString).max(5).optional(),
});

export const ClientTripDelaySchema = z.object({
  delayMinutes: z.coerce.number().int().min(5).max(720),
  reason: z.string().min(1, 'Reason is required').max(300),
  proofFileIds: z.array(objectIdString).max(5).optional(),
});

export const ClientTripCrewSchema = z.object({
  driverId: objectIdString.optional(),
  conductorId: objectIdString.optional(),
});

export const ClientTripBlockSeatsSchema = z.object({
  seatNumbers: z.array(z.string().min(1)).min(1, 'Pick at least one seat'),
  reason: z.string().min(1, 'Reason is required').max(300),
});

export const ClientTripUnblockSeatsSchema = z.object({
  seatNumbers: z.array(z.string().min(1)).min(1, 'Pick at least one seat'),
});

export const ClientTripListQuerySchema = z.object({
  status: z.string().optional(),
  when: z.enum(['up', 'today', 'past', 'all']).optional(),
  routeId: objectIdString.optional(),
  busId: objectIdString.optional(),
  travelDate: z.string().optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(50),
  sort: z.string().optional(),
  dir: z.coerce.number().optional(),
});

export class ClientCreateTripDto extends createZodDto(ClientCreateTripSchema) {}
export class ClientUpdateTripDto extends createZodDto(ClientUpdateTripSchema) {}
export class ClientTripCancelDto extends createZodDto(ClientTripCancelSchema) {}
export class ClientTripDelayDto extends createZodDto(ClientTripDelaySchema) {}
export class ClientTripCrewDto extends createZodDto(ClientTripCrewSchema) {}
export class ClientTripBlockSeatsDto extends createZodDto(ClientTripBlockSeatsSchema) {}
export class ClientTripUnblockSeatsDto extends createZodDto(ClientTripUnblockSeatsSchema) {}
export class ClientTripListQueryDto extends createZodDto(ClientTripListQuerySchema) {}
export class ClientTripIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const CLIENT_TRIPS_EXPORT_KIND: ExportKind<ClientTripView> = {
  key: 'my_trips',
  columns: [
    { header: 'Trip ID', value: (t) => t.id },
    { header: 'Route', value: (t) => t.route },
    { header: 'Bus', value: (t) => t.bus },
    { header: 'Departs', value: (t) => timeOf(t.departureAt) },
    { header: 'Driver', value: (t) => t.driver ?? 'Not assigned' },
    { header: 'Booked', value: (t) => `${t.bookedSeats}/${t.totalSeats}` },
    { header: 'Fare', value: (t) => `₹${(t.startingFarePaise / 100).toFixed(2)}` },
    { header: 'Status', value: (t) => readable(t.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const TripsClientExportController = exportController({
  base: 'client/trips',
  permission: 'trips.read',
  kind: CLIENT_TRIPS_EXPORT_KIND,
  service: TripsClientManageService,
  query: ClientTripListQueryDto,
  title: 'trips',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('Client Trips')
@Controller('client/trips')
export class TripsClientController {
  constructor(private readonly service: TripsClientManageService) {}

  @Get()
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'List trips with status filters, search, and KPIs' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: ClientTripListQueryDto,
  ): Promise<PaginatedResult<ClientTripView> & { kpis: ClientTripKpis }> {
    return this.service.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'Get single trip details' })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
  ): Promise<ClientTripView> {
    return this.service.get(actor, params.id);
  }

  @Post()
  @RequirePermission('trips.create')
  @ZodApiBody(ClientCreateTripDto)
  @ApiOperation({ summary: 'Create a draft trip' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ClientCreateTripDto,
    @Req() request: Request,
  ): Promise<ClientTripView> {
    return this.service.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('trips.update')
  @ZodApiBody(ClientUpdateTripDto)
  @ApiOperation({ summary: 'Update a draft trip' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Body() body: ClientUpdateTripDto,
    @Req() request: Request,
  ): Promise<ClientTripView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/publish')
  @RequirePermission('trips.publish')
  @ApiOperation({ summary: 'Publish a draft trip to put it on sale' })
  publish(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Req() request: Request,
  ): Promise<ClientTripView> {
    return this.service.publish(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/cancel')
  @RequirePermission('trips.cancel')
  @ZodApiBody(ClientTripCancelDto)
  @ApiOperation({ summary: 'Cancel a trip with reason and optional proof file' })
  cancel(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Body() body: ClientTripCancelDto,
    @Req() request: Request,
  ): Promise<ClientTripView> {
    return this.service.cancel(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/delay')
  @RequirePermission('trips.update')
  @ZodApiBody(ClientTripDelayDto)
  @ApiOperation({ summary: 'Delay a trip with minutes, reason, and optional proof' })
  delay(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Body() body: ClientTripDelayDto,
    @Req() request: Request,
  ): Promise<ClientTripView> {
    return this.service.delay(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/crew')
  @RequirePermission('trips.update')
  @ZodApiBody(ClientTripCrewDto)
  @ApiOperation({ summary: 'Assign or change driver and conductor' })
  assignCrew(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Body() body: ClientTripCrewDto,
    @Req() request: Request,
  ): Promise<ClientTripView> {
    return this.service.assignCrew(actor, params.id, body, clientRequestInfo(request));
  }

  @Get(':id/manifest')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'Get passenger manifest for trip' })
  manifest(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
  ): Promise<{ bookings: unknown[]; message: string }> {
    return this.service.manifest(actor, params.id);
  }

  @Get(':id/seats')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'Get seat inventory for trip' })
  listSeats(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
  ): Promise<SeatInventoryItem[]> {
    return this.service.listSeats(actor, params.id);
  }

  @Post(':id/seats/block')
  @RequirePermission('trips.update')
  @ZodApiBody(ClientTripBlockSeatsDto)
  @ApiOperation({ summary: 'Block seats for counter sale or maintenance' })
  blockSeats(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Body() body: ClientTripBlockSeatsDto,
    @Req() request: Request,
  ): Promise<{ blockedCount: number }> {
    return this.service.blockSeats(actor, params.id, body.seatNumbers, body.reason, clientRequestInfo(request));
  }

  @Post(':id/seats/unblock')
  @RequirePermission('trips.update')
  @ZodApiBody(ClientTripUnblockSeatsDto)
  @ApiOperation({ summary: 'Unblock seats' })
  unblockSeats(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientTripIdParamDto,
    @Body() body: ClientTripUnblockSeatsDto,
    @Req() request: Request,
  ): Promise<{ unblockedCount: number }> {
    return this.service.unblockSeats(actor, params.id, body.seatNumbers, clientRequestInfo(request));
  }
}
