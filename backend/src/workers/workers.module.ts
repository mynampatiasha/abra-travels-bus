import { Module } from '@nestjs/common';
import { InventoryModule } from '../modules/inventory/inventory.module';
import { EventRouterModule } from '../modules/notifications/event_router_core';
import { OperatorStaffModule } from '../modules/operator-staff/crew_client_manage';
import { CrewDocumentReminderWorker } from './crew-document-reminder.worker';
import { DomainEventDispatchProcessor } from './domain-event-dispatch.processor';
import { OutboxRelayWorker } from './outbox-relay.worker';
import { QueueWorkerHost } from './queue-worker-host.service';
import { SeatLockExpiryWorker } from './seat-lock-expiry.worker';

/** Background processing. Imported only by WorkerModule — never by the HTTP API. */
@Module({
  imports: [OperatorStaffModule, EventRouterModule, InventoryModule],
  providers: [
    DomainEventDispatchProcessor,
    QueueWorkerHost,
    OutboxRelayWorker,
    CrewDocumentReminderWorker,
    SeatLockExpiryWorker,
  ],
  exports: [QueueWorkerHost, OutboxRelayWorker],
})
export class WorkersModule {}
