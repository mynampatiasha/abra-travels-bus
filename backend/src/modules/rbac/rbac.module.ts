import { Module } from '@nestjs/common';
import { APP_GUARD, DiscoveryModule } from '@nestjs/core';
import { MongooseModule } from '@nestjs/mongoose';
import { AuditLogsModule } from '../audit-logs/audit-logs.module';
import { UsersModule } from '../users/users.module';
import { AuthorizationCatalogController } from './controllers/authorization-catalog.controller';
import { MyPermissionsController } from './controllers/my-permissions.controller';
import { UserAuthorizationController } from './controllers/user-authorization.controller';
import { PermissionGuard } from './guards/permission.guard';
import { PermissionOverrideRepository } from './repositories/permission-override.repository';
import { RoleRepository } from './repositories/role.repository';
import {
  PERMISSION_OVERRIDE_MODEL,
  permissionOverrideSchema,
} from './schemas/permission-override.schema';
import { ROLE_MODEL, roleSchema } from './schemas/role.schema';
import { AuthorizationAdministrationService } from './services/authorization-administration.service';
import { AuthorizationService } from './services/authorization.service';
import { EffectivePermissionsService } from './services/effective-permissions.service';
import { EndpointAccessDeclarationCheck } from './services/endpoint-access-declaration.check';
import { SystemRolesSynchronizer } from './services/system-roles-synchronizer.service';

/**
 * `rbac` — authorization (documentation/authorization.md): permission catalogue, roles,
 * user-level ALLOW / DENY overrides, the central AuthorizationService, the global PermissionGuard
 * behind `@RequirePermission`, `/me/permissions`, and the administration of other users' access.
 *
 * Authentication (who the caller is) is the `authentication` module; this module decides what an
 * authenticated caller may do. Other modules inject AuthorizationService for checks on single
 * records and use ScopedRepository for lists.
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: ROLE_MODEL, schema: roleSchema },
      { name: PERMISSION_OVERRIDE_MODEL, schema: permissionOverrideSchema },
    ]),
    DiscoveryModule,
    UsersModule,
    AuditLogsModule,
  ],
  controllers: [
    MyPermissionsController,
    AuthorizationCatalogController,
    UserAuthorizationController,
  ],
  providers: [
    RoleRepository,
    PermissionOverrideRepository,
    SystemRolesSynchronizer,
    EffectivePermissionsService,
    AuthorizationService,
    AuthorizationAdministrationService,
    EndpointAccessDeclarationCheck,
    PermissionGuard,
    // Runs after the authentication guard (AuthenticationModule is registered first)
    { provide: APP_GUARD, useExisting: PermissionGuard },
  ],
  exports: [AuthorizationService, EffectivePermissionsService],
})
export class RbacModule {}
