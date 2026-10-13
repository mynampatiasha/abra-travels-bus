import { Body, Controller, Get, Module, Param, Put, Query, Req } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { RbacModule } from '../rbac/rbac.module';
import {
  appOfHeader,
  AvailabilityGuard,
  AvailabilityState,
  FEATURE_FLAG_MODEL,
  FEATURE_KEYS,
  featureFlagSchema,
  type FlagView,
  FlagsAdminManageService,
  FlagsStartupSeeder,
  MAINTENANCE_MODEL,
  MAINTENANCE_SCOPES,
  type MaintenanceApp,
  type MaintenanceStatus,
  type MaintenanceView,
  maintenanceSchema,
} from './flags_admin_manage.service';

// ===== 1. REQUEST TYPES =============================================================
// The schemas of the data live in flags_admin_manage.service.ts (`feature_flags`, `maintenance`).

const reason = z.string().trim().min(3).max(300);
const moment = z
  .string()
  .refine((value) => !Number.isNaN(Date.parse(value)), 'must be a date and time')
  .transform((value) => new Date(value));

export class FlagKeyParamDto extends createZodDto(z.object({ key: z.enum(FEATURE_KEYS) })) {}
export class SetFlagDto extends createZodDto(z.object({ on: z.boolean(), reason })) {}

/** Only what is sent changes. `from` and `to` may be cleared with null. */
export class ChangeMaintenanceDto extends createZodDto(
  z.object({
    scopes: z.partialRecord(z.enum(MAINTENANCE_SCOPES), z.boolean()).optional(),
    message: z.string().trim().min(3).max(300).optional(),
    from: moment.nullable().optional(),
    to: moment.nullable().optional(),
    reason,
  }),
) {}

export class StatusQueryDto extends createZodDto(
  z.object({ app: z.enum(['customer', 'operator', 'partner', 'admin']).optional() }),
) {}

// ===== 2. CONTROLLERS ===============================================================

/** The admin "Feature flags" list. */
@ApiTags('settings')
@Controller('admin/feature-flags')
export class FlagsAdminController {
  constructor(private readonly flags: FlagsAdminManageService) {}

  // permission: settings.read | audit: none | notifies: nobody
  @Get()
  @RequirePermission('settings.read')
  @ApiOperation({ summary: 'Every feature switch', description: 'Requires settings.read.' })
  list(): Promise<FlagView[]> {
    return this.flags.listFlags();
  }

  // permission: settings.update | audit: feature-flag.changed | reaches every server within seconds
  @Put(':key')
  @RequirePermission('settings.update')
  @ZodApiBody(SetFlagDto)
  @ApiOperation({
    summary: 'Turn a feature on or off',
    description:
      'Requires settings.update. A reason is required and the change is audited. Turning a ' +
      'feature off makes its endpoints answer "switched off" straight away on every server.',
  })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED (unknown feature)' })
  set(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: FlagKeyParamDto,
    @Body() body: SetFlagDto,
    @Req() request: Request,
  ): Promise<FlagView> {
    return this.flags.setFlag(actor, params.key, body.on, body.reason, clientRequestInfo(request));
  }
}

/** The admin "Maintenance mode" card. */
@ApiTags('settings')
@Controller('admin/maintenance')
export class MaintenanceAdminController {
  constructor(private readonly flags: FlagsAdminManageService) {}

  // permission: settings.read | audit: none | notifies: nobody
  @Get()
  @RequirePermission('settings.read')
  @ApiOperation({
    summary: 'Maintenance settings',
    description:
      'Requires settings.read. The switches, the message, the window and which apps are stopped right now.',
  })
  show(): Promise<MaintenanceView> {
    return this.flags.getMaintenance();
  }

  // permission: settings.update | audit: maintenance.changed
  @Put()
  @RequirePermission('settings.update')
  @ZodApiBody(ChangeMaintenanceDto)
  @ApiOperation({
    summary: 'Change maintenance',
    description:
      'Requires settings.update. Send only what changes: `scopes` (global, customer, operator, ' +
      'partner, admin), `message`, `from`, `to`. `global` stops the customer, operator and ' +
      'partner apps; the admin portal has its own switch. Staff with maintenance.bypass can ' +
      'always sign in to the admin portal. A reason is required and the change is audited.',
  })
  @ApiResponse({
    status: 400,
    description: 'VALIDATION_FAILED (end before start, nothing to change)',
  })
  change(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ChangeMaintenanceDto,
    @Req() request: Request,
  ): Promise<MaintenanceView> {
    return this.flags.changeMaintenance(actor, body, clientRequestInfo(request));
  }
}

/** What every app asks on start-up, before anybody signs in. */
@ApiTags('settings')
@Controller()
export class AvailabilityPublicController {
  constructor(private readonly flags: FlagsAdminManageService) {}

  // access: public | audit: none
  @Get('features')
  @PublicEndpoint()
  @ApiOperation({
    summary: 'Which features are on',
    description:
      'Public. A plain map from feature key to true or false, so an app can hide what is off.',
  })
  features(): Promise<Record<string, boolean>> {
    return this.flags.featureMap();
  }

  // access: public | audit: none
  @Get('maintenance/status')
  @PublicEndpoint()
  @ApiOperation({
    summary: 'Is this app in maintenance?',
    description:
      'Public. `app` is customer, operator, partner or admin; without it the `X-Abra-App` ' +
      'header is used, and then customer. Returns whether it is stopped, the message to show and ' +
      'when it should end.',
  })
  status(@Query() query: StatusQueryDto, @Req() request: Request): Promise<MaintenanceStatus> {
    const app: MaintenanceApp =
      query.app ?? appOfHeader(request.headers['x-abra-app']) ?? 'customer';
    return this.flags.statusFor(app);
  }
}

// ===== 3. MODULE ====================================================================

/**
 * `feature-flags`: switches and maintenance. Other features read `AvailabilityState.isOn(key)` or
 * put `@RequireFeature('key')` on an endpoint; the global guard enforces both and maintenance.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: FEATURE_FLAG_MODEL, schema: featureFlagSchema },
      { name: MAINTENANCE_MODEL, schema: maintenanceSchema },
    ]),
    RbacModule,
  ],
  controllers: [FlagsAdminController, MaintenanceAdminController, AvailabilityPublicController],
  providers: [
    AvailabilityState,
    FlagsStartupSeeder,
    FlagsAdminManageService,
    AvailabilityGuard,
    // Runs after the authentication and permission guards, so the caller is known
    { provide: APP_GUARD, useExisting: AvailabilityGuard },
  ],
  exports: [AvailabilityState],
})
export class FeatureFlagsModule {}
