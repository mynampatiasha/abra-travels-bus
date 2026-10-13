import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { DocumentTypesModule } from '../document-types/document-types.module';
import {
  AdminKycConfigurationController,
  AdminKycConfigurationService,
  KYC_CONFIGURATION_MODEL,
  kycConfigurationMongoSchema,
} from './admin_kyc_configuration';
import { CryptoModule } from '../../common/crypto/crypto.module';
import { EmailModule } from '../../integrations/email/email.module';
import { WhatsAppModule } from '../../integrations/whatsapp/whatsapp.module';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { RbacModule } from '../rbac/rbac.module';
import { IntegrationsAdminManageController } from './integrations_admin_manage';
import {
  INTEGRATION_SETTINGS_MODEL,
  IntegrationSettingsStore,
  IntegrationsAdminManageService,
  integrationSettingsSchema,
} from './integrations_admin_manage.service';
import { EmailSettingsController } from './controllers/email-settings.controller';
import { WhatsAppSettingsController } from './controllers/whatsapp-settings.controller';
import { EmailSettingsAdminService } from './services/email-settings-admin.service';
import { WhatsAppSettingsAdminService } from './services/whatsapp-settings-admin.service';

/**
 * `system-settings` — Platform domain (documentation/architecture.md §5). So far: the WhatsApp
 * Business and email (SMTP) settings administrators manage, each with a connection test
 * (documentation/whatsapp-architecture.md). General system settings are implemented in Phase 6
 * (documentation/implementation-plan.md).
 */
@Module({
  imports: [
    WhatsAppModule,
    EmailModule,
    AuditLogsModule,
    RbacModule,
    DocumentTypesModule,
    CryptoModule,
    MongooseModule.forFeature([
      { name: KYC_CONFIGURATION_MODEL, schema: kycConfigurationMongoSchema },
      { name: INTEGRATION_SETTINGS_MODEL, schema: integrationSettingsSchema },
    ]),
  ],
  controllers: [
    WhatsAppSettingsController,
    EmailSettingsController,
    AdminKycConfigurationController,
    // Last: its `:key` routes must never come before the fixed whatsapp and email paths
    IntegrationsAdminManageController,
  ],
  providers: [
    WhatsAppSettingsAdminService,
    EmailSettingsAdminService,
    AdminKycConfigurationService,
    IntegrationSettingsStore,
    IntegrationsAdminManageService,
  ],
  exports: [IntegrationSettingsStore],
})
export class SystemSettingsModule {}
