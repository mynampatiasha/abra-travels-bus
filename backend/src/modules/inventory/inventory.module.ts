import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { SeatLocksController, SeatMapController } from './seat_locks_customer';
import {
  SEAT_LOCK_GROUP_MODEL,
  SeatLocksService,
  seatLockGroupSchema,
} from './seat_locks_customer.service';

/**
 * `inventory`: Inventory and booking domain (documentation/architecture.md section 5 and
 * seat-locking.md). The seat map of a trip and the 10 minute seat hold for customers. The seats
 * themselves (`seat_inventory`) are made by the trips module when a trip is published.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: SEAT_LOCK_GROUP_MODEL, schema: seatLockGroupSchema }])],
  controllers: [SeatMapController, SeatLocksController],
  providers: [SeatLocksService],
  exports: [SeatLocksService],
})
export class InventoryModule {}
