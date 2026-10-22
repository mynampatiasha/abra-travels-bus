/**
 * Payout and fees: schemas, request rules, controller, module.
 * Collections: payout_settings (one record), refund_slabs.
 */
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Module,
  Param,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { MongooseModule, Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { type Document } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind } from '../catalogue-shared/catalogue_export_manage.service';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { PayoutCfgService, type RefundSlabView } from './payout_cfg_admin_manage.service';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

export enum PayoutMode {
  AUTO_SPLIT = 'AUTO_SPLIT',
  MANUAL = 'MANUAL',
}
export enum CouponFunding {
  PLATFORM = 'PLATFORM',
  OPERATOR = 'OPERATOR',
  SPLIT = 'SPLIT',
}

/** ONE record for the platform (key = 'platform'). Money fields are paise. */
@Schema({ collection: 'payout_settings', timestamps: false })
export class PayoutSettings {
  @Prop({ required: true, unique: true, default: 'platform' })
  key!: string;

  @Prop({ required: true, enum: PayoutMode, default: PayoutMode.MANUAL })
  defaultMode!: PayoutMode;

  @Prop({ required: true, min: 1, default: 7 })
  cycleDays!: number;

  @Prop({ required: true, min: 0, default: 0 })
  minPayout!: number; // paise

  @Prop({ required: true, min: 0, default: 0 })
  holdDays!: number;

  @Prop({ required: true, default: false })
  razorpayRoute!: boolean;

  @Prop({ required: true, min: 0, max: 28, default: 0 })
  gstPct!: number;

  @Prop({ required: true, min: 0, default: 0 })
  convenienceFee!: number; // paise

  @Prop({ required: true, enum: CouponFunding, default: CouponFunding.PLATFORM })
  couponFunding!: CouponFunding;

  // The default commission is stored with this record but belongs to the
  // Commission feature (another session). Not built here; strict mode keeps it untouched.

  @Prop()
  updatedBy?: string;

  @Prop()
  updatedAt?: Date;
}
export type PayoutSettingsDocument = PayoutSettings & Document;
export const PayoutSettingsSchema = SchemaFactory.createForClass(PayoutSettings);

@Schema({ collection: 'refund_slabs', timestamps: true })
export class RefundSlab {
  @Prop({ required: true, min: 0 })
  hoursBefore!: number;

  @Prop({ required: true, min: 0, max: 100 })
  refundPct!: number;

  @Prop({ type: Date, default: null })
  deletedAt!: Date | null;
}
export type RefundSlabDocument = RefundSlab & Document;
export const RefundSlabSchema = SchemaFactory.createForClass(RefundSlab);
// Unique among slabs that are not removed (a removed slab can be replaced).
RefundSlabSchema.index(
  { hoursBefore: 1 },
  { unique: true, partialFilterExpression: { deletedAt: { $type: 'null' } } },
);

// ---------------------------------------------------------------------------
// Request rules
// ---------------------------------------------------------------------------

export class UpdatePayoutSettingsDto extends createZodDto(
  z
    .object({
      defaultMode: z.nativeEnum(PayoutMode),
      cycleDays: z.number().int().min(1),
      minPayout: z.number().int().min(0), // paise
      holdDays: z.number().int().min(0),
      razorpayRoute: z.boolean(),
      // up to two decimals, for example 5.5
      gstPct: z
        .number()
        .min(0)
        .max(28)
        .refine(
          (value) => Math.abs(value * 100 - Math.round(value * 100)) < 1e-9,
          'at most two decimals',
        ),
      convenienceFee: z.number().int().min(0), // paise
      couponFunding: z.nativeEnum(CouponFunding),
    })
    .strict(),
) {}

export class CreateRefundSlabDto extends createZodDto(
  z
    .object({
      hoursBefore: z.number().int().min(0),
      refundPct: z.number().int().min(0).max(100),
    })
    .strict(),
) {}

export class RefundSlabListQueryDto extends createZodDto(
  z.object({
    includeDeleted: z
      .enum(['true', 'false'])
      .transform((value) => value === 'true')
      .optional(),
    ...pagingShape,
  }),
) {}

export class RefundSlabIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

// ---------------------------------------------------------------------------
// Export (the shared server export: csv and xlsx, audited)
// ---------------------------------------------------------------------------

export const REFUND_SLABS_EXPORT_KIND: ExportKind<RefundSlabView> = {
  key: 'refund_slabs',
  columns: [
    { header: 'Cancel at least (hours before)', value: (slab) => slab.hoursBefore },
    { header: 'Refund percent', value: (slab) => slab.refundPct },
  ],
};

/** `GET admin/payout/refund-slabs/export`. Registered before the controller below. */
export const RefundSlabsExportController = exportController({
  base: 'admin/payout/refund-slabs',
  permission: 'payout.export',
  kind: REFUND_SLABS_EXPORT_KIND,
  service: PayoutCfgService,
  query: RefundSlabListQueryDto,
  title: 'refund slabs',
  load: (service, query) => service.listSlabPage(query as never),
});

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

@ApiTags('payout')
@Controller('admin/payout')
export class PayoutCfgAdminController {
  constructor(private readonly svc: PayoutCfgService) {}

  // payout.read; read only. null = nothing saved yet (no invented defaults)
  @Get('settings')
  @RequirePermission('payout.read')
  @ApiOperation({ summary: 'Payout and fee settings', description: 'Requires payout.read.' })
  async getSettings() {
    return { settings: await this.svc.getSettings() };
  }

  // payout.manage; audit payout.settings-changed (sensitive)
  @Put('settings')
  @RequirePermission('payout.manage')
  @ZodApiBody(UpdatePayoutSettingsDto)
  @ApiOperation({
    summary: 'Save payout and fee settings',
    description:
      'Requires payout.manage. Applies to new bookings and settlements. Razorpay Route cannot ' +
      'be switched off while operators are on Automatic payout. Audited.',
  })
  updateSettings(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() dto: UpdatePayoutSettingsDto,
    @Req() req: Request,
  ) {
    return this.svc.updateSettings(dto, actor, clientRequestInfo(req));
  }

  // payout.read; read only
  @Get('refund-slabs')
  @RequirePermission('payout.read')
  @ApiOperation({ summary: 'Cancellation refund slabs', description: 'Requires payout.read.' })
  listSlabs(@Query() query: RefundSlabListQueryDto) {
    return this.svc.listSlabs(query.includeDeleted ?? false);
  }

  // payout.manage; audit payout.slab-added (sensitive)
  @Post('refund-slabs')
  @RequirePermission('payout.manage')
  @ZodApiBody(CreateRefundSlabDto)
  @ApiOperation({ summary: 'Add a refund slab', description: 'Requires payout.manage. Audited.' })
  createSlab(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() dto: CreateRefundSlabDto,
    @Req() req: Request,
  ) {
    return this.svc.createSlab(dto, actor, clientRequestInfo(req));
  }

  // payout.read; read only
  @Get('refund-slabs/:id')
  @RequirePermission('payout.read')
  @ApiOperation({ summary: 'One refund slab', description: 'Requires payout.read.' })
  getSlab(@Param() params: RefundSlabIdParamDto) {
    return this.svc.getSlab(params.id);
  }

  // payout.delete; audit payout.slab-removed (sensitive); Undo is restore
  @Delete('refund-slabs/:id')
  @RequirePermission('payout.delete')
  @ApiOperation({
    summary: 'Remove a refund slab',
    description: 'Requires payout.delete. Audited.',
  })
  removeSlab(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RefundSlabIdParamDto,
    @Req() req: Request,
  ) {
    return this.svc.removeSlab(params.id, actor, clientRequestInfo(req));
  }

  // payout.delete; audit payout.slab-restored (sensitive)
  @Post('refund-slabs/:id/restore')
  @HttpCode(200)
  @RequirePermission('payout.delete')
  @ApiOperation({
    summary: 'Undo the removal of a refund slab',
    description: 'Requires payout.delete. Audited.',
  })
  restoreSlab(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RefundSlabIdParamDto,
    @Req() req: Request,
  ) {
    return this.svc.restoreSlab(params.id, actor, clientRequestInfo(req));
  }
}

// ---------------------------------------------------------------------------
// Module (the operator payout mode and bank verification stay in modules/operators)
// ---------------------------------------------------------------------------

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: PayoutSettings.name, schema: PayoutSettingsSchema },
      { name: RefundSlab.name, schema: RefundSlabSchema },
    ]),
    RbacModule,
    CatalogueSharedModule,
  ],
  controllers: [RefundSlabsExportController, PayoutCfgAdminController],
  providers: [PayoutCfgService],
  exports: [PayoutCfgService],
})
export class PayoutCfgModule {}
