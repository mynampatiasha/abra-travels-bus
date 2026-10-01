import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequirePermission } from '../decorators/require-permission.decorator';
import { PermissionRegistry } from '../permissions/permission-registry';
import { RoleRepository } from '../repositories/role.repository';
import { EffectivePermissionsService } from '../services/effective-permissions.service';

export interface PermissionView {
  key: string;
  module: string;
  action: string;
  name: string;
  description: string;
  sensitive: boolean;
  grantableTo: string[];
}

export interface RoleView {
  key: string;
  name: string;
  description: string;
  userType: string;
  dataScopeType: string;
  isSystemRole: boolean;
  permissionKeys: string[];
}

/** The permission catalogue and the role catalogue, for administration screens. */
@ApiTags('authorization')
@Controller()
export class AuthorizationCatalogController {
  constructor(
    private readonly roles: RoleRepository,
    private readonly effectivePermissions: EffectivePermissionsService,
  ) {}

  @Get('permissions')
  @RequirePermission('roles.read')
  @ApiOperation({
    summary: 'Permission catalogue',
    description: 'Requires roles.read. Every permission with its module, name and description.',
  })
  @ApiResponse({ status: 200, description: 'Permissions in declaration order' })
  permissions(): PermissionView[] {
    return PermissionRegistry.all().map((definition) => ({
      key: definition.key,
      module: definition.module,
      action: definition.action,
      name: definition.name,
      description: definition.description,
      sensitive: definition.sensitive ?? false,
      grantableTo: [...definition.grantableTo],
    }));
  }

  @Get('roles')
  @RequirePermission('roles.read')
  @ApiOperation({
    summary: 'Role catalogue',
    description:
      'Requires roles.read. Roles the caller could assign: a caller without the full-access ' +
      'wildcard sees only roles whose permissions they hold themselves.',
  })
  @ApiResponse({ status: 200, description: 'Roles with their permission keys and data scope' })
  async list(@CurrentActor() actor: AuthenticatedUserActor): Promise<RoleView[]> {
    const [roles, mine] = await Promise.all([
      this.roles.findAll(),
      this.effectivePermissions.forActor(actor),
    ]);
    return roles
      .filter(
        (role) =>
          mine.hasWildcard ||
          role.permissionKeys.every(
            (key) => PermissionRegistry.has(key) && mine.permissions.has(key),
          ),
      )
      .map((role) => ({
        key: role.key,
        name: role.name,
        description: role.description,
        userType: role.userType,
        dataScopeType: role.dataScopeType,
        isSystemRole: role.isSystemRole,
        permissionKeys: role.permissionKeys,
      }));
  }
}
