import { SetMetadata } from '@nestjs/common';

export const IS_AUTHENTICATED_ONLY = 'abra:isAuthenticatedOnly';

/**
 * Marks a controller or handler as self-service: any authenticated user may call it, and it acts
 * only on the caller's own account (own profile, own sessions, own permissions). No permission
 * key is involved — the handler takes the user id from the actor, never from the request.
 *
 * Every endpoint must declare exactly how it is protected: `@PublicEndpoint()`,
 * `@AuthenticatedOnly()` or `@RequirePermission(...)`. The application refuses to start otherwise.
 */
export const AuthenticatedOnly = (): MethodDecorator & ClassDecorator =>
  SetMetadata(IS_AUTHENTICATED_ONLY, true);
