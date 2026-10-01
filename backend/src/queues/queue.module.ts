import { Global, Module } from '@nestjs/common';
import { QueueHealthService } from './queue-health.service';
import { QueueRegistry } from './queue-registry.service';

/** BullMQ producers and queue health, shared by the API and the worker process. */
@Global()
@Module({
  providers: [QueueRegistry, QueueHealthService],
  exports: [QueueRegistry, QueueHealthService],
})
export class QueueModule {}
