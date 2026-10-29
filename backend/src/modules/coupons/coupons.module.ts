import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { RbacModule } from '../rbac/rbac.module';
import { CouponsAdminController, CouponsCustomerController, OffersPublicController } from './coupons';
import { COUPON_MODEL, CouponsService, couponSchema } from './coupons.service';

/**
 * `coupons`: Inventory and booking domain (documentation/architecture.md section 5). Admin makes
 * coupons, a customer checks a code, and a booking reserves it. The offers pages for operators
 * and the website come later.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: COUPON_MODEL, schema: couponSchema }]), RbacModule],
  controllers: [CouponsCustomerController, CouponsAdminController, OffersPublicController],
  providers: [CouponsService],
  exports: [CouponsService],
})
export class CouponsModule {}
