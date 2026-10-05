import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RateLimitModule } from '../../common/rate-limit/rate-limit.module';
import { CitiesModule } from '../cities/cities.module';
import { OperatorsModule } from '../operators/operators.module';
import { TripDiscoveryController } from './controllers/trip-discovery.controller';
import { TripCatalogueRepository } from './repositories/trip-catalogue.repository';
import { TRIP_MODEL, tripSchema } from './schemas/trip.schema';
import { TripDiscoveryService } from './services/trip-discovery.service';

/**
 * `trips` — Supply domain (documentation/architecture.md §5). So far: the trip collection and
 * public trip discovery (documentation/discovery.md). Creating, publishing and running trips
 * arrive with the operator portal and trip operations.
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: TRIP_MODEL, schema: tripSchema }]),
    RateLimitModule,
    CitiesModule,
    OperatorsModule,
  ],
  controllers: [TripDiscoveryController],
  providers: [TripCatalogueRepository, TripDiscoveryService],
  exports: [MongooseModule],
})
export class TripsModule {}
