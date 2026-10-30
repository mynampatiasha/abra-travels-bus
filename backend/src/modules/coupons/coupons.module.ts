import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { RbacModule } from '../rbac/rbac.module';
import { CouponsAdminController, CouponsCustomerController, CouponsExportController, OffersPublicController } from './coupons';
import { COUPON_MODEL, CouponsService, couponSchema } from './coupons.service';

/**
 * `coupons`: Inventory and booking domain (documentation/architecture.md section 5). Admin makes
 * coupons, a customer checks a code, and a booking reserves it. The offers pages for operators
 * and the website come later.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: COUPON_MODEL, schema: couponSchema }]), RbacModule, CatalogueSharedModule],
  controllers: [CouponsExportController, CouponsCustomerController, CouponsAdminController, OffersPublicController],
  providers: [CouponsService],
  exports: [CouponsService],
})
export class CouponsModule {}
