import { Controller, Get, Param } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { CatalogueIdParamDto } from '../cities/dto/city-admin.dto';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { BusTypesManageService } from './bus_types_admin_manage.service';
import { type BusTypeView } from './services/bus-types.service';

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
