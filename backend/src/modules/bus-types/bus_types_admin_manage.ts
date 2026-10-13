import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CatalogueIdParamDto } from '../cities/dto/city-admin.dto';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { BusTypesManageService } from './bus_types_admin_manage.service';
import { type BusTypeView } from './services/bus-types.service';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind, readable } from '../catalogue-shared/catalogue_export_manage.service';
import { BusTypeListQueryDto } from './dto/bus-type.dto';
import { BusTypesService } from './services/bus-types.service';

/** Bus types and amenities page of the admin portal: the routes the list does not have. */
@ApiTags('catalogue')
@Controller('catalogue/bus-types')
export class BusTypesManageController {
  constructor(private readonly manage: BusTypesManageService) {}

  @Get(':id')
  @RequirePermission('catalogue.read')
  @ApiOperation({
    summary: 'One bus type',
    description: 'Requires catalogue.read. A deleted bus type is not found.',
  })
  get(@Param() params: CatalogueIdParamDto): Promise<BusTypeView> {
    return this.manage.get(params.id);
  }
}

/** The bus types list as a file. */
export const BUS_TYPES_EXPORT_KIND: ExportKind<BusTypeView> = {
  key: 'bus-types',
  columns: [
    { header: 'Bus type', value: (type) => type.name },
    { header: 'Key', value: (type) => type.key },
    { header: 'Air conditioned', value: (type) => type.isAc },
    { header: 'Seating', value: (type) => readable(type.berthType) },
    { header: 'Status', value: (type) => (type.isActive ? 'Active' : 'Inactive') },
  ],
};

/** `GET catalogue/bus-types/export`. Register it before the module's other controllers. */
export const BusTypesExportController = exportController({
  base: 'catalogue/bus-types',
  permission: 'catalogue.export',
  kind: BUS_TYPES_EXPORT_KIND,
  service: BusTypesService,
  query: BusTypeListQueryDto,
  title: 'bus types',
  load: (service, query) => service.list(query as never),
});
