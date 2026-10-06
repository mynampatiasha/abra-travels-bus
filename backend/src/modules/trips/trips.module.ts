import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RateLimitModule } from '../../common/rate-limit/rate-limit.module';
import { BusTypesModule } from '../bus-types/bus-types.module';
import { BusesModule } from '../buses/buses.module';
import { CitiesModule } from '../cities/cities.module';
import { LocationsModule } from '../locations/locations.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { RoutesModule } from '../routes/routes.module';
import { TripDiscoveryController } from './controllers/trip-discovery.controller';
import { TripManagementController } from './controllers/trip-management.controller';
import { TripCatalogueRepository } from './repositories/trip-catalogue.repository';
import { TripRepository } from './repositories/trip.repository';
import { TRIP_MODEL, tripSchema } from './schemas/trip.schema';
import { TripDiscoveryService } from './services/trip-discovery.service';
import { TripManagementService } from './services/trip-management.service';

/**
 * `trips` — Supply domain (documentation/architecture.md §5). Trips: public discovery
 * (documentation/discovery.md) and creation, publishing and cancellation by the people who run
 * them (documentation/catalogue-management.md). Running a trip (boarding to arrival) arrives
 * with trip operations.
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: TRIP_MODEL, schema: tripSchema }]),
    RateLimitModule,
    RbacModule,
    CitiesModule,
    OperatorsModule,
    BusTypesModule,
    BusesModule,
    RoutesModule,
    LocationsModule,
  ],
  controllers: [TripDiscoveryController, TripManagementController],
  providers: [TripCatalogueRepository, TripDiscoveryService, TripRepository, TripManagementService],
  exports: [MongooseModule],
})
export class TripsModule {}
