import { type NestExpressApplication } from '@nestjs/platform-express';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { type App } from 'supertest/types';
import { type ApiErrorBody } from '../common/filters/api-exception.filter';
import { AppModule } from '../app.module';
import { validTestEnvironment } from '../config/tests/valid-test-environment';
import { configureHttpApplication } from '../configure-http-application';

interface SuccessBody {
  success: true;
  data: Record<string, unknown>;
  meta: { requestId: string };
}

interface OpenApiDocument {
  openapi: string;
  paths: Record<string, unknown>;
}

/**
 * Boots the real application (real HTTP pipeline, real MongoDB replica set and Redis from
 * infrastructure/docker-compose.development.yml). No business endpoints exist yet.
 */
describe('HTTP application (e2e)', () => {
  let app: NestExpressApplication;
  let server: App;

  beforeAll(async () => {
    Object.assign(process.env, validTestEnvironment({ API_DOCS_ENABLED: 'true' }));
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestExpressApplication>({ bufferLogs: true });
    configureHttpApplication(app);
    await app.init();
    server = app.getHttpServer();
  });

  afterAll(async () => {
    await app?.close();
  });

  it('GET /health/live returns the success envelope with a request id', async () => {
    const response = await request(server).get('/health/live').expect(200);
    const requestId = response.headers['x-request-id'] as string;
    expect(requestId).toEqual(expect.any(String));
    expect(response.body).toEqual({ success: true, data: { status: 'ok' }, meta: { requestId } });
  });

  it('GET /health/ready reports MongoDB, Redis, queues and outbox up', async () => {
    const response = await request(server).get('/health/ready').expect(200);
    expect((response.body as SuccessBody).data).toMatchObject({
      ready: true,
      checks: {
        mongodb: { status: 'up' },
        redis: { status: 'up' },
        queues: {
          status: 'up',
          details: {
            'domain-events': {
              waiting: expect.any(Number) as unknown,
              oldestWaitingAgeMs: expect.any(Number) as unknown,
              workers: expect.any(Number) as unknown,
            },
          },
        },
        outbox: { status: 'up', details: { pending: expect.any(Number) as unknown } },
      },
      // No worker runs in this test, so readiness stays 200 and the problem is a warning
      warnings: expect.arrayContaining(['queue domain-events: no worker connected']) as unknown,
    });
  });

  it('echoes a safe caller-supplied X-Request-Id in header and body', async () => {
    const response = await request(server)
      .get('/health/live')
      .set('X-Request-Id', 'client-trace-12345')
      .expect(200);
    expect(response.headers['x-request-id']).toBe('client-trace-12345');
    expect((response.body as SuccessBody).meta.requestId).toBe('client-trace-12345');
  });

  it('answers unknown routes with the standard error envelope', async () => {
    const response = await request(server).get('/api/v1/does-not-exist').expect(404);
    expect(response.body).toEqual({
      success: false,
      error: {
        code: 'RESOURCE_NOT_FOUND',
        message: expect.any(String) as unknown,
        requestId: response.headers['x-request-id'] as string,
      },
    });
  });

  it('answers malformed JSON with MALFORMED_REQUEST', async () => {
    const response = await request(server)
      .post('/api/v1/bookings')
      .set('Content-Type', 'application/json')
      .send('{"broken":')
      .expect(400);
    expect((response.body as ApiErrorBody).error.code).toBe('MALFORMED_REQUEST');
  });

  it('rejects JSON bodies over 1 MB with PAYLOAD_TOO_LARGE', async () => {
    const response = await request(server)
      .post('/api/v1/bookings')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({ padding: 'x'.repeat(1_100_000) }))
      .expect(413);
    expect((response.body as ApiErrorBody).error.code).toBe('PAYLOAD_TOO_LARGE');
  });

  it('serves Swagger UI at /api/docs and the OpenAPI document at /api/docs-json', async () => {
    const ui = await request(server).get('/api/docs').redirects(1).expect(200);
    expect(ui.text).toContain('swagger');

    const response = await request(server).get('/api/docs-json').expect(200);
    const document = response.body as OpenApiDocument;
    expect(document.openapi).toMatch(/^3\./);
    expect(Object.keys(document.paths)).toEqual(
      expect.arrayContaining(['/health/live', '/health/ready']),
    );
  });

  it('sets security headers', async () => {
    const response = await request(server).get('/health/live').expect(200);
    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-powered-by']).toBeUndefined();
  });
});
