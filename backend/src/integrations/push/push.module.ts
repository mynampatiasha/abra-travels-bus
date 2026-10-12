import { Module } from '@nestjs/common';
import { AppConfigService } from '../../config/app-config.service';
import { DevelopmentPushProvider } from './development-push.provider';
import { FcmPushProvider } from './fcm-push.provider';
import { PUSH_PROVIDER, type PushProvider } from './push-provider.interface';

export function createPushProvider(config: AppConfigService): PushProvider {
  switch (config.get('PUSH_PROVIDER')) {
    case 'fcm':
      // The environment rules guarantee the credentials are set when the provider is fcm
      return new FcmPushProvider(config.get('FCM_SERVICE_ACCOUNT_JSON') ?? '');
    case 'development':
      if (config.isProduction) {
        throw new Error('The development push adapter cannot be used in production');
      }
      return new DevelopmentPushProvider();
    default:
      throw new Error('No push provider is implemented for this setting');
  }
}

@Module({
  providers: [
    { provide: PUSH_PROVIDER, inject: [AppConfigService], useFactory: createPushProvider },
  ],
  exports: [PUSH_PROVIDER],
})
export class PushModule {}
