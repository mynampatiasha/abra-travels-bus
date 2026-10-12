import {
  GoogleSignInController,
  ClientPhoneSignInController,
  ClientLoginMethodsController,
  GoogleSignInService,
  FirebaseGoogleVerifier,
} from './google_sign_in';
import { USER_MODEL, userSchema } from '../users/schemas/user.schema';
import { OPERATOR_MODEL, operatorSchema } from '../operators/schemas/operator.schema';
import { ROLE_MODEL, roleSchema } from '../rbac/schemas/role.schema';
import {
  ONBOARDING_SUBMISSION_MODEL,
  onboardingSubmissionSchema,
} from '../onboarding/schemas/onboarding-submission.schema';
import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { MongooseModule } from '@nestjs/mongoose';
import { CryptoModule } from '../../common/crypto/crypto.module';
import { RateLimitModule } from '../../common/rate-limit/rate-limit.module';
import { OtpDeliveryModule } from '../../integrations/otp-delivery/otp-delivery.module';
import { CustomersModule } from '../customers/customers.module';
import { SessionsModule } from '../sessions/sessions.module';
import { UsersModule } from '../users/users.module';
import { AuthenticationController } from './controllers/authentication.controller';
import { CurrentUserController } from './controllers/current-user.controller';
import { AccessTokenAuthenticationGuard } from './guards/access-token-authentication.guard';
import { OtpChallengeRepository } from './repositories/otp-challenge.repository';
import { OTP_CHALLENGE_MODEL, otpChallengeSchema } from './schemas/otp-challenge.schema';
import { AccessTokenService } from './services/access-token.service';
import { AuthSessionIssuer } from './services/auth-session-issuer.service';
import { LoginThrottleService } from './services/login-throttle.service';
import { MfaService } from './services/mfa.service';
import { OtpLoginService } from './services/otp-login.service';
import { OtpService } from './services/otp.service';
import { PasswordHasher } from './services/password-hasher.service';
import { PasswordLoginService } from './services/password-login.service';
import { PasswordManagementService } from './services/password-management.service';
import { TokenRefreshService } from './services/token-refresh.service';

/**
 * `authentication` — Identity domain (documentation/authentication.md). Passwords (Argon2id),
 * phone OTP, access and refresh tokens, temporary lockout, TOTP two-step verification, and the
 * global guard that turns a verified access token into the request actor.
 *
 * Authorization (roles, permissions, overrides) is `rbac`, Phase 2 step 8.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: OTP_CHALLENGE_MODEL, schema: otpChallengeSchema },
      { name: USER_MODEL, schema: userSchema },
      { name: OPERATOR_MODEL, schema: operatorSchema },
      { name: ROLE_MODEL, schema: roleSchema },
      { name: ONBOARDING_SUBMISSION_MODEL, schema: onboardingSubmissionSchema },
    ]),
    CryptoModule,
    RateLimitModule,
    OtpDeliveryModule,
    UsersModule,
    CustomersModule,
    SessionsModule,
  ],
  controllers: [
    AuthenticationController,
    CurrentUserController,
    GoogleSignInController,
    ClientPhoneSignInController,
    ClientLoginMethodsController,
  ],
  providers: [
    GoogleSignInService,
    FirebaseGoogleVerifier,
    PasswordHasher,
    AccessTokenService,
    OtpChallengeRepository,
    OtpService,
    LoginThrottleService,
    MfaService,
    AuthSessionIssuer,
    PasswordLoginService,
    OtpLoginService,
    PasswordManagementService,
    TokenRefreshService,
    AccessTokenAuthenticationGuard,
    // Deny by default: every route requires a valid access token unless marked @PublicEndpoint()
    { provide: APP_GUARD, useExisting: AccessTokenAuthenticationGuard },
  ],
  exports: [AccessTokenService, PasswordHasher],
})
export class AuthenticationModule {}
