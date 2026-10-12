import { Injectable } from '@nestjs/common';
import { type ClientSession, type Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import {
  normalizeEmail,
  normalizePhoneNumber,
} from '../../../common/validation/contact-identifiers';
import { type StoredUser, UserRepository } from '../repositories/user.repository';
import { type User } from '../schemas/user.schema';

/** What a user may see about their own account. Never contains credentials or MFA secrets. */
export interface UserProfile {
  id: string;
  name: string | null;
  email: string | null;
  phone: string | null;
  emailVerified: boolean;
  phoneVerified: boolean;
  userType: User['userType'];
  status: User['status'];
  operatorId: string | null;
  partnerId: string | null;
  preferredLanguage: string;
  hasPassword: boolean;
  mfaEnabled: boolean;
  lastLoginAt: string | null;
  createdAt: string | null;
}

export interface NewCustomerInput {
  phone: string;
  name?: string;
  email?: string;
  passwordHash?: string;
  preferredLanguage?: string;
}

const DUPLICATE_KEY_ERROR = 11000;

export function isDuplicateKeyError(error: unknown): error is { keyPattern?: object } {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { code?: unknown }).code === DUPLICATE_KEY_ERROR
  );
}

export function toUserProfile(user: StoredUser): UserProfile {
  return {
    id: user._id.toHexString(),
    name: user.name ?? null,
    email: user.email ?? null,
    phone: user.phone ?? null,
    emailVerified: user.emailVerifiedAt != null,
    phoneVerified: user.phoneVerifiedAt != null,
    userType: user.userType,
    status: user.status,
    operatorId: user.operatorId?.toHexString() ?? null,
    partnerId: user.partnerId?.toHexString() ?? null,
    preferredLanguage: user.preferredLanguage,
    hasPassword: Boolean(user.passwordHash),
    mfaEnabled: user.mfa.enabled,
    lastLoginAt: user.lastLoginAt?.toISOString() ?? null,
    createdAt: user.createdAt?.toISOString() ?? null,
  };
}

/** The users collection as seen by the rest of the backend. Owns `UserRepository`. */
@Injectable()
export class UsersService {
  constructor(private readonly repository: UserRepository) {}

  findById(id: string, session?: ClientSession): Promise<StoredUser | null> {
    return this.repository.findById(id, { session });
  }

  findByPhone(phone: string, session?: ClientSession): Promise<StoredUser | null> {
    return this.repository.findByPhone(phone, { session });
  }

  /** Sign-in identifier: an email address or a phone number. Unknown formats find nothing. */
  findByLoginIdentifier(identifier: string): Promise<StoredUser | null> {
    if (identifier.includes('@')) return this.repository.findByEmail(normalizeEmail(identifier));
    const phone = normalizePhoneNumber(identifier);
    return phone ? this.repository.findByPhone(phone) : Promise.resolve(null);
  }

  /** Throws RESOURCE_NOT_FOUND for a missing user (callers pass the authenticated user id). */
  async getById(id: string): Promise<StoredUser> {
    const user = await this.repository.findById(id);
    if (!user) throw new ApiException('RESOURCE_NOT_FOUND', 'User not found');
    return user;
  }

  /**
   * Creates a customer whose phone number has just been verified by OTP. A duplicate phone or
   * email surfaces as ALREADY_REGISTERED; the unique indexes make this race-free.
   */
  async createCustomer(input: NewCustomerInput, session: ClientSession): Promise<StoredUser> {
    const now = new Date();
    try {
      return await this.repository.insert(
        {
          phone: input.phone,
          phoneVerifiedAt: now,
          ...(input.name ? { name: input.name } : {}),
          ...(input.email ? { email: input.email } : {}),
          ...(input.passwordHash
            ? { passwordHash: input.passwordHash, passwordChangedAt: now }
            : {}),
          userType: 'CUSTOMER',
          roleIds: [],
          dataScope: { type: 'OWN_RECORDS', operatorIds: [] },
          status: 'ACTIVE',
          preferredLanguage: input.preferredLanguage ?? 'en',
        },
        { session },
      );
    } catch (error) {
      // A transient transaction error must reach TransactionRunner unchanged so it can retry
      if (!isDuplicateKeyError(error)) throw error;
      throw new ApiException(
        'ALREADY_REGISTERED',
        'An account already exists for this phone number or email',
      );
    }
  }

  async setPassword(id: string, passwordHash: string, session?: ClientSession): Promise<void> {
    await this.repository.setFields(
      id,
      { passwordHash, passwordChangedAt: new Date() },
      { session },
    );
  }

  async recordLogin(id: string, session?: ClientSession): Promise<void> {
    await this.repository.setFields(id, { lastLoginAt: new Date() }, { session });
  }

  /** Authorization changes (roles, data scope, overrides) always bump `permissionVersion`. */
  applyAuthorizationChange(
    id: Types.ObjectId,
    change: { roleIds?: Types.ObjectId[]; dataScope?: User['dataScope'] },
    session: ClientSession,
  ): Promise<boolean> {
    return this.repository.applyAuthorizationChange(id, change, session);
  }

  bumpPermissionVersionForRoles(
    roleIds: readonly Types.ObjectId[],
    session: ClientSession,
  ): Promise<number> {
    return this.repository.bumpPermissionVersionForRoles(roleIds, session);
  }

  setPendingMfaSecret(id: string, pendingSecretEncrypted: string): Promise<boolean> {
    return this.repository.setPendingMfaSecret(id, pendingSecretEncrypted);
  }

  activateMfa(
    id: string,
    pendingSecretEncrypted: string,
    recoveryCodeHashes: string[],
    timeStep: number,
  ): Promise<boolean> {
    return this.repository.activateMfa(
      id,
      pendingSecretEncrypted,
      recoveryCodeHashes,
      timeStep,
      new Date(),
    );
  }

  disableMfa(id: string): Promise<boolean> {
    return this.repository.disableMfa(id);
  }

  consumeTotpTimeStep(id: string, timeStep: number): Promise<boolean> {
    return this.repository.consumeTotpTimeStep(id, timeStep);
  }

  consumeRecoveryCode(id: string, recoveryCodeHash: string): Promise<boolean> {
    return this.repository.consumeRecoveryCode(id, recoveryCodeHash);
  }

  /**
   * Creates a platform staff account with a password. Used by the Super Admin bootstrap; staff
   * invited by an administrator arrive with user management.
   */
  async createStaff(
    input: {
      name: string;
      email: string;
      passwordHash: string;
      roleIds: Types.ObjectId[];
    },
    session: ClientSession,
  ): Promise<StoredUser> {
    const now = new Date();
    try {
      return await this.repository.insert(
        {
          name: input.name,
          email: input.email,
          emailVerifiedAt: now,
          passwordHash: input.passwordHash,
          passwordChangedAt: now,
          userType: 'STAFF',
          roleIds: input.roleIds,
          dataScope: { type: 'ALL', operatorIds: [] },
          status: 'ACTIVE',
          preferredLanguage: 'en',
        },
        { session },
      );
    } catch (error) {
      if (!isDuplicateKeyError(error)) throw error;
      throw new ApiException('ALREADY_REGISTERED', 'An account already exists for this email');
    }
  }

  /**
   * Creates the first account of a bus operator, the owner who accepted an invitation. Sees only
   * its own operator's data. The email address is already proven: the invitation link was sent to
   * it.
   */
  async createOperatorAdmin(
    input: {
      name: string;
      email: string;
      phone?: string | undefined;
      passwordHash: string;
      roleIds: Types.ObjectId[];
      operatorId: Types.ObjectId;
    },
    session: ClientSession,
  ): Promise<StoredUser> {
    const now = new Date();
    try {
      return await this.repository.insert(
        {
          name: input.name,
          email: input.email,
          emailVerifiedAt: now,
          ...(input.phone ? { phone: input.phone } : {}),
          passwordHash: input.passwordHash,
          passwordChangedAt: now,
          userType: 'OPERATOR_STAFF',
          roleIds: input.roleIds,
          operatorId: input.operatorId,
          dataScope: { type: 'OWN_OPERATOR', operatorIds: [input.operatorId] },
          status: 'ACTIVE',
          preferredLanguage: 'en',
        },
        { session },
      );
    } catch (error) {
      if (!isDuplicateKeyError(error)) throw error;
      throw new ApiException('ALREADY_REGISTERED', 'An account already exists for this email');
    }
  }

  /** Active accounts holding any of the roles, optionally of one operator. For notifications. */
  findActiveByRoleIds(
    roleIds: readonly Types.ObjectId[],
    filter: { operatorId?: Types.ObjectId | undefined } = {},
  ): Promise<StoredUser[]> {
    return this.repository.findActiveByRoleIds(roleIds, filter);
  }

  /** Number of accounts holding the role, whatever their status. */
  countWithRole(roleId: Types.ObjectId, session?: ClientSession): Promise<number> {
    return this.repository.countWithRole(roleId, { session });
  }
}
