import { Inject, Injectable } from '@nestjs/common';
import { SMS_PROVIDER, type SmsProvider } from '../sms/sms-provider.interface';
import {
  type OtpDeliveryProvider,
  type OtpDeliveryRequest,
} from './otp-delivery-provider.interface';

/** One-time codes by SMS. Real providers map `purpose: 'OTP'` to their registered (DLT) template. */
@Injectable()
export class SmsOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly channel = 'SMS';

  constructor(@Inject(SMS_PROVIDER) private readonly sms: SmsProvider) {}

  get providerKey(): string {
    return this.sms.providerKey;
  }

  deliver(request: OtpDeliveryRequest): Promise<void> {
    const minutes = Math.max(1, Math.round(request.expiresInSeconds / 60));
    return this.sms.send({
      to: request.to,
      purpose: 'OTP',
      body:
        `${request.code} is your Abra Travels verification code. It expires in ${minutes} ` +
        'minutes. Do not share it with anyone.',
    });
  }
}
