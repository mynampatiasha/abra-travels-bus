import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { BUS_MODEL, busSchema } from './schemas/bus.schema';

/**
 * `buses` — Supply domain (documentation/architecture.md §5). So far only the collection that trip
 * discovery reads (documentation/discovery.md); the management API arrives with the operator
 * portal (documentation/implementation-plan.md).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: BUS_MODEL, schema: busSchema }])],
  exports: [MongooseModule],
})
export class BusesModule {}
