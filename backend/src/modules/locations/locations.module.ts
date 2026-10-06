import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CitiesModule } from '../cities/cities.module';
import { OperatorsModule } from '../operators/operators.module';
import { RbacModule } from '../rbac/rbac.module';
import { LocationsController } from './controllers/locations.controller';
import { LocationRepository } from './repositories/location.repository';
import { LOCATION_MODEL, locationSchema } from './schemas/location.schema';
import { LocationsService } from './services/locations.service';

/**
 * `locations` — Supply domain (documentation/architecture.md §5). Boarding and dropping
 * places, shared or owned by an operator (documentation/catalogue-management.md).
 */
@Module({
  imports: [
    MongooseModule.forFeature([{ name: LOCATION_MODEL, schema: locationSchema }]),
    RbacModule,
    CitiesModule,
    OperatorsModule,
  ],
  controllers: [LocationsController],
  providers: [LocationRepository, LocationsService],
  exports: [LocationRepository, MongooseModule],
})
export class LocationsModule {}
