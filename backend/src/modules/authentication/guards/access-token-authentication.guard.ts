import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { OPERATOR_MODEL, type Operator } from '../../operators/schemas/operator.schema';
import {
  type CanActivate,
  type ExecutionContext,
  Injectable,
  SetMetadata,
  Optional,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { type Request } from 'express';
import { IS_PUBLIC_ENDPOINT } from '../../../common/decorators/public-endpoint.decorator';
import { ApiException } from '../../../common/errors/api-exception';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import { type StoredAuthSession } from '../../sessions/repositories/auth-session.repository';
import { SessionsService } from '../../sessions/services/sessions.service';
import { type StoredUser } from '../../users/repositories/user.repository';
import { UsersService } from '../../users/services/users.service';
import { AccessTokenService } from '../services/access-token.service';

const ALLOWED_DURING_MFA_ENROLLMENT = 'abra:allowedDuringMfaEnrollment';

/**
 * Lets a session that still has to enrol MFA call this endpoint (the enrolment endpoints
 * themselves, the profile and logout). Every other endpoint answers MFA_ENROLLMENT_REQUIRED.
 */
export const AllowDuringMfaEnrollment = (): MethodDecorator & ClassDecorator =>
  SetMetadata(ALLOWED_DURING_MFA_ENROLLMENT, true);

const BEARER_PATTERN = /^Bearer ([A-Za-z0-9._-]{20,4096})$/;

function unauthenticated(message = 'Authentication is required'): ApiException {
  return new ApiException('UNAUTHENTICATED', message);
}

export function buildActor(user: StoredUser, session: StoredAuthSession): AuthenticatedUserActor {
  return {
    actorType: 'USER',
    userId: user._id.toHexString(),
    ...(user.partnerId ? { partnerId: user.partnerId.toHexString() } : {}),
    dataScope: {
      type: user.dataScope.type,
      operatorIds: user.dataScope.operatorIds.map((operatorId) => operatorId.toHexString()),
    },
    userType: user.userType,
    sessionId: session._id.toHexString(),
    permissionVersion: user.permissionVersion,
    roleIds: user.roleIds.map((roleId) => roleId.toHexString()),
    ...(user.operatorId ? { operatorId: user.operatorId.toHexString() } : {}),
    mfaEnrollmentPending: session.mfaEnrollmentPending,
  };
}

/**
 * Global guard: every endpoint requires a valid access token unless it is marked
 * `@PublicEndpoint()` (deny by default).
 *
 * Request → Bearer token → signature / expiry / issuer / audience → session still active →
 * user still ACTIVE → permission version unchanged → actor attached to the request context.
 * Scoped repositories and (from step 8) the permission guard read the actor from there.
 *
 * The session and the user are read from MongoDB on every request, so logout, session
 * revocation and account deactivation take effect immediately, not when the token expires.
 */
@Injectable()
export class AccessTokenAuthenticationGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly accessTokens: AccessTokenService,
    private readonly sessions: SessionsService,
    private readonly users: UsersService,
    @Optional() @InjectModel(OPERATOR_MODEL) private readonly operators?: Model<Operator>,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_ENDPOINT, targets)) return true;

    const request = context.switchToHttp().getRequest<Request>();
    const token = BEARER_PATTERN.exec(request.headers.authorization ?? '')?.[1];
    if (!token) throw unauthenticated();

    const claims = await this.accessTokens.verify(token);
    const [session, user] = await Promise.all([
      this.sessions.findActive(claims.sessionId, claims.userId),
      this.users.findById(claims.userId),
    ]);
    if (!session || !user || user.status !== 'ACTIVE') {
      throw unauthenticated('The session is no longer valid. Please sign in again.');
    }
    if (claims.permissionVersion !== user.permissionVersion) {
      // The account changed since this token was issued; the client refreshes and retries
      throw new ApiException('PERMISSIONS_CHANGED', 'Account access changed. Refresh the session.');
    }
    if (
      session.mfaEnrollmentPending &&
      !this.reflector.getAllAndOverride<boolean>(ALLOWED_DURING_MFA_ENROLLMENT, targets)
    ) {
      throw new ApiException(
        'MFA_ENROLLMENT_REQUIRED',
        'Set up two-step verification to continue.',
      );
    }

    if (user.userType === 'OPERATOR_STAFF' && user.operatorId && this.operators) {
      const operator = await this.operators.findById(user.operatorId).lean();
      const path = request.path.replace(/^\/api\/v1/, '');
      const onboardingAccess = [
        '/auth/',
        '/me',
        '/client/kyc',
        '/notifications',
        '/files',
        '/onboarding/submissions',
      ];
      if (
        operator?.status !== 'ACTIVE' &&
        !onboardingAccess.some(
          (prefix) =>
            path === prefix || path.startsWith(prefix.endsWith('/') ? prefix : prefix + '/'),
        )
      ) {
        throw new ApiException(
          'PERMISSION_DENIED',
          'Complete KYC and wait for admin approval before accessing account features.',
        );
      }
    }
    RequestContextService.attachActor(buildActor(user, session));
    return true;
  }
}
