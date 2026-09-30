import { Global, Module } from '@nestjs/common';
import { AppConfigService } from './app-config.service';
import { loadEnvironment } from './environment-loader';

@Global()
@Module({
  providers: [
    { provide: AppConfigService, useFactory: () => new AppConfigService(loadEnvironment()) },
  ],
  exports: [AppConfigService],
})
export class AppConfigModule {}
