import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AmenitiesModule } from '../amenities/amenities_admin_manage';
import { BusTypesModule } from '../bus-types/bus-types.module';
import { BusDocumentsModule } from './bus_documents_client_manage';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import {
  BusesAdminController,
  BusesExportController,
  BusesImportController,
} from './buses_admin_manage';
import { BusesAdminManageService } from './buses_admin_manage.service';
import {
  BusesClientController,
  BusesClientExportController,
  SeatLayoutsClientController,
  SEAT_LAYOUT_MODEL,
  seatLayoutSchema,
} from './buses_client_manage';
import { BusesClientManageService, SeatLayoutRepository } from './buses_client_manage.service';
import { BusRepository } from './repositories/bus.repository';

import { BUS_MODEL, busSchema } from './schemas/bus.schema';

import { BusesService } from './services/buses.service';

/**
 * `buses` — Supply domain (documentation/architecture.md §5). An operator's vehicles
 * (documentation/catalogue-management.md). Seat layouts and buses admin & client management.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: BUS_MODEL, schema: busSchema },
      { name: SEAT_LAYOUT_MODEL, schema: seatLayoutSchema },
    ]),
    RbacModule,
    BusTypesModule,
    BusDocumentsModule,
    AmenitiesModule,
    OperatorsModule,
    CatalogueSharedModule,
  ],
  controllers: [
    BusesExportController,
    BusesImportController,
    BusesClientExportController,
    BusesAdminController,
    BusesClientController,
    SeatLayoutsClientController,
  ],
  providers: [
    BusRepository,
    SeatLayoutRepository,
    BusesService,
    BusesAdminManageService,
    BusesClientManageService,
  ],
  exports: [
    BusRepository,
    SeatLayoutRepository,
    BusesService,
    BusesAdminManageService,
    BusesClientManageService,
    MongooseModule,
  ],
})
export class BusesModule {}
