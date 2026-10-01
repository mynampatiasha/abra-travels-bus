import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { AuditLogQueryDto } from '../dto/audit-log-query.dto';
import { type AuditLogView, AuditLogService } from '../services/audit-log.service';

@ApiTags('audit')
@Controller('audit-logs')
export class AuditLogController {
  constructor(private readonly auditLogs: AuditLogService) {}

  @Get()
  @RequirePermission('audit.read')
  @ApiOperation({
    summary: 'Audit trail',
    description:
      "Requires audit.read. Audited changes, newest first, limited to the caller's data scope: " +
      'an operator administrator sees only entries about their own operator. Filters ' +
      '(action, entityId, actorUserId, operatorId) narrow the result and cannot widen the scope.',
  })
  @ApiResponse({
    status: 200,
    description: 'Audit entries (paginated: meta.page, pageSize, total)',
  })
  search(@Query() query: AuditLogQueryDto): Promise<PaginatedResult<AuditLogView>> {
    return this.auditLogs.search(query);
  }
}
