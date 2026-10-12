import { Body, Controller, Get, Param, Post, Put, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { CatalogueIdParamDto, SetActiveDto } from '../../cities/dto/city-admin.dto';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import {
  CreateDocumentTypeDto,
  DocumentTypeListQueryDto,
  UpdateDocumentTypeDto,
} from '../dto/document-type.dto';
import { type DocumentTypeView, DocumentTypesService } from '../services/document-types.service';

@ApiTags('catalogue')
@Controller('catalogue/document-types')
export class DocumentTypesController {
  constructor(private readonly documentTypes: DocumentTypesService) {}

  @Get()
  @RequirePermission('documents.read')
  @ApiOperation({
    summary: 'List the documents operators must provide',
    description:
      'Requires documents.read. Platform staff see every type (`active` and `appliesTo` filter); ' +
      'operator staff see only the active ones, which is the checklist they must complete. ' +
      'Paginated.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: DocumentTypeListQueryDto,
  ): Promise<PaginatedResult<DocumentTypeView>> {
    return this.documentTypes.list(query, { activeOnly: actor.userType !== 'STAFF' });
  }

  @Post()
  @RequirePermission('documents.manage')
  @ZodApiBody(CreateDocumentTypeDto)
  @ApiOperation({
    summary: 'Add a document type',
    description:
      'Requires documents.manage. The key and what it applies to (operator or bus) are ' +
      'permanent. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateDocumentTypeDto,
    @Req() request: Request,
  ): Promise<DocumentTypeView> {
    return this.documentTypes.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('documents.manage')
  @ZodApiBody(UpdateDocumentTypeDto)
  @ApiOperation({
    summary: 'Edit a document type',
    description:
      'Requires documents.manage. Documents already uploaded keep the rules they were ' +
      'uploaded under. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: UpdateDocumentTypeDto,
    @Req() request: Request,
  ): Promise<DocumentTypeView> {
    return this.documentTypes.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/active')
  @RequirePermission('documents.manage')
  @ZodApiBody(SetActiveDto)
  @ApiOperation({
    summary: 'Enable or disable a document type',
    description:
      'Requires documents.manage. A disabled type is no longer asked for; types are never ' +
      'deleted so past submissions stay readable. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CatalogueIdParamDto,
    @Body() body: SetActiveDto,
    @Req() request: Request,
  ): Promise<DocumentTypeView> {
    return this.documentTypes.update(
      actor,
      params.id,
      { isActive: body.active },
      clientRequestInfo(request),
    );
  }
}
