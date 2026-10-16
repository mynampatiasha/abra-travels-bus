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
import { type Types } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { importController } from '../catalogue-shared/catalogue_import_manage';
import {
  type ImportColumn,
  type ImportSpec,
  parseNumber,
} from '../catalogue-shared/catalogue_import_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  type AdminBusView,
  BusesAdminManageService,
} from './buses_admin_manage.service';
import {
  BulkMaintenanceDto,
  BusListQueryDto,
  ChangeBusStatusDto,
  CreateBusDto,
  UpdateBusDto,
} from './dto/bus.dto';

export class BusIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const BUSES_EXPORT_KIND: ExportKind<AdminBusView> = {
  key: 'buses',
  columns: [
    { header: 'Registration', value: (bus) => bus.registrationNumber },
    { header: 'Bus Name', value: (bus) => bus.name },
    { header: 'Operator', value: (bus) => bus.operatorName ?? '' },
    { header: 'Type', value: (bus) => bus.busTypeName ?? '' },
    { header: 'Seats', value: (bus) => bus.seatCapacity },
    { header: 'Layout', value: (bus) => bus.seatLayoutType },
    { header: 'Insurance Expiry', value: (bus) => (bus.insuranceExpiryDate ? timeOf(bus.insuranceExpiryDate) : '-') },
    { header: 'Status', value: (bus) => readable(bus.status) },
  ],
};

export const BusesExportController = exportController({
  base: 'catalogue/buses',
  permission: 'buses.read',
  kind: BUSES_EXPORT_KIND,
  service: BusesAdminManageService,
  query: BusListQueryDto,
  title: 'buses',
  load: (service, query) => service.list(query as never),
});

const BUS_IMPORT_COLUMNS: readonly ImportColumn[] = [
  { key: 'registration', header: 'Registration', required: true, sample: 'TS09 UB 1234' },
  { key: 'name', header: 'Bus name', required: true, sample: 'Kaveri Gold 12' },
  { key: 'type', header: 'Bus type', required: true, sample: 'AC Sleeper' },
  { key: 'seats', header: 'Seats', required: true, sample: '40' },
];

export const BUS_IMPORT_SPEC: ImportSpec<CreateBusDto, BusesAdminManageService> = {
  key: 'buses',
  columns: BUS_IMPORT_COLUMNS,
  async begin(context) {
    const types = await context.connection
      .model<{ name: string; isActive: boolean }>('BusType')
      .find({ isActive: true })
      .lean<Array<{ _id: Types.ObjectId; name: string }>>()
      .exec();
    context.state.busTypes = new Map(types.map((t) => [t.name.trim().toLowerCase(), t]));
    context.state.seen = new Set<string>();
  },
  async prepare(raw: Readonly<Record<string, string>>, context, rowNumber: number) {
    const label = raw.registration || `Row ${rowNumber}`;
    const errors: string[] = [];

    const reg = String(raw.registration ?? '').trim().toUpperCase().replace(/[\s-]/g, '');
    const name = String(raw.name ?? '').trim();
    const typeStr = String(raw.type ?? '').trim();
    const seats = parseNumber(raw.seats ?? '');

    if (!reg || reg.length < 5 || reg.length > 15) {
      errors.push('Registration must be a valid vehicle number (e.g. TS09 UB 1234).');
    }
    if (!name || name.length < 2) {
      errors.push('Bus name must be at least 2 characters.');
    }

    const busTypes = context.state.busTypes as Map<string, { _id: Types.ObjectId; name: string }>;
    const busType = busTypes.get(typeStr.toLowerCase());
    if (!busType) {
      errors.push(`Bus type: "${typeStr}" is not an active bus type.`);
    }

    if (seats === null || seats === undefined || seats < 10 || seats > 80) {
      errors.push('Seats must be a number between 10 and 80.');
    }

    if (errors.length > 0 || !busType || seats === null || seats === undefined) return { errors, label };

    const seen = context.state.seen as Set<string>;
    if (seen.has(reg)) {
      return { errors: [`Registration ${reg} is duplicated in this file.`], label };
    }
    seen.add(reg);

    const exists = await context.connection.collection('buses').countDocuments({ registrationNumber: reg });
    if (exists > 0) {
      return { errors: [`A bus with registration ${reg} already exists.`], label };
    }

    const dto: CreateBusDto = {
      registrationNumber: reg,
      name,
      busTypeId: busType._id.toHexString(),
      seatCapacity: seats,
      seatLayoutType: '2+2 Seater',
      amenities: [],
    };
    return { dto, label };
  },
  async create(context, actor, dto, client) {
    await context.service.create(actor, dto, client);
  },
};

export const BusesImportController = importController({
  base: 'catalogue/buses',
  permission: 'buses.create',
  spec: BUS_IMPORT_SPEC,
  service: BusesAdminManageService,
  title: 'buses',
});

@ApiTags('catalogue')
@Controller('catalogue/buses')
export class BusesAdminController {
  constructor(private readonly service: BusesAdminManageService) {}

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'List buses (admin)' })
  list(@Query() query: BusListQueryDto): Promise<PaginatedResult<AdminBusView>> {
    return this.service.list(query);
  }

  @Get(':id')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'Get bus by ID' })
  get(@Param() params: BusIdParamDto): Promise<AdminBusView> {
    return this.service.get(params.id);
  }

  @Post()
  @RequirePermission('buses.create')
  @ZodApiBody(CreateBusDto)
  @ApiOperation({ summary: 'Create bus (admin)' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBusDto,
    @Req() request: Request,
  ): Promise<AdminBusView> {
    return this.service.create(actor, body, clientRequestInfo(request));
  }

  @Patch(':id')
  @RequirePermission('buses.update')
  @ZodApiBody(UpdateBusDto)
  @ApiOperation({ summary: 'Update bus (admin)' })
  updatePatch(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusIdParamDto,
    @Body() body: UpdateBusDto,
    @Req() request: Request,
  ): Promise<AdminBusView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('buses.update')
  @ZodApiBody(UpdateBusDto)
  @ApiOperation({ summary: 'Update bus (admin, PUT alias)' })
  updatePut(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusIdParamDto,
    @Body() body: UpdateBusDto,
    @Req() request: Request,
  ): Promise<AdminBusView> {
    return this.service.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/status')
  @RequirePermission('buses.update')
  @ZodApiBody(ChangeBusStatusDto)
  @ApiOperation({ summary: 'Change bus status (admin)' })
  changeStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusIdParamDto,
    @Body() body: ChangeBusStatusDto,
    @Req() request: Request,
  ): Promise<AdminBusView> {
    return this.service.changeStatus(actor, params.id, body, clientRequestInfo(request));
  }

  @Post('bulk-maintenance')
  @RequirePermission('buses.update')
  @ZodApiBody(BulkMaintenanceDto)
  @ApiOperation({ summary: 'Bulk mark maintenance (admin)' })
  bulkMaintenance(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: BulkMaintenanceDto,
    @Req() request: Request,
  ): Promise<{ updatedCount: number }> {
    return this.service.bulkMaintenance(actor, body, clientRequestInfo(request));
  }
}
