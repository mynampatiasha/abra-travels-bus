import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Res,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { memoryStorage } from 'multer';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { FileIdParamDto, UploadFileDto } from '../dto/file.dto';
import { type FileView, FilesService, type IncomingFile } from '../services/files.service';

/** The largest any document type may allow (25 MB); each type sets its own, lower, limit. */
const HARD_LIMIT_BYTES = 25 * 1024 * 1024;

@ApiTags('files')
@Controller('files')
export class FilesController {
  constructor(private readonly files: FilesService) {}

  @Post()
  @RequirePermission('documents.upload')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: HARD_LIMIT_BYTES, files: 1, fields: 4 },
    }),
  )
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'documentTypeId'],
      properties: {
        file: { type: 'string', format: 'binary' },
        documentTypeId: { type: 'string' },
        operatorId: { type: 'string' },
      },
    },
  })
  @ApiOperation({
    summary: 'Upload a document file',
    description:
      'Requires documents.upload. Multipart: `file` plus `documentTypeId` (and `operatorId` ' +
      'for platform staff). The file is checked against that document type: size, and its ' +
      'real type from its bytes (PDF, JPG or PNG). Returns the file record; attaching it to ' +
      'a submission is a separate step.',
  })
  upload(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: UploadFileDto,
    @UploadedFile() file: IncomingFile | undefined,
  ): Promise<FileView> {
    return this.files.upload(actor, body, file);
  }

  @Get(':id')
  @RequirePermission('documents.view')
  @ApiOperation({
    summary: 'Describe an uploaded file',
    description:
      'Requires documents.view. Only files of the caller’s own operator (all, for platform staff).',
  })
  describe(@Param() params: FileIdParamDto): Promise<FileView> {
    return this.files.describe(params.id);
  }

  @Get(':id/content')
  @RequirePermission('documents.view')
  @ApiOperation({
    summary: 'Download an uploaded file',
    description:
      'Requires documents.view. Streams the file only to someone whose scope includes the ' +
      'owning operator. Never cached, never opened by the browser as a page.',
  })
  async content(
    @Param() params: FileIdParamDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const { file, content } = await this.files.open(params.id);
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    return new StreamableFile(content, {
      type: file.mimeType,
      length: file.sizeBytes,
      disposition: `attachment; filename*=UTF-8''${encodeURIComponent(file.originalName)}`,
    });
  }
}
