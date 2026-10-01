import {
  type BeforeApplicationShutdown,
  Injectable,
  Logger,
  type OnApplicationBootstrap,
} from '@nestjs/common';
import { AppConfigService } from '../config/app-config.service';
import { OutboxRelayService } from '../events/outbox-relay.service';

/**
 * Runs the outbox relay continuously in the worker process: a full batch is followed immediately
 * by the next one; otherwise it sleeps OUTBOX_POLL_INTERVAL_MS. A failed pass (MongoDB briefly
 * unreachable) is logged and retried on the next tick. Shutdown wakes the loop and waits for the
 * current pass to finish, so no claimed event is abandoned mid-publish.
 */
@Injectable()
export class OutboxRelayWorker implements OnApplicationBootstrap, BeforeApplicationShutdown {
  private readonly logger = new Logger(OutboxRelayWorker.name);
  private running = false;
  private loop: Promise<void> | undefined;
  private wakeUp: (() => void) | undefined;

  constructor(
    private readonly relay: OutboxRelayService,
    private readonly config: AppConfigService,
  ) {}

  onApplicationBootstrap(): void {
    this.start();
  }

  get isRunning(): boolean {
    return this.running;
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.loop = this.runLoop();
    this.logger.log({ relayId: this.relay.relayId }, 'Outbox relay started');
  }

  async stop(): Promise<void> {
    this.running = false;
    this.wakeUp?.();
    await this.loop;
    this.loop = undefined;
  }

  async beforeApplicationShutdown(): Promise<void> {
    await this.stop();
    this.logger.log('Outbox relay stopped');
  }

  private async runLoop(): Promise<void> {
    const batchSize = this.config.get('OUTBOX_BATCH_SIZE');
    while (this.running) {
      let processed = 0;
      try {
        const result = await this.relay.relayBatch();
        processed = result.published + result.retried + result.failed + result.leaseLost;
      } catch (error) {
        this.logger.error(
          { message: error instanceof Error ? error.message : 'unknown' },
          'Outbox relay pass failed',
        );
      }
      if (this.running && processed < batchSize) {
        await this.sleep(this.config.get('OUTBOX_POLL_INTERVAL_MS'));
      }
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      const timer = setTimeout(done, ms);
      const wake = (): void => done();
      this.wakeUp = wake;
      function done(): void {
        clearTimeout(timer);
        resolve();
      }
    }).finally(() => {
      this.wakeUp = undefined;
    });
  }
}
