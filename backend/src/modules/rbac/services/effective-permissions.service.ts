import { Injectable } from '@nestjs/common';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { type StoredUser } from '../../users/repositories/user.repository';
import { UsersService } from '../../users/services/users.service';
import { PermissionOverrideRepository } from '../repositories/permission-override.repository';
import { RoleRepository, type StoredRole } from '../repositories/role.repository';
import { IMPLICIT_ROLE_BY_USER_TYPE } from '../roles/system-roles';
import {
  type EffectivePermissions,
  NO_PERMISSIONS,
  resolveEffectivePermissions,
} from './effective-permissions';

const CACHE_TTL_MS = 60_000;
const CACHE_MAX_ENTRIES = 5_000;

interface CacheEntry {
  expiresAtMs: number;
  value: EffectivePermissions;
}

/**
 * Loads a user's roles and overrides from MongoDB and resolves the effective permissions.
 *
 * Results are cached in memory per `userId:permissionVersion`. Every role, override or scope
 * change increments the user's `permissionVersion` in the same transaction, so a changed user
 * never hits a stale entry — on this instance or any other. The cache is only a shortcut;
 * MongoDB stays the source of truth.
 */
@Injectable()
export class EffectivePermissionsService {
  private readonly cache = new Map<string, CacheEntry>();

  constructor(
    private readonly users: UsersService,
    private readonly roles: RoleRepository,
    private readonly overrides: PermissionOverrideRepository,
  ) {}

  /** Effective permissions of the authenticated actor. An unknown user has none. */
  async forActor(actor: AuthenticatedUserActor): Promise<EffectivePermissions> {
    const cacheKey = `${actor.userId}:${actor.permissionVersion}`;
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAtMs > Date.now()) return cached.value;

    const user = await this.users.findById(actor.userId);
    // The actor was built from this user a moment ago; if the version moved, do not cache
    if (!user) return NO_PERMISSIONS;
    const value = await this.forUser(user);
    if (user.permissionVersion === actor.permissionVersion) this.remember(cacheKey, value);
    return value;
  }

  /** Effective permissions of any user, always from MongoDB (administration, audit snapshots). */
  async forUser(user: StoredUser): Promise<EffectivePermissions> {
    const [roles, overrides] = await Promise.all([
      this.rolesOf(user),
      this.overrides.findForUser(user._id),
    ]);
    return resolveEffectivePermissions(user.userType, roles, overrides);
  }

  /** Roles stored on the user, or the implicit role of the account kind when none is stored. */
  async rolesOf(user: StoredUser): Promise<StoredRole[]> {
    if (user.roleIds.length > 0) return this.roles.findByIds(user.roleIds);
    const implicit = IMPLICIT_ROLE_BY_USER_TYPE[user.userType];
    return implicit ? this.roles.findByKeys([implicit]) : [];
  }

  private remember(key: string, value: EffectivePermissions): void {
    if (this.cache.size >= CACHE_MAX_ENTRIES) {
      // Drop the oldest entries (Map keeps insertion order); correctness never depends on a hit
      for (const oldest of [...this.cache.keys()].slice(0, CACHE_MAX_ENTRIES / 10)) {
        this.cache.delete(oldest);
      }
    }
    this.cache.set(key, { expiresAtMs: Date.now() + CACHE_TTL_MS, value });
  }
}
