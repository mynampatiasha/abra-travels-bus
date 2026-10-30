import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { Types } from 'mongoose';
import { z } from 'zod';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { pagingShape } from '../../common/pipes/list-query';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { ApiException } from '../../common/errors/api-exception';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind, readable } from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type CouponCheck, type CouponUsage, type CouponView, CouponsService, type PublicOfferView } from './coupons.service';

class ValidateCouponDto extends createZodDto(
  z.object({
    tripId: z.string().trim().min(1).max(40),
    code: z.string().trim().min(1).max(40),
    basePaise: z.number().int().min(0),
  }),
) {}

class CreateCouponDto extends createZodDto(
  z.object({
    code: z.string().trim().min(3).max(20),
    title: z.string().trim().min(2).max(80),
    description: z.string().trim().max(300).optional(),
    discountType: z.enum(['PERCENT', 'FLAT']),
    value: z.number().int().min(1).max(1_000_000_000),
    maxDiscountPaise: z.number().int().min(1).optional(),
    minBookingPaise: z.number().int().min(0).default(0),
    usageLimit: z.number().int().min(0).default(0),
    perCustomerLimit: z.number().int().min(1).max(100).default(1),
    fundedBy: z.enum(['ABRA', 'OPERATOR']).default('ABRA'),
    operatorIds: z.array(z.string()).max(50).optional(),
    newUsersOnly: z.boolean().default(false),
    startsAt: z.coerce.date(),
    endsAt: z.coerce.date(),
  }),
) {}

class UpdateCouponDto extends createZodDto(
  z.object({
    title: z.string().trim().min(2).max(80).optional(),
    description: z.string().trim().max(300).optional(),
    value: z.number().int().min(1).max(1_000_000_000).optional(),
    maxDiscountPaise: z.number().int().min(1).optional(),
    minBookingPaise: z.number().int().min(0).optional(),
    usageLimit: z.number().int().min(0).optional(),
    perCustomerLimit: z.number().int().min(1).max(100).optional(),
    fundedBy: z.enum(['ABRA', 'OPERATOR']).optional(),
    newUsersOnly: z.boolean().optional(),
    startsAt: z.coerce.date().optional(),
    endsAt: z.coerce.date().optional(),
  }),
) {}

export class CouponListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    status: z.enum(['ACTIVE', 'PAUSED']).optional(),
    funder: z.enum(['ABRA', 'OPERATOR']).optional(),
    ...pagingShape,
  }),
) {}

const rupees = (paise: number | null) => (paise === null ? '' : paise / 100);

/** The columns of the table, in the file. */
export const COUPON_EXPORT_KIND: ExportKind<CouponView> = {
  key: 'coupons',
  columns: [
    { header: 'Code', value: (row) => row.code },
    { header: 'Title', value: (row) => row.title },
    { header: 'Discount', value: (row) => (row.discountType === 'PERCENT' ? `${row.value}%` : rupees(row.value)) },
    { header: 'Highest discount (Rs)', value: (row) => rupees(row.maxDiscountPaise) },
    { header: 'Lowest booking (Rs)', value: (row) => rupees(row.minBookingPaise) },
    { header: 'Uses', value: (row) => row.usedCount },
    { header: 'Limit', value: (row) => (row.usageLimit === 0 ? 'No limit' : row.usageLimit) },
    { header: 'Per customer', value: (row) => row.perCustomerLimit },
    { header: 'Paid by', value: (row) => (row.fundedBy === 'OPERATOR' ? 'Operator' : 'Platform') },
    { header: 'First booking only', value: (row) => (row.newUsersOnly ? 'Yes' : 'No') },
    { header: 'Starts', value: (row) => new Date(row.startsAt) },
    { header: 'Ends', value: (row) => new Date(row.endsAt) },
    { header: 'Status', value: (row) => readable(row.status) },
  ],
};

/** Registered first: the main controller has `PATCH :id`, which would take "export" for an id. */
export const CouponsExportController = exportController({
  base: 'admin/coupons',
  permission: 'offers.export',
  kind: COUPON_EXPORT_KIND,
  service: CouponsService,
  query: CouponListQueryDto,
  title: 'the coupons',
  load: (service, query) => service.rows(query as never),
});

/** Customer: check a code, and see the codes on offer. */
@ApiTags('coupons')
@AuthenticatedOnly()
@Controller('coupons')
export class CouponsCustomerController {
  constructor(private readonly coupons: CouponsService) {}

  @Post('validate')
  @HttpCode(200)
  @ZodApiBody(ValidateCouponDto)
  @ApiOperation({
    summary: 'Check a coupon code',
    description:
      'Customer. Answers valid or not, with the discount in paise or the reason in words. A code ' +
      'that does not apply is a normal answer (valid false), not an error.',
  })
  validate(@CurrentActor() actor: AuthenticatedUserActor, @Body() body: ValidateCouponDto): Promise<CouponCheck> {
    return this.coupons.check(new Types.ObjectId(actor.userId), body.tripId, body.code, body.basePaise);
  }

  @Get()
  @ApiOperation({ summary: 'Codes on offer', description: 'Customer. Active codes that are in date and not used up.' })
  list(@Query('tripId') _tripId?: string): Promise<CouponView[]> {
    return this.coupons.suggestions();
  }
}

/** Offers for everyone, signed in or not. */
@ApiTags('coupons')
@PublicEndpoint()
@Controller('offers')
export class OffersPublicController {
  constructor(private readonly coupons: CouponsService) {}

  @Get()
  @ApiOperation({
    summary: 'Offers you can use',
    description: 'Public. Active offers that are in date and not used up, with what they give and their conditions.',
  })
  list(): Promise<PublicOfferView[]> {
    return this.coupons.publicOffers();
  }
}

/** Admin: the coupons of the platform. */
@ApiTags('coupons')
@Controller('admin/coupons')
export class CouponsAdminController {
  constructor(private readonly coupons: CouponsService) {}

  @Get()
  @RequirePermission('offers.read')
  @ApiOperation({ summary: 'All coupons', description: 'Requires offers.read.' })
  list(): Promise<CouponView[]> {
    return this.coupons.list();
  }

  @Post()
  @RequirePermission('offers.manage')
  @ZodApiBody(CreateCouponDto)
  @ApiOperation({ summary: 'New coupon', description: 'Requires offers.manage. A code is used once (ALREADY_REGISTERED).' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Req() request: Request,
    @Body() body: CreateCouponDto,
  ): Promise<CouponView> {
    return this.coupons.create(actor, clientRequestInfo(request), body);
  }

  @Patch(':id')
  @RequirePermission('offers.manage')
  @ZodApiBody(UpdateCouponDto)
  @ApiOperation({
    summary: 'Change a coupon',
    description:
      'Requires offers.manage. Title, limits, dates and who pays can change. The code and the kind of discount never ' +
      'change, and the amount only before the first use (RESOURCE_IN_USE). The total limit cannot go below the uses so far. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Req() request: Request,
    @Param('id') id: string,
    @Body() body: UpdateCouponDto,
  ): Promise<CouponView> {
    return this.coupons.update(actor, clientRequestInfo(request), id, body);
  }

  @Delete(':id')
  @HttpCode(200)
  @RequirePermission('offers.delete')
  @ApiOperation({
    summary: 'Delete a coupon',
    description: 'Requires offers.delete. Only a coupon nobody has used (RESOURCE_IN_USE otherwise: pause it). Audited.',
  })
  remove(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Req() request: Request,
    @Param('id') id: string,
  ): Promise<{ deleted: true }> {
    return this.coupons.remove(actor, clientRequestInfo(request), id);
  }

  @Get(':id/usage')
  @RequirePermission('offers.read')
  @ApiOperation({
    summary: 'Who used a coupon',
    description: 'Requires offers.read. Each booking that used it, the customer, what it took off and where that use stands.',
  })
  usage(@Param('id') id: string): Promise<CouponUsage> {
    return this.coupons.usage(id);
  }

  @Patch(':id/status')
  @RequirePermission('offers.manage')
  @ApiOperation({ summary: 'Pause or resume a coupon', description: 'Requires offers.manage. Body: { "status": "ACTIVE" | "PAUSED" }.' })
  setStatus(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Req() request: Request,
    @Param('id') id: string,
    @Body() body: { status?: string },
  ): Promise<CouponView> {
    if (body.status !== 'ACTIVE' && body.status !== 'PAUSED') {
      throw new ApiException('VALIDATION_FAILED', 'status is ACTIVE or PAUSED.');
    }
    return this.coupons.setStatus(actor, clientRequestInfo(request), id, body.status);
  }
}
