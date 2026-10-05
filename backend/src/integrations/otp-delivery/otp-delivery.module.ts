import { Module } from '@nestjs/common';
import { SmsModule } from '../sms/sms.module';
import { WhatsAppModule } from '../whatsapp/whatsapp.module';
import { OtpDeliveryService } from './otp-delivery.service';
import { SmsOtpDeliveryProvider } from './sms-otp-delivery.provider';
import { WhatsAppOtpDeliveryProvider } from './whatsapp-otp-delivery.provider';

/** One-time code delivery over the configured channels (WhatsApp, SMS). */
@Module({
  imports: [SmsModule, WhatsAppModule],
  providers: [WhatsAppOtpDeliveryProvider, SmsOtpDeliveryProvider, OtpDeliveryService],
  exports: [OtpDeliveryService],
})
export class OtpDeliveryModule {}
