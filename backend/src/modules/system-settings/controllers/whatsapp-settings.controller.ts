import { Body, Controller, Get, Put, Req } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { UpdateWhatsAppSettingsDto } from '../dto/whatsapp-settings.dto';
import {
  WhatsAppSettingsAdminService,
  type WhatsAppSettingsView,
} from '../services/whatsapp-settings-admin.service';

/** WhatsApp Business settings for administrators. Customer apps never call these. */
@ApiTags('settings')
@Controller('settings/integrations/whatsapp')
export class WhatsAppSettingsController {
  constructor(private readonly settings: WhatsAppSettingsAdminService) {}

  @Get()
  @RequirePermission('settings.read')
  @ApiOperation({
    summary: 'WhatsApp settings in use',
    description:
      'Requires settings.read. Shows the settings the backend sends with: values saved by an ' +
      'administrator, otherwise the environment configuration. The access token is never ' +
      'returned, only whether one is set, its source and (when saved here) its last four ' +
      'characters.',
  })
  @ApiResponse({ status: 200, description: 'Settings, status and what is missing' })
  @ApiResponse({ status: 403, description: 'PERMISSION_DENIED' })
  describe(): Promise<WhatsAppSettingsView> {
    return this.settings.describe();
  }

  @Put()
  @RequirePermission('settings.update')
  @ZodApiBody(UpdateWhatsAppSettingsDto)
  @ApiOperation({
    summary: 'Change WhatsApp settings',
    description:
      'Requires settings.update. Only the fields sent are changed; null clears a field and ' +
      'returns it to the environment configuration. The access token is stored encrypted and ' +
      'cannot be read back. A reason is required and the change is written to the audit trail ' +
      'without the token. Changes apply to the next message.',
  })
  @ApiResponse({ status: 200, description: 'The settings after the change' })
  @ApiResponse({ status: 400, description: 'VALIDATION_FAILED' })
  @ApiResponse({ status: 403, description: 'PERMISSION_DENIED' })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: UpdateWhatsAppSettingsDto,
    @Req() request: Request,
  ): Promise<WhatsAppSettingsView> {
    return this.settings.update(actor, body, clientRequestInfo(request));
  }
}
