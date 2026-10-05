import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { LOCATION_MODEL, locationSchema } from './schemas/location.schema';

/**
 * `locations` — Supply domain (documentation/architecture.md §5). So far only the collection that trip
 * discovery reads (documentation/discovery.md); the management API arrives with the operator
 * portal (documentation/implementation-plan.md).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: LOCATION_MODEL, schema: locationSchema }])],
  exports: [MongooseModule],
})
export class LocationsModule {}
