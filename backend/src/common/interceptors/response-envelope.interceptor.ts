import {
  type CallHandler,
  type ExecutionContext,
  Injectable,
  type NestInterceptor,
  StreamableFile,
} from '@nestjs/common';
import { map, type Observable } from 'rxjs';
import { RequestContextService } from '../request-context/request-context.service';

export interface ApiSuccessBody<T> {
  success: true;
  data: T;
  meta: { requestId: string | undefined } & Record<string, unknown>;
}

/**
 * Wraps controller results in `{ success: true, data, meta: { requestId, ... } }`
 * (api-architecture.md §1). Paginated handlers return `PaginatedResult`, whose paging fields
 * move into `meta`. Files and streams are passed through untouched.
 */
export class PaginatedResult<T> {
  constructor(
    readonly items: T[],
    readonly page: number,
    readonly pageSize: number,
    readonly total: number,
  ) {}
}

@Injectable()
export class ResponseEnvelopeInterceptor implements NestInterceptor {
  intercept(_context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      map((result: unknown) => {
        if (result instanceof StreamableFile) return result;

        const requestId = RequestContextService.requestId();
        if (result instanceof PaginatedResult) {
          const { items, page, pageSize, total } = result as PaginatedResult<unknown>;
          return {
            success: true,
            data: items,
            meta: { requestId, page, pageSize, total },
          } satisfies ApiSuccessBody<unknown[]>;
        }
        return {
          success: true,
          data: result ?? null,
          meta: { requestId },
        } satisfies ApiSuccessBody<unknown>;
      }),
    );
  }
}
