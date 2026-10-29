import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AppConfigService } from '../../config/app-config.service';
import { BookingsModule } from '../bookings/bookings.module';
import { InventoryModule } from '../inventory/inventory.module';
import { DevelopmentPaymentGateway, PAYMENT_GATEWAY, type PaymentGateway, RazorpayPaymentGateway } from './payment_gateway';
import { PaymentsCustomerController } from './payments_customer';
import { PAYMENT_MODEL, PaymentsCustomerService, paymentSchema } from './payments_customer.service';

/**
 * `payments`: Payments domain (documentation/payment-flow.md). A customer pays for a booking
 * through the gateway chosen by PAYMENT_GATEWAY (razorpay, or the labelled development gateway).
 * Refunds, reconciliation and the admin payments page come later.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: PAYMENT_MODEL, schema: paymentSchema }]), BookingsModule, InventoryModule],
  controllers: [PaymentsCustomerController],
  providers: [
    PaymentsCustomerService,
    {
      provide: PAYMENT_GATEWAY,
      inject: [AppConfigService],
      useFactory: (config: AppConfigService): PaymentGateway =>
        config.get('PAYMENT_GATEWAY') === 'razorpay'
          ? new RazorpayPaymentGateway(config.get('RAZORPAY_KEY_ID') ?? '', config.get('RAZORPAY_KEY_SECRET') ?? '')
          : new DevelopmentPaymentGateway(config.get('OTP_HASH_SECRET')),
    },
  ],
  exports: [PaymentsCustomerService],
})
export class PaymentsModule {}
