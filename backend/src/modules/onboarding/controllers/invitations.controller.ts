import { Body, Controller, Get, HttpCode, Param, Post, Query, Req } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { PublicEndpoint } from '../../../common/decorators/public-endpoint.decorator';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import {
  AcceptInvitationDto,
  InspectInvitationDto,
  InvitationIdParamDto,
  InvitationListQueryDto,
  InviteClientDto,
} from '../dto/onboarding.dto';
import {
  type InvitationPreview,
  type InvitationView,
  InvitationsService,
} from '../services/invitations.service';

/**
 * Inviting bus owners. The staff endpoints need `operators.create` (platform staff only);
 * `inspect` and `accept` are the two public calls the invitation link leads to.
 */
@ApiTags('onboarding')
@Controller('onboarding/invitations')
export class InvitationsController {
  constructor(private readonly invitations: InvitationsService) {}

  @Post()
  @RequirePermission('operators.create')
  @ZodApiBody(InviteClientDto)
  @ApiOperation({
    summary: 'Invite a bus owner',
    description:
      'Requires operators.create. Creates the company (awaiting approval) and its onboarding ' +
      'file, and emails the owner a link valid for 7 days. If the email could not be sent the ' +
      'invitation still exists: `emailStatus` and `emailProblem` say so and it can be resent. ' +
      'Outside production the response also carries `inviteUrl`. Audited.',
  })
  invite(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: InviteClientDto,
    @Req() request: Request,
  ): Promise<InvitationView> {
    return this.invitations.invite(actor, body, clientRequestInfo(request));
  }

  @Get()
  @RequirePermission('operators.create')
  @ApiOperation({
    summary: 'List invitations',
    description: 'Requires operators.create. Newest first; `status` filters. Paginated.',
  })
  list(@Query() query: InvitationListQueryDto): Promise<PaginatedResult<InvitationView>> {
    return this.invitations.list(query);
  }

  @Post(':id/resend')
  @HttpCode(200)
  @RequirePermission('operators.create')
  @ApiOperation({
    summary: 'Resend an invitation',
    description:
      'Requires operators.create. Only while pending. Makes a new link (the old one stops ' +
      'working) valid for 7 days and emails it. Audited.',
  })
  resend(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: InvitationIdParamDto,
    @Req() request: Request,
  ): Promise<InvitationView> {
    return this.invitations.resend(actor, params.id, clientRequestInfo(request));
  }

  @Post(':id/revoke')
  @HttpCode(200)
  @RequirePermission('operators.create')
  @ApiOperation({
    summary: 'Withdraw an invitation',
    description: 'Requires operators.create. Only while pending. Audited.',
  })
  revoke(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: InvitationIdParamDto,
    @Req() request: Request,
  ): Promise<InvitationView> {
    return this.invitations.revoke(actor, params.id, clientRequestInfo(request));
  }

  @Post('inspect')
  @HttpCode(200)
  @PublicEndpoint()
  @ZodApiBody(InspectInvitationDto)
  @ApiOperation({
    summary: 'Who an invitation link is for',
    description:
      'Public. The Client Portal calls it before showing the set-password page. Returns the ' +
      'company, owner name and email; a wrong, used, withdrawn or expired link is one answer: ' +
      'RESOURCE_NOT_FOUND.',
  })
  inspect(@Body() body: InspectInvitationDto): Promise<InvitationPreview> {
    return this.invitations.inspect(body.token);
  }

  @Post('accept')
  @HttpCode(200)
  @PublicEndpoint()
  @ZodApiBody(AcceptInvitationDto)
  @ApiOperation({
    summary: 'Accept an invitation',
    description:
      'Public. The owner sets a password and the account is created for the invited company ' +
      '(operator administrator, that company only). The link works once. Then the owner signs ' +
      'in as usual.',
  })
  accept(@Body() body: AcceptInvitationDto): Promise<{ email: string }> {
    return this.invitations.accept(body);
  }
}
