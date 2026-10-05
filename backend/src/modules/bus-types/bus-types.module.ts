import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { BUS_TYPE_MODEL, busTypeSchema } from './schemas/bus-type.schema';

/**
 * `bus-types` — Supply domain (documentation/architecture.md §5). So far only the collection that trip
 * discovery reads (documentation/discovery.md); the management API arrives with the operator
 * portal (documentation/implementation-plan.md).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: BUS_TYPE_MODEL, schema: busTypeSchema }])],
  exports: [MongooseModule],
})
export class BusTypesModule {}
