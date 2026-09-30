import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { AppConfigService } from './config/app-config.service';
import { EnvironmentValidationError, loadEnvironment } from './config/environment-loader';
import { configureHttpApplication } from './configure-http-application';

async function bootstrap(): Promise<void> {
  // Validate configuration before anything connects; the message names keys, never values
  try {
    loadEnvironment();
  } catch (error) {
    if (error instanceof EnvironmentValidationError) {
      process.stderr.write(`${error.message}\n\nThe backend was not started.\n`);
      process.exit(1);
    }
    throw error;
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule, { bufferLogs: true });
  configureHttpApplication(app);

  const port = app.get(AppConfigService).get('PORT');
  await app.listen(port);
}

bootstrap().catch((error: unknown) => {
  process.stderr.write(
    `Backend failed to start: ${error instanceof Error ? (error.stack ?? error.message) : String(error)}\n`,
  );
  process.exit(1);
});
