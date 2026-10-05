import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { OPERATOR_MODEL, operatorSchema } from './schemas/operator.schema';

/**
 * `operators` — Supply domain (documentation/architecture.md §5). So far only the collection that trip
 * discovery reads (documentation/discovery.md); the management API arrives with the operator
 * portal (documentation/implementation-plan.md).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: OPERATOR_MODEL, schema: operatorSchema }])],
  exports: [MongooseModule],
})
export class OperatorsModule {}
