import {
  Controller,
  Get,
  Param,
  Post,
  Query,
  Res,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { memoryStorage } from 'multer';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { type ProofFileView, ProofFilesService } from './files_core.service';
import { type IncomingFile } from './services/files.service';

/*
 * Proof files (`/files/proofs`): upload, look at and download the pictures, PDFs and text notes
 * that sensitive actions carry. The rules (5 files, 600 KB each, real type read from the bytes)
 * live in files_core.service.ts. Attaching a proof to an action is done by that action's own
 * service (ProofFilesService.attach), inside its transaction.
 */

class ProofIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

class ProofContentQueryDto extends createZodDto(
  z.object({ disposition: z.enum(['inline', 'attachment']).default('attachment') }),
) {}

@ApiTags('files')
@Controller('files/proofs')
@AuthenticatedOnly()
export class ProofFilesController {
  constructor(private readonly proofs: ProofFilesService) {}

  // access: any signed-in person | audit: none (the action that attaches the proof is audited)
  @Post()
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      // A little above the 600 KB rule, so the person gets the plain message, not a transport error
      limits: { fileSize: 1024 * 1024, files: 1, fields: 0 },
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
    summary: 'Upload a proof file',
    description:
      'Any signed-in person. One picture (JPG or PNG), PDF or text file of at most 600 KB; its ' +
      'real type is read from its bytes. Returns the proof record. The proof is attached to an ' +
      'action by sending its id with that action (at most 5 per action).',
  })
  upload(
    @CurrentActor() actor: AuthenticatedUserActor,
    @UploadedFile() file: IncomingFile | undefined,
  ): Promise<ProofFileView> {
    return this.proofs.upload(actor, file);
  }

  // access: Abra staff, the operator concerned, the uploader, people the action names | audit: none
  @Get(':id')
  @ApiOperation({
    summary: 'Describe a proof file',
    description:
      'Name, type and size. Only for Abra staff, the operator the proof concerns, the person who ' +
      'uploaded it and the people the action names; anyone else gets 404.',
  })
  describe(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ProofIdParamDto,
  ): Promise<ProofFileView> {
    return this.proofs.describe(actor, params.id);
  }

  // access: same as describe | audit: none
  @Get(':id/content')
  @ApiOperation({
    summary: 'View or download a proof file',
    description:
      '`disposition=inline` shows a picture, PDF or text in the page; the default downloads it. ' +
      'Never cached, never run as a page (sandboxed, no sniffing).',
  })
  async content(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ProofIdParamDto,
    @Query() query: ProofContentQueryDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const { file, content } = await this.proofs.open(actor, params.id);
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    response.setHeader(
      'Content-Security-Policy',
      "default-src 'none'; sandbox; style-src 'unsafe-inline'",
    );
    return new StreamableFile(content, {
      type: file.mimeType === 'text/plain' ? 'text/plain; charset=utf-8' : file.mimeType,
      length: file.sizeBytes,
      disposition: `${query.disposition}; filename*=UTF-8''${encodeURIComponent(file.originalName)}`,
    });
  }
}
