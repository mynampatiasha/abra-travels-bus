import { randomBytes } from 'node:crypto';
import { Types } from 'mongoose';
import { FieldEncryptionService } from '../../../common/crypto/field-encryption.service';
import { ApiException } from '../../../common/errors/api-exception';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { type StoredUser } from '../../users/repositories/user.repository';
import { type UsersService } from '../../users/services/users.service';
import {
  normalizeEmail,
  normalizePhoneNumber,
} from '../../../common/validation/contact-identifiers';

/** A stored user for unit tests. Not written to any database. */
export function testUser(overrides: Partial<StoredUser> = {}): StoredUser {
  return {
    _id: new Types.ObjectId(),
    name: 'Test User',
    phone: '+919876543210',
    userType: 'CUSTOMER',
    roleIds: [],
    dataScope: { type: 'OWN_RECORDS', operatorIds: [] },
    status: 'ACTIVE',
    permissionVersion: 1,
    mfa: { enabled: false, recoveryCodeHashes: [] },
    preferredLanguage: 'en',
    ...overrides,
  };
}

/**
 * UsersService stand-in holding users in memory, with the same conditional-update semantics as
 * UserRepository (MFA activation once, TOTP step only forwards, recovery code once).
 */
export class InMemoryUsers {
  private readonly users = new Map<string, StoredUser>();

  add(user: StoredUser): StoredUser {
    this.users.set(user._id.toHexString(), user);
    return user;
  }

  get(id: string): StoredUser {
    const user = this.users.get(id);
    if (!user) throw new Error('test user missing');
    return user;
  }

  findById(id: string): Promise<StoredUser | null> {
    return Promise.resolve(this.users.get(id) ?? null);
  }

  getById(id: string): Promise<StoredUser> {
    const user = this.users.get(id);
    return user
      ? Promise.resolve(user)
      : Promise.reject(new ApiException('RESOURCE_NOT_FOUND', 'User not found'));
  }

  findByPhone(phone: string): Promise<StoredUser | null> {
    return Promise.resolve([...this.users.values()].find((user) => user.phone === phone) ?? null);
  }

  /** Same normalisation as UsersService.findByLoginIdentifier: email if it has '@', else phone. */
  findByLoginIdentifier(identifier: string): Promise<StoredUser | null> {
    const all = [...this.users.values()];
    if (identifier.includes('@')) {
      const email = normalizeEmail(identifier);
      return Promise.resolve(all.find((user) => user.email === email) ?? null);
    }
    const phone = normalizePhoneNumber(identifier);
    return Promise.resolve(phone ? (all.find((user) => user.phone === phone) ?? null) : null);
  }

  setPassword(id: string, passwordHash: string): Promise<void> {
    Object.assign(this.get(id), { passwordHash, passwordChangedAt: new Date() });
    return Promise.resolve();
  }

  recordLogin(id: string): Promise<void> {
    this.get(id).lastLoginAt = new Date();
    return Promise.resolve();
  }

  setPendingMfaSecret(id: string, pendingSecretEncrypted: string): Promise<boolean> {
    const user = this.get(id);
    if (user.mfa.enabled) return Promise.resolve(false);
    user.mfa.pendingSecretEncrypted = pendingSecretEncrypted;
    return Promise.resolve(true);
  }

  activateMfa(
    id: string,
    pendingSecretEncrypted: string,
    recoveryCodeHashes: string[],
    timeStep: number,
  ): Promise<boolean> {
    const user = this.get(id);
    if (user.mfa.enabled || user.mfa.pendingSecretEncrypted !== pendingSecretEncrypted) {
      return Promise.resolve(false);
    }
    user.mfa = {
      enabled: true,
      secretEncrypted: pendingSecretEncrypted,
      pendingSecretEncrypted: null,
      recoveryCodeHashes,
      lastUsedTimeStep: timeStep,
      enabledAt: new Date(),
    };
    user.permissionVersion += 1;
    return Promise.resolve(true);
  }

  disableMfa(id: string): Promise<boolean> {
    const user = this.get(id);
    if (!user.mfa.enabled) return Promise.resolve(false);
    user.mfa = { enabled: false, recoveryCodeHashes: [] };
    user.permissionVersion += 1;
    return Promise.resolve(true);
  }

  consumeTotpTimeStep(id: string, timeStep: number): Promise<boolean> {
    const user = this.get(id);
    const last = user.mfa.lastUsedTimeStep;
    if (!user.mfa.enabled || (last != null && last >= timeStep)) return Promise.resolve(false);
    user.mfa.lastUsedTimeStep = timeStep;
    return Promise.resolve(true);
  }

  consumeRecoveryCode(id: string, hash: string): Promise<boolean> {
    const user = this.get(id);
    const index = user.mfa.recoveryCodeHashes.indexOf(hash);
    if (!user.mfa.enabled || index < 0) return Promise.resolve(false);
    user.mfa.recoveryCodeHashes.splice(index, 1);
    return Promise.resolve(true);
  }

  asService(): UsersService {
    return this as unknown as UsersService;
  }
}

export function testEncryption(): FieldEncryptionService {
  return new FieldEncryptionService(
    configOf({ FIELD_ENCRYPTION_KEY: randomBytes(32).toString('base64') }),
  );
}

export async function failureOf(work: Promise<unknown>): Promise<ApiException> {
  const error: unknown = await work.then(
    () => undefined,
    (caught: unknown) => caught,
  );
  if (!(error instanceof ApiException)) {
    throw new Error(`Expected an ApiException, got: ${String(error)}`);
  }
  return error;
}
