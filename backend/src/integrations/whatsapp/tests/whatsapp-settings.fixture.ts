import { type AppConfigService } from '../../../config/app-config.service';
import { type WhatsAppSettings } from '../whatsapp-settings.schema';
import {
  type EffectiveWhatsAppSettings,
  resolveWhatsAppSettings,
} from '../whatsapp-settings.store';

/**
 * WhatsApp settings for unit tests: the environment configuration, with `admin` laid over it the
 * way stored administrator settings are (tokens are given in plain form here).
 */
export function whatsAppSettingsOf(
  config: AppConfigService,
  admin: Partial<WhatsAppSettings> = {},
): { effective: () => Promise<EffectiveWhatsAppSettings> } {
  return {
    effective: () =>
      Promise.resolve(
        resolveWhatsAppSettings({ key: 'default', ...admin }, config, (value) => value),
      ),
  };
}
