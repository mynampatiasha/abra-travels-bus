import {
  type ArgumentsHost,
  Catch,
  type ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';
import { type Response } from 'express';
import { API_ERROR_STATUS, type ApiErrorCode, errorCodeForStatus } from '../errors/api-error-codes';
import { ApiException } from '../errors/api-exception';
import { RequestContextService } from '../request-context/request-context.service';

export interface ApiErrorBody {
  success: false;
  error: {
    code: ApiErrorCode;
    message: string;
    details?: Record<string, unknown>;
    requestId: string | undefined;
  };
}

/**
 * Framework messages for these codes can echo parser internals or the full URL (query strings may
 * carry phone numbers or PNRs); replace them.
 */
const FIXED_MESSAGES: Partial<Record<ApiErrorCode, string>> = {
  INTERNAL_ERROR: 'An unexpected error occurred',
  RESOURCE_NOT_FOUND: 'No endpoint matches this method and path',
  MALFORMED_REQUEST: 'Request could not be parsed (invalid JSON or URL encoding)',
};

interface ResolvedError {
  status: number;
  code: ApiErrorCode;
  message: string;
  details?: Record<string, unknown>;
}

/**
 * Turns every error into the standard envelope
 * `{ success: false, error: { code, message, details, requestId } }` (api-architecture.md §1).
 * Unexpected errors are logged with their stack and answered with a generic INTERNAL_ERROR, so
 * internal details never reach the client.
 * Message translation by Accept-Language is added with the multilingual module (Phase 8).
 */
@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(ApiExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const resolved = this.resolve(exception);

    if (exception instanceof ApiException) {
      // Deliberate failure (e.g. SERVICE_UNAVAILABLE): no stack trace needed
      if (resolved.status >= 500) this.logger.warn({ code: resolved.code }, resolved.message);
    } else if (resolved.status >= 500) {
      this.logger.error(
        { err: exception, code: resolved.code },
        'Request failed with an unexpected error',
      );
    }

    const body: ApiErrorBody = {
      success: false,
      error: {
        code: resolved.code,
        message: resolved.message,
        ...(resolved.details ? { details: resolved.details } : {}),
        requestId: RequestContextService.requestId(),
      },
    };
    response.status(resolved.status).json(body);
  }

  private resolve(exception: unknown): ResolvedError {
    if (exception instanceof ApiException) {
      return {
        status: exception.status,
        code: exception.code,
        message: exception.message,
        ...(exception.details ? { details: exception.details } : {}),
      };
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const code = errorCodeForStatus(status);
      return {
        status: code === 'INTERNAL_ERROR' ? API_ERROR_STATUS.INTERNAL_ERROR : status,
        code,
        message: FIXED_MESSAGES[code] ?? exception.message,
      };
    }

    const bodyParserError = this.asBodyParserError(exception);
    if (bodyParserError) return bodyParserError;

    return { status: 500, code: 'INTERNAL_ERROR', message: 'An unexpected error occurred' };
  }

  /** express.json() errors (bad JSON, body over the 1 MB limit) arrive as plain errors with a `type`. */
  private asBodyParserError(exception: unknown): ResolvedError | undefined {
    if (typeof exception !== 'object' || exception === null || !('type' in exception)) {
      return undefined;
    }
    switch (exception.type) {
      case 'entity.parse.failed':
        return {
          status: 400,
          code: 'MALFORMED_REQUEST',
          message: 'Request body is not valid JSON',
        };
      case 'entity.too.large':
        return {
          status: 413,
          code: 'PAYLOAD_TOO_LARGE',
          message: 'Request body exceeds the 1 MB limit',
        };
      case 'encoding.unsupported':
      case 'charset.unsupported':
        return {
          status: 415,
          code: 'UNSUPPORTED_MEDIA_TYPE',
          message: 'Unsupported request body encoding',
        };
      default:
        return undefined;
    }
  }
}
