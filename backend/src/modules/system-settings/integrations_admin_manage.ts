import { Body, Controller, Get, HttpCode, Param, Post, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  INTEGRATION_KEYS,
  type IntegrationSummary,
  type IntegrationView,
  IntegrationsAdminManageService,
} from './integrations_admin_manage.service';
import { type SettingsTestResult } from './services/email-settings-admin.service';

// ===== 1. REQUEST TYPES =============================================================
// The schema of the data lives in integrations_admin_manage.service.ts (`integration_settings`).

export class IntegrationKeyParamDto extends createZodDto(
  z.object({ key: z.enum(INTEGRATION_KEYS) }),
) {}

/**
 * Only the fields that are sent change. `null` clears a field and returns it to the environment
 * value. Secrets are write-only. A reason is always required.
 */
export class UpdateIntegrationDto extends createZodDto(
  z.object({
    enabled: z.boolean().optional(),
    values: z
      .record(z.string().max(40), z.union([z.string().max(2000), z.boolean(), z.null()]))
      .optional(),
    secrets: z.record(z.string().max(40), z.union([z.string().max(20_000), z.null()])).optional(),
    reason: z.string().trim().min(3).max(300),
  }),
) {}

// ===== 2. CONTROLLER ================================================================

/** Razorpay, Maps, SMS, Push and the AI assistant. WhatsApp and email have their own pages. */
@ApiTags('settings')
@Controller('settings/integrations')
export class IntegrationsAdminManageController {
  constructor(private readonly integrations: IntegrationsAdminManageService) {}

  // permission: settings.read | audit: none | notifies: nobody
  @Get()
  @RequirePermission('settings.read')
  @ApiOperation({
    summary: 'Every integration with its status',
    description:
      'Requires settings.read. One line each for WhatsApp, email, Razorpay, Maps, SMS, Push and ' +
      'the assistant: READY, DISABLED or INCOMPLETE, and what is missing.',
  })
  list(): Promise<IntegrationSummary[]> {
    return this.integrations.list();
  }

  // permission: settings.read | audit: none | notifies: nobody
  @Get(':key')
  @RequirePermission('settings.read')
  @ApiOperation({
    summary: 'One integration',
    description:
      'Requires settings.read. Shows the settings in use: values saved by an administrator, ' +
      'otherwise the environment configuration. Secrets are never returned, only whether one ' +
      'is set, where it comes from and (when saved here) its last four characters.',
  })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED (unknown integration)' })
  describe(@Param() params: IntegrationKeyParamDto): Promise<IntegrationView> {
    return this.integrations.describe(params.key);
  }

  // permission: settings.update | audit: settings.integration.changed | notifies: nobody
  @Put(':key')
  @RequirePermission('settings.update')
  @ZodApiBody(UpdateIntegrationDto)
  @ApiOperation({
    summary: 'Change one integration',
    description:
      'Requires settings.update. Only the fields sent are changed. Secrets are stored ' +
      'encrypted and cannot be read back. A reason is required; the change is written to the ' +
      'audit trail without any secret and applies to the next use.',
  })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: IntegrationKeyParamDto,
    @Body() body: UpdateIntegrationDto,
    @Req() request: Request,
  ): Promise<IntegrationView> {
    return this.integrations.update(actor, params.key, body, clientRequestInfo(request));
  }

  // permission: settings.update | audit: none | notifies: nobody (nothing is sent to customers)
  @Post(':key/test-connection')
  @HttpCode(200)
  @RequirePermission('settings.update')
  @ApiOperation({
    summary: 'Test the saved credentials',
    description:
      'Requires settings.update. Asks the provider a harmless question with the saved ' +
      'credentials. A failure is a normal answer with `ok: false` and the reason.',
  })
  testConnection(@Param() params: IntegrationKeyParamDto): Promise<SettingsTestResult> {
    return this.integrations.testConnection(params.key);
  }
}
