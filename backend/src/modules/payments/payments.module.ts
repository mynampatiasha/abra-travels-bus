import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { BookingsModule } from '../bookings/bookings.module';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { InventoryModule } from '../inventory/inventory.module';
import { RbacModule } from '../rbac/rbac.module';
import { SystemSettingsModule } from '../system-settings/system-settings.module';
import { PaymentsAdminController, PaymentsExportController } from './payments_admin_manage';
import { PaymentsAdminService } from './payments_admin_manage.service';
import { PaymentGatewayProvider } from './payment_gateway';
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
 * through the gateway chosen by PAYMENT_GATEWAY (razorpay, or the labelled development gateway); the
 * Razorpay keys come from Settings, Integrations in the admin app, then the environment.
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
    SystemSettingsModule,
  ],
  controllers: [PaymentsExportController, PaymentsAdminController, PaymentsCustomerController, PaymentsWebhookController],
  providers: [
    PaymentsCustomerService,
    PaymentsAdminService,
    PaymentGatewayProvider,
  ],
  exports: [PaymentsCustomerService],
})
export class PaymentsModule {}
