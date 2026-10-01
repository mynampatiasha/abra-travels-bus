import 'reflect-metadata';
import { Logger as NestLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { exitOnInvalidEnvironment } from './config/exit-on-invalid-environment';
import { WorkerModule } from './worker.module';

/**
 * Worker process entry point (`node dist/worker.js`, `npm run worker:dev`). Runs the BullMQ
 * workers and the outbox relay; no HTTP server. SIGTERM / SIGINT trigger a graceful shutdown:
 * relay pass finishes, active jobs finish, then connections close.
 */
async function bootstrap(): Promise<void> {
  exitOnInvalidEnvironment('worker');

  const app = await NestFactory.createApplicationContext(WorkerModule, { bufferLogs: true });
  app.useLogger(app.get(Logger));
  app.enableShutdownHooks();
  new NestLogger('Worker').log({ pid: process.pid }, 'Worker process ready');
}

bootstrap().catch((error: unknown) => {
  process.stderr.write(
    `Worker failed to start: ${error instanceof Error ? (error.stack ?? error.message) : String(error)}\n`,
  );
  process.exit(1);
});
