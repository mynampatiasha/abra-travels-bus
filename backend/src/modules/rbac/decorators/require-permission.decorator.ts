import { applyDecorators, SetMetadata } from '@nestjs/common';
import { ApiBearerAuth, ApiForbiddenResponse, ApiUnauthorizedResponse } from '@nestjs/swagger';
import { type PermissionKey } from '../permissions/permission-catalog';

export const REQUIRED_PERMISSIONS = 'abra:requiredPermissions';

/**
 * Declares the permission(s) an endpoint needs; PermissionGuard enforces them on the server for
 * every request. With several keys, all of them are required. Only keys from the permission
 * catalogue compile.
 *
 *   @RequirePermission('bookings.cancel')
 *
 * Also documents the endpoint in OpenAPI (bearer auth, 401, 403).
 */
export function RequirePermission(
  ...permissions: [PermissionKey, ...PermissionKey[]]
): MethodDecorator & ClassDecorator {
  return applyDecorators(
    SetMetadata(REQUIRED_PERMISSIONS, permissions),
    ApiBearerAuth('access-token'),
    ApiUnauthorizedResponse({
      description: 'UNAUTHENTICATED, TOKEN_EXPIRED or PERMISSIONS_CHANGED',
    }),
    ApiForbiddenResponse({
      description: `PERMISSION_DENIED — requires ${permissions.join(', ')}`,
    }),
  );
}
