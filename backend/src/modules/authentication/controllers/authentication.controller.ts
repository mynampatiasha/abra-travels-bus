import { Body, Controller, HttpCode, Post, Req, Res } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request, type Response } from 'express';
import { PublicEndpoint } from '../../../common/decorators/public-endpoint.decorator';
import { ApiException } from '../../../common/errors/api-exception';
import { clientRequestInfo } from '../../../common/http/client-request-info';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { AppConfigService } from '../../../config/app-config.service';
import { SessionsService } from '../../sessions/services/sessions.service';
import {
  CompleteMfaLoginDto,
  LogoutDto,
  PasswordLoginDto,
  RefreshTokenDto,
  RegisterCustomerDto,
  RequestOtpDto,
  ResetPasswordDto,
  VerifyOtpDto,
} from '../dto/authentication.dto';
import {
  clearRefreshTokenCookie,
  deliverRefreshToken,
  refreshTokenFrom,
} from '../refresh-token-cookie';
import {
  type AuthenticationResult,
  type MfaRequiredResult,
} from '../services/auth-session-issuer.service';
import { OtpLoginService } from '../services/otp-login.service';
import { type OtpRequestResult } from '../services/otp.service';
import { PasswordLoginService } from '../services/password-login.service';
import { PasswordManagementService } from '../services/password-management.service';
import { TokenRefreshService } from '../services/token-refresh.service';

const TOKENS_DESCRIPTION =
  'Access token (Bearer, short-lived) and refresh token. With device.clientType = WEB the ' +
  'refresh token is set as an HttpOnly cookie and left empty in the body.';

/**
 * Sign-in, sign-up and token endpoints (authentication.md §6). All public: this is where a caller
 * becomes authenticated. Every limit is enforced on the server.
 */
@ApiTags('authentication')
@PublicEndpoint()
@Controller('auth')
export class AuthenticationController {
  constructor(
    private readonly otpLogin: OtpLoginService,
    private readonly passwordLogin: PasswordLoginService,
    private readonly passwords: PasswordManagementService,
    private readonly tokenRefresh: TokenRefreshService,
    private readonly sessions: SessionsService,
    private readonly config: AppConfigService,
  ) {}

  @Post('otp/send')
  @HttpCode(200)
  @ZodApiBody(RequestOtpDto)
  @ApiOperation({
    summary: 'Send a verification code by SMS',
    description:
      'Public. purpose SIGN_IN (default) or PASSWORD_RESET. The response is the same whether or ' +
      'not an account exists for the number. Limited per number and per IP, with a cooldown ' +
      'between sends. The code is never returned by the API.',
  })
  @ApiResponse({ status: 200, description: 'expiresInSeconds, resendAfterSeconds' })
  @ApiResponse({ status: 429, description: 'RATE_LIMITED (details.retryAfterSeconds)' })
  sendOtp(@Body() body: RequestOtpDto, @Req() request: Request): Promise<OtpRequestResult> {
    return this.otpLogin.requestCode(body.phone, body.purpose, clientRequestInfo(request));
  }

  @Post('otp/verify')
  @HttpCode(200)
  @ZodApiBody(VerifyOtpDto)
  @ApiOperation({
    summary: 'Sign in with a verification code',
    description:
      'Public. Signs in the owner of the phone number; creates the customer account on first ' +
      `use. ${TOKENS_DESCRIPTION} Returns { mfaRequired, mfaToken } for accounts with two-step ` +
      'verification. A wrong, expired, used or replaced code answers OTP_INVALID.',
  })
  @ApiResponse({ status: 200, description: 'Tokens, or an MFA challenge' })
  @ApiResponse({ status: 401, description: 'OTP_INVALID' })
  async verifyOtp(
    @Body() body: VerifyOtpDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<AuthenticationResult | MfaRequiredResult> {
    const result = await this.otpLogin.signIn(body, body.device, clientRequestInfo(request));
    return this.deliver(response, result, body.device.clientType);
  }

  @Post('register')
  @ZodApiBody(RegisterCustomerDto)
  @ApiOperation({
    summary: 'Register a customer account',
    description:
      'Public. Creates a customer with name and optional email and password. The phone number ' +
      'must be verified with a SIGN_IN code from /auth/otp/send. Terms must be accepted. ' +
      TOKENS_DESCRIPTION,
  })
  @ApiResponse({ status: 201, description: 'Account created; tokens returned' })
  @ApiResponse({ status: 401, description: 'OTP_INVALID' })
  @ApiResponse({ status: 409, description: 'ALREADY_REGISTERED' })
  async register(
    @Body() body: RegisterCustomerDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<AuthenticationResult> {
    const { device } = body;
    const result = await this.otpLogin.register(
      {
        phone: body.phone,
        code: body.code,
        name: body.name,
        marketingConsent: body.marketingConsent,
        ...(body.email !== undefined ? { email: body.email } : {}),
        ...(body.password !== undefined ? { password: body.password } : {}),
        ...(body.preferredLanguage !== undefined
          ? { preferredLanguage: body.preferredLanguage }
          : {}),
      },
      device,
      clientRequestInfo(request),
    );
    return deliverRefreshToken(response, this.config, result, device.clientType);
  }

  @Post('login')
  @HttpCode(200)
  @ZodApiBody(PasswordLoginDto)
  @ApiOperation({
    summary: 'Sign in with email or phone and password',
    description:
      `Public. ${TOKENS_DESCRIPTION} Returns { mfaRequired, mfaToken } when the account uses ` +
      'two-step verification. Unknown identifier and wrong password both answer ' +
      'INVALID_CREDENTIALS. Repeated failures lock the identifier temporarily (ACCOUNT_LOCKED).',
  })
  @ApiResponse({ status: 200, description: 'Tokens, or an MFA challenge' })
  @ApiResponse({ status: 401, description: 'INVALID_CREDENTIALS' })
  @ApiResponse({ status: 423, description: 'ACCOUNT_LOCKED (details.retryAfterSeconds)' })
  async login(
    @Body() body: PasswordLoginDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<AuthenticationResult | MfaRequiredResult> {
    const result = await this.passwordLogin.login(body, body.device, clientRequestInfo(request));
    return this.deliver(response, result, body.device.clientType);
  }

  @Post('mfa/verify')
  @HttpCode(200)
  @ZodApiBody(CompleteMfaLoginDto)
  @ApiOperation({
    summary: 'Complete sign-in with the second factor',
    description:
      'Public. mfaToken from the first step plus either the 6-digit authenticator code or a ' +
      `recovery code. ${TOKENS_DESCRIPTION} A code cannot be used twice.`,
  })
  @ApiResponse({ status: 200, description: 'Tokens' })
  @ApiResponse({ status: 401, description: 'MFA_INVALID' })
  @ApiResponse({ status: 423, description: 'ACCOUNT_LOCKED' })
  async completeMfa(
    @Body() body: CompleteMfaLoginDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<AuthenticationResult> {
    const result = await this.passwordLogin.completeMfa(
      body,
      body.device,
      clientRequestInfo(request),
    );
    return deliverRefreshToken(response, this.config, result, body.device.clientType);
  }

  @Post('refresh')
  @HttpCode(200)
  @ZodApiBody(RefreshTokenDto)
  @ApiOperation({
    summary: 'Exchange the refresh token for new tokens',
    description:
      'Public. Rotation: the presented refresh token stops working and a new one is returned. ' +
      'Presenting a replaced token again revokes the whole session (theft detection). Web ' +
      'clients send the cookie together with the header X-Abra-Client: web.',
  })
  @ApiResponse({ status: 200, description: 'New access token and refresh token' })
  @ApiResponse({ status: 401, description: 'UNAUTHENTICATED — sign in again' })
  async refresh(
    @Body() body: RefreshTokenDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<AuthenticationResult> {
    const fromCookie = body.refreshToken === undefined;
    const token = refreshTokenFrom(request, body.refreshToken);
    if (token === undefined)
      throw new ApiException('UNAUTHENTICATED', 'Authentication is required');
    try {
      const result = await this.tokenRefresh.refresh(token, clientRequestInfo(request));
      return deliverRefreshToken(response, this.config, result, fromCookie ? 'WEB' : 'MOBILE');
    } catch (error) {
      if (fromCookie) clearRefreshTokenCookie(response, this.config);
      throw error;
    }
  }

  @Post('logout')
  @HttpCode(200)
  @ZodApiBody(LogoutDto)
  @ApiOperation({
    summary: 'Sign out this device',
    description:
      'Public (works even when the access token has expired). Revokes the session of the ' +
      'presented refresh token and clears the web cookie. Web clients send the cookie together ' +
      'with the header X-Abra-Client: web; a cookie without it is ignored (401). Otherwise ' +
      'always answers 200.',
  })
  @ApiResponse({ status: 200, description: 'Signed out' })
  @ApiResponse({ status: 401, description: 'UNAUTHENTICATED (cookie without X-Abra-Client)' })
  async logout(
    @Body() body: LogoutDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ): Promise<{ signedOut: true }> {
    // Same rule as /auth/refresh: the cookie counts only with the X-Abra-Client header (CSRF)
    const token = refreshTokenFrom(request, body.refreshToken);
    await this.sessions.revokeByRefreshToken(token);
    clearRefreshTokenCookie(response, this.config);
    return { signedOut: true };
  }

  @Post('password/reset')
  @HttpCode(200)
  @ZodApiBody(ResetPasswordDto)
  @ApiOperation({
    summary: 'Set a new password with a verification code',
    description:
      'Public. Forgotten password: request a code with /auth/otp/send (purpose PASSWORD_RESET), ' +
      'then send it here with the new password. Signs out every device of the account.',
  })
  @ApiResponse({ status: 200, description: 'Password changed' })
  @ApiResponse({ status: 401, description: 'OTP_INVALID' })
  async resetPassword(@Body() body: ResetPasswordDto): Promise<{ passwordReset: true }> {
    await this.passwords.resetWithOtp(body);
    return { passwordReset: true };
  }

  private deliver<T extends AuthenticationResult | MfaRequiredResult>(
    response: Response,
    result: T,
    clientType: 'MOBILE' | 'WEB',
  ): T | AuthenticationResult {
    return 'mfaRequired' in result
      ? result
      : deliverRefreshToken(response, this.config, result, clientType);
  }
}
