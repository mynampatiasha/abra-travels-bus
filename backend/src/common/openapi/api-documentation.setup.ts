import { type INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

export const API_DOCS_PATH = 'api/docs';

/**
 * OpenAPI 3 document (architecture.md §1). UI at /api/docs, JSON at /api/docs-json.
 * Every endpoint states its required permission or "Public" in its description
 * (api-architecture.md §1).
 */
export function setupApiDocumentation(app: INestApplication): void {
  const document = SwaggerModule.createDocument(
    app,
    new DocumentBuilder()
      .setTitle('Abra Travels API')
      .setDescription(
        'Bus booking, operations, master inventory and partner platform. ' +
          'All responses use the envelope { success, data, meta } or { success: false, error }.',
      )
      .setVersion('v1')
      .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'access-token')
      .build(),
  );
  SwaggerModule.setup(API_DOCS_PATH, app, document, {
    jsonDocumentUrl: `${API_DOCS_PATH}-json`,
    customSiteTitle: 'Abra Travels API',
  });
}
