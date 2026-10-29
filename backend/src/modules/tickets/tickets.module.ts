import { Module } from '@nestjs/common';
import { BookingsModule } from '../bookings/bookings.module';
import { TicketsCustomerController } from './tickets_customer';
import { TicketsCustomerService } from './tickets_customer.service';

/**
 * `tickets`: the e-ticket of a confirmed booking with a signed QR. The PDF, the calendar file,
 * sharing and the conductor check-in come later.
 */
@Module({
  imports: [BookingsModule],
  controllers: [TicketsCustomerController],
  providers: [TicketsCustomerService],
  exports: [TicketsCustomerService],
})
export class TicketsModule {}
