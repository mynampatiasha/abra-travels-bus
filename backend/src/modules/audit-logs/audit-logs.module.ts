import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditLogController } from './controllers/audit-log.controller';
import { AuditLogRepository } from './repositories/audit-log.repository';
import { AUDIT_LOG_MODEL, auditLogSchema } from './schemas/audit-log.schema';
import { AuditLogService } from './services/audit-log.service';

/**
 * `audit-logs` — the append-only audit trail (`audit_logs`). Modules record sensitive changes
 * through AuditLogService inside the transaction of the change; entries are read through the
 * caller's data scope.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: AUDIT_LOG_MODEL, schema: auditLogSchema }])],
  controllers: [AuditLogController],
  providers: [AuditLogRepository, AuditLogService],
  exports: [AuditLogService],
})
export class AuditLogsModule {}
