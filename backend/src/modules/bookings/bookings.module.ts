import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { CouponsModule } from '../coupons/coupons.module';
import { RbacModule } from '../rbac/rbac.module';
import { BookingsAdminController, BookingsExportController } from './bookings_admin_manage';
import { BookingsAdminService } from './bookings_admin_manage.service';
import { BookingsCustomerController, TripPolicyController } from './bookings_customer';
import { BOOKING_MODEL, BookingsCustomerService, bookingSchema } from './bookings_customer.service';

/**
 * `bookings`: Inventory and booking domain (documentation/architecture.md section 5). A customer
 * books the seats they hold (state-machines.md section 3). Payment, tickets and the admin and
 * operator lists follow in the next steps of Phase 3.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: BOOKING_MODEL, schema: bookingSchema }]), CouponsModule, RbacModule, CatalogueSharedModule],
  controllers: [BookingsExportController, BookingsAdminController, BookingsCustomerController, TripPolicyController],
  providers: [BookingsCustomerService, BookingsAdminService],
  exports: [BookingsCustomerService, MongooseModule],
})
export class BookingsModule {}
