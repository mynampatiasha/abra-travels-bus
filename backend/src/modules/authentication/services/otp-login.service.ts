import { Injectable, Logger } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { TransactionRunner } from '../../../database/transaction-runner.service';
import { CustomersService } from '../../customers/services/customers.service';
import { type StoredUser } from '../../users/repositories/user.repository';
import { UsersService } from '../../users/services/users.service';
import {
  type AuthenticationResult,
  AuthSessionIssuer,
  type DeviceInfo,
  type MfaRequiredResult,
} from './auth-session-issuer.service';
import { type OtpRequestResult, OtpService } from './otp.service';
import { PasswordHasher } from './password-hasher.service';
import { assertPasswordAcceptable } from './password-policy';
import { type OtpPurpose } from '../schemas/otp-challenge.schema';

export interface RegistrationInput {
  phone: string;
  code: string;
  name: string;
  email?: string;
  password?: string;
  preferredLanguage?: string;
  marketingConsent: boolean;
}

/** User types that may sign in with a phone OTP alone (authentication.md §1). */
const OTP_SIGN_IN_USER_TYPES: ReadonlySet<StoredUser['userType']> = new Set(['CUSTOMER', 'DRIVER']);

/**
 * Phone OTP sign-in and customer registration. Possession of the phone is proven by the code
 * before anything about the account is revealed or created.
 */
@Injectable()
export class OtpLoginService {
  private readonly logger = new Logger(OtpLoginService.name);

  constructor(
    private readonly otp: OtpService,
    private readonly users: UsersService,
    private readonly customers: CustomersService,
    private readonly transactions: TransactionRunner,
    private readonly issuer: AuthSessionIssuer,
    private readonly hasher: PasswordHasher,
  ) {}

  /**
   * SIGN_IN codes are sent to any valid number (the account is created on first verification).
   * PASSWORD_RESET codes are sent only to an active account, but the answer is identical either
   * way, so the endpoint cannot be used to find out which numbers are registered.
   */
  async requestCode(
    phone: string,
    purpose: OtpPurpose,
    client: ClientRequestInfo,
  ): Promise<OtpRequestResult> {
    if (purpose === 'SIGN_IN') return this.otp.request(phone, purpose, client);
    const user = await this.users.findByPhone(phone);
    return this.otp.request(phone, purpose, client, { deliver: user?.status === 'ACTIVE' });
  }

  /** Signs in the owner of the phone, creating the customer account on first use. */
  async signIn(
    input: { phone: string; code: string },
    device: DeviceInfo,
    client: ClientRequestInfo,
  ): Promise<AuthenticationResult | MfaRequiredResult> {
    await this.otp.verify(input.phone, 'SIGN_IN', input.code);

    const existing = await this.users.findByPhone(input.phone);
    if (!existing) {
      const created = await this.createCustomer({ phone: input.phone, marketingConsent: false });
      return this.issuer.issue(created, device, client, { mfaVerified: false });
    }

    if (!OTP_SIGN_IN_USER_TYPES.has(existing.userType)) {
      throw new ApiException(
        'PERMISSION_DENIED',
        'This account signs in with its password, not with a verification code.',
      );
    }
    this.issuer.assertCanSignIn(existing);
    if (existing.mfa.enabled) return this.issuer.mfaChallengeFor(existing);
    return this.issuer.issue(existing, device, client, { mfaVerified: false });
  }

  /** Customer sign-up with profile details; the phone must be verified by a SIGN_IN code. */
  async register(
    input: RegistrationInput,
    device: DeviceInfo,
    client: ClientRequestInfo,
  ): Promise<AuthenticationResult> {
    if (input.password !== undefined) {
      assertPasswordAcceptable(input.password, input);
    }
    await this.otp.verify(input.phone, 'SIGN_IN', input.code);

    const passwordHash =
      input.password !== undefined ? await this.hasher.hash(input.password) : undefined;
    const user = await this.createCustomer({
      phone: input.phone,
      name: input.name,
      ...(input.email ? { email: input.email } : {}),
      ...(passwordHash ? { passwordHash } : {}),
      ...(input.preferredLanguage ? { preferredLanguage: input.preferredLanguage } : {}),
      marketingConsent: input.marketingConsent,
    });
    return this.issuer.issue(user, device, client, { mfaVerified: false });
  }

  /** User and customer profile are created together or not at all. */
  private async createCustomer(input: {
    phone: string;
    name?: string;
    email?: string;
    passwordHash?: string;
    preferredLanguage?: string;
    marketingConsent: boolean;
  }): Promise<StoredUser> {
    const { marketingConsent, ...userInput } = input;
    const user = await this.transactions.run(async (session) => {
      const created = await this.users.createCustomer(userInput, session);
      await this.customers.createForUser(created._id, { marketingConsent }, session);
      return created;
    });
    this.logger.log({ userId: user._id.toHexString() }, 'Customer account created');
    return user;
  }
}
