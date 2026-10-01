import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_ENDPOINT = 'abra:isPublicEndpoint';

/**
 * Marks a controller or handler as reachable without an access token. Everything else requires
 * authentication (deny by default — architecture.md rule 4).
 */
export const PublicEndpoint = (): MethodDecorator & ClassDecorator =>
  SetMetadata(IS_PUBLIC_ENDPOINT, true);
