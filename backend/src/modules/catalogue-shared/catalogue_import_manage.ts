import {
  Controller,
  Get,
  HttpCode,
  Inject,
  Post,
  Query,
  Req,
  Res,
  StreamableFile,
  type Type,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request, type Response } from 'express';
import { memoryStorage } from 'multer';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type PermissionKey } from '../rbac/permissions/permission-catalog';
import { EXPORT_FORMATS } from './catalogue_export_manage.service';
import {
  CatalogueImportService,
  IMPORT_MAX_BYTES,
  type ImportResult,
  type ImportSpec,
} from './catalogue_import_manage.service';

/*
 * `GET <list>/import-template` and `POST <list>/import?dryRun=true|false` for an admin list. A dry
 * run (the default) changes nothing and answers row by row; `dryRun=false` saves the rows that
 * are right. Register the controller BEFORE the module's others (`GET <list>/:id`).
 */

export class ImportTemplateQueryDto extends createZodDto(
  z.object({ format: z.enum(EXPORT_FORMATS).default('csv') }),
) {}

export class ImportQueryDto extends createZodDto(
  z.object({
    dryRun: z
      .enum(['true', 'false'])
      .default('true')
      .transform((value) => value === 'true'),
  }),
) {}

export interface ImportControllerSpec<Dto, Service> {
  readonly base: string;
  /** What adding a record needs: importing creates records, so it is the same key. */
  readonly permission: PermissionKey;
  readonly spec: ImportSpec<Dto, Service>;
  readonly service: Type<Service>;
  readonly title: string;
}

export function importController<Dto, Service>(
  description: ImportControllerSpec<Dto, Service>,
): Type<unknown> {
  const { base, permission, spec, title } = description;

  @ApiTags('catalogue')
  @Controller(base)
  class ImportController {
    constructor(
      private readonly importer: CatalogueImportService,
      @Inject(description.service) private readonly service: Service,
    ) {}

    @Get('import-template')
    @RequirePermission(permission)
    @ApiOperation({
      summary: `Template to import ${title}`,
      description:
        `Requires ${permission}. The column headings and one example row, as csv (default) or ` +
        'xlsx (`format`). The headings are the ones the export uses, so an exported file can be ' +
        'imported again.',
    })
    async template(
      @Query() query: ImportTemplateQueryDto,
      @Res({ passthrough: true }) response: Response,
    ): Promise<StreamableFile> {
      const file = await this.importer.template(spec, query.format);
      response.setHeader('Content-Disposition', `attachment; filename="${file.fileName}"`);
      response.setHeader('Cache-Control', 'no-store');
      response.setHeader('X-Content-Type-Options', 'nosniff');
      return new StreamableFile(file.body, { type: file.contentType });
    }

    @Post('import')
    @HttpCode(200)
    @RequirePermission(permission)
    @UseInterceptors(
      FileInterceptor('file', {
        storage: memoryStorage(),
        limits: { fileSize: IMPORT_MAX_BYTES, files: 1, fields: 2 },
      }),
    )
    @ApiConsumes('multipart/form-data')
    @ApiBody({
      schema: {
        type: 'object',
        required: ['file'],
        properties: { file: { type: 'string', format: 'binary' } },
      },
    })
    @ApiOperation({
      summary: `Import ${title} from a file`,
      description:
        `Requires ${permission}. A csv or xlsx file (field \`file\`, at most 1 MB and 500 rows). ` +
        '`dryRun=true` (default) only checks; `dryRun=false` saves the rows that are right and ' +
        'leaves the others out. The answer lists every row with its errors. Audited.',
    })
    run(
      @CurrentActor() actor: AuthenticatedUserActor,
      @Query() query: ImportQueryDto,
      @UploadedFile() file: { buffer: Buffer } | undefined,
      @Req() request: Request,
    ): Promise<ImportResult> {
      return this.importer.run(
        spec,
        this.service,
        actor,
        clientRequestInfo(request),
        file?.buffer,
        query.dryRun,
      );
    }
  }

  return ImportController;
}
