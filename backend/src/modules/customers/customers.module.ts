import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { SessionsModule } from '../sessions/sessions.module';
import { USER_MODEL, userSchema } from '../users/schemas/user.schema';
import { CustomerRepository } from './repositories/customer.repository';
import { CustomersAdminController } from './customers_admin_manage';
import { CustomersAdminService } from './customers_admin_manage.service';
import { CustomersCustomerController } from './customers_customer';
import { CustomersCustomerService } from './customers_customer.service';
import { CustomerPreferenceService } from './notification_settings.service';
import { CUSTOMER_MODEL, customerSchema } from './schemas/customer.schema';
import { CustomersService } from './services/customers.service';

/**
 * `customers` — Identity domain (documentation/architecture.md §5). Owns the `customers`
 * collection (the profile of a CUSTOMER user). The customer's own profile and account live under
 * `/customer`; staff manage customers under `/admin/customers`.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: CUSTOMER_MODEL, schema: customerSchema },
      { name: USER_MODEL, schema: userSchema },
    ]),
    RbacModule,
    SessionsModule,
  ],
  controllers: [CustomersCustomerController, CustomersAdminController],
  providers: [
    CustomerRepository,
    CustomersService,
    CustomersCustomerService,
    CustomersAdminService,
    CustomerPreferenceService,
  ],
  exports: [CustomersService, CustomerPreferenceService],
})
export class CustomersModule {}
