import { Module } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { DevelopmentWhatsAppProvider } from './development-whatsapp.provider';
import { MetaCloudWhatsAppProvider } from './meta-cloud-whatsapp.provider';
import { WHATSAPP_PROVIDER, type WhatsAppProvider } from './whatsapp-provider.interface';

function required(config: AppConfigService, key: Parameters<AppConfigService['get']>[0]): string {
  const value = config.get(key);
  // Configuration validation already requires these for WHATSAPP_PROVIDER=meta
  if (typeof value !== 'string' || value.length === 0) throw new Error(`${key} is not configured`);
  return value;
}

export function createWhatsAppProvider(config: AppConfigService): WhatsAppProvider {
  const selected = config.get('WHATSAPP_PROVIDER');
  switch (selected) {
    case 'meta':
      return new MetaCloudWhatsAppProvider({
        accessToken: required(config, 'WHATSAPP_ACCESS_TOKEN'),
        phoneNumberId: required(config, 'WHATSAPP_PHONE_NUMBER_ID'),
        apiVersion: required(config, 'WHATSAPP_GRAPH_API_VERSION'),
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
  providers: [
    { provide: WHATSAPP_PROVIDER, inject: [AppConfigService], useFactory: createWhatsAppProvider },
  ],
  exports: [WHATSAPP_PROVIDER],
})
export class WhatsAppModule {}
