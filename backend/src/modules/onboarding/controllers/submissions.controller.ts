import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import {
  CreateBusSubmissionDto,
  RejectSubmissionDto,
  ReviewDocumentDto,
  SetDocumentDto,
  SubmissionDocumentParamDto,
  SubmissionIdParamDto,
  SubmissionListQueryDto,
} from '../dto/onboarding.dto';
import { SubmissionReviewService } from '../services/submission-review.service';
import {
  type SubmissionSummaryView,
  type SubmissionView,
} from '../services/submission-view.service';
import { SubmissionsService } from '../services/submissions.service';

/**
 * The onboarding files of a company and of each bus: the owner collects documents and sends them
 * for review; a platform employee reviews them. Reading is limited to the caller's own operator
 * (all operators for platform staff).
 */
@ApiTags('onboarding')
@Controller('onboarding/submissions')
export class SubmissionsController {
  constructor(
    private readonly submissions: SubmissionsService,
    private readonly review: SubmissionReviewService,
  ) {}

  @Get()
  @RequirePermission('documents.view')
  @ApiOperation({
    summary: 'List onboarding files',
    description:
      'Requires documents.view. `status`, `subjectType` and (platform staff) `operatorId` ' +
      'filter. With status=PENDING it is the review queue, oldest first. Paginated.',
  })
  list(@Query() query: SubmissionListQueryDto): Promise<PaginatedResult<SubmissionSummaryView>> {
    return this.submissions.list(query);
  }

  @Get(':id')
  @RequirePermission('documents.view')
  @ApiOperation({
    summary: 'One onboarding file',
    description:
      'Requires documents.view. The documents with their files and decisions, the checklist of ' +
      'what is asked for and where each stands, what blocks sending it (`problems`), and its ' +
      'history. A rejected document carries the reviewer’s reason.',
  })
  get(@Param() params: SubmissionIdParamDto): Promise<SubmissionView> {
    return this.submissions.get(params.id);
  }

  @Post()
  @RequirePermission('documents.upload')
  @ZodApiBody(CreateBusSubmissionDto)
  @ApiOperation({
    summary: 'Start the onboarding file of a bus',
    description:
      'Requires documents.upload. For a bus the owner added that awaits approval. Asking again ' +
      'returns the same file. The company’s own file is created when it is invited.',
  })
  createForBus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBusSubmissionDto,
  ): Promise<SubmissionView> {
    return this.submissions.createForBus(actor, body);
  }

  @Put(':id/documents/:documentTypeId')
  @RequirePermission('documents.upload')
  @ZodApiBody(SetDocumentDto)
  @ApiOperation({
    summary: 'Put files into a document',
    description:
      'Requires documents.upload. Replaces what that document held. The files are uploaded ' +
      'first with POST /files for the same document type. Allowed while the file is a draft or ' +
      'was sent back; an approved document cannot be changed. Needs `expiryDate` (YYYY-MM-DD, ' +
      'not in the past) for documents that expire.',
  })
  setDocument(
    @Param() params: SubmissionDocumentParamDto,
    @Body() body: SetDocumentDto,
  ): Promise<SubmissionView> {
    return this.submissions.setDocument(params.id, params.documentTypeId, body);
  }

  @Delete(':id/documents/:documentTypeId')
  @RequirePermission('documents.upload')
  @ApiOperation({
    summary: 'Remove a document',
    description: 'Requires documents.upload. Same rules as replacing it.',
  })
  removeDocument(@Param() params: SubmissionDocumentParamDto): Promise<SubmissionView> {
    return this.submissions.removeDocument(params.id, params.documentTypeId);
  }

  @Post(':id/submit')
  @HttpCode(200)
  @RequirePermission('documents.upload')
  @ApiOperation({
    summary: 'Send for review',
    description:
      'Requires documents.upload. Every required document must be in, none expired or still ' +
      'rejected; otherwise VALIDATION_FAILED lists what is missing. After a rejection it sends ' +
      'the fixed file again; documents already approved are not looked at twice. Audited.',
  })
  submit(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: SubmissionIdParamDto,
    @Req() request: Request,
  ): Promise<SubmissionView> {
    return this.submissions.submit(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/documents/:documentTypeId/review')
  @HttpCode(200)
  @RequirePermission('documents.review')
  @ZodApiBody(ReviewDocumentDto)
  @ApiOperation({
    summary: 'Accept or reject one document',
    description:
      'Requires documents.review. Only while the file waits for review. Rejecting needs a ' +
      '`reason`, which the owner reads. A decision can be changed until the file is decided.',
  })
  reviewDocument(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: SubmissionDocumentParamDto,
    @Body() body: ReviewDocumentDto,
  ): Promise<SubmissionView> {
    return this.review.reviewDocument(actor, params.id, params.documentTypeId, body);
  }

  @Post(':id/approve')
  @HttpCode(200)
  @RequirePermission('documents.review')
  @ApiOperation({
    summary: 'Approve the file',
    description:
      'Requires documents.review. Every document must be accepted and unexpired. Approving a ' +
      'company makes the operator ACTIVE; approving a bus makes it ACTIVE, and only once its ' +
      'company is. Audited; the owner is notified.',
  })
  approve(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: SubmissionIdParamDto,
    @Req() request: Request,
  ): Promise<SubmissionView> {
    return this.review.approve(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/reject')
  @HttpCode(200)
  @RequirePermission('documents.review')
  @ZodApiBody(RejectSubmissionDto)
  @ApiOperation({
    summary: 'Send the file back',
    description:
      'Requires documents.review. At least one document must be rejected with its reason, and ' +
      'every document must have been reviewed. The owner is notified with the reasons, fixes ' +
      'only the rejected documents and sends the file again. Audited.',
  })
  reject(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: SubmissionIdParamDto,
    @Body() body: RejectSubmissionDto,
    @Req() request: Request,
  ): Promise<SubmissionView> {
    return this.review.reject(actor, params.id, body, clientRequestInfo(request));
  }
}
