import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { PERMISSION_CATALOG } from '../permissions/permission-catalog';
import { validatePermissionDefinitions } from '../permissions/permission-registry';
import { audienceOfUserType, permissionKeysFromLevels } from '../permissions/access-pages';
import { RoleRepository, type StoredRole } from '../repositories/role.repository';
import { SYSTEM_ROLES, validateRoleDefinitions } from '../roles/system-roles';

/**
 * At start-up: validates the permission catalogue and the role definitions (a mistake stops the
 * process), then mirrors the system roles into the `roles` collection so users can reference them
 * by id. Idempotent and safe when the API and the worker start at the same time. Creates roles
 * only — never users.
 */
@Injectable()
export class SystemRolesSynchronizer implements OnApplicationBootstrap {
  private readonly logger = new Logger(SystemRolesSynchronizer.name);

  constructor(private readonly roles: RoleRepository) {}

  async onApplicationBootstrap(): Promise<void> {
    await this.synchronize();
  }

  async synchronize(): Promise<void> {
    validatePermissionDefinitions(PERMISSION_CATALOG);
    validateRoleDefinitions(SYSTEM_ROLES);

    await this.roles.ensureIndexes();
    const stored = new Map((await this.roles.findAll()).map((role) => [role.key, role]));
    for (const role of SYSTEM_ROLES) {
      const edited = stored.get(role.key)?.pageLevels;
      await this.roles.upsertSystemRole(
        {
          key: role.key,
          name: role.name,
          description: role.description,
          userType: role.userType,
          dataScopeType: role.dataScopeType,
          permissionKeys: [...role.permissionKeys],
        },
        edited !== undefined,
      );
    }
    await this.refreshEditedRoles(stored);
    this.logger.log({ roles: SYSTEM_ROLES.length }, 'System roles synchronised');
  }

  /**
   * Roles edited in the access matrix keep their page levels. Permissions added to a module
   * after the edit reach them here, because the keys are derived again from the levels.
   */
  private async refreshEditedRoles(stored: ReadonlyMap<string, StoredRole>): Promise<void> {
    let refreshed = 0;
    for (const role of stored.values()) {
      if (!role.pageLevels) continue;
      const audience = audienceOfUserType(role.userType);
      if (!audience) continue;
      const keys = permissionKeysFromLevels(audience, role.pageLevels, role.permissionKeys);
      const current = [...role.permissionKeys].sort();
      if (keys.length === current.length && keys.every((key, i) => key === current[i])) continue;
      await this.roles.setAccess(role.key, { pageLevels: role.pageLevels, permissionKeys: keys });
      refreshed += 1;
    }
    if (refreshed > 0) this.logger.log({ roles: refreshed }, 'Matrix-edited roles refreshed');
  }
}
