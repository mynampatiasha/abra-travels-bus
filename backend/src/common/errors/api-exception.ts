import { API_ERROR_STATUS, type ApiErrorCode } from './api-error-codes';

/**
 * The only exception type business code should throw. The HTTP status is derived from the code,
 * so the same code always produces the same status.
 */
export class ApiException extends Error {
  readonly status: number;

  constructor(
    readonly code: ApiErrorCode,
    message: string,
    readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'ApiException';
    this.status = API_ERROR_STATUS[code];
  }
}
