import { Inject, Injectable } from '@nestjs/common';
import { WHATSAPP_PROVIDER, type WhatsAppProvider } from '../whatsapp/whatsapp-provider.interface';
import { WhatsAppSettingsStore } from '../whatsapp/whatsapp-settings.store';
import {
  type OtpDeliveryProvider,
  type OtpDeliveryRequest,
} from './otp-delivery-provider.interface';

/** Name the development adapter records when no real template is configured. */
const DEVELOPMENT_TEMPLATE_NAME = 'development_otp';

/**
 * One-time codes on WhatsApp, through an approved authentication template (set by an
 * administrator, or WHATSAPP_OTP_TEMPLATE_NAME / _LANGUAGE): the code fills the body placeholder and the "copy
 * code" button. Template text is owned by the WhatsApp Business account, not by this code.
 */
@Injectable()
export class WhatsAppOtpDeliveryProvider implements OtpDeliveryProvider {
  readonly channel = 'WHATSAPP';

  constructor(
    @Inject(WHATSAPP_PROVIDER) private readonly whatsApp: WhatsAppProvider,
    @Inject(WhatsAppSettingsStore)
    private readonly settings: Pick<WhatsAppSettingsStore, 'effective'>,
  ) {}

  get providerKey(): string {
    return this.whatsApp.providerKey;
  }

  async deliver(request: OtpDeliveryRequest): Promise<void> {
    const settings = await this.settings.effective();
    await this.whatsApp.sendTemplate({
      to: request.to,
      // Configuration validation requires both for the real (meta) provider
      templateName: settings.otpTemplateName ?? DEVELOPMENT_TEMPLATE_NAME,
      languageCode: settings.otpTemplateLanguage ?? 'en',
      bodyParameters: [request.code],
      urlButtonParameter: request.code,
      purpose: 'OTP',
    });
  }
}
