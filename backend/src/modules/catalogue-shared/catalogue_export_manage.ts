import {
  Controller,
  Get,
  Inject,
  type PipeTransform,
  Query,
  Req,
  Res,
  StreamableFile,
  type Type,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request, type Response } from 'express';
import { z, type ZodObject, type ZodRawShape } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { ApiException } from '../../common/errors/api-exception';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type ZodDtoClass } from '../../common/pipes/zod-validation.pipe';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type PermissionKey } from '../rbac/permissions/permission-catalog';
import {
  CatalogueExportService,
  EXPORT_FORMATS,
  type ExportFormat,
  type ExportKind,
} from './catalogue_export_manage.service';

/*
 * `GET <list>/export?format=csv|xlsx` for an admin list: the list's own filters, its own service
 * and the module's export permission. The controller is made from one description, so every list
 * exports the same way. Register it BEFORE the module's other controllers: those have
 * `GET <list>/:id`, which would otherwise take "export" for an id.
 */

/** What a list is exported from. */
export interface ExportSpec<Row, Service> {
  /** Path of the list, without the API prefix. */
  readonly base: string;
  readonly permission: PermissionKey;
  readonly kind: ExportKind<Row>;
  /** The list's service, which the module provides. */
  readonly service: Type<Service>;
  /** Reads one page of the list the way the list's own endpoint does. */
  readonly load: (
    service: Service,
    query: Record<string, unknown> & { page: number; pageSize: number },
  ) => Promise<PaginatedResult<Row>>;
  /** The list's query class: the export takes the same filters (everything but the paging). */
  readonly query: ZodDtoClass;
  /** Shown in the API documentation. */
  readonly title: string;
}

/** Checks the query of an export against the list's own filters plus `format`. */
class ExportQueryPipe implements PipeTransform {
  private readonly schema: ZodObject<ZodRawShape>;

  constructor(listQuery: ZodDtoClass) {
    this.schema = (listQuery.zodSchema as unknown as ZodObject<ZodRawShape>)
      .omit({ page: true, pageSize: true })
      .extend({ format: z.enum(EXPORT_FORMATS).default('csv') })
      .strict();
  }

  transform(value: unknown): Record<string, unknown> {
    const result = this.schema.safeParse(value ?? {});
    if (result.success) return result.data;
    throw new ApiException('VALIDATION_FAILED', 'Request validation failed', {
      location: 'query',
      issues: result.error.issues.map((issue) => ({
        path: issue.path.join('.'),
        code: issue.code,
        message: issue.message,
      })),
    });
  }
}

export function exportController<Row, Service>(spec: ExportSpec<Row, Service>): Type<unknown> {
  const pipe = new ExportQueryPipe(spec.query);

  @ApiTags('catalogue')
  @Controller(spec.base)
  class ExportController {
    constructor(
      private readonly exporter: CatalogueExportService,
      @Inject(spec.service) private readonly lists: Service,
    ) {}

    @Get('export')
    @RequirePermission(spec.permission)
    @ApiOperation({
      summary: `Export ${spec.title}`,
      description:
        `Requires ${spec.permission}. \`format\` is csv (default) or xlsx; every other query ` +
        'parameter is a filter of the list, with the same meaning and the same result. At most ' +
        '20,000 rows. The export is audited.',
    })
    async export(
      @CurrentActor() actor: AuthenticatedUserActor,
      @Query(pipe) query: Record<string, unknown>,
      @Req() request: Request,
      @Res({ passthrough: true }) response: Response,
    ): Promise<StreamableFile> {
      const { format, ...filters } = query as Record<string, unknown> & { format: ExportFormat };
      const file = await this.exporter.export(
        spec.kind,
        actor,
        clientRequestInfo(request),
        format,
        filters,
        (page, pageSize) => spec.load(this.lists, { ...filters, page, pageSize }),
      );
      response.setHeader('Content-Disposition', `attachment; filename="${file.fileName}"`);
      response.setHeader('Cache-Control', 'no-store');
      response.setHeader('X-Content-Type-Options', 'nosniff');
      return new StreamableFile(file.body, { type: file.contentType });
    }
  }

  return ExportController;
}
