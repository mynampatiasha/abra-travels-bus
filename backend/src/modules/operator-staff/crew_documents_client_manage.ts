import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
  StreamableFile,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor, FilesInterceptor } from '@nestjs/platform-express';
import { ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { memoryStorage } from 'multer';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { type IncomingFile } from '../files/services/files.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  CREW_DOC_TYPES,
  CrewDocumentsClientManageService,
  MAX_CREW_DOC_BYTES,
  MAX_FILES_PER_CREW_DOC,
  crewSampleCsv,
  type CrewDocumentView,
  type CrewImportResult,
} from './crew_documents_client_manage.service';

const emptyToUndefined = (value: unknown): unknown => (value === '' ? undefined : value);

const crewDocParams = z.object({ id: objectIdString });
const crewDocFileParams = z.object({ id: objectIdString, docId: objectIdString });
const crewDocOneFileParams = z.object({ id: objectIdString, docId: objectIdString, fileId: z.string().uuid() });

export class CrewDocCrewParamDto extends createZodDto(crewDocParams) {}
export class CrewDocParamDto extends createZodDto(crewDocFileParams) {}
export class CrewDocFileParamDto extends createZodDto(crewDocOneFileParams) {}

export class CrewDocCreateDto extends createZodDto(
  z.object({
    docType: z.enum(CREW_DOC_TYPES),
    docName: z.preprocess(emptyToUndefined, z.string().max(100).optional()),
    validTill: z.preprocess(emptyToUndefined, z.string().optional()),
  }),
) {}

export class CrewDocUpdateDto extends createZodDto(
  z.object({
    docName: z.string().max(100).optional(),
    validTill: z.string().nullable().optional(),
  }),
) {}

export class CrewDocContentQueryDto extends createZodDto(
  z.object({ disposition: z.enum(['inline', 'attachment']).default('attachment') }),
) {}

const upload = (many: boolean) =>
  many
    ? FilesInterceptor('files', MAX_FILES_PER_CREW_DOC, {
        storage: memoryStorage(),
        limits: { fileSize: MAX_CREW_DOC_BYTES + 1024, files: MAX_FILES_PER_CREW_DOC },
      })
    : FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 1024 * 1024, files: 1 } });

@ApiTags('Client Crew Documents')
@Controller('client/crew')
export class CrewDocumentsClientController {
  constructor(private readonly service: CrewDocumentsClientManageService) {}

  @Get('import/sample')
  @RequirePermission('buses.create')
  @ApiOperation({ summary: 'Download the sample CSV for importing drivers and crew' })
  sample(): StreamableFile {
    return new StreamableFile(Buffer.from(crewSampleCsv(), 'utf8'), {
      type: 'text/csv; charset=utf-8',
      disposition: 'attachment; filename="Crew_Import_Sample.csv"',
    });
  }

  @Post('import')
  @RequirePermission('buses.create')
  @UseInterceptors(upload(false))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Import drivers and crew from a filled CSV file' })
  importCsv(
    @CurrentActor() actor: AuthenticatedUserActor,
    @UploadedFile() file: IncomingFile | undefined,
  ): Promise<CrewImportResult> {
    return this.service.importCsv(actor, file);
  }

  @Get(':id/documents')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'List the documents of one person' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocCrewParamDto,
  ): Promise<CrewDocumentView[]> {
    return this.service.list(actor, params.id);
  }

  @Post(':id/documents')
  @RequirePermission('buses.update')
  @UseInterceptors(upload(true))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Add a document (one or more files) to a person' })
  add(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocCrewParamDto,
    @Body() dto: CrewDocCreateDto,
    @UploadedFiles() files: IncomingFile[] | undefined,
  ): Promise<CrewDocumentView> {
    return this.service.add(actor, params.id, dto, files ?? []);
  }

  @Post(':id/documents/:docId/files')
  @RequirePermission('buses.update')
  @UseInterceptors(upload(true))
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Add more files to a document' })
  addFiles(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocParamDto,
    @UploadedFiles() files: IncomingFile[] | undefined,
  ): Promise<CrewDocumentView> {
    return this.service.addFiles(actor, params.id, params.docId, files ?? []);
  }

  @Patch(':id/documents/:docId')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Change the validity date (or the name of an "Other" document)' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocParamDto,
    @Body() dto: CrewDocUpdateDto,
  ): Promise<CrewDocumentView> {
    return this.service.update(actor, params.id, params.docId, dto);
  }

  @Delete(':id/documents/:docId')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Delete a document and its files' })
  remove(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocParamDto,
  ): Promise<{ success: boolean }> {
    return this.service.remove(actor, params.id, params.docId);
  }

  @Delete(':id/documents/:docId/files/:fileId')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Delete one file of a document' })
  removeFile(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocFileParamDto,
  ): Promise<CrewDocumentView> {
    return this.service.removeFile(actor, params.id, params.docId, params.fileId);
  }

  @Get(':id/documents/:docId/files/:fileId')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'View or download one file of a document' })
  async content(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewDocFileParamDto,
    @Query() query: CrewDocContentQueryDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const { file, content } = await this.service.openFile(actor, params.id, params.docId, params.fileId);
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader('Content-Security-Policy', "default-src 'none'; sandbox; style-src 'unsafe-inline'");
    return new StreamableFile(content, {
      type: file.mimeType,
      length: file.sizeBytes,
      disposition: `${query.disposition}; filename*=UTF-8''${encodeURIComponent(file.originalName)}`,
    });
  }
}
