import { type Readable } from 'node:stream';
import {
  Body,
  Controller,
  Delete,
  Get,
  Module,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  StreamableFile,
  UploadedFiles,
  UseInterceptors,
} from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { FilesInterceptor } from '@nestjs/platform-express';
import { ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request, type Response } from 'express';
import { memoryStorage } from 'multer';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { AppConfigService } from '../../config/app-config.service';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { createFileStorage } from '../files/files.module';
import { type IncomingFile } from '../files/services/files.service';
import { FILE_STORAGE } from '../files/storage/file-storage';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import {
  BUS_DOC_REMINDER_MODEL,
  BUS_DOC_TYPES,
  BUS_DOCUMENT_MODEL,
  BusDocReminderSchema,
  BusDocumentSchema,
  BusDocumentsClientManageService,
  MAX_BUS_DOC_BYTES,
  MAX_FILES_PER_BUS_DOC,
  type BusDocTypeView,
  type BusDocumentView,
  type DriverBusView,
} from './bus_documents_client_manage.service';

// ===== 1. WHAT THE SCREENS SEND =====

const emptyToUndefined = (value: unknown): unknown => (value === '' ? undefined : value);

/** Reminder days arrive as a list (JSON) or as text from a form ("30, 15, 7"). */
const remindDays = z.preprocess(
  (value) => {
    if (value === '' || value === undefined || value === null) return undefined;
    if (typeof value === 'string') return value.split(',').map((part) => Number(part.trim()));
    return value;
  },
  z.array(z.number()).optional(),
);

const busParams = z.object({ busId: objectIdString });
const docParams = z.object({ busId: objectIdString, docId: objectIdString });
const fileParams = z.object({ busId: objectIdString, docId: objectIdString, fileId: z.string().uuid() });

export class BusDocBusParamDto extends createZodDto(busParams) {}
export class BusDocParamDto extends createZodDto(docParams) {}
export class BusDocFileParamDto extends createZodDto(fileParams) {}

export class BusDocCreateDto extends createZodDto(
  z.object({
    docType: z.enum(BUS_DOC_TYPES),
    docName: z.preprocess(emptyToUndefined, z.string().max(100).optional()),
    validTill: z.preprocess(emptyToUndefined, z.string().optional()),
    remindDaysBefore: remindDays,
  }),
) {}

export class BusDocUpdateDto extends createZodDto(
  z.object({
    docName: z.string().max(100).optional(),
    validTill: z.string().optional(),
    remindDaysBefore: remindDays,
  }),
) {}

export class BusDocContentQueryDto extends createZodDto(
  z.object({ disposition: z.enum(['inline', 'attachment']).default('attachment') }),
) {}

const upload = FilesInterceptor('files', MAX_FILES_PER_BUS_DOC, {
  storage: memoryStorage(),
  limits: { fileSize: MAX_BUS_DOC_BYTES + 1024, files: MAX_FILES_PER_BUS_DOC },
});

/** The file as the browser receives it: never run by the browser, never kept in a cache. */
async function streamOf(
  opened: Promise<{ file: { mimeType: string; sizeBytes: number; originalName: string }; content: Readable }>,
  disposition: 'inline' | 'attachment',
  response: Response,
): Promise<StreamableFile> {
  const { file, content } = await opened;
  response.setHeader('Cache-Control', 'private, no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Content-Security-Policy', "default-src 'none'; sandbox; style-src 'unsafe-inline'");
  return new StreamableFile(content, {
    type: file.mimeType,
    length: file.sizeBytes,
    disposition: `${disposition}; filename*=UTF-8''${encodeURIComponent(file.originalName)}`,
  });
}

// ===== 2. THE OWNER'S SCREEN =====

/** The kinds of document an owner can add to a bus. */
@ApiTags('client portal')
@Controller('client/bus-document-types')
export class BusDocumentTypesClientController {
  constructor(private readonly service: BusDocumentsClientManageService) {}

  @Get()
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'The kinds of bus document, and which are required' })
  types(): BusDocTypeView[] {
    return this.service.types();
  }
}

@ApiTags('client portal')
@Controller('client/buses')
export class BusDocumentsClientController {
  constructor(private readonly service: BusDocumentsClientManageService) {}

  @Get(':busId/documents')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'The documents of one of my buses, with their expiry dates' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocBusParamDto,
  ): Promise<BusDocumentView[]> {
    return this.service.list(actor, params.busId);
  }

  @Post(':busId/documents')
  @RequirePermission('buses.update')
  @UseInterceptors(upload)
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Add a document (one or more files) with its expiry date and reminder days' })
  add(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocBusParamDto,
    @Body() dto: BusDocCreateDto,
    @UploadedFiles() files: IncomingFile[] | undefined,
    @Req() request: Request,
  ): Promise<BusDocumentView> {
    return this.service.add(actor, params.busId, dto, files ?? [], clientRequestInfo(request));
  }

  @Post(':busId/documents/:docId/files')
  @RequirePermission('buses.update')
  @UseInterceptors(upload)
  @ApiConsumes('multipart/form-data')
  @ApiOperation({ summary: 'Add more files to a document' })
  addFiles(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocParamDto,
    @UploadedFiles() files: IncomingFile[] | undefined,
    @Req() request: Request,
  ): Promise<BusDocumentView> {
    return this.service.addFiles(actor, params.busId, params.docId, files ?? [], clientRequestInfo(request));
  }

  @Patch(':busId/documents/:docId')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Rename a document, change its expiry date or its reminder days' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocParamDto,
    @Body() dto: BusDocUpdateDto,
    @Req() request: Request,
  ): Promise<BusDocumentView> {
    return this.service.update(actor, params.busId, params.docId, dto, clientRequestInfo(request));
  }

  @Delete(':busId/documents/:docId')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Delete a document and its files' })
  remove(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocParamDto,
    @Req() request: Request,
  ): Promise<{ success: boolean }> {
    return this.service.remove(actor, params.busId, params.docId, clientRequestInfo(request));
  }

  @Delete(':busId/documents/:docId/files/:fileId')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Delete one file of a document' })
  removeFile(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocFileParamDto,
    @Req() request: Request,
  ): Promise<BusDocumentView> {
    return this.service.removeFile(actor, params.busId, params.docId, params.fileId, clientRequestInfo(request));
  }

  @Get(':busId/documents/:docId/files/:fileId')
  @RequirePermission('buses.read')
  @ApiOperation({ summary: 'View or download one file of a document' })
  content(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocFileParamDto,
    @Query() query: BusDocContentQueryDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    return streamOf(this.service.openFile(actor, params.busId, params.docId, params.fileId), query.disposition, response);
  }
}

// ===== 3. THE DRIVER'S AND CONDUCTOR'S SCREEN =====

/** The buses a driver or conductor runs, and their documents (view and download only). */
@ApiTags('driver app')
@Controller('driver/buses')
export class BusDocumentsDriverController {
  constructor(private readonly service: BusDocumentsClientManageService) {}

  @Get()
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'The buses I run (usual bus, or on my trips), with how many documents are due' })
  buses(@CurrentActor() actor: AuthenticatedUserActor): Promise<DriverBusView[]> {
    return this.service.driverBuses(actor);
  }

  @Get(':busId/documents')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'The documents of one of my buses' })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocBusParamDto,
  ): Promise<BusDocumentView[]> {
    return this.service.driverDocuments(actor, params.busId);
  }

  @Get(':busId/documents/:docId/files/:fileId')
  @RequirePermission('trips.read')
  @ApiOperation({ summary: 'View or download one file of a document of my bus' })
  content(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BusDocFileParamDto,
    @Query() query: BusDocContentQueryDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    return streamOf(
      this.service.driverOpenFile(actor, params.busId, params.docId, params.fileId),
      query.disposition,
      response,
    );
  }
}

// ===== 4. THE MODULE =====

/** Bus documents, their reminders and the driver's view. Imported by BusesModule. */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: BUS_DOCUMENT_MODEL, schema: BusDocumentSchema },
      { name: BUS_DOC_REMINDER_MODEL, schema: BusDocReminderSchema },
    ]),
    RbacModule,
  ],
  controllers: [BusDocumentTypesClientController, BusDocumentsClientController, BusDocumentsDriverController],
  providers: [
    BusDocumentsClientManageService,
    { provide: FILE_STORAGE, inject: [AppConfigService], useFactory: createFileStorage },
  ],
  exports: [BusDocumentsClientManageService],
})
export class BusDocumentsModule {}
