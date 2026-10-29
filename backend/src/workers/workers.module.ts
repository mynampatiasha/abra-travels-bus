import { Module } from '@nestjs/common';
import { EventRouterModule } from '../modules/notifications/event_router_core';
import { OperatorStaffModule } from '../modules/operator-staff/crew_client_manage';
import { CrewDocumentReminderWorker } from './crew-document-reminder.worker';
import { DomainEventDispatchProcessor } from './domain-event-dispatch.processor';
import { OutboxRelayWorker } from './outbox-relay.worker';
import { QueueWorkerHost } from './queue-worker-host.service';

/** Background processing. Imported only by WorkerModule — never by the HTTP API. */
@Module({
  imports: [OperatorStaffModule, EventRouterModule],
  providers: [
    DomainEventDispatchProcessor,
    QueueWorkerHost,
    OutboxRelayWorker,
    CrewDocumentReminderWorker,
  ],
  exports: [QueueWorkerHost, OutboxRelayWorker],
})
export class WorkersModule {}
