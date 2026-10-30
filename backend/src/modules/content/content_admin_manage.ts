import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  CONTENT_STATUSES,
  ContentService,
  MAX_ANSWER_LENGTH,
  MAX_BODY_LENGTH,
  MAX_CATEGORY_LENGTH,
  MAX_QUESTION_LENGTH,
  MAX_TITLE_LENGTH,
  PAGE_KEYS,
  type ContactView,
  type FaqView,
  type PageView,
  type PublicPageView,
} from './content_admin_manage.service';

const pageKey = z.enum(PAGE_KEYS);

export class PageKeyParamDto extends createZodDto(z.object({ key: pageKey })) {}
export class FaqIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export class SavePageDto extends createZodDto(
  z.object({
    title: z.string().trim().min(1).max(MAX_TITLE_LENGTH),
    body: z.string().max(MAX_BODY_LENGTH),
    status: z.enum(CONTENT_STATUSES),
  }),
) {}

export class FaqDto extends createZodDto(
  z.object({
    question: z.string().trim().min(1).max(MAX_QUESTION_LENGTH),
    answer: z.string().trim().min(1).max(MAX_ANSWER_LENGTH),
    category: z.string().trim().max(MAX_CATEGORY_LENGTH).optional(),
    order: z.number().int().min(0).max(100_000).optional(),
    status: z.enum(CONTENT_STATUSES),
  }),
) {}

export class FaqListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    status: z.enum(CONTENT_STATUSES).optional(),
    category: z.string().trim().max(MAX_CATEGORY_LENGTH).optional(),
    page: z.coerce.number().int().min(1).max(10_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
  }),
) {}

export class PublicFaqQueryDto extends createZodDto(
  z.object({ category: z.string().trim().max(MAX_CATEGORY_LENGTH).optional() }),
) {}

export class SaveContactDto extends createZodDto(
  z.object({
    phone: z.string().trim().max(40),
    email: z.union([z.literal(''), z.string().trim().email().max(160)]),
    address: z.string().trim().max(400),
    hours: z.string().trim().max(200),
  }),
) {}

// ===== PUBLIC: customer app and website, no sign-in =====

@ApiTags('content')
@PublicEndpoint()
@Controller('content')
export class ContentPublicController {
  constructor(private readonly content: ContentService) {}

  @Get('pages/:key')
  @Header('Cache-Control', 'public, max-age=60')
  @ApiOperation({
    summary: 'An information page',
    description: 'No sign-in. Terms, privacy or about; only a published page is shown (else 404).',
  })
  page(@Param() params: PageKeyParamDto): Promise<PublicPageView> {
    return this.content.publicPage(params.key);
  }

  @Get('faqs')
  @Header('Cache-Control', 'public, max-age=60')
  @ApiOperation({
    summary: 'The FAQs',
    description: 'No sign-in. Published questions in the order staff set; `category` narrows them.',
  })
  faqs(@Query() query: PublicFaqQueryDto): Promise<FaqView[]> {
    return this.content.publicFaqs(query.category);
  }

  @Get('contact')
  @Header('Cache-Control', 'public, max-age=60')
  @ApiOperation({
    summary: 'Support contact details',
    description: 'No sign-in. Phone, email, address and hours; `configured` is false until saved.',
  })
  contact(): Promise<ContactView> {
    return this.content.publicContact();
  }
}

// ===== ADMIN =====

@ApiTags('content')
@Controller('admin/content')
export class ContentAdminController {
  constructor(private readonly content: ContentService) {}

  @Get('pages')
  @RequirePermission('content.read')
  @ApiOperation({
    summary: 'The information pages',
    description:
      'Requires content.read. Terms, privacy and about, written or not, with their status.',
  })
  pages(): Promise<PageView[]> {
    return this.content.listPages();
  }

  @Get('pages/:key')
  @RequirePermission('content.read')
  @ApiOperation({ summary: 'One information page', description: 'Requires content.read.' })
  page(@Param() params: PageKeyParamDto): Promise<PageView> {
    return this.content.getPage(params.key);
  }

  @Put('pages/:key')
  @RequirePermission('content.manage')
  @ZodApiBody(SavePageDto)
  @ApiOperation({
    summary: 'Save an information page',
    description:
      'Requires content.manage. Saves the text as a draft or publishes it; an empty page cannot ' +
      'be published. Audited.',
  })
  savePage(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: PageKeyParamDto,
    @Body() body: SavePageDto,
    @Req() request: Request,
  ): Promise<PageView> {
    return this.content.savePage(actor, params.key, body, clientRequestInfo(request));
  }

  @Get('faqs')
  @RequirePermission('content.read')
  @ApiOperation({
    summary: 'List FAQs',
    description: 'Requires content.read. Filters: search, status, category.',
  })
  faqs(@Query() query: FaqListQueryDto): Promise<PaginatedResult<FaqView>> {
    return this.content.listFaqs(query);
  }

  @Post('faqs')
  @RequirePermission('content.manage')
  @ZodApiBody(FaqDto)
  @ApiOperation({ summary: 'Add a FAQ', description: 'Requires content.manage. Audited.' })
  createFaq(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: FaqDto,
    @Req() request: Request,
  ): Promise<FaqView> {
    return this.content.createFaq(actor, body, clientRequestInfo(request));
  }

  @Patch('faqs/:id')
  @RequirePermission('content.manage')
  @ZodApiBody(FaqDto)
  @ApiOperation({
    summary: 'Change a FAQ',
    description: 'Requires content.manage. Also publishes or unpublishes it. Audited.',
  })
  updateFaq(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: FaqIdParamDto,
    @Body() body: FaqDto,
    @Req() request: Request,
  ): Promise<FaqView> {
    return this.content.updateFaq(actor, params.id, body, clientRequestInfo(request));
  }

  @Delete('faqs/:id')
  @RequirePermission('content.manage')
  @ApiOperation({
    summary: 'Delete a FAQ',
    description: 'Requires content.manage. It disappears from every app. Audited.',
  })
  removeFaq(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: FaqIdParamDto,
    @Req() request: Request,
  ): Promise<FaqView> {
    return this.content.removeFaq(actor, params.id, clientRequestInfo(request));
  }

  @Get('contact')
  @RequirePermission('content.read')
  @ApiOperation({ summary: 'Contact details', description: 'Requires content.read.' })
  contact(): Promise<ContactView> {
    return this.content.getContact();
  }

  @Put('contact')
  @RequirePermission('content.manage')
  @ZodApiBody(SaveContactDto)
  @ApiOperation({
    summary: 'Save the contact details',
    description: 'Requires content.manage. At least a phone number or an email. Audited.',
  })
  saveContact(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: SaveContactDto,
    @Req() request: Request,
  ): Promise<ContactView> {
    return this.content.saveContact(actor, body, clientRequestInfo(request));
  }
}
