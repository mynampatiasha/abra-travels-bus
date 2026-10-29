import { Body, Controller, Get, HttpCode, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Types } from 'mongoose';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { ApiException } from '../../common/errors/api-exception';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { type CouponCheck, type CouponView, CouponsService } from './coupons.service';

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
  create(@Body() body: CreateCouponDto): Promise<CouponView> {
    return this.coupons.create(body);
  }

  @Patch(':id/status')
  @RequirePermission('offers.manage')
  @ApiOperation({ summary: 'Pause or resume a coupon', description: 'Requires offers.manage. Body: { "status": "ACTIVE" | "PAUSED" }.' })
  setStatus(@Param('id') id: string, @Body() body: { status?: string }): Promise<CouponView> {
    if (body.status !== 'ACTIVE' && body.status !== 'PAUSED') {
      throw new ApiException('VALIDATION_FAILED', 'status is ACTIVE or PAUSED.');
    }
    return this.coupons.setStatus(id, body.status);
  }
}
