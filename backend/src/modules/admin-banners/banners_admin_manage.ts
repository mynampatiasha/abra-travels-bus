import { Body, Controller, Param, Patch, Post, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { changeReason, objectIdString } from '../../common/pipes/list-query';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type BannerView, BannerIdParamDto } from './admin-banners.model';
import { type BannerOrderEntry, BannersManageService } from './banners_admin_manage.service';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { BannerListQueryDto } from './admin-banners.model';
import { AdminBannersService } from './admin-banners.service';

/** The Up / Down arrow of the banners list: one banner, one step. */
export class MoveBannerDto extends createZodDto(
  z.object({ id: objectIdString, direction: z.enum(['up', 'down']) }),
) {}

export class ArchiveBannerDto extends createZodDto(z.object({ reason: changeReason.optional() })) {}

/**
 * Banner actions of the admin banners page: duplicate, archive, un-archive and move up or down
 * (documentation/abra-master-plan.md, Appendix D.25).
 */
@ApiTags('banners')
@Controller('admin/banners')
export class BannersManageController {
  constructor(private readonly manage: BannersManageService) {}

  @Patch('order')
  @RequirePermission('banners.manage')
  @ZodApiBody(MoveBannerDto)
  @ApiOperation({
    summary: 'Move a banner up or down',
    description:
      'Requires banners.manage. Moves one banner one place earlier (`up`) or later (`down`) among ' +
      'the banners of its placement that are not archived, and answers with the new order. ' +
      'Moving the first one up or the last one down changes nothing. Audited.',
  })
  move(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: MoveBannerDto,
    @Req() request: Request,
  ): Promise<BannerOrderEntry[]> {
    return this.manage.move(actor, body.id, body.direction, clientRequestInfo(request));
  }

  @Post(':id/duplicate')
  @RequirePermission('banners.manage')
  @ApiOperation({
    summary: 'Duplicate a banner',
    description:
      'Requires banners.manage. A draft copy named "<title> (copy)", with its own copy of the ' +
      'images. It is not published. Audited.',
  })
  duplicate(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.manage.duplicate(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/archive')
  @RequirePermission('banners.manage')
  @ZodApiBody(ArchiveBannerDto)
  @ApiOperation({
    summary: 'Archive a banner',
    description:
      'Requires banners.manage. Unpublishes the banner and puts it away (status ARCHIVED). It ' +
      'can be brought back with un-archive. Audited.',
  })
  archive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Body() body: ArchiveBannerDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.manage.archive(actor, params.id, clientRequestInfo(request), body.reason);
  }

  @Post(':id/unarchive')
  @RequirePermission('banners.manage')
  @ApiOperation({
    summary: 'Bring an archived banner back',
    description: 'Requires banners.manage. The banner returns as a draft. Audited.',
  })
  unarchive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: BannerIdParamDto,
    @Req() request: Request,
  ): Promise<BannerView> {
    return this.manage.unarchive(actor, params.id, clientRequestInfo(request));
  }
}

/** The words of the demo for a banner status: a banner that is on is Published. */
function bannerStatusWord(status: string): string {
  if (status === 'LIVE') return 'Published';
  if (status === 'INACTIVE') return 'Draft';
  return readable(status);
}

/** The banners list as a file. */
export const BANNERS_EXPORT_KIND: ExportKind<BannerView> = {
  key: 'banners',
  columns: [
    { header: 'Banner', value: (banner) => banner.title },
    { header: 'Subtitle', value: (banner) => banner.subtitle },
    { header: 'Status', value: (banner) => bannerStatusWord(banner.status) },
    { header: 'Starts', value: (banner) => timeOf(banner.startsAt) },
    { header: 'Ends', value: (banner) => timeOf(banner.endsAt) },
    { header: 'Shown to', value: (banner) => readable(banner.audience) },
    { header: 'Opens', value: (banner) => readable(banner.linkType) },
    { header: 'Link value', value: (banner) => banner.linkValue },
    { header: 'Colour style', value: (banner) => readable(banner.colourStyle) },
    { header: 'Order', value: (banner) => banner.sortOrder },
    { header: 'Created', value: (banner) => timeOf(banner.createdAt) },
  ],
};

/** `GET admin/banners/export`. Register it before the module's other controllers. */
export const BannersExportController = exportController({
  base: 'admin/banners',
  permission: 'banners.export',
  kind: BANNERS_EXPORT_KIND,
  service: AdminBannersService,
  query: BannerListQueryDto,
  title: 'banners',
  load: (service, query) => service.list(query as never),
});
