import { Body, Controller, Get, HttpCode, Post, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { SendTestEmailDto, UpdateEmailSettingsDto } from '../dto/email-settings.dto';
import {
  EmailSettingsAdminService,
  type EmailSettingsView,
  type SettingsTestResult,
} from '../services/email-settings-admin.service';

/** SMTP (email) settings for administrators. */
@ApiTags('settings')
@Controller('settings/integrations/email')
export class EmailSettingsController {
  constructor(private readonly settings: EmailSettingsAdminService) {}

  @Get()
  @RequirePermission('settings.read')
  @ApiOperation({
    summary: 'Email settings in use',
    description: 'Requires settings.read. The password is never returned, only whether one is set.',
  })
  @ApiResponse({ status: 200, description: 'Settings, status and what is missing' })
  describe(): Promise<EmailSettingsView> {
    return this.settings.describe();
  }

  @Put()
  @RequirePermission('settings.update')
  @ZodApiBody(UpdateEmailSettingsDto)
  @ApiOperation({
    summary: 'Change email settings',
    description:
      'Requires settings.update. Only the fields sent are changed; null clears a field. The ' +
      'password is stored encrypted and cannot be read back. A reason is required and the ' +
      'change is written to the audit trail without the password. Applies to the next email.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: UpdateEmailSettingsDto,
    @Req() request: Request,
  ): Promise<EmailSettingsView> {
    return this.settings.update(actor, body, clientRequestInfo(request));
  }

  @Post('test-connection')
  @HttpCode(200)
  @RequirePermission('settings.update')
  @ApiOperation({
    summary: 'Test the saved mail server',
    description:
      'Requires settings.update. Connects and signs in with the saved settings without ' +
      'sending a message. A failure is a normal answer with `ok: false` and the reason.',
  })
  testConnection(): Promise<SettingsTestResult> {
    return this.settings.testConnection();
  }

  @Post('test-email')
  @HttpCode(200)
  @RequirePermission('settings.update')
  @ZodApiBody(SendTestEmailDto)
  @ApiOperation({
    summary: 'Send a test email',
    description:
      'Requires settings.update. Sends a real test message with the saved settings to the ' +
      'address given. A failure is a normal answer with `ok: false` and the reason.',
  })
  sendTestEmail(@Body() body: SendTestEmailDto): Promise<SettingsTestResult> {
    return this.settings.sendTestEmail(body.to);
  }
}
