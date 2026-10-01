import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { type NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { AppConfigService } from './config/app-config.service';
import { exitOnInvalidEnvironment } from './config/exit-on-invalid-environment';
import { configureHttpApplication } from './configure-http-application';

async function bootstrap(): Promise<void> {
  exitOnInvalidEnvironment('backend');

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
