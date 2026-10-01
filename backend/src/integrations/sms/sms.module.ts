import { Module } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { DevelopmentSmsProvider } from './development-sms.provider';
import { SMS_PROVIDER, type SmsProvider } from './sms-provider.interface';

export function createSmsProvider(config: AppConfigService): SmsProvider {
  const selected = config.get('SMS_PROVIDER');
  switch (selected) {
    case 'development':
      if (config.isProduction) {
        throw new Error('The development SMS adapter cannot be used in production');
      }
      return new DevelopmentSmsProvider(config.get('NODE_ENV') === 'development');
    default:
      // Real providers are added here together with their SMS_PROVIDER value
      throw new Error(`No SMS provider is implemented for "${String(selected)}"`);
  }
}

@Module({
  providers: [{ provide: SMS_PROVIDER, inject: [AppConfigService], useFactory: createSmsProvider }],
  exports: [SMS_PROVIDER],
})
export class SmsModule {}
