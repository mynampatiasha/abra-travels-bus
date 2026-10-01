import { Controller, Delete, Get, HttpCode, Param } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { ApiException } from '../../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { type SessionSummary, SessionsService } from '../services/sessions.service';

/** The signed-in devices of the authenticated user (authentication.md §5). */
@ApiTags('sessions')
@ApiBearerAuth('access-token')
@Controller('me/sessions')
export class MySessionsController {
  constructor(private readonly sessions: SessionsService) {}

  @Get()
  @ApiOperation({
    summary: 'List my active sessions',
    description:
      'Authenticated. Devices signed in to this account, most recently used first. ' +
      'Never returns tokens.',
  })
  @ApiResponse({ status: 200, description: 'Active sessions; `current` marks this device' })
  @ApiResponse({ status: 401, description: 'UNAUTHENTICATED or TOKEN_EXPIRED' })
  list(@CurrentActor() actor: AuthenticatedUserActor): Promise<SessionSummary[]> {
    return this.sessions.listActive(actor.userId, actor.sessionId);
  }

  @Delete(':sessionId')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Sign out one of my devices',
    description:
      'Authenticated. Revokes one of my own sessions; its refresh token and access tokens stop ' +
      'working immediately. A session of another user answers RESOURCE_NOT_FOUND.',
  })
  @ApiResponse({ status: 200, description: 'Session revoked' })
  @ApiResponse({ status: 404, description: 'RESOURCE_NOT_FOUND' })
  async revoke(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param('sessionId') sessionId: string,
  ): Promise<{ revoked: true }> {
    const revoked = await this.sessions.revoke(sessionId, actor.userId, 'REVOKED_BY_USER');
    if (!revoked) throw new ApiException('RESOURCE_NOT_FOUND', 'Session not found');
    return { revoked: true };
  }
}
