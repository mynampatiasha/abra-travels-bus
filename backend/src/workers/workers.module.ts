import { Module } from '@nestjs/common';
import { BusDocumentsModule } from '../modules/buses/bus_documents_client_manage';
import { EventRouterModule } from '../modules/notifications/event_router_core';
import { OperatorStaffModule } from '../modules/operator-staff/crew_client_manage';
import { BusDocumentReminderWorker } from './bus-document-reminder.worker';
import { CrewDocumentReminderWorker } from './crew-document-reminder.worker';
import { DomainEventDispatchProcessor } from './domain-event-dispatch.processor';
import { OutboxRelayWorker } from './outbox-relay.worker';
import { QueueWorkerHost } from './queue-worker-host.service';

/** Background processing. Imported only by WorkerModule — never by the HTTP API. */
@Module({
  imports: [OperatorStaffModule, BusDocumentsModule, EventRouterModule],
  providers: [
    DomainEventDispatchProcessor,
    QueueWorkerHost,
    OutboxRelayWorker,
    CrewDocumentReminderWorker,
    BusDocumentReminderWorker,
  ],
  exports: [QueueWorkerHost, OutboxRelayWorker],
})
export class WorkersModule {}
