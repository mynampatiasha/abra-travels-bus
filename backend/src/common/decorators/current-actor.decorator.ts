import { createParamDecorator } from '@nestjs/common';
import { ApiException } from '../errors/api-exception';
import {
  type AuthenticatedUserActor,
  isAuthenticatedUserActor,
} from '../request-context/request-actor';
import { RequestContextService } from '../request-context/request-context.service';

export function currentAuthenticatedActor(): AuthenticatedUserActor {
  const actor = RequestContextService.actor();
  if (!isAuthenticatedUserActor(actor)) {
    throw new ApiException('UNAUTHENTICATED', 'Authentication is required');
  }
  return actor;
}

/** The authenticated user of the current request, as set by the access-token guard. */
export const CurrentActor = createParamDecorator(() => currentAuthenticatedActor());
