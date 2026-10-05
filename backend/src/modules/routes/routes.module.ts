import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ROUTE_MODEL, routeSchema } from './schemas/route.schema';

/**
 * `routes` — Supply domain (documentation/architecture.md §5). So far only the collection that trip
 * discovery reads (documentation/discovery.md); the management API arrives with the operator
 * portal (documentation/implementation-plan.md).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: ROUTE_MODEL, schema: routeSchema }])],
  exports: [MongooseModule],
})
export class RoutesModule {}
