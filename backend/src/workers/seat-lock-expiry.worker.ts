import {
  type BeforeApplicationShutdown,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
} from '@nestjs/common';
import { PaymentsCustomerService } from '../modules/payments/payments_customer.service';
import { SeatLocksService } from '../modules/inventory/seat_locks_customer.service';

/** Every 15 seconds, as in seat-locking.md. A late run only delays the tidy-up: an expired hold is already free. */
const EVERY_MS = 15_000;

/** Puts the seats of holds that ran out back on sale and keeps the trip counters right (worker process only). */
@Injectable()
export class SeatLockExpiryWorker implements OnApplicationBootstrap, BeforeApplicationShutdown {
  private readonly logger = new Logger(SeatLockExpiryWorker.name);
  private timer: NodeJS.Timeout | undefined;
  private running = false;

  constructor(
    private readonly seatLocks: SeatLocksService,
    private readonly payments: PaymentsCustomerService,
  ) {}

  onApplicationBootstrap(): void {
    this.timer = setInterval(() => void this.run(), EVERY_MS);
    this.timer.unref();
  }

  beforeApplicationShutdown(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async run(now = new Date()): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      // Unpaid bookings first: they give the coupon back along with the seats
      const unpaid = await this.payments.expireUnpaid(now);
      if (unpaid.bookings > 0) this.logger.log(unpaid, 'Expired unpaid bookings');
      const result = await this.seatLocks.expireOverdue(now);
      if (result.groups > 0) this.logger.log(result, 'Expired seat holds');
    } catch (error) {
      this.logger.error(
        { message: error instanceof Error ? error.message : 'unknown' },
        'Seat hold expiry failed',
      );
    } finally {
      this.running = false;
    }
  }
}
