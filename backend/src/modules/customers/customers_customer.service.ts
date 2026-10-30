import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { SessionsService } from '../sessions/services/sessions.service';
import { USER_MODEL, type User } from '../users/schemas/user.schema';
import { CUSTOMER_MODEL, type Customer } from './schemas/customer.schema';

/*
 * The customer's own profile: read it, change the name, email and language, and delete the account.
 * Signing out of all devices already exists (`POST /auth/logout-all`).
 */

/** The languages the apps offer. */
export const CUSTOMER_LANGUAGES = ['en', 'hi', 'te', 'kn', 'ta', 'ml', 'mr', 'bn'] as const;
export type CustomerLanguage = (typeof CUSTOMER_LANGUAGES)[number];

/** A booking in one of these states still has a journey to take or money to settle. */
export const UPCOMING_BOOKING_STATUSES = [
  'SEAT_LOCKED',
  'PAYMENT_PENDING',
  'CONFIRMED',
  'PARTIALLY_CANCELLED',
] as const;

export const DELETED_CUSTOMER_NAME = 'Deleted customer';

export type StoredCustomerUser = User & { _id: Types.ObjectId };

export interface ProfileView {
  id: string;
  name: string;
  email: string;
  phone: string;
  language: CustomerLanguage;
  signInMethod: 'google' | 'apple' | 'whatsapp' | 'password';
  emailVerified: boolean;
  joinedAt: string | null;
}

export interface ProfileInput {
  name?: string | undefined;
  email?: string | undefined;
  language?: CustomerLanguage | undefined;
}

/** How the person signs in, from what the account holds. */
export function signInMethodOf(user: User): ProfileView['signInMethod'] {
  if (user.googleFirebaseUid || user.authProvider === 'google') return 'google';
  if (user.appleFirebaseUid || user.authProvider === 'apple') return 'apple';
  if (user.passwordHash && user.authProvider !== 'whatsapp') return 'password';
  return 'whatsapp';
}

export function profileViewOf(user: StoredCustomerUser): ProfileView {
  const language = CUSTOMER_LANGUAGES.find((code) => code === user.preferredLanguage) ?? 'en';
  return {
    id: user._id.toHexString(),
    name: user.name ?? '',
    email: user.email ?? '',
    phone: user.phone ?? '',
    language,
    signInMethod: signInMethodOf(user),
    emailVerified: Boolean(user.emailVerifiedAt),
    joinedAt: user.createdAt ? user.createdAt.toISOString() : null,
  };
}

export function fieldError(path: string, message: string): ApiException {
  return new ApiException('VALIDATION_FAILED', 'Request validation failed', {
    location: 'body',
    issues: [{ path, code: 'custom', message }],
  });
}

/**
 * Refuses while the customer still has a booking to travel on. Read-only: the bookings collection
 * is looked at by customer and status, and nothing else is imported from the bookings module.
 */
export async function assertNoUpcomingBookings(
  connection: Connection,
  customerId: Types.ObjectId,
  who: 'you' | 'this customer',
): Promise<void> {
  const count = await connection
    .collection('bookings')
    .countDocuments({ customerId, status: { $in: [...UPCOMING_BOOKING_STATUSES] } });
  if (count > 0) {
    throw new ApiException(
      'INVALID_STATE_TRANSITION',
      who === 'you'
        ? `You still have ${count === 1 ? 'a booking' : `${count} bookings`} to travel on. Cancel or complete ${count === 1 ? 'it' : 'them'} first, then delete your account.`
        : `This customer still has ${count === 1 ? 'a booking' : `${count} bookings`} to travel on. They must be cancelled or completed first.`,
    );
  }
}

@Injectable()
export class CustomersCustomerService {
  constructor(
    @InjectModel(USER_MODEL) private readonly users: Model<User>,
    @InjectModel(CUSTOMER_MODEL) private readonly customers: Model<Customer>,
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly sessions: SessionsService,
  ) {}

  async get(actor: AuthenticatedUserActor): Promise<ProfileView> {
    return profileViewOf(await this.mine(actor));
  }

  async update(
    actor: AuthenticatedUserActor,
    input: ProfileInput,
    client: ClientRequestInfo,
  ): Promise<ProfileView> {
    const before = await this.mine(actor);
    const set: Record<string, unknown> = {};
    if (input.name !== undefined) {
      const name = input.name.trim();
      if (!name) throw fieldError('name', 'Enter your name');
      set.name = name;
    }
    if (input.email !== undefined) {
      const email = input.email.trim().toLowerCase();
      if (!email) throw fieldError('email', 'Enter your email address');
      if (email !== before.email) {
        set.email = email;
        set.emailVerifiedAt = null;
      }
    }
    if (input.language !== undefined) set.preferredLanguage = input.language;
    // The email is required: an account that has none must give one with its first save
    if (!before.email && set.email === undefined) {
      throw fieldError('email', 'Enter your email address');
    }
    if (Object.keys(set).length === 0) return profileViewOf(before);

    try {
      const saved = await this.changes.run({
        actor,
        client,
        action: 'customer.updated',
        entityType: 'customer',
        before: this.describe(before),
        apply: async (session) => {
          const stored = await this.users
            .findOneAndUpdate(
              { _id: before._id, userType: 'CUSTOMER' },
              { $set: set },
              { returnDocument: 'after', session },
            )
            .lean<StoredCustomerUser>()
            .exec();
          if (!stored) throw new ApiException('RESOURCE_NOT_FOUND', 'This account no longer exists.');
          return stored;
        },
        describe: (user) => this.describe(user),
      });
      return profileViewOf(saved);
    } catch (error) {
      if (isDuplicateKeyError(error)) {
        throw new ApiException(
          'ALREADY_REGISTERED',
          'This email is already used by another account.',
        );
      }
      throw error;
    }
  }

  /**
   * Deletes the account: the personal data goes, the bookings and payments stay as financial
   * records. Refused while a booking is still to be travelled on.
   */
  async deleteAccount(actor: AuthenticatedUserActor, client: ClientRequestInfo): Promise<void> {
    const before = await this.mine(actor);
    await assertNoUpcomingBookings(this.connection, before._id, 'you');
    await this.changes.run({
      actor,
      client,
      action: 'customer.account-deleted',
      entityType: 'customer',
      before: this.describe(before),
      apply: async (session) => {
        const now = new Date();
        const stored = await this.users
          .findOneAndUpdate(
            { _id: before._id, userType: 'CUSTOMER' },
            {
              $set: {
                name: DELETED_CUSTOMER_NAME,
                status: 'DEACTIVATED',
                passwordHash: null,
                emailVerifiedAt: null,
                phoneVerifiedAt: null,
              },
              $unset: {
                email: '',
                phone: '',
                firebaseUid: '',
                googleFirebaseUid: '',
                appleFirebaseUid: '',
                authProvider: '',
              },
              $inc: { permissionVersion: 1 },
            },
            { returnDocument: 'after', session },
          )
          .lean<StoredCustomerUser>()
          .exec();
        if (!stored) throw new ApiException('RESOURCE_NOT_FOUND', 'This account no longer exists.');
        await this.customers
          .updateOne(
            { userId: before._id },
            {
              $set: {
                deletedAt: now,
                anonymisedAt: now,
                'notificationPreferences.email': false,
                'notificationPreferences.sms': false,
                'notificationPreferences.whatsapp': false,
                'notificationPreferences.push': false,
                'notificationPreferences.marketing': false,
              },
            },
            { session },
          )
          .exec();
        await this.sessions.revokeAllForUser(before._id.toHexString(), 'ACCOUNT_DISABLED', {
          dbSession: session,
        });
        return stored;
      },
      // The audit trail keeps who deleted what, never the personal data
      describe: (user) => ({ name: DELETED_CUSTOMER_NAME, status: user.status }),
    });
  }

  private describe(user: User): Record<string, unknown> {
    return { name: user.name ?? '', language: user.preferredLanguage, status: user.status };
  }

  private async mine(actor: AuthenticatedUserActor): Promise<StoredCustomerUser> {
    if (actor.userType !== 'CUSTOMER') {
      throw new ApiException('PERMISSION_DENIED', 'Only a customer account has a customer profile.');
    }
    const user = await this.users
      .findOne({ _id: new Types.ObjectId(actor.userId), userType: 'CUSTOMER' })
      .lean<StoredCustomerUser>()
      .exec();
    if (!user) throw new ApiException('RESOURCE_NOT_FOUND', 'This account no longer exists.');
    return user;
  }
}
