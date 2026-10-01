import { Body, Controller, Get, HttpCode, Post, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Response } from 'express';
import { AuthenticatedOnly } from '../../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AppConfigService } from '../../../config/app-config.service';
import { SessionsService } from '../../sessions/services/sessions.service';
import { toUserProfile, type UserProfile, UsersService } from '../../users/services/users.service';
import { ActivateTotpDto, ChangePasswordDto, DisableTotpDto } from '../dto/authentication.dto';
import { AllowDuringMfaEnrollment } from '../guards/access-token-authentication.guard';
import { clearRefreshTokenCookie } from '../refresh-token-cookie';
import { type MfaEnrollment, MfaService, type MfaStatus } from '../services/mfa.service';
import { PasswordManagementService } from '../services/password-management.service';

export interface CurrentUserResponse {
  user: UserProfile;
  session: { id: string; mfaEnrollmentRequired: boolean };
}

/** The authenticated user's own account: profile, password, two-step verification. */
@ApiTags('authentication')
@ApiBearerAuth('access-token')
@AuthenticatedOnly()
@Controller()
export class CurrentUserController {
  constructor(
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly passwords: PasswordManagementService,
    private readonly mfa: MfaService,
    private readonly config: AppConfigService,
  ) {}

  @Get('me')
  @AllowDuringMfaEnrollment()
  @ApiOperation({
    summary: 'Current authenticated user',
    description:
      'Authenticated. Profile of the caller: user type, operator, language, whether a password ' +
      'and two-step verification are set. Never returns credentials.',
  })
  @ApiResponse({ status: 200, description: 'User profile and current session' })
  @ApiResponse({
    status: 401,
    description: 'UNAUTHENTICATED, TOKEN_EXPIRED or PERMISSIONS_CHANGED',
  })
  async me(@CurrentActor() actor: AuthenticatedUserActor): Promise<CurrentUserResponse> {
    return {
      user: toUserProfile(await this.users.getById(actor.userId)),
      session: { id: actor.sessionId, mfaEnrollmentRequired: actor.mfaEnrollmentPending },
    };
  }

  @Post('me/password')
  @HttpCode(200)
  @ZodApiBody(ChangePasswordDto)
  @ApiOperation({
    summary: 'Set or change my password',
    description:
      'Authenticated. currentPassword is required when a password is already set. Signs out ' +
      'every other device.',
  })
  @ApiResponse({ status: 200, description: 'Password saved' })
  @ApiResponse({ status: 401, description: 'INVALID_CREDENTIALS (wrong current password)' })
  changePassword(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ChangePasswordDto,
  ): Promise<{ otherSessionsSignedOut: number }> {
    return this.passwords.setOrChange(actor, body);
  }

  @Post('auth/logout-all')
  @HttpCode(200)
  @AllowDuringMfaEnrollment()
  @ApiOperation({
    summary: 'Sign out all my devices',
    description: 'Authenticated. Revokes every session of the account, including this one.',
  })
  @ApiResponse({ status: 200, description: 'Number of sessions revoked' })
  async logoutAll(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Res({ passthrough: true }) response: Response,
  ): Promise<{ sessionsSignedOut: number }> {
    const sessionsSignedOut = await this.sessions.revokeAllForUser(actor.userId, 'LOGOUT_ALL');
    clearRefreshTokenCookie(response, this.config);
    return { sessionsSignedOut };
  }

  @Get('me/mfa')
  @AllowDuringMfaEnrollment()
  @ApiOperation({
    summary: 'Two-step verification status',
    description:
      'Authenticated. Whether TOTP is on, mandatory, and how many recovery codes remain.',
  })
  @ApiResponse({ status: 200, description: 'enabled, required, recoveryCodesRemaining' })
  mfaStatus(@CurrentActor() actor: AuthenticatedUserActor): Promise<MfaStatus> {
    return this.mfa.status(actor.userId);
  }

  @Post('me/mfa/totp/enroll')
  @HttpCode(200)
  @AllowDuringMfaEnrollment()
  @ApiOperation({
    summary: 'Start two-step verification setup',
    description:
      'Authenticated. Returns a new TOTP secret and its otpauth:// URI for the authenticator ' +
      'app. Shown once. Nothing changes until the setup is confirmed with a code.',
  })
  @ApiResponse({ status: 200, description: 'secret, keyUri' })
  @ApiResponse({ status: 409, description: 'INVALID_STATE_TRANSITION (already on)' })
  enrollTotp(@CurrentActor() actor: AuthenticatedUserActor): Promise<MfaEnrollment> {
    return this.mfa.startEnrollment(actor.userId);
  }

  @Post('me/mfa/totp/activate')
  @HttpCode(200)
  @AllowDuringMfaEnrollment()
  @ZodApiBody(ActivateTotpDto)
  @ApiOperation({
    summary: 'Confirm two-step verification setup',
    description:
      'Authenticated. Confirms the setup with a code from the authenticator app, turns two-step ' +
      'verification on, returns the recovery codes (shown once) and signs out other devices. ' +
      'The access token must then be refreshed.',
  })
  @ApiResponse({ status: 200, description: 'recoveryCodes' })
  @ApiResponse({ status: 401, description: 'MFA_INVALID' })
  activateTotp(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: ActivateTotpDto,
  ): Promise<{ recoveryCodes: string[] }> {
    return this.mfa.activate(actor, body.code);
  }

  @Post('me/mfa/totp/disable')
  @HttpCode(200)
  @ZodApiBody(DisableTotpDto)
  @ApiOperation({
    summary: 'Turn two-step verification off',
    description:
      'Authenticated. Requires a current authenticator code or a recovery code. Refused for ' +
      'accounts where two-step verification is mandatory.',
  })
  @ApiResponse({ status: 200, description: 'Two-step verification is off' })
  @ApiResponse({ status: 401, description: 'MFA_INVALID' })
  @ApiResponse({ status: 403, description: 'PERMISSION_DENIED (mandatory for this account)' })
  async disableTotp(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: DisableTotpDto,
  ): Promise<{ enabled: false }> {
    await this.mfa.disable(actor, {
      ...(body.code !== undefined ? { code: body.code } : {}),
      ...(body.recoveryCode !== undefined ? { recoveryCode: body.recoveryCode } : {}),
    });
    return { enabled: false };
  }
}
