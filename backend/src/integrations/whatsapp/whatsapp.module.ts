import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AppConfigService } from '../../config/app-config.service';
import { DevelopmentWhatsAppProvider } from './development-whatsapp.provider';
import { MetaCloudWhatsAppProvider } from './meta-cloud-whatsapp.provider';
import {
  WHATSAPP_PROVIDER,
  WhatsAppDeliveryError,
  type WhatsAppProvider,
} from './whatsapp-provider.interface';
import { WHATSAPP_SETTINGS_MODEL, whatsAppSettingsSchema } from './whatsapp-settings.schema';
import { WhatsAppSettingsStore } from './whatsapp-settings.store';

export function createWhatsAppProvider(
  config: AppConfigService,
  settings: Pick<WhatsAppSettingsStore, 'effective'>,
): WhatsAppProvider {
  const selected = config.get('WHATSAPP_PROVIDER');
  switch (selected) {
    case 'meta':
      // Resolved for every message, so a credential changed by an administrator applies
      // without a restart. Environment values are the fallback (validated at start-up).
      return new MetaCloudWhatsAppProvider(async () => {
        const { accessToken, phoneNumberId, apiVersion } = await settings.effective();
        if (!accessToken || !phoneNumberId || !apiVersion) {
          throw new WhatsAppDeliveryError('WhatsApp is not fully configured');
        }
        return { accessToken, phoneNumberId, apiVersion };
      });
    case 'development':
      if (config.isProduction) {
        throw new Error('The development WhatsApp adapter cannot be used in production');
      }
      return new DevelopmentWhatsAppProvider(config.get('NODE_ENV') === 'development');
    default:
      throw new Error(`No WhatsApp provider is implemented for "${String(selected)}"`);
  }
}

@Module({
  imports: [
    MongooseModule.forFeature([{ name: WHATSAPP_SETTINGS_MODEL, schema: whatsAppSettingsSchema }]),
  ],
  providers: [
    WhatsAppSettingsStore,
    {
      provide: WHATSAPP_PROVIDER,
      inject: [AppConfigService, WhatsAppSettingsStore],
      useFactory: createWhatsAppProvider,
    },
  ],
  exports: [WHATSAPP_PROVIDER, WhatsAppSettingsStore],
})
export class WhatsAppModule {}
