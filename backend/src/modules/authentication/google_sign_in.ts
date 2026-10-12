/* eslint-disable max-lines -- Client social/phone sign-in and verified linking stay in one feature file. */
import { readFileSync } from 'node:fs';
import { Injectable, Controller, Get, Post, Body, Req, Res, HttpCode } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { type Request, type Response } from 'express';
import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { z } from 'zod';
import { AppConfigService } from '../../config/app-config.service';
import { phoneNumberSchema } from '../../common/validation/contact-identifiers';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { OtpService } from './services/otp.service';
import { PublicEndpoint } from '../../common/decorators/public-endpoint.decorator';
import { ApiException } from '../../common/errors/api-exception';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { TransactionRunner } from '../../database/transaction-runner.service';
import { USER_MODEL, type User } from '../users/schemas/user.schema';
import { type StoredUser } from '../users/repositories/user.repository';
import { CustomersService } from '../customers/services/customers.service';
import { OPERATOR_MODEL, type Operator } from '../operators/schemas/operator.schema';
import { ROLE_MODEL, type Role } from '../rbac/schemas/role.schema';
import {
  ONBOARDING_SUBMISSION_MODEL,
  type OnboardingSubmission,
} from '../onboarding/schemas/onboarding-submission.schema';
import { AuthSessionIssuer } from './services/auth-session-issuer.service';
import { LoginThrottleService } from './services/login-throttle.service';
import { PasswordHasher } from './services/password-hasher.service';
import { deliverRefreshToken } from './refresh-token-cookie';

export class GoogleSignInDto extends createZodDto(
  z
    .object({
      idToken: z.string().min(20).max(10000),
      audience: z.enum(['CUSTOMER', 'CLIENT']),
      acceptTerms: z.literal(true),
      linkPassword: z.string().min(1).max(128).optional(),
      device: z
        .object({
          clientType: z.enum(['WEB', 'MOBILE']),
          deviceName: z.string().max(80).optional(),
        })
        .strict(),
    })
    .strict(),
) {}

export interface GoogleIdentity {
  uid: string;
  email: string;
  name?: string;
}

@Injectable()
export class FirebaseGoogleVerifier {
  constructor(private readonly config: AppConfigService) {}
  async verify(
    token: string,
    provider: 'google.com' | 'apple.com' = 'google.com',
  ): Promise<GoogleIdentity> {
    const projectId = this.config.get('FIREBASE_PROJECT_ID');
    if (!projectId)
      throw new ApiException('SERVICE_UNAVAILABLE', 'Google sign-in is not configured.');
    try {
      let app = getApps().find((a) => a.name === 'abra-auth');
      if (!app) {
        const account = this.config.get('FCM_SERVICE_ACCOUNT_JSON');
        const credential = account
          ? cert(
              JSON.parse(
                account.trim().startsWith('{') ? account : readFileSync(account, 'utf8'),
              ) as Record<string, unknown>,
            )
          : applicationDefault();
        app = initializeApp({ projectId, credential }, 'abra-auth');
      }
      const decoded = await getAuth(app).verifyIdToken(token, true);
      if (
        decoded.firebase.sign_in_provider !== provider ||
        !decoded.email_verified ||
        !decoded.email
      )
        throw new Error('Unverified provider');
      return {
        uid: decoded.uid,
        email: decoded.email.toLowerCase(),
        ...(decoded.name ? { name: String(decoded.name).slice(0, 120) } : {}),
      };
    } catch {
      throw new ApiException(
        'INVALID_CREDENTIALS',
        'Social sign-in could not be verified. Please try again.',
      );
    }
  }
}

@Injectable()
export class GoogleSignInService {
  constructor(
    private readonly verifier: FirebaseGoogleVerifier,
    @InjectModel(USER_MODEL) private readonly users: Model<User>,
    @InjectModel(OPERATOR_MODEL) private readonly operators: Model<Operator>,
    @InjectModel(ROLE_MODEL) private readonly roles: Model<Role>,
    @InjectModel(ONBOARDING_SUBMISSION_MODEL)
    private readonly submissions: Model<OnboardingSubmission>,
    private readonly customers: CustomersService,
    private readonly transactions: TransactionRunner,
    private readonly issuer: AuthSessionIssuer,
    private readonly throttle: LoginThrottleService,
    private readonly hasher: PasswordHasher,
    private readonly otp: OtpService,
  ) {}
  private async createAccount(
    identity: { uid?: string; email?: string; name?: string; phone?: string },
    audience: 'CLIENT' | 'CUSTOMER',
    provider: 'google' | 'apple' | 'whatsapp',
    session: import('mongoose').ClientSession,
  ) {
    const operatorId = audience === 'CLIENT' ? new Types.ObjectId() : undefined;
    const role = operatorId
      ? await this.roles.findOne({ key: 'OPERATOR_ADMIN' }).session(session)
      : undefined;
    if (operatorId && !role)
      throw new ApiException('SERVICE_UNAVAILABLE', 'Client registration is not available.');
    if (operatorId)
      await this.operators.create(
        [
          {
            _id: operatorId,
            companyName: identity.name ?? identity.email ?? 'New bus owner',
            status: 'PENDING_APPROVAL',
          },
        ],
        { session },
      );
    const [created] = await this.users.create(
      [
        {
          name: identity.name,
          email: identity.email,
          emailVerifiedAt: identity.email ? new Date() : null,
          phone: identity.phone,
          phoneVerifiedAt: identity.phone ? new Date() : null,
          firebaseUid: identity.uid,
          ...(provider === 'google'
            ? { googleFirebaseUid: identity.uid }
            : provider === 'apple'
              ? { appleFirebaseUid: identity.uid }
              : {}),
          authProvider: provider,
          userType: audience === 'CLIENT' ? 'OPERATOR_STAFF' : 'CUSTOMER',
          status: 'ACTIVE',
          roleIds: role ? [role._id] : [],
          operatorId,
          dataScope: {
            type: operatorId ? 'OWN_OPERATOR' : 'OWN_RECORDS',
            operatorIds: operatorId ? [operatorId] : [],
          },
        },
      ],
      { session },
    );
    if (!created) throw new Error('User not created');
    if (operatorId)
      await this.submissions.create(
        [
          {
            operatorId,
            subjectType: 'OPERATOR',
            kycRequired: true,
            status: 'DRAFT',
            documents: [],
            submitCount: 0,
            history: [{ at: new Date(), action: 'CREATED', byUserId: created._id }],
          },
        ],
        { session },
      );
    else await this.customers.createForUser(created._id, { marketingConsent: false }, session);
    return created.toObject();
  }
  async clientPhone(input: ClientPhoneDto, client: ReturnType<typeof clientRequestInfo>) {
    await this.throttle.assertIpAllowed(client.ip);
    await this.otp.verify(input.phone, 'SIGN_IN', input.code);
    let user = await this.users.findOne({ phone: input.phone }).lean<StoredUser>();
    if (user && user.userType !== 'OPERATOR_STAFF')
      throw new ApiException(
        'PERMISSION_DENIED',
        'This phone belongs to a different account. Sign in to your client account and link an unused phone.',
      );
    if (!user) {
      try {
        user = await this.transactions.run((session) =>
          this.createAccount({ phone: input.phone }, 'CLIENT', 'whatsapp', session),
        );
      } catch (error) {
        if ((error as { code?: number }).code === 11000)
          throw new ApiException('ALREADY_REGISTERED', 'Account already exists. Sign in again.');
        throw error;
      }
    }
    this.issuer.assertCanSignIn(user);
    if (user.mfa.enabled) return this.issuer.mfaChallengeFor(user);
    return this.issuer.issue(user, input.device, client, { mfaVerified: false });
  }
  async methods(actor: AuthenticatedUserActor) {
    if (actor.userType !== 'OPERATOR_STAFF')
      throw new ApiException('PERMISSION_DENIED', 'Client account required.');
    const user = await this.users.findById(actor.userId).lean<StoredUser>();
    if (!user) throw new ApiException('RESOURCE_NOT_FOUND', 'Account not found.');
    return {
      phone: user.phone ?? null,
      email: user.email ?? null,
      hasPassword: !!user.passwordHash,
      socialLinked: !!user.firebaseUid,
    };
  }
  async linkPhone(actor: AuthenticatedUserActor, input: LinkClientPhoneDto) {
    await this.methods(actor);
    await this.otp.verify(input.phone, 'SIGN_IN', input.code);
    try {
      await this.users.updateOne(
        { _id: actor.userId },
        { $set: { phone: input.phone, phoneVerifiedAt: new Date() } },
      );
    } catch (error) {
      if ((error as { code?: number }).code === 11000)
        throw new ApiException(
          'ALREADY_REGISTERED',
          'That phone is already linked to another account.',
        );
      throw error;
    }
    return { linked: true };
  }
  async linkSocial(actor: AuthenticatedUserActor, input: LinkClientSocialDto) {
    await this.methods(actor);
    const identity = await this.verifier.verify(
      input.idToken,
      input.provider === 'apple' ? 'apple.com' : 'google.com',
    );
    const user = await this.users.findById(actor.userId).lean<StoredUser>();
    if (!user) throw new ApiException('RESOURCE_NOT_FOUND', 'Account not found.');
    const field = input.provider === 'google' ? 'googleFirebaseUid' : 'appleFirebaseUid';
    const linked =
      user[field] ?? (user.authProvider === input.provider ? user.firebaseUid : undefined);
    if (linked && linked !== identity.uid)
      throw new ApiException(
        'INVALID_CREDENTIALS',
        'This account already has a different identity for this provider.',
      );
    const owner = await this.users.findOne({
      $or: [
        { firebaseUid: identity.uid },
        { googleFirebaseUid: identity.uid },
        { appleFirebaseUid: identity.uid },
        { email: identity.email },
      ],
      _id: { $ne: user._id },
    });
    if (owner)
      throw new ApiException(
        'ALREADY_REGISTERED',
        'That identity belongs to another account. Accounts cannot be merged here.',
      );
    try {
      const result = await this.users.updateOne(
        { _id: user._id, $or: [{ [field]: { $exists: false } }, { [field]: identity.uid }] },
        {
          $set: {
            [field]: identity.uid,
            ...(!user.firebaseUid
              ? { firebaseUid: identity.uid, authProvider: input.provider }
              : {}),
            ...(!user.email ? { email: identity.email, emailVerifiedAt: new Date() } : {}),
          },
        },
      );
      if (!result.matchedCount)
        throw new ApiException('INVALID_CREDENTIALS', 'Account linking changed. Try again.');
    } catch (error) {
      if ((error as { code?: number }).code === 11000)
        throw new ApiException('ALREADY_REGISTERED', 'That identity is already linked.');
      throw error;
    }
    return { linked: true };
  }
  async signIn(
    input: GoogleSignInDto,
    client: ReturnType<typeof clientRequestInfo>,
    provider: 'google' | 'apple' = 'google',
  ) {
    await this.throttle.assertIpAllowed(client.ip);
    const identity = await this.verifier.verify(
      input.idToken,
      provider === 'apple' ? 'apple.com' : 'google.com',
    );
    const userType = input.audience === 'CLIENT' ? 'OPERATOR_STAFF' : 'CUSTOMER';
    const providerField = provider === 'google' ? 'googleFirebaseUid' : 'appleFirebaseUid';
    let user = await this.users
      .findOne({
        $or: [
          { firebaseUid: identity.uid },
          { [providerField]: identity.uid },
          { email: identity.email },
        ],
      })
      .lean<StoredUser>();
    if (user) {
      this.issuer.assertCanSignIn(user);
      if (user.userType !== userType)
        throw new ApiException(
          'PERMISSION_DENIED',
          'Use the sign-in page for your existing account.',
        );
      const existingIdentity =
        user[providerField] ?? (user.authProvider === provider ? user.firebaseUid : undefined);
      if (existingIdentity && existingIdentity !== identity.uid)
        throw new ApiException(
          'INVALID_CREDENTIALS',
          'This email is linked to a different identity.',
        );
      if (!existingIdentity) {
        // Existing local accounts require proof of their password before linking.
        await this.throttle.assertNotLocked('password', identity.email);
        if (
          !input.linkPassword ||
          !user.passwordHash ||
          !(await this.hasher.verify(input.linkPassword, user.passwordHash))
        ) {
          await this.throttle.recordFailure('password', identity.email);
          throw new ApiException(
            'INVALID_CREDENTIALS',
            'An account already exists. Enter its current password to link Google.',
            { googleLinkRequired: true },
          );
        }
        await this.users.updateOne(
          { _id: user._id, [providerField]: { $exists: false } },
          {
            $set: {
              [providerField]: identity.uid,
              ...(!user.firebaseUid ? { firebaseUid: identity.uid, authProvider: provider } : {}),
              emailVerifiedAt: new Date(),
            },
          },
        );
        user = await this.users.findById(user._id).lean<StoredUser>();
        if (!user || user[providerField] !== identity.uid)
          throw new ApiException('INVALID_CREDENTIALS', 'Account linking failed.');
      }
    } else {
      try {
        user = await this.transactions.run(async (session) => {
          return this.createAccount(identity, input.audience, provider, session);
        });
      } catch (error) {
        if ((error as { code?: number }).code === 11000)
          throw new ApiException(
            'ALREADY_REGISTERED',
            'Your account was created by another request. Please sign in again.',
          );
        throw error;
      }
    }
    if (user.mfa.enabled) return this.issuer.mfaChallengeFor(user);
    return this.issuer.issue(user, input.device, client, { mfaVerified: false });
  }
}

@Controller('auth')
@PublicEndpoint()
export class GoogleSignInController {
  constructor(
    private readonly google: GoogleSignInService,
    private readonly config: AppConfigService,
  ) {}
  @Post('google')
  @HttpCode(200)
  async signIn(
    @Body() body: GoogleSignInDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.google.signIn(body, clientRequestInfo(request));
    return 'mfaRequired' in result
      ? result
      : deliverRefreshToken(response, this.config, result, body.device.clientType);
  }
  @Post('apple')
  @HttpCode(200)
  async apple(
    @Body() body: GoogleSignInDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.google.signIn(body, clientRequestInfo(request), 'apple');
    return 'mfaRequired' in result
      ? result
      : deliverRefreshToken(response, this.config, result, body.device.clientType);
  }
}

export class ClientPhoneDto extends createZodDto(
  z
    .object({
      phone: phoneNumberSchema,
      code: z.string().regex(/^\d{4,8}$/),
      acceptTerms: z.literal(true),
      device: z
        .object({
          clientType: z.enum(['WEB', 'MOBILE']),
          deviceName: z.string().max(80).optional(),
        })
        .strict(),
    })
    .strict(),
) {}
export class LinkClientPhoneDto extends createZodDto(
  z.object({ phone: phoneNumberSchema, code: z.string().regex(/^\d{4,8}$/) }).strict(),
) {}
export class LinkClientSocialDto extends createZodDto(
  z
    .object({ idToken: z.string().min(20).max(10000), provider: z.enum(['google', 'apple']) })
    .strict(),
) {}
@Controller('auth/client/otp')
@PublicEndpoint()
export class ClientPhoneSignInController {
  constructor(
    private readonly google: GoogleSignInService,
    private readonly config: AppConfigService,
  ) {}
  @Post('verify')
  @HttpCode(200)
  async verify(
    @Body() body: ClientPhoneDto,
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    const result = await this.google.clientPhone(body, clientRequestInfo(request));
    return 'mfaRequired' in result
      ? result
      : deliverRefreshToken(response, this.config, result, body.device.clientType);
  }
}
@Controller('client/kyc/login-methods')
@AuthenticatedOnly()
export class ClientLoginMethodsController {
  constructor(private readonly google: GoogleSignInService) {}
  @Get() get(@CurrentActor() actor: AuthenticatedUserActor) {
    return this.google.methods(actor);
  }
  @Post('phone') @HttpCode(200) phone(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: LinkClientPhoneDto,
  ) {
    return this.google.linkPhone(actor, body);
  }
  @Post('social') @HttpCode(200) social(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: LinkClientSocialDto,
  ) {
    return this.google.linkSocial(actor, body);
  }
}
