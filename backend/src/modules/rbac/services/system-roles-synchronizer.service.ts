import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { PERMISSION_CATALOG } from '../permissions/permission-catalog';
import { validatePermissionDefinitions } from '../permissions/permission-registry';
import { RoleRepository } from '../repositories/role.repository';
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
    for (const role of SYSTEM_ROLES) {
      await this.roles.upsertSystemRole({
        key: role.key,
        name: role.name,
        description: role.description,
        userType: role.userType,
        dataScopeType: role.dataScopeType,
        permissionKeys: [...role.permissionKeys],
      });
    }
    this.logger.log({ roles: SYSTEM_ROLES.length }, 'System roles synchronised');
  }
}
