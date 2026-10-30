import { Module, forwardRef } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RateLimitModule } from '../../common/rate-limit/rate-limit.module';
import { BusTypesModule } from '../bus-types/bus-types.module';
import { BusesModule } from '../buses/buses.module';
import { CitiesModule } from '../cities/cities.module';
import { LocationsModule } from '../locations/locations.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { RoutesModule } from '../routes/routes.module';
import { FilesModule } from '../files/files.module';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { TripDiscoveryController } from './controllers/trip-discovery.controller';
import { TripManagementController } from './controllers/trip-management.controller';
import { TripCatalogueRepository } from './repositories/trip-catalogue.repository';
import { TripRepository } from './repositories/trip.repository';
import { TRIP_MODEL, tripSchema } from './schemas/trip.schema';
import { SEAT_INVENTORY_MODEL, seatInventorySchema } from './schemas/seat-inventory.schema';
import { TripDiscoveryService } from './services/trip-discovery.service';
import { TripManagementService } from './services/trip-management.service';
import { TripsClientController, TripsClientExportController } from './trips_client_manage';
import { TripCodeBackfill } from './trip_codes';
import { TripsClientManageService } from './trips_client_manage.service';
import { TripsAdminController, TripsAdminExportController } from './trips_admin_manage';
import { TripsAdminManageService } from './trips_admin_manage.service';

/**
 * `trips` — Supply domain (documentation/architecture.md §5). Trips: public discovery
 * (documentation/discovery.md) and creation, publishing and cancellation by the people who run
 * them (documentation/catalogue-management.md). Running a trip (boarding to arrival) arrives
 * with trip operations.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: TRIP_MODEL, schema: tripSchema },
      { name: SEAT_INVENTORY_MODEL, schema: seatInventorySchema },
    ]),
    RateLimitModule,
    forwardRef(() => RbacModule),
    CitiesModule,
    OperatorsModule,
    BusTypesModule,
    BusesModule,
    RoutesModule,
    LocationsModule,
    FilesModule,
    CatalogueSharedModule,
  ],
  controllers: [
    TripDiscoveryController,
    TripManagementController,
    TripsClientExportController,
    TripsClientController,
    TripsAdminExportController,
    TripsAdminController,
  ],
  providers: [
    TripCatalogueRepository,
    TripDiscoveryService,
    TripRepository,
    TripManagementService,
    TripsClientManageService,
    TripsAdminManageService,
    TripCodeBackfill,
  ],
  exports: [MongooseModule, TripsClientManageService, TripsAdminManageService],
})
export class TripsModule {}
