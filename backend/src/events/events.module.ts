import { Global, Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { DomainEventHandlerRegistry } from './domain-event-handler.registry';
import { OUTBOX_EVENT_MODEL, outboxEventSchema } from './outbox-event.schema';
import { OutboxRelayService } from './outbox-relay.service';
import { OutboxRepository } from './outbox.repository';
import { OutboxService } from './outbox.service';

/**
 * Transactional outbox and domain-event plumbing. Business modules inject OutboxService to record
 * events and DomainEventHandlerRegistry to consume them. The relay loop runs only in the worker.
 */
@Global()
@Module({
  imports: [MongooseModule.forFeature([{ name: OUTBOX_EVENT_MODEL, schema: outboxEventSchema }])],
  providers: [OutboxRepository, OutboxService, OutboxRelayService, DomainEventHandlerRegistry],
  exports: [OutboxRepository, OutboxService, OutboxRelayService, DomainEventHandlerRegistry],
})
export class EventsModule {}
