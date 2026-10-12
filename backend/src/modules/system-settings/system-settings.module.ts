import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { DocumentTypesModule } from '../document-types/document-types.module';
import {
  AdminKycConfigurationController,
  AdminKycConfigurationService,
  KYC_CONFIGURATION_MODEL,
  kycConfigurationMongoSchema,
} from './admin_kyc_configuration';
import { EmailModule } from '../../integrations/email/email.module';
import { WhatsAppModule } from '../../integrations/whatsapp/whatsapp.module';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { RbacModule } from '../rbac/rbac.module';
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
    MongooseModule.forFeature([
      { name: KYC_CONFIGURATION_MODEL, schema: kycConfigurationMongoSchema },
    ]),
  ],
  controllers: [
    WhatsAppSettingsController,
    EmailSettingsController,
    AdminKycConfigurationController,
  ],
  providers: [
    WhatsAppSettingsAdminService,
    EmailSettingsAdminService,
    AdminKycConfigurationService,
  ],
})
export class SystemSettingsModule {}
