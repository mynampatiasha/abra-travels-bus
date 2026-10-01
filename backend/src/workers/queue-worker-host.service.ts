import {
  type BeforeApplicationShutdown,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
} from '@nestjs/common';
import { type Job, type Processor, Worker } from 'bullmq';
import { AppConfigService } from '../config/app-config.service';
import { bullmqConnectionOptions } from '../queues/bullmq-connection.factory';
import { QUEUE_NAMES, type QueueName } from '../queues/queue-names';
import { DomainEventDispatchProcessor } from './domain-event-dispatch.processor';

/**
 * Owns the BullMQ Worker instances of the worker process (one per queue). Workers start after
 * all modules are initialised and are closed gracefully on shutdown: `close()` stops taking new
 * jobs and waits for active ones to finish, so a deploy never cuts a job in half.
 */
@Injectable()
export class QueueWorkerHost implements OnApplicationBootstrap, BeforeApplicationShutdown {
  private readonly logger = new Logger(QueueWorkerHost.name);
  private readonly workers: Worker[] = [];

  constructor(
    private readonly config: AppConfigService,
    private readonly domainEventDispatch: DomainEventDispatchProcessor,
  ) {}

  onApplicationBootstrap(): void {
    this.startWorker(QUEUE_NAMES.DOMAIN_EVENTS, (job) => this.domainEventDispatch.process(job));
  }

  get runningWorkers(): number {
    return this.workers.filter((worker) => worker.isRunning()).length;
  }

  private startWorker(name: QueueName, processor: Processor): void {
    const worker = new Worker(name, processor, {
      connection: bullmqConnectionOptions(this.config.get('REDIS_URL'), 'worker'),
      prefix: this.config.get('QUEUE_PREFIX'),
      concurrency: this.config.get('WORKER_CONCURRENCY'),
    });

    worker.on('failed', (job: Job | undefined, error: Error) => {
      const attempts = job?.opts.attempts ?? 1;
      const final = (job?.attemptsMade ?? attempts) >= attempts;
      const context = { queue: name, jobId: job?.id, attemptsMade: job?.attemptsMade, final };
      if (final)
        this.logger.error({ ...context, message: error.message }, 'Job failed permanently');
      else this.logger.warn({ ...context, message: error.message }, 'Job failed; will retry');
    });
    worker.on('error', (error: Error) =>
      this.logger.error({ queue: name, message: error.message }, 'Worker connection error'),
    );

    this.workers.push(worker);
    this.logger.log(
      { queue: name, concurrency: this.config.get('WORKER_CONCURRENCY') },
      'Worker started',
    );
  }

  async beforeApplicationShutdown(): Promise<void> {
    await Promise.allSettled(this.workers.map((worker) => worker.close()));
    this.logger.log({ workers: this.workers.length }, 'Workers closed');
    this.workers.length = 0;
  }
}
