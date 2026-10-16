import {
  Body,
  Controller,
  Delete,
  Get,
  Module,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
} from '@nestjs/common';
import { getConnectionToken, MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { type Connection } from 'mongoose';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import { CatalogueSharedModule } from '../catalogue-shared/catalogue_shared_manage';
import { type ExportKind, readable } from '../catalogue-shared/catalogue_export_manage.service';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import { UsersModule } from '../users/users.module';
import {
  COMMISSION_DEFAULT_MODEL,
  COMMISSION_HISTORY_MODEL,
  COMMISSION_MODES,
  COMMISSION_RULE_MODEL,
  COMMISSION_SCOPES,
  COMMISSION_STATUSES,
  CommissionService,
  commissionDefaultSchema,
  commissionHistorySchema,
  commissionRuleSchema,
  MAX_NOTE_LENGTH,
  MAX_SEATS,
  MIN_SEATS,
  PAYOUT_FEES_PROVIDER,
  payoutFeesFrom,
  RULE_SORTS,
  type CalculationResult,
  type CommissionDefaultView,
  type CommissionHistoryView,
  type CommissionRuleView,
  type TargetChoice,
} from './commission_admin_manage.service';

/*
 * The admin Commission page (`/admin/commission`): rules, the default rule, the price calculator
 * and the change history. Only staff with commissions.manage change anything; everyone who may
 * read commissions sees it (operators see their own rule, read-only, in the client portal).
 */

const ruleId = z.string().regex(/^CR-\d{1,9}$/, 'must be a rule id like CR-1');
const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be a date like 2026-10-31');
const commissionValue = z.number().int().min(0).max(1_000_000_000);
const note = z.string().max(MAX_NOTE_LENGTH).optional();

export class RuleIdParamDto extends createZodDto(z.object({ id: ruleId })) {}

export class RuleListQueryDto extends createZodDto(
  z.object({
    search: z.string().trim().max(100).optional(),
    scope: z.enum(COMMISSION_SCOPES).optional(),
    status: z.enum(COMMISSION_STATUSES).optional(),
    sort: z.enum(RULE_SORTS).optional(),
    dir: z.enum(['asc', 'desc']).optional(),
    page: z.coerce.number().int().min(1).max(10_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(10),
  }),
) {}

export class CreateRuleDto extends createZodDto(
  z.object({
    scope: z.enum(COMMISSION_SCOPES),
    targetId: objectIdString,
    mode: z.enum(COMMISSION_MODES),
    value: commissionValue,
    effectiveFrom: day,
    agreedNote: note,
  }),
) {}

export class NewVersionDto extends createZodDto(
  z.object({
    mode: z.enum(COMMISSION_MODES),
    value: commissionValue,
    effectiveFrom: day,
    agreedNote: note,
  }),
) {}

export class SetActiveDto extends createZodDto(z.object({ active: z.boolean() })) {}

export class SetDefaultDto extends createZodDto(
  z.object({ mode: z.enum(COMMISSION_MODES), value: commissionValue }),
) {}

export class CalculateDto extends createZodDto(
  z.object({
    farePerSeatPaise: z.number().int().min(0).max(100_000_000),
    seats: z.number().int().min(MIN_SEATS).max(MAX_SEATS),
    operatorId: objectIdString.optional(),
    routeId: objectIdString.optional(),
    busTypeId: objectIdString.optional(),
  }),
) {}

export class HistoryQueryDto extends createZodDto(
  z.object({
    page: z.coerce.number().int().min(1).max(10_000).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
  }),
) {}

export class TargetsQueryDto extends createZodDto(
  z.object({ scope: z.enum(COMMISSION_SCOPES), search: z.string().trim().max(100).optional() }),
) {}

// ===== EXPORT =====

const SCOPE_LABELS: Readonly<Record<string, string>> = {
  OPERATOR: 'Operator',
  ROUTE: 'Route',
  BUS_TYPE: 'Bus type',
};

/** The columns of the table, in the file. */
export const COMMISSION_EXPORT_KIND: ExportKind<CommissionRuleView> = {
  key: 'commission-rules',
  columns: [
    { header: 'ID', value: (row) => row.id },
    { header: 'Applies to', value: (row) => SCOPE_LABELS[row.scope] ?? row.scope },
    { header: 'Target', value: (row) => row.targetName },
    { header: 'Commission', value: (row) => row.commission },
    { header: 'Effective from', value: (row) => row.effectiveFrom },
    { header: 'Version', value: (row) => `v${row.version}` },
    { header: 'Status', value: (row) => readable(row.status) },
    { header: 'Agreed note', value: (row) => row.agreedNote },
  ],
};

/** Registered first: the main controller has `GET rules/:id`, which would take "export" for an id. */
export const CommissionExportController = exportController({
  base: 'admin/commission/rules',
  permission: 'commissions.export',
  kind: COMMISSION_EXPORT_KIND,
  service: CommissionService,
  query: RuleListQueryDto,
  title: 'the commission rules',
  load: (service, query) => service.list(query as never),
});

// ===== CONTROLLER =====

@ApiTags('commission')
@Controller('admin/commission')
export class CommissionAdminController {
  constructor(private readonly commission: CommissionService) {}

  @Get('rules')
  @RequirePermission('commissions.read')
  @ApiOperation({
    summary: 'List commission rules',
    description:
      'Requires commissions.read. Rules that are not deleted, oldest first. Filters: search ' +
      '(id, target, agreed note), scope (Applies to) and status.',
  })
  list(@Query() query: RuleListQueryDto): Promise<PaginatedResult<CommissionRuleView>> {
    return this.commission.list(query);
  }

  @Post('rules')
  @RequirePermission('commissions.manage')
  @ZodApiBody(CreateRuleDto)
  @ApiOperation({
    summary: 'New commission rule',
    description:
      'Requires commissions.manage. One active rule per operator, route or bus type: a second one ' +
      'is refused (ALREADY_REGISTERED). Percentage 0 to 40; the date is today or later. Audited.',
  })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: CreateRuleDto,
    @Req() request: Request,
  ): Promise<CommissionRuleView> {
    return this.commission.create(actor, body, clientRequestInfo(request));
  }

  @Get('rules/:id')
  @RequirePermission('commissions.read')
  @ApiOperation({
    summary: 'One commission rule',
    description: 'Requires commissions.read. The rule with every version it has had.',
  })
  get(@Param() params: RuleIdParamDto): Promise<CommissionRuleView> {
    return this.commission.get(params.id);
  }

  @Post('rules/:id/versions')
  @RequirePermission('commissions.manage')
  @ZodApiBody(NewVersionDto)
  @ApiOperation({
    summary: 'Save a new version of a rule',
    description:
      'Requires commissions.manage. A change is a new version that starts on its date; bookings ' +
      'made before keep what they were sold with. Audited.',
  })
  newVersion(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RuleIdParamDto,
    @Body() body: NewVersionDto,
    @Req() request: Request,
  ): Promise<CommissionRuleView> {
    return this.commission.newVersion(actor, params.id, body, clientRequestInfo(request));
  }

  @Patch('rules/:id/active')
  @RequirePermission('commissions.manage')
  @ZodApiBody(SetActiveDto)
  @ApiOperation({
    summary: 'Activate or deactivate a rule',
    description:
      'Requires commissions.manage. Activating is refused while another rule is active for the ' +
      'same target. Audited.',
  })
  setActive(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RuleIdParamDto,
    @Body() body: SetActiveDto,
    @Req() request: Request,
  ): Promise<CommissionRuleView> {
    return this.commission.setActive(actor, params.id, body.active, clientRequestInfo(request));
  }

  @Delete('rules/:id')
  @RequirePermission('commissions.delete')
  @ApiOperation({
    summary: 'Delete a commission rule',
    description:
      'Requires commissions.delete. Soft delete: it disappears from the list and from every price, ' +
      'and `POST rules/:id/restore` brings it back. Audited.',
  })
  remove(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RuleIdParamDto,
    @Req() request: Request,
  ): Promise<CommissionRuleView> {
    return this.commission.remove(actor, params.id, clientRequestInfo(request));
  }

  @Post('rules/:id/restore')
  @RequirePermission('commissions.delete')
  @ApiOperation({
    summary: 'Undo the delete of a rule',
    description:
      'Requires commissions.delete. If another rule became active for the same target meanwhile, ' +
      'the rule comes back switched off (`restoredInactive`). Audited.',
  })
  restore(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: RuleIdParamDto,
    @Req() request: Request,
  ): Promise<CommissionRuleView & { restoredInactive: boolean }> {
    return this.commission.restore(actor, params.id, clientRequestInfo(request));
  }

  @Get('default')
  @RequirePermission('commissions.read')
  @ApiOperation({
    summary: 'The default commission',
    description:
      'Requires commissions.read. Used when no rule applies. `configured` is false until it is ' +
      'saved: nothing is assumed.',
  })
  getDefault(): Promise<CommissionDefaultView> {
    return this.commission.getDefault();
  }

  @Put('default')
  @RequirePermission('commissions.manage')
  @ZodApiBody(SetDefaultDto)
  @ApiOperation({
    summary: 'Change the default commission',
    description: 'Requires commissions.manage. Percentage 0 to 40. New bookings only. Audited.',
  })
  setDefault(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: SetDefaultDto,
    @Req() request: Request,
  ): Promise<CommissionDefaultView> {
    return this.commission.setDefault(actor, body, clientRequestInfo(request));
  }

  @Get('targets')
  @RequirePermission('commissions.read')
  @ApiOperation({
    summary: 'Operators, routes or bus types to pick from',
    description:
      'Requires commissions.read. The "Which one" list of a rule, by scope; `search` narrows it.',
  })
  targets(@Query() query: TargetsQueryDto): Promise<TargetChoice[]> {
    return this.commission.targets(query.scope, query.search);
  }

  @Post('calculate')
  @RequirePermission('commissions.read')
  @ZodApiBody(CalculateDto)
  @ApiOperation({
    summary: 'Price calculator',
    description:
      'Requires commissions.read. The rule that applies (operator, route, bus type, default) and ' +
      'the seven amounts, in paise, from the same function the booking uses. Refused with a ' +
      'sentence until a default commission and the Payout and fees settings are saved.',
  })
  calculate(@Body() body: CalculateDto): Promise<CalculationResult> {
    return this.commission.calculate(body);
  }

  @Get('history')
  @RequirePermission('commissions.read')
  @ApiOperation({
    summary: 'Change history',
    description:
      'Requires commissions.read. Every change to a rule or the default: who, what, when. Newest first.',
  })
  history(@Query() query: HistoryQueryDto): Promise<PaginatedResult<CommissionHistoryView>> {
    return this.commission.listHistory(query.page, query.pageSize);
  }
}

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: COMMISSION_RULE_MODEL, schema: commissionRuleSchema },
      { name: COMMISSION_HISTORY_MODEL, schema: commissionHistorySchema },
      { name: COMMISSION_DEFAULT_MODEL, schema: commissionDefaultSchema },
    ]),
    RbacModule,
    UsersModule,
    CatalogueSharedModule,
  ],
  controllers: [CommissionExportController, CommissionAdminController],
  providers: [
    CommissionService,
    {
      provide: PAYOUT_FEES_PROVIDER,
      inject: [getConnectionToken()],
      useFactory: (connection: Connection) => payoutFeesFrom(connection),
    },
  ],
  exports: [CommissionService],
})
export class CommissionsModule {}
