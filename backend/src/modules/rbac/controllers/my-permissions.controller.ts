import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { AuthenticatedOnly } from '../../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { UsersService } from '../../users/services/users.service';
import { type MyPermissionsView, toMyPermissionsView } from '../services/authorization-views';
import { EffectivePermissionsService } from '../services/effective-permissions.service';

@ApiTags('authorization')
@ApiBearerAuth('access-token')
@Controller('me/permissions')
export class MyPermissionsController {
  constructor(
    private readonly users: UsersService,
    private readonly effectivePermissions: EffectivePermissionsService,
  ) {}

  @Get()
  @AuthenticatedOnly()
  @ApiOperation({
    summary: 'My effective permissions',
    description:
      "Authenticated. The caller's own roles, effective permission keys (role permissions plus " +
      'ALLOW overrides minus DENY overrides) and data scope, for deciding which screens and ' +
      'actions to show. Always the caller — there is no user id parameter. The server enforces ' +
      'every permission regardless of what the client shows.',
  })
  @ApiResponse({
    status: 200,
    description:
      'userId, userType, roles, permissionVersion, dataScope, operatorId, partnerId, ' +
      'permissions, permissionsByModule',
  })
  @ApiResponse({
    status: 401,
    description: 'UNAUTHENTICATED, TOKEN_EXPIRED or PERMISSIONS_CHANGED',
  })
  async mine(@CurrentActor() actor: AuthenticatedUserActor): Promise<MyPermissionsView> {
    const user = await this.users.getById(actor.userId);
    const [roles, effective] = await Promise.all([
      this.effectivePermissions.rolesOf(user),
      this.effectivePermissions.forUser(user),
    ]);
    return toMyPermissionsView(user, roles, effective);
  }
}
