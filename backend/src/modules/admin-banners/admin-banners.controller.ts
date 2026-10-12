import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Headers,
  Param,
  Post,
  Put,
  Query,
  Req,
  Res,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request, type Response } from 'express';
import { memoryStorage } from 'multer';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { preferredLanguage } from '../../common/http/preferred-language';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { SetActiveDto } from '../cities/dto/city-admin.dto';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  BannerIdParamDto,
  BannerImageVariantQueryDto,
  BannerListQueryDto,
  type BannerView,
  CreateBannerDto,
  PublicBannerImageQueryDto,
  PublicBannerQueryDto,
  type PublicBannerView,
  UpdateBannerDto,
} from './admin-banners.model';
import {
  AdminBannersService,
  BANNER_IMAGE_MAX_BYTES,
  type IncomingBannerImage,
} from './admin-banners.service';

@ApiTags('banners')
@Controller('admin/banners')
export class AdminBannersController {
  constructor(private readonly banners: AdminBannersService) {}

  @Get()
  @RequirePermission('banners.read')
  @ApiOperation({
    summary: 'List banners',
    description:
      'Requires banners.read. Filters: `search` (title or subtitle), `status` ' +
      '(LIVE, SCHEDULED, EXPIRED, INACTIVE, ARCHIVED — worked out from the dates now), `placement`, ' +
      '`language`, `from`/`to` (days created). Ordered by placement, sort order, newest. ' +
      'Paginated.',
  })
  list(@Query() query: BannerListQueryDto): Promise<PaginatedResult<BannerView>> {
    return this.banners.list(query);
  }

  @Get(':id')
  @RequirePermission('banners.read')
  @ApiOperation({ summary: 'Show a banner', description: 'Requires banners.read.' })
  get(@Param() params: BannerIdParamDto): Promise<BannerView> {
    return this.banners.get(params.id);
  }

  @Post()
  @RequirePermission('banners.manage')
  @ZodApiBody(CreateBannerDto)
  @ApiOperation({
    summary: 'Add a banner',
    description:
      'Requires banners.manage. The image is uploaded separately (or given as an https ' +
      '`externalImageUrl`). `startsAt`/`endsAt` are ISO date-times with a time zone, or null. ' +
      'Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateBannerDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.banners.create(actor, body, clientRequestInfo(request));
  }

  @Put(':id')
  @RequirePermission('banners.manage')
  @ZodApiBody(UpdateBannerDto)
  @ApiOperation({
    summary: 'Edit a banner',
    description:
      'Requires banners.manage. Only the fields sent change; the link and the dates are ' +
      'checked on the result. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Body() body: UpdateBannerDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.banners.update(actor, params.id, body, clientRequestInfo(request));
  }

  @Post(':id/active')
  @RequirePermission('banners.manage')
  @ZodApiBody(SetActiveDto)
  @ApiOperation({
    summary: 'Enable or disable a banner',
    description: 'Requires banners.manage. A disabled banner is never shown. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Body() body: SetActiveDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.banners.setActive(
      actor,
      params.id,
      body.active,
      clientRequestInfo(request),
      body.reason,
    );
  }

  @Post(':id/image')
  @RequirePermission('banners.manage')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: BANNER_IMAGE_MAX_BYTES, files: 1, fields: 2 },
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
    summary: 'Upload a banner image',
    description:
      'Requires banners.manage. `variant=mobile` (default, the main image) or `desktop` ' +
      '(optional wider image for tablets and desktops). Multipart field `file`: JPG, PNG or ' +
      'WebP (checked from the bytes), at most 3 MB. Replaces the previous image of that ' +
      'variant and its external image address. Audited.',
  })
  @ApiResponse({ status: 413, description: 'PAYLOAD_TOO_LARGE' })
  @ApiResponse({ status: 415, description: 'UNSUPPORTED_MEDIA_TYPE' })
  uploadImage(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Query() query: BannerImageVariantQueryDto,
    @UploadedFile() file: IncomingBannerImage | undefined,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.banners.uploadImage(
      actor,
      params.id,
      query.variant,
      file,
      clientRequestInfo(request),
    );
  }

  @Delete(':id/image')
  @RequirePermission('banners.manage')
  @ApiOperation({
    summary: 'Remove a banner image',
    description:
      'Requires banners.manage. Removes the stored image of `variant` (mobile by default, or ' +
      'desktop); an external image address is kept. Returns the banner. Audited.',
  })
  removeImage(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Query() query: BannerImageVariantQueryDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.banners.removeImage(actor, params.id, query.variant, clientRequestInfo(request));
  }
}

@ApiTags('discovery')
@PublicEndpoint()
@Controller('banners')
export class PublicBannersController {
  constructor(private readonly banners: AdminBannersService) {}

  @Get()
  @Header('Cache-Control', 'public, max-age=60')
  @ApiOperation({
    summary: 'Banners to show in the customer app',
    description:
      'Public. Live banners of `placement` (default HOME_TOP) for every language or the ' +
      'Accept-Language language, in display order, at most 10. `imageUrl` is an https ' +
      'address or a path relative to /api/v1/; `desktopImageUrl` (or null) is the wider image ' +
      'for tablets and desktops.',
  })
  @ApiResponse({
    status: 200,
    description:
      'Banners: id, title, subtitle, buttonText, linkType, linkValue, imageUrl, desktopImageUrl',
  })
  list(
    @Query() query: PublicBannerQueryDto,
    @Headers('accept-language') acceptLanguage?: string,
  ): Promise<PublicBannerView[]> {
    return this.banners.live(query.placement, preferredLanguage(acceptLanguage));
  }

  @Get(':id/image')
  @ApiOperation({
    summary: 'Banner image',
    description:
      'Public. The uploaded image of a banner: `variant=mobile` (default) or `desktop`. ' +
      'Cached for a day; the address changes with every upload.',
  })
  async image(
    @Param() params: BannerIdParamDto,
    @Query() query: PublicBannerImageQueryDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<StreamableFile> {
    const { content, mimeType } = await this.banners.openImage(params.id, query.variant);
    response.setHeader('Cache-Control', 'public, max-age=86400');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    // Shown by the customer and admin web apps, which run on other origins
    response.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    return new StreamableFile(content, { type: mimeType });
  }
}
