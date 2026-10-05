import { Inject, Injectable } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { WHATSAPP_PROVIDER, type WhatsAppProvider } from '../whatsapp/whatsapp-provider.interface';
import {
  type OtpDeliveryProvider,
  type OtpDeliveryRequest,
} from './otp-delivery-provider.interface';

/** Name the development adapter records when no real template is configured. */
const DEVELOPMENT_TEMPLATE_NAME = 'development_otp';

/**
 * One-time codes on WhatsApp, through an approved authentication template
 * (WHATSAPP_OTP_TEMPLATE_NAME / _LANGUAGE): the code fills the body placeholder and the "copy
 * code" button. Template text is owned by the WhatsApp Business account, not by this code.
 */
@Injectable()
export class WhatsAppOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly channel = 'WHATSAPP';

  constructor(
    @Inject(WHATSAPP_PROVIDER) private readonly whatsApp: WhatsAppProvider,
    private readonly config: AppConfigService,
  ) {}

  get providerKey(): string {
    return this.whatsApp.providerKey;
  }

  deliver(request: OtpDeliveryRequest): Promise<void> {
    return this.whatsApp.sendTemplate({
      to: request.to,
      // Configuration validation requires both for the real (meta) provider
      templateName: this.config.get('WHATSAPP_OTP_TEMPLATE_NAME') ?? DEVELOPMENT_TEMPLATE_NAME,
      languageCode: this.config.get('WHATSAPP_OTP_TEMPLATE_LANGUAGE') ?? 'en',
      bodyParameters: [request.code],
      urlButtonParameter: request.code,
      purpose: 'OTP',
    });
  }
}
