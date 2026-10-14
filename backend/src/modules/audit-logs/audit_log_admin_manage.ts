import { Controller, Get, Module, Param, Query } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { dateRangeShape, objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { type ExportKind } from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import {
  AuditLogAdminService,
  type AuditEntryView,
  type AuditFilterChoices,
  AUDIT_SORTS,
} from './audit_log_admin_manage.service';
import { AuditLogRepository } from './repositories/audit-log.repository';
import { AUDIT_ACTIONS, AUDIT_LOG_MODEL, auditLogSchema } from './schemas/audit-log.schema';
import { AuditLogService } from './services/audit-log.service';

/*
 * The audit log page ("audit" in the demos): the trail with the demo's filters (search, person,
 * type, action, dates), one entry opened, and a download. Reads go through the caller's data
 * scope: an operator sees only the entries about its own records. Entries are never changed here.
 */

export class AuditListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    personId: objectIdString.optional(),
    /** The demo's Type filter: "Sensitive only". */
    type: z.enum(['sensitive']).optional(),
    action: z.enum(AUDIT_ACTIONS).optional(),
    entityType: z.string().trim().min(1).max(64).optional(),
    entityId: objectIdString.optional(),
    operatorId: objectIdString.optional(),
    ...dateRangeShape,
    sort: z.enum(AUDIT_SORTS).default('newest'),
    ...pagingShape,
    // The demo shows 15 rows a page
    pageSize: z.coerce.number().int().min(1).max(100).default(15),
  }),
) {}

export class AuditIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

/** What a downloaded row says: the same words as the page. */
export const AUDIT_EXPORT_KIND: ExportKind<AuditEntryView> = {
  key: 'audit-log',
  columns: [
    {
      header: 'When',
      value: (row) => new Date(row.at).toISOString().replace('T', ' ').slice(0, 19),
    },
    { header: 'Who', value: (row) => row.actorName },
    { header: 'Role', value: (row) => row.actorRoleLabel },
    { header: 'Action', value: (row) => row.actionLabel },
    { header: 'Sensitive', value: (row) => row.sensitive },
    { header: 'Target', value: (row) => row.targetLabel },
    { header: 'Reason', value: (row) => row.reason },
    { header: 'IP address', value: (row) => row.ip },
  ],
};

/** Registered first: the list controller has `GET :id`, which would take "export" for an id. */
export const AuditLogExportController = exportController({
  base: 'audit-logs',
  permission: 'audit.export',
  kind: AUDIT_EXPORT_KIND,
  service: AuditLogAdminService,
  query: AuditListQueryDto,
  title: 'the audit log',
  load: (service, query) => service.list(query as never),
});

@ApiTags('audit')
@Controller('audit-logs')
export class AuditLogAdminController {
  constructor(private readonly auditLogs: AuditLogAdminService) {}

  @Get()
  @RequirePermission('audit.read')
  @ApiOperation({
    summary: 'Audit log',
    description:
      "Requires audit.read. Audited changes within the caller's data scope (an operator sees only " +
      'entries about its own records). Filters: search (person, action, record, reason, IP), ' +
      'personId, type=sensitive, action, entityType, entityId, operatorId, from and to (days), ' +
      'sort (newest, oldest, action). Each row has the words for the screen: actorName, ' +
      'actorRoleLabel, actionLabel, targetLabel and sensitive. An operator sees "Abra team" in ' +
      'place of a platform member.',
  })
  list(@Query() query: AuditListQueryDto): Promise<PaginatedResult<AuditEntryView>> {
    return this.auditLogs.list(query);
  }

  /** Before `:id`, so "filters" is not taken for an id. */
  @Get('filters')
  @RequirePermission('audit.read')
  @ApiOperation({
    summary: 'Audit log filter choices',
    description:
      'Requires audit.read. The people and the actions that appear in the entries the caller ' +
      'can see: the choices of the Person and Action filters.',
  })
  filters(): Promise<AuditFilterChoices> {
    return this.auditLogs.filters();
  }

  @Get(':id')
  @RequirePermission('audit.read')
  @ApiOperation({
    summary: 'One audit entry',
    description:
      'Requires audit.read. The entry with who, role, action, target, IP address and, for the ' +
      'change itself, the state before and after. An entry outside the data scope is not found.',
  })
  get(@Param() params: AuditIdParamDto): Promise<AuditEntryView> {
    return this.auditLogs.get(params.id);
  }
}

@Module({
  imports: [
    MongooseModule.forFeature([{ name: AUDIT_LOG_MODEL, schema: auditLogSchema }]),
    RbacModule,
    UsersModule,
    CatalogueSharedModule,
  ],
  controllers: [AuditLogExportController, AuditLogAdminController],
  providers: [AuditLogRepository, AuditLogService, AuditLogAdminService],
  exports: [AuditLogAdminService],
})
export class AuditLogsAdminModule {}
