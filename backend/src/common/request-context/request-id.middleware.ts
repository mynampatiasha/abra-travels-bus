import { randomUUID } from 'node:crypto';
import { type NextFunction, type Request, type Response } from 'express';
import { RequestContextService } from './request-context.service';

export const REQUEST_ID_HEADER = 'x-request-id';

// A caller-supplied id (load balancer, partner, app) is kept only if it is safe to log and echo
const ACCEPTED_REQUEST_ID = /^[A-Za-z0-9._:-]{8,128}$/;

export function resolveRequestId(incoming: string | string[] | undefined): string {
  const candidate = Array.isArray(incoming) ? incoming[0] : incoming;
  return candidate !== undefined && ACCEPTED_REQUEST_ID.test(candidate) ? candidate : randomUUID();
}

/**
 * Registered first (before logging and routing), so every log line, error body and response
 * header of a request carries the same id.
 */
export function requestIdMiddleware(
  request: Request,
  response: Response,
  next: NextFunction,
): void {
  const requestId = resolveRequestId(request.headers[REQUEST_ID_HEADER]);
  (request as Request & { id: string }).id = requestId;
  response.setHeader('X-Request-Id', requestId);
  RequestContextService.run({ requestId }, next);
}
