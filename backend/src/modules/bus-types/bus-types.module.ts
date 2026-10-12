import { Module } from '@nestjs/common';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { BusTypesExportController } from './bus_types_admin_manage';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { BusTypesManageController } from './bus_types_admin_manage';
import { BusTypesManageService } from './bus_types_admin_manage.service';
import { BusTypesController } from './controllers/bus-types.controller';
import { BusTypeRepository } from './repositories/bus-type.repository';
import { BUS_TYPE_MODEL, busTypeSchema } from './schemas/bus-type.schema';
import { BusTypesService } from './services/bus-types.service';

/**
 * `bus-types` — Supply domain (documentation/architecture.md §5). The kinds of bus, managed
 * by platform staff (documentation/catalogue-management.md).
 */
@Module({
  imports: [CatalogueSharedModule, 
    MongooseModule.forFeature([{ name: BUS_TYPE_MODEL, schema: busTypeSchema }]),
    RbacModule,
  ],
  controllers: [BusTypesExportController, BusTypesController, BusTypesManageController],
  providers: [BusTypeRepository, BusTypesService, BusTypesManageService],
  exports: [BusTypeRepository, MongooseModule],
})
export class BusTypesModule {}
