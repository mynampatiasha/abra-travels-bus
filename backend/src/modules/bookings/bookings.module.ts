import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { BookingsCustomerController } from './bookings_customer';
import { BOOKING_MODEL, BookingsCustomerService, bookingSchema } from './bookings_customer.service';

/**
 * `bookings`: Inventory and booking domain (documentation/architecture.md section 5). A customer
 * books the seats they hold (state-machines.md section 3). Payment, tickets and the admin and
 * operator lists follow in the next steps of Phase 3.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: BOOKING_MODEL, schema: bookingSchema }])],
  controllers: [BookingsCustomerController],
  providers: [BookingsCustomerService],
  exports: [BookingsCustomerService],
})
export class BookingsModule {}
