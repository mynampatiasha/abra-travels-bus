import { Module } from '@nestjs/common';
import { WhatsAppModule } from '../../integrations/whatsapp/whatsapp.module';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { RbacModule } from '../rbac/rbac.module';
import { WhatsAppSettingsController } from './controllers/whatsapp-settings.controller';
import { WhatsAppSettingsAdminService } from './services/whatsapp-settings-admin.service';

/**
 * `system-settings` — Platform domain (documentation/architecture.md §5). So far: the WhatsApp
 * Business settings administrators manage (documentation/whatsapp-architecture.md). General
 * system settings are implemented in Phase 6 (documentation/implementation-plan.md).
 */
@Module({
  imports: [WhatsAppModule, AuditLogsModule, RbacModule],
  controllers: [WhatsAppSettingsController],
  providers: [WhatsAppSettingsAdminService],
})
export class SystemSettingsModule {}
