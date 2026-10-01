import { Module } from '@nestjs/common';
import { DomainEventDispatchProcessor } from './domain-event-dispatch.processor';
import { OutboxRelayWorker } from './outbox-relay.worker';
import { QueueWorkerHost } from './queue-worker-host.service';

/** Background processing. Imported only by WorkerModule — never by the HTTP API. */
@Module({
  providers: [DomainEventDispatchProcessor, QueueWorkerHost, OutboxRelayWorker],
  exports: [QueueWorkerHost, OutboxRelayWorker],
})
export class WorkersModule {}
