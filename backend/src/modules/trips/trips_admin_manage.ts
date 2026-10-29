import {
  Body,
  Controller,
  Get,
  Param,
  Post,
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
  type AdminTripKpis,
  type AdminTripView,
  TripsAdminManageService,
} from './trips_admin_manage.service';
import { type SeatInventoryItem } from './schemas/seat-inventory.schema';

export const AdminTripListQuerySchema = z.object({
  operatorId: objectIdString.optional(),
  status: z.string().optional(),
  routeId: objectIdString.optional(),
  search: z.string().optional(),
  occupancy: z.enum(['low', 'high', 'all']).optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(50),
  sort: z.string().optional(),
  dir: z.coerce.number().optional(),
});

export const AdminBlockSeatsSchema = z.object({
  seatNumbers: z.array(z.string().min(1)).min(1, 'Pick at least one seat'),
  reason: z.string().min(1, 'Reason is required').max(300),
});

export const AdminUnblockSeatsSchema = z.object({
  seatNumbers: z.array(z.string().min(1)).min(1, 'Pick at least one seat'),
});

export class AdminTripListQueryDto extends createZodDto(AdminTripListQuerySchema) {}
export class AdminTripIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}
export class AdminBlockSeatsDto extends createZodDto(AdminBlockSeatsSchema) {}
export class AdminUnblockSeatsDto extends createZodDto(AdminUnblockSeatsSchema) {}

export const ADMIN_TRIPS_EXPORT_KIND: ExportKind<AdminTripView> = {
  key: 'admin_trips',
  columns: [
    { header: 'Trip ID', value: (t) => t.id },
    { header: 'Operator', value: (t) => t.operatorName },
    { header: 'Route', value: (t) => t.route },
    { header: 'Bus', value: (t) => t.bus },
    { header: 'Departs', value: (t) => timeOf(t.departureAt) },
    { header: 'Sold', value: (t) => String(t.bookedSeats) },
    { header: 'Held', value: (t) => String(t.heldSeats) },
    { header: 'Blocked', value: (t) => String(t.blockedSeats) },
    { header: 'Free', value: (t) => String(t.availableSeats) },
    { header: 'Occupancy', value: (t) => `${t.occupancyPercent}%` },
    { header: 'Status', value: (t) => readable(t.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const TripsAdminExportController = exportController({
  base: 'admin/trips',
  permission: 'trips.read',
  kind: ADMIN_TRIPS_EXPORT_KIND,
  service: TripsAdminManageService,
  query: AdminTripListQueryDto,
  title: 'trips and seat inventory',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('Admin Trips')
@Controller('admin/trips')
export class TripsAdminController {
  constructor(private readonly service: TripsAdminManageService) {}

  @Get()
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'List trips across all operators with KPIs' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: AdminTripListQueryDto,
  ): Promise<PaginatedResult<AdminTripView> & { kpis: AdminTripKpis }> {
    return this.service.list(actor, query);
  }

  @Get(':id')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'Get single trip details' })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminTripIdParamDto,
  ): Promise<AdminTripView> {
    return this.service.get(actor, params.id);
  }

  @Get(':id/seats')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'Get seat inventory for trip' })
  listSeats(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminTripIdParamDto,
  ): Promise<SeatInventoryItem[]> {
    return this.service.listSeats(actor, params.id);
  }

  @Post(':id/seats/block')
  @RequirePermission('trips.update')
  @ZodApiBody(AdminBlockSeatsDto)
  @ApiOperation({ summary: 'Admin block seats with reason' })
  blockSeats(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminTripIdParamDto,
    @Body() body: AdminBlockSeatsDto,
    @Req() request: Request,
  ): Promise<{ blockedCount: number }> {
    return this.service.blockSeats(actor, params.id, body.seatNumbers, body.reason, clientRequestInfo(request));
  }

  @Post(':id/seats/unblock')
  @RequirePermission('trips.update')
  @ZodApiBody(AdminUnblockSeatsDto)
  @ApiOperation({ summary: 'Admin unblock seats' })
  unblockSeats(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: AdminTripIdParamDto,
    @Body() body: AdminUnblockSeatsDto,
    @Req() request: Request,
  ): Promise<{ unblockedCount: number }> {
    return this.service.unblockSeats(actor, params.id, body.seatNumbers, clientRequestInfo(request));
  }

  @Post('release-holds')
  @RequirePermission('trips.update')
  @ApiOperation({ summary: 'Release expired seat holds' })
  releaseExpiredHolds(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Req() request: Request,
  ): Promise<{ releasedCount: number }> {
    return this.service.releaseExpiredHolds(actor, clientRequestInfo(request));
  }
}
