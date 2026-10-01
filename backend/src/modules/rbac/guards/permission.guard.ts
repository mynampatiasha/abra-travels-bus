import { type CanActivate, type ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { IS_AUTHENTICATED_ONLY } from '../../../common/decorators/authenticated-only.decorator';
import { IS_PUBLIC_ENDPOINT } from '../../../common/decorators/public-endpoint.decorator';
import { ApiException } from '../../../common/errors/api-exception';
import { isAuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import { REQUIRED_PERMISSIONS } from '../decorators/require-permission.decorator';
import { AuthorizationService } from '../services/authorization.service';

/**
 * Global guard, after authentication: enforces `@RequirePermission(...)` on the server for every
 * request, whatever the client shows or hides.
 *
 *   @PublicEndpoint()        → no check
 *   @AuthenticatedOnly()     → any authenticated user (self-service on the caller's own account)
 *   @RequirePermission(a, b) → the actor must hold every listed permission
 *   nothing declared         → denied (and the application refuses to start, see
 *                              EndpointAccessDeclarationCheck)
 *
 * No authenticated actor → 401. Missing permission → 403.
 */
@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly authorization: AuthorizationService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_ENDPOINT, targets)) return true;

    const actor = RequestContextService.actor();
    if (!isAuthenticatedUserActor(actor)) {
      throw new ApiException('UNAUTHENTICATED', 'Authentication is required');
    }

    // The handler's own declaration wins over the controller's
    const required = this.reflector.getAllAndOverride<string[] | undefined>(
      REQUIRED_PERMISSIONS,
      targets,
    );
    if (required && required.length > 0) {
      for (const permission of required) {
        await this.authorization.require(actor, permission);
      }
      return true;
    }
    if (this.reflector.getAllAndOverride<boolean>(IS_AUTHENTICATED_ONLY, targets)) return true;

    throw new ApiException('PERMISSION_DENIED', 'You do not have permission to do this.');
  }
}
