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

  /**
   * Creates or refreshes a system role from its definition in code. Idempotent. A role that was
   * edited in the access matrix keeps its permission keys (they come from its page levels).
   */
  async upsertSystemRole(
    role: Omit<Role, 'isSystemRole' | 'pageLevels' | 'operatorId'>,
    keepPermissionKeys = false,
  ): Promise<void> {
    const { permissionKeys, ...rest } = role;
    await this.model.updateOne(
      { key: role.key },
      { $set: { ...rest, ...(keepPermissionKeys ? {} : { permissionKeys }), isSystemRole: true } },
      { upsert: true },
    );
  }

  findByKey(key: string, session?: ClientSession): Promise<StoredRole | null> {
    return this.model.findOne({ key }, null, { session }).lean<StoredRole>().exec();
  }

  /** Stores the page levels of a role together with the permission keys derived from them. */
  async setAccess(
    key: string,
    access: { pageLevels: Record<string, string>; permissionKeys: string[] },
    session?: ClientSession,
  ): Promise<boolean> {
    const result = await this.model.updateOne({ key }, { $set: access }, { session });
    return result.matchedCount === 1;
  }

  async createCustomRole(
    role: Omit<Role, 'isSystemRole'>,
    session: ClientSession,
  ): Promise<StoredRole> {
    const [created] = await this.model.create([{ ...role, isSystemRole: false }], { session });
    return created!.toObject();
  }

  async rename(
    key: string,
    fields: { name: string; description: string },
    session: ClientSession,
  ): Promise<boolean> {
    const result = await this.model.updateOne(
      { key, isSystemRole: false },
      { $set: fields },
      { session },
    );
    return result.matchedCount === 1;
  }

  async deleteCustomRole(key: string, session: ClientSession): Promise<boolean> {
    const result = await this.model.deleteOne({ key, isSystemRole: false }, { session });
    return result.deletedCount === 1;
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
