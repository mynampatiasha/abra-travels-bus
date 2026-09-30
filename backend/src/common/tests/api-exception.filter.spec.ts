import { type ArgumentsHost, Logger, NotFoundException } from '@nestjs/common';
import { ApiException } from '../errors/api-exception';
import { ApiExceptionFilter } from '../filters/api-exception.filter';
import { RequestContextService } from '../request-context/request-context.service';

function captureResponse(exception: unknown): { status: number; body: unknown } {
  const captured = { status: 0, body: undefined as unknown };
  const response = {
    status(code: number) {
      captured.status = code;
      return this;
    },
    json(body: unknown) {
      captured.body = body;
    },
  };
  const host = {
    switchToHttp: () => ({ getResponse: () => response }),
  } as unknown as ArgumentsHost;

  const filter = new ApiExceptionFilter();
  RequestContextService.run({ requestId: 'test-request-id' }, () => filter.catch(exception, host));
  return captured;
}

describe('ApiExceptionFilter', () => {
  // The filter logs unexpected errors; keep test output clean
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('renders an ApiException with its code, status, details and the request id', () => {
    const { status, body } = captureResponse(
      new ApiException('INVALID_STATE_TRANSITION', 'Booking cannot move to CONFIRMED', {
        from: 'EXPIRED',
      }),
    );
    expect(status).toBe(409);
    expect(body).toEqual({
      success: false,
      error: {
        code: 'INVALID_STATE_TRANSITION',
        message: 'Booking cannot move to CONFIRMED',
        details: { from: 'EXPIRED' },
        requestId: 'test-request-id',
      },
    });
  });

  it('maps framework HTTP exceptions to a code', () => {
    const { status, body } = captureResponse(new NotFoundException('Cannot GET /x'));
    expect(status).toBe(404);
    expect(body).toMatchObject({ error: { code: 'RESOURCE_NOT_FOUND' } });
  });

  it('hides the message of unexpected errors', () => {
    const { status, body } = captureResponse(new Error('connection string mongodb://secret@host'));
    expect(status).toBe(500);
    expect(body).toMatchObject({
      error: { code: 'INTERNAL_ERROR', message: 'An unexpected error occurred' },
    });
    expect(JSON.stringify(body)).not.toContain('secret');
  });

  it('maps body-parser errors (invalid JSON, too large)', () => {
    expect(captureResponse({ type: 'entity.parse.failed' }).body).toMatchObject({
      error: { code: 'MALFORMED_REQUEST' },
    });
    expect(captureResponse({ type: 'entity.too.large' }).status).toBe(413);
  });
});
