import { Schema } from 'mongoose';
import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
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
  type ClientBusKpis,
  type ClientBusView,
  type ClientSeatLayoutView,
  BusesClientManageService,
} from './buses_client_manage.service';
import {
  BusListQueryDto,
  ChangeBusStatusDto,
  CreateBusDto,
  SaveSeatLayoutDto,
  UpdateBusDto,
} from './dto/bus.dto';

export class ClientBusIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}
export class BusLayoutParamDto extends createZodDto(z.object({ busId: objectIdString })) {}
export class LayoutVersionParamDto extends createZodDto(z.object({ versionId: objectIdString })) {}

export const CLIENT_BUSES_EXPORT_KIND: ExportKind<ClientBusView> = {
  key: 'my_buses',
  columns: [
    { header: 'Registration', value: (bus) => bus.registrationNumber },
    { header: 'Bus Name', value: (bus) => bus.name },
    { header: 'Type', value: (bus) => bus.displayName },
    { header: 'Seats', value: (bus) => bus.seatCapacity },
    { header: 'Layout', value: (bus) => bus.seatLayoutType },
    { header: 'Insurance Expiry', value: (bus) => (bus.insuranceExpiryDate ? timeOf(bus.insuranceExpiryDate) : '-') },
    { header: 'Status', value: (bus) => readable(bus.status) },
  ],
};

function currentActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (actor?.actorType !== 'USER') throw new Error('An export needs a signed-in user');
  return actor as AuthenticatedUserActor;
}

export const BusesClientExportController = exportController({
  base: 'client/buses',
  permission: 'buses.read',
  kind: CLIENT_BUSES_EXPORT_KIND,
  service: BusesClientManageService,
  query: BusListQueryDto,
  title: 'my buses',
  load: (service, query) => service.list(currentActor(), query as never),
});

@ApiTags('client portal')
@Controller('client/buses')
export class BusesClientController {
  constructor(private readonly service: BusesClientManageService) {}

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'List my buses with KPIs' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: BusListQueryDto,
  ): Promise<PaginatedResult<ClientBusView>> {
    return this.service.list(actor, query);
  }

  @Get('kpis')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get bus KPIs for current operator' })
  kpis(@CurrentActor() actor: AuthenticatedUserActor): Promise<ClientBusKpis> {
    return this.service.kpis(actor);
  }

  @Get(':id')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get one of my buses' })
  get(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientBusIdParamDto,
  ): Promise<ClientBusView> {
    return this.service.get(actor, params.id);
  }

  @Post()
  @RequirePermission('buses.create')
  @ZodApiBody(CreateBusDto)
  @ApiOperation({ summary: 'Add a bus (send for approval)' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBusDto,
    @Req() request: Request,
  ): Promise<ClientBusView> {
    return this.service.create(actor, body, clientRequestInfo(request));
  }

  @Patch(':id')
  @RequirePermission('buses.update')
  @ZodApiBody(UpdateBusDto)
  @ApiOperation({ summary: 'Edit my bus' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientBusIdParamDto,
    @Body() body: UpdateBusDto,
    @Req() request: Request,
  ): Promise<ClientBusView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/status')
  @RequirePermission('buses.update')
  @ZodApiBody(ChangeBusStatusDto)
  @ApiOperation({ summary: 'Mark maintenance or active' })
  changeStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ClientBusIdParamDto,
    @Body() body: ChangeBusStatusDto,
    @Req() request: Request,
  ): Promise<ClientBusView> {
    return this.service.changeStatus(actor, params.id, body, clientRequestInfo(request));
  }
}

@ApiTags('client portal')
@Controller('client/seat-layouts')
export class SeatLayoutsClientController {
  constructor(private readonly service: BusesClientManageService) {}

  @Get(':busId')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get active seat layout of a bus' })
  getLayout(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusLayoutParamDto,
  ): Promise<ClientSeatLayoutView> {
    return this.service.getLayoutForBus(actor, params.busId);
  }

  @Put(':busId')
  @RequirePermission('buses.update')
  @ZodApiBody(SaveSeatLayoutDto)
  @ApiOperation({ summary: 'Save new seat layout version for a bus' })
  saveLayout(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusLayoutParamDto,
    @Body() body: SaveSeatLayoutDto,
    @Req() request: Request,
  ): Promise<ClientSeatLayoutView> {
    return this.service.saveLayout(actor, params.busId, body, clientRequestInfo(request));
  }

  @Get('version/:versionId')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get layout snapshot by version ID' })
  getVersion(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: LayoutVersionParamDto,
  ): Promise<ClientSeatLayoutView> {
    return this.service.getLayoutVersion(actor, params.versionId);
  }
}

// ===== SEAT LAYOUT SCHEMA & TYPES =====

export {
  SEAT_LAYOUT_MODEL,
  SEAT_TYPES,
  type SeatType,
  SEAT_CATEGORIES,
  type SeatCategory,
  type SeatItem,
  type SeatLayout,
} from './buses_client_manage.service';
import {
  SEAT_TYPES,
  SEAT_CATEGORIES,
  type SeatLayout,
} from './buses_client_manage.service';

export const seatLayoutSchema = new Schema<SeatLayout>(
  {
    busId: { type: Schema.Types.ObjectId, required: true, index: true },
    operatorId: { type: Schema.Types.ObjectId, required: true, index: true },
    version: { type: Number, required: true },
    name: { type: String, required: true, trim: true, maxlength: 80 },
    layoutType: { type: String, required: true, trim: true, maxlength: 40, default: '2+2 Seater' },
    decks: { type: Number, required: true, default: 1, min: 1, max: 2 },
    map: { type: [String], required: true, default: [] },
    upperDeckMap: { type: [String], default: undefined },
    seats: [
      {
        seatNumber: { type: String, required: true },
        deck: { type: Number, required: true, default: 1 },
        row: { type: Number, required: true },
        col: { type: Number, required: true },
        type: { type: String, enum: SEAT_TYPES, required: true, default: 'SEAT' },
        category: { type: String, enum: SEAT_CATEGORIES, required: true, default: 'STANDARD' },
        isLadies: { type: Boolean, required: true, default: false },
        isBlocked: { type: Boolean, required: true, default: false },
      },
    ],
    totalSeats: { type: Number, required: true, min: 1, max: 120 },
    ladiesSeatsCount: { type: Number, required: true, default: 0 },
  },
  { collection: 'seat_layouts', timestamps: true, versionKey: false },
);

seatLayoutSchema.index({ busId: 1, version: -1 });
seatLayoutSchema.index({ busId: 1, version: 1 }, { unique: true });
