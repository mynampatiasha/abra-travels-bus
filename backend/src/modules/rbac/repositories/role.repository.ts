import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import { ROLE_MODEL, type Role } from '../schemas/role.schema';

export type StoredRole = Role & { _id: Types.ObjectId };

/** `roles` — the platform's role catalogue. Not tenant data, so not a ScopedRepository. */
@Injectable()
export class RoleRepository {
  constructor(@InjectModel(ROLE_MODEL) private readonly model: Model<Role>) {}

  /** Indexes must exist before roles are upserted, so the unique key index is built first. */
  async ensureIndexes(): Promise<void> {
    await this.model.createIndexes();
  }

  /** Creates or refreshes a system role from its definition in code. Idempotent. */
  async upsertSystemRole(role: Omit<Role, 'isSystemRole'>): Promise<void> {
    await this.model.updateOne(
      { key: role.key },
      { $set: { ...role, isSystemRole: true } },
      { upsert: true },
    );
  }

  findAll(): Promise<StoredRole[]> {
    return this.model.find().sort({ key: 1 }).lean<StoredRole[]>().exec();
  }

  findByIds(ids: readonly Types.ObjectId[], session?: ClientSession): Promise<StoredRole[]> {
    if (ids.length === 0) return Promise.resolve([]);
    return this.model
      .find({ _id: { $in: ids } }, null, { session })
      .lean<StoredRole[]>()
      .exec();
  }

  findByKeys(keys: readonly string[], session?: ClientSession): Promise<StoredRole[]> {
    if (keys.length === 0) return Promise.resolve([]);
    return this.model
      .find({ key: { $in: keys } }, null, { session })
      .lean<StoredRole[]>()
      .exec();
  }
}
