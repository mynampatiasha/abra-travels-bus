import { Body, Controller, Get, Param, Patch, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { phoneNumberSchema } from '../../common/validation/contact-identifiers';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import { InvitationIdParamDto } from './dto/onboarding.dto';
import { InvitationsManageService } from './invitations_admin_manage.service';
import { type InvitationView } from './services/invitations.service';
import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { InvitationListQueryDto } from './dto/onboarding.dto';
import { InvitationsService } from './services/invitations.service';

/** Only the fields sent change. `phone: null` removes the number. */
export class UpdateInvitationDto extends createZodDto(
  z.object({
    companyName: z.string().trim().min(2).max(160).optional(),
    ownerName: z.string().trim().min(2).max(120).optional(),
    email: z.email().max(254).optional(),
    phone: phoneNumberSchema.nullable().optional(),
    /** A new closing time for the invitation, in the future and at most 30 days away. */
    expiresAt: z.iso
      .datetime({ offset: true })
      .transform((value) => new Date(value))
      .refine((value) => value.getTime() > Date.now(), { message: 'must be in the future' })
      .optional(),
  }),
) {}

/** Invitations page of the admin portal: open one and edit it. */
@ApiTags('onboarding')
@Controller('onboarding/invitations')
export class InvitationsManageController {
  constructor(private readonly manage: InvitationsManageService) {}

  @Get(':id')
  @RequirePermission('operators.create')
  @ApiOperation({
    summary: 'One invitation',
    description: 'Requires operators.create. A deleted invitation is not found.',
  })
  get(@Param() params: InvitationIdParamDto): Promise<InvitationView> {
    return this.manage.get(params.id);
  }

  @Patch(':id')
  @RequirePermission('operators.create')
  @ZodApiBody(UpdateInvitationDto)
  @ApiOperation({
    summary: 'Edit a pending invitation',
    description:
      'Requires operators.create. Only while pending (also after it expired: a new `expiresAt` ' +
      'opens it again). Changing the email invalidates the old link and the invitation must be ' +
      'resent. The company name also changes on a company still awaiting approval. Audited.',
  })
  update(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: InvitationIdParamDto,
    @Body() body: UpdateInvitationDto,
    @Req() request: Request,
  ): Promise<InvitationView> {
    return this.manage.update(actor, params.id, body, clientRequestInfo(request));
  }
}

/** The invitations list as a file; a pending invitation past its date is Expired. */
export const INVITATIONS_EXPORT_KIND: ExportKind<InvitationView> = {
  key: 'invitations',
  columns: [
    { header: 'Company', value: (invitation) => invitation.companyName },
    { header: 'Owner', value: (invitation) => invitation.ownerName },
    { header: 'Email', value: (invitation) => invitation.email },
    { header: 'Phone', value: (invitation) => invitation.phone },
    {
      header: 'Status',
      value: (invitation) => (invitation.expired ? 'Expired' : readable(invitation.status)),
    },
    { header: 'Email sent', value: (invitation) => readable(invitation.emailStatus) },
    { header: 'Link valid until', value: (invitation) => timeOf(invitation.expiresAt) },
    { header: 'Invited on', value: (invitation) => timeOf(invitation.createdAt) },
  ],
};

/** `GET onboarding/invitations/export`. Register it before the module's other controllers. */
export const InvitationsExportController = exportController({
  base: 'onboarding/invitations',
  permission: 'operators.export',
  kind: INVITATIONS_EXPORT_KIND,
  service: InvitationsService,
  query: InvitationListQueryDto,
  title: 'invitations',
  load: (service, query) => service.list(query as never),
});
