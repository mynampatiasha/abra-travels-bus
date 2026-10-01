import { RequestMethod } from '@nestjs/common';
import { type NestExpressApplication } from '@nestjs/platform-express';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';
import { ApiExceptionFilter } from './common/filters/api-exception.filter';
import { ResponseEnvelopeInterceptor } from './common/interceptors/response-envelope.interceptor';
import { setupApiDocumentation } from './common/openapi/api-documentation.setup';
import { ZodValidationPipe } from './common/pipes/zod-validation.pipe';
import { requestIdMiddleware } from './common/request-context/request-id.middleware';
import { AppConfigService } from './config/app-config.service';

export const API_PREFIX = 'api/v1';

/**
 * HTTP pipeline shared by main.ts and the e2e tests, so tests exercise exactly what runs.
 * Order matters: request id first, so every later log line and error carries it.
 */
export function configureHttpApplication(app: NestExpressApplication): void {
  const config = app.get(AppConfigService);

  app.set('trust proxy', config.get('TRUST_PROXY_HOPS'));
  app.use(requestIdMiddleware);
  app.useLogger(app.get(Logger));

  app.use(helmet());
  app.enableCors({
    origin: config.get('CORS_ALLOWED_ORIGINS'),
    credentials: true,
    exposedHeaders: ['X-Request-Id'],
  });
  // api-architecture.md §1: request body limit 1 MB (uploads use pre-signed URLs)
  app.useBodyParser('json', { limit: '1mb' });

  app.setGlobalPrefix(API_PREFIX, {
    exclude: [{ path: 'health/{*path}', method: RequestMethod.ALL }],
  });
  app.useGlobalFilters(new ApiExceptionFilter());
  app.useGlobalPipes(new ZodValidationPipe());
  app.useGlobalInterceptors(new ResponseEnvelopeInterceptor());
  app.enableShutdownHooks();

  if (config.apiDocsEnabled) setupApiDocumentation(app);
}
