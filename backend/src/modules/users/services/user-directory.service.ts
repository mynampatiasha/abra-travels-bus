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
}

export interface UserDirectoryQuery {
  userType?: User['userType'];
  status?: User['status'];
  operatorId?: string;
  partnerId?: string;
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
      })),
      query.page,
      query.pageSize,
      total,
    );
  }
}
