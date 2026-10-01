import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CustomerRepository } from './repositories/customer.repository';
import { CUSTOMER_MODEL, customerSchema } from './schemas/customer.schema';
import { CustomersService } from './services/customers.service';

/**
 * `customers` — Identity domain (documentation/architecture.md §5). Owns the `customers`
 * collection (customer profile of a CUSTOMER user). Profile endpoints arrive with the customer
 * account features.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: CUSTOMER_MODEL, schema: customerSchema }])],
  providers: [CustomerRepository, CustomersService],
  exports: [CustomersService],
})
export class CustomersModule {}
