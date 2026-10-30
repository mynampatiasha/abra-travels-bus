import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AppConfigService } from '../../config/app-config.service';
import { BookingsModule } from '../bookings/bookings.module';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { InventoryModule } from '../inventory/inventory.module';
import { RbacModule } from '../rbac/rbac.module';
import { PaymentsAdminController, PaymentsExportController } from './payments_admin_manage';
import { PaymentsAdminService } from './payments_admin_manage.service';
import { DevelopmentPaymentGateway, PAYMENT_GATEWAY, type PaymentGateway, RazorpayPaymentGateway } from './payment_gateway';
import { PaymentsCustomerController } from './payments_customer';
import { PaymentsWebhookController } from './payments_webhook';
import {
  PAYMENT_EVENT_MODEL,
  PAYMENT_MODEL,
  PaymentsCustomerService,
  paymentEventSchema,
  paymentSchema,
} from './payments_customer.service';

/**
 * `payments`: Payments domain (documentation/payment-flow.md). A customer pays for a booking
 * through the gateway chosen by PAYMENT_GATEWAY (razorpay, or the labelled development gateway).
 * Refunds, reconciliation and the admin payments page come later.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: PAYMENT_MODEL, schema: paymentSchema },
      { name: PAYMENT_EVENT_MODEL, schema: paymentEventSchema },
    ]),
    BookingsModule,
    InventoryModule,
    RbacModule,
    CatalogueSharedModule,
  ],
  controllers: [PaymentsExportController, PaymentsAdminController, PaymentsCustomerController, PaymentsWebhookController],
  providers: [
    PaymentsCustomerService,
    PaymentsAdminService,
    {
      provide: PAYMENT_GATEWAY,
      inject: [AppConfigService],
      useFactory: (config: AppConfigService): PaymentGateway =>
        config.get('PAYMENT_GATEWAY') === 'razorpay'
          ? new RazorpayPaymentGateway(
              config.get('RAZORPAY_KEY_ID') ?? '',
              config.get('RAZORPAY_KEY_SECRET') ?? '',
              config.get('RAZORPAY_WEBHOOK_SECRET') ?? '',
            )
          : new DevelopmentPaymentGateway(config.get('OTP_HASH_SECRET')),
    },
  ],
  exports: [PaymentsCustomerService],
})
export class PaymentsModule {}
