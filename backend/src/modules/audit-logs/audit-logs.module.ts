import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditLogRepository } from './repositories/audit-log.repository';
import { AUDIT_LOG_MODEL, auditLogSchema } from './schemas/audit-log.schema';
import { AuditLogService } from './services/audit-log.service';

/**
 * `audit-logs` — the append-only audit trail (`audit_logs`). Modules record sensitive changes
 * through AuditLogService inside the transaction of the change. Reading the trail is the
 * audit page: AuditLogsAdminModule (audit_log_admin_manage.ts).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: AUDIT_LOG_MODEL, schema: auditLogSchema }])],
  providers: [AuditLogRepository, AuditLogService],
  exports: [AuditLogService],
})
export class AuditLogsModule {}
