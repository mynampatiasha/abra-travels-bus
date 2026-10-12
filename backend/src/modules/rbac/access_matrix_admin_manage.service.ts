import { Injectable } from '@nestjs/common';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { UsersService } from '../users/services/users.service';
import {
  ACCESS_LEVEL_LABELS,
  type AccessAudience,
  type AccessLevel,
  audienceOfUserType,
  findPage,
  inferLevel,
  pagesFor,
  permissionKeysFromLevels,
} from './permissions/access-pages';
import { PermissionRegistry } from './permissions/permission-registry';
import { RoleRepository, type StoredRole } from './repositories/role.repository';
import { AuditedChangeRunner } from './services/audited-change.service';
import { EffectivePermissionsService } from './services/effective-permissions.service';
import { invalidInput } from './services/authorization-rules';

// ===== 1. VIEWS =====================================================================

export interface MatrixRoleView {
  key: string;
  name: string;
  description: string;
  isSystemRole: boolean;
  /** The Super Admin row: full access, cannot be changed. */
  locked: boolean;
  /** One level per page id. */
  levels: Record<string, AccessLevel>;
  /** Pages whose permission keys do not match a level exactly (set by hand through overrides). */
  inexactPages: string[];
}

export interface MatrixView {
  audience: AccessAudience;
  levels: ReadonlyArray<{ level: AccessLevel; label: string }>;
  pages: ReadonlyArray<{ id: string; title: string }>;
  roles: MatrixRoleView[];
}

// ===== 2. RULES =====================================================================

const SYSTEM_ORDER = ['SUPER_ADMIN', 'ADMIN', 'SUPPORT', 'OPERATOR_ADMIN', 'OPERATOR_MANAGER'];

function isLocked(role: StoredRole): boolean {
  return role.key === 'SUPER_ADMIN' || role.permissionKeys.includes('*');
}

function userTypeOf(audience: AccessAudience): 'STAFF' | 'OPERATOR_STAFF' {
  return audience === 'ADMIN' ? 'STAFF' : 'OPERATOR_STAFF';
}

function notFound(what: string): ApiException {
  return new ApiException('RESOURCE_NOT_FOUND', `${what} was not found`);
}

/** Letters and underscores only, as role keys must be (`^[A-Z][A-Z_]{1,63}$`). */
function customRoleKey(name: string): string {
  const slug = name
    .toUpperCase()
    .replace(/[^A-Z]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
  const suffix = Array.from({ length: 4 }, () =>
    String.fromCharCode(65 + Math.floor(Math.random() * 26)),
  ).join('');
  return `CUSTOM_${slug || 'ROLE'}_${suffix}`;
}

/** The level of every page, from the stored levels or, for roles never edited, from their keys. */
export function levelsOf(role: StoredRole, audience: AccessAudience) {
  const keys = new Set(role.permissionKeys);
  const wildcard = role.permissionKeys.includes('*');
  const levels: Record<string, AccessLevel> = {};
  const inexact: string[] = [];
  for (const page of pagesFor(audience)) {
    const stored = role.pageLevels?.[page.id];
    if (stored) {
      levels[page.id] = stored;
      continue;
    }
    const inferred = inferLevel(page, keys, wildcard);
    levels[page.id] = inferred.level;
    if (!inferred.exact) inexact.push(page.id);
  }
  return { levels, inexact };
}

// ===== 3. SERVICE ===================================================================

/**
 * The access matrix: what each role may do on each portal page. Only the Super Admin changes it
 * (the wildcard check below, on top of the `roles.manage` permission on the endpoints). A change
 * is stored as page levels, turned into permission keys, written with an audit entry in one
 * transaction, and bumps `permissionVersion` of every holder so their next token carries the new
 * access. The Super Admin row can never be changed.
 */
@Injectable()
export class AccessMatrixAdminManageService {
  constructor(
    private readonly roles: RoleRepository,
    private readonly users: UsersService,
    private readonly changes: AuditedChangeRunner,
    private readonly effectivePermissions: EffectivePermissionsService,
  ) {}

  async matrix(audience: AccessAudience): Promise<MatrixView> {
    const userType = userTypeOf(audience);
    const all = (await this.roles.findAll()).filter((role) => role.userType === userType);
    const order = (role: StoredRole) => {
      const i = SYSTEM_ORDER.indexOf(role.key);
      return i >= 0 ? i : SYSTEM_ORDER.length + (role.isSystemRole ? 0 : 1);
    };
    all.sort((a, b) => order(a) - order(b) || a.name.localeCompare(b.name));
    return {
      audience,
      levels: (Object.keys(ACCESS_LEVEL_LABELS) as AccessLevel[]).map((level) => ({
        level,
        label: ACCESS_LEVEL_LABELS[level],
      })),
      pages: pagesFor(audience).map((page) => ({ id: page.id, title: page.title })),
      roles: all.map((role) => {
        const { levels, inexact } = levelsOf(role, audience);
        return {
          key: role.key,
          name: role.name,
          description: role.description,
          isSystemRole: role.isSystemRole,
          locked: isLocked(role),
          levels,
          inexactPages: inexact,
        };
      }),
    };
  }

  /** Changes one page of one role. */
  async setPageLevel(
    actor: AuthenticatedUserActor,
    roleKey: string,
    pageId: string,
    level: AccessLevel,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<MatrixRoleView> {
    await this.assertSuperAdmin(actor);
    const { role, audience } = await this.editableRole(roleKey);
    if (!findPage(audience, pageId)) throw notFound('That page');
    const current = levelsOf(role, audience).levels;
    return this.save(actor, role, audience, { ...current, [pageId]: level }, reason, client, {
      pageId,
      from: current[pageId],
      to: level,
    });
  }

  /** Gives one level to every page of one role ("set every area to View"). */
  async setAllLevels(
    actor: AuthenticatedUserActor,
    roleKey: string,
    level: AccessLevel,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<MatrixRoleView> {
    await this.assertSuperAdmin(actor);
    const { role, audience } = await this.editableRole(roleKey);
    const levels = Object.fromEntries(pagesFor(audience).map((page) => [page.id, level])) as Record<
      string,
      AccessLevel
    >;
    return this.save(actor, role, audience, levels, reason, client, { allPages: true, to: level });
  }

  /** A new role, optionally starting with the access of another role of the same portal. */
  async createRole(
    actor: AuthenticatedUserActor,
    input: { audience: AccessAudience; name: string; copyFromRoleKey?: string | undefined },
    client: ClientRequestInfo,
  ): Promise<MatrixRoleView> {
    await this.assertSuperAdmin(actor);
    const userType = userTypeOf(input.audience);
    const existing = (await this.roles.findAll()).filter((role) => role.userType === userType);
    if (existing.some((role) => role.name.toLowerCase() === input.name.toLowerCase())) {
      throw invalidInput('name', 'A role with this name already exists');
    }
    let base: StoredRole | undefined;
    if (input.copyFromRoleKey) {
      base = existing.find((role) => role.key === input.copyFromRoleKey);
      if (!base || isLocked(base)) throw invalidInput('copyFromRoleKey', 'Choose another role');
    }
    const levels = base
      ? levelsOf(base, input.audience).levels
      : (Object.fromEntries(pagesFor(input.audience).map((page) => [page.id, 'NONE'])) as Record<
          string,
          AccessLevel
        >);
    const permissionKeys = this.derive(
      userType,
      input.audience,
      levels,
      base?.permissionKeys ?? [],
    );

    const created = await this.changes.run<StoredRole>({
      actor,
      client,
      action: 'role.created',
      entityType: 'role',
      before: {},
      apply: (session) =>
        this.roles.createCustomRole(
          {
            key: customRoleKey(input.name),
            name: input.name,
            description: base ? `Copy of ${base.name}` : 'Custom role',
            userType,
            dataScopeType:
              base?.dataScopeType ?? (input.audience === 'ADMIN' ? 'ALL' : 'OWN_OPERATOR'),
            permissionKeys,
            pageLevels: levels,
          },
          session,
        ),
      describe: (role) => ({ key: role.key, name: role.name, copiedFrom: base?.key ?? null }),
    });
    return this.view(created, input.audience);
  }

  async renameRole(
    actor: AuthenticatedUserActor,
    roleKey: string,
    name: string,
    client: ClientRequestInfo,
  ): Promise<MatrixRoleView> {
    await this.assertSuperAdmin(actor);
    const { role, audience } = await this.editableRole(roleKey);
    if (role.isSystemRole) throw invalidInput('roleKey', 'A system role cannot be renamed');
    const updated = await this.changes.run<StoredRole>({
      actor,
      client,
      action: 'role.renamed',
      entityType: 'role',
      before: { name: role.name },
      apply: async (session) => {
        await this.roles.rename(role.key, { name, description: role.description }, session);
        return { ...role, name };
      },
      describe: (r) => ({ name: r.name }),
    });
    return this.view(updated, audience);
  }

  /** Deleting a custom role is refused while anybody still holds it. */
  async deleteRole(
    actor: AuthenticatedUserActor,
    roleKey: string,
    reason: string | undefined,
    client: ClientRequestInfo,
  ): Promise<{ deleted: true }> {
    await this.assertSuperAdmin(actor);
    const { role } = await this.editableRole(roleKey);
    if (role.isSystemRole) throw invalidInput('roleKey', 'A system role cannot be deleted');
    await this.changes.run<StoredRole>({
      actor,
      client,
      action: 'role.deleted',
      entityType: 'role',
      before: { key: role.key, name: role.name },
      ...(reason ? { reason } : {}),
      apply: async (session) => {
        const holders = await this.users.countWithRole(role._id, session);
        if (holders > 0) {
          throw new ApiException(
            'INVALID_STATE_TRANSITION',
            `${holders} user(s) still have this role. Give them another role first.`,
            { holders },
          );
        }
        await this.roles.deleteCustomRole(role.key, session);
        return role;
      },
      describe: () => ({ deleted: true }),
    });
    return { deleted: true };
  }

  // ----- helpers ---------------------------------------------------------------

  private async save(
    actor: AuthenticatedUserActor,
    role: StoredRole,
    audience: AccessAudience,
    levels: Record<string, AccessLevel>,
    reason: string | undefined,
    client: ClientRequestInfo,
    change: Record<string, unknown>,
  ): Promise<MatrixRoleView> {
    const permissionKeys = this.derive(role.userType, audience, levels, role.permissionKeys);
    const updated = await this.changes.run<StoredRole>({
      actor,
      client,
      action: 'role.access.changed',
      entityType: 'role',
      before: {
        role: role.key,
        levels: levelsOf(role, audience).levels,
        permissionCount: role.permissionKeys.length,
      },
      ...(reason ? { reason } : {}),
      apply: async (session) => {
        await this.roles.setAccess(role.key, { pageLevels: levels, permissionKeys }, session);
        await this.users.bumpPermissionVersionForRoles([role._id], session);
        return { ...role, pageLevels: levels, permissionKeys };
      },
      describe: (r) => ({
        role: r.key,
        change,
        levels: levelsOf(r, audience).levels,
        permissionCount: r.permissionKeys.length,
      }),
      operatorIdOf: (r) => r.operatorId,
    });
    return this.view(updated, audience);
  }

  /** Permission keys for the levels, limited to what this kind of account may ever hold. */
  private derive(
    userType: string,
    audience: AccessAudience,
    levels: Record<string, AccessLevel>,
    baseKeys: readonly string[],
  ): string[] {
    return permissionKeysFromLevels(audience, levels, baseKeys).filter(
      (key) =>
        key === '*' ||
        !PermissionRegistry.has(key) ||
        PermissionRegistry.isGrantableTo(key, userType as 'STAFF' | 'OPERATOR_STAFF'),
    );
  }

  private view(role: StoredRole, audience: AccessAudience): MatrixRoleView {
    const { levels, inexact } = levelsOf(role, audience);
    return {
      key: role.key,
      name: role.name,
      description: role.description,
      isSystemRole: role.isSystemRole,
      locked: isLocked(role),
      levels,
      inexactPages: inexact,
    };
  }

  private async editableRole(
    roleKey: string,
  ): Promise<{ role: StoredRole; audience: AccessAudience }> {
    const role = await this.roles.findByKey(roleKey);
    const audience = role ? audienceOfUserType(role.userType) : undefined;
    if (!role || !audience) throw notFound('That role');
    if (isLocked(role)) {
      throw new ApiException('PERMISSION_DENIED', 'The Super Admin always has full access');
    }
    return { role, audience };
  }

  /** Only the holder of the full-access wildcard edits the matrix, whatever other permissions say. */
  private async assertSuperAdmin(actor: AuthenticatedUserActor): Promise<void> {
    const mine = await this.effectivePermissions.forActor(actor);
    if (!mine.hasWildcard) {
      throw new ApiException('PERMISSION_DENIED', 'Only the Super Admin can change access');
    }
  }
}
