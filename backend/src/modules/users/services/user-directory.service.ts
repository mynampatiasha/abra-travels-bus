import { Injectable } from '@nestjs/common';
import { type QueryFilter, Types } from 'mongoose';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { UserDirectoryRepository } from '../repositories/user-directory.repository';
import { type User } from '../schemas/user.schema';

/** A user as listed for administrators. No credentials, no MFA data. */
export interface UserDirectoryEntry {
  id: string;
  name: string | null;
  email: string | null;
  phone: string | null;
  userType: User['userType'];
  status: User['status'];
  operatorId: string | null;
  partnerId: string | null;
  createdAt: string | null;
  lastLoginAt: string | null;
  loginMethods: string[];
}

export interface UserDirectoryQuery {
  userType?: User['userType'];
  status?: User['status'];
  operatorId?: string;
  partnerId?: string;
  search?: string;
  loginMethod?: 'google' | 'apple' | 'whatsapp' | 'password';
  page: number;
  pageSize: number;
}

/** Lists users through the actor's data scope (UserDirectoryRepository). */
@Injectable()
export class UserDirectoryService {
  constructor(private readonly repository: UserDirectoryRepository) {}

  async list(query: UserDirectoryQuery): Promise<PaginatedResult<UserDirectoryEntry>> {
    // Caller-supplied filters are AND-ed with the scope filter by the repository
    const filter: QueryFilter<User> = {
      ...(query.userType ? { userType: query.userType } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.operatorId ? { operatorId: new Types.ObjectId(query.operatorId) } : {}),
      ...(query.partnerId ? { partnerId: new Types.ObjectId(query.partnerId) } : {}),
    };
    const clauses: QueryFilter<User>[] = [];
    if (query.search) {
      const text = query.search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      clauses.push({
        $or: ['name', 'email', 'phone'].map((field) => ({
          [field]: { $regex: text, $options: 'i' },
        })),
      });
    }
    if (query.loginMethod === 'google' || query.loginMethod === 'apple') {
      const provider = query.loginMethod;
      clauses.push({
        $or: [
          { [`${provider}FirebaseUid`]: { $type: 'string' } },
          { authProvider: provider, firebaseUid: { $type: 'string' } },
        ],
      });
    } else if (query.loginMethod === 'whatsapp') {
      clauses.push({ phone: { $type: 'string' }, phoneVerifiedAt: { $ne: null } });
    } else if (query.loginMethod === 'password') {
      clauses.push({ passwordHash: { $type: 'string' } });
    }
    if (clauses.length) filter.$and = clauses;
    const [users, total] = await Promise.all([
      this.repository.findMany(filter, {
        sort: { createdAt: -1 },
        skip: (query.page - 1) * query.pageSize,
        limit: query.pageSize,
      }),
      this.repository.count(filter),
    ]);
    return new PaginatedResult(
      users.map((user) => ({
        id: user._id.toHexString(),
        name: user.name ?? null,
        email: user.email ?? null,
        phone: user.phone ?? null,
        userType: user.userType,
        status: user.status,
        operatorId: user.operatorId?.toHexString() ?? null,
        partnerId: user.partnerId?.toHexString() ?? null,
        createdAt: user.createdAt?.toISOString() ?? null,
        lastLoginAt: user.lastLoginAt?.toISOString() ?? null,
        loginMethods: [
          ...(user.googleFirebaseUid || (user.authProvider === 'google' && user.firebaseUid)
            ? ['Google']
            : []),
          ...(user.appleFirebaseUid || (user.authProvider === 'apple' && user.firebaseUid)
            ? ['Apple']
            : []),
          ...(user.phone && user.phoneVerifiedAt ? ['WhatsApp OTP'] : []),
          ...(user.passwordHash ? ['Email / phone and password'] : []),
        ],
      })),
      query.page,
      query.pageSize,
      total,
    );
  }
}
