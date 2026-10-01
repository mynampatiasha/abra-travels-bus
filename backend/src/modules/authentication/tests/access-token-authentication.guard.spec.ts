import { type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { randomBytes } from 'node:crypto';
import { Types } from 'mongoose';
import { PublicEndpoint } from '../../../common/decorators/public-endpoint.decorator';
import { isAuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { RequestContextService } from '../../../common/request-context/request-context.service';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import { SessionsService } from '../../sessions/services/sessions.service';
import { InMemoryAuthSessionRepository } from '../../sessions/tests/in-memory-auth-session.repository';
import { type StoredUser } from '../../users/repositories/user.repository';
import {
  AccessTokenAuthenticationGuard,
  AllowDuringMfaEnrollment,
} from '../guards/access-token-authentication.guard';
import { AccessTokenService } from '../services/access-token.service';
import { failureOf, InMemoryUsers, testUser } from './authentication-test.fixtures';

class ProbeController {
  @PublicEndpoint()
  open(): void {}
  secured(): void {}
  @AllowDuringMfaEnrollment()
  enrollment(): void {}
}

@PublicEndpoint()
class PublicController {
  anything(): void {}
}

type Handler = keyof ProbeController;

function httpContext(
  authorization: string | undefined,
  handler: Handler | 'anything' = 'secured',
  controller: typeof ProbeController | typeof PublicController = ProbeController,
): ExecutionContext {
  const prototype = controller.prototype as unknown as Record<string, () => void>;
  return {
    getType: () => 'http',
    getHandler: () => prototype[handler],
    getClass: () => controller,
    switchToHttp: () => ({ getRequest: () => ({ headers: { authorization } }) }),
  } as unknown as ExecutionContext;
}

async function setup(userOverrides: Partial<StoredUser> = {}, mfaEnrollmentPending = false) {
  const config = configOf({
    JWT_ACCESS_SECRET: randomBytes(64).toString('base64'),
    JWT_ACCESS_TTL_SECONDS: 900,
    JWT_ISSUER: 'abra-travels',
    JWT_AUDIENCE: 'abra-travels-apps',
    MFA_CHALLENGE_TTL_SECONDS: 300,
    REFRESH_TOKEN_TTL_DAYS: 30,
    REFRESH_TOKEN_TTL_DAYS_STAFF: 7,
  });
  const users = new InMemoryUsers();
  const user = users.add(testUser(userOverrides));
  const sessionRepository = new InMemoryAuthSessionRepository();
  const sessions = new SessionsService(sessionRepository.asRepository(), config);
  const accessTokens = new AccessTokenService(config);
  const guard = new AccessTokenAuthenticationGuard(
    new Reflector(),
    accessTokens,
    sessions,
    users.asService(),
  );

  const { session } = await sessions.create({
    userId: user._id,
    userType: user.userType,
    clientType: 'MOBILE',
    client: { ip: '203.0.113.7' },
    mfaVerified: false,
    mfaEnrollmentPending,
  });
  const { token } = await accessTokens.issue({
    userId: user._id.toHexString(),
    userType: user.userType,
    sessionId: session._id.toHexString(),
    permissionVersion: user.permissionVersion,
  });
  return {
    guard,
    user,
    session,
    sessions,
    sessionRepository,
    accessTokens,
    token,
    bearer: `Bearer ${token}`,
  };
}

/** Runs the guard inside a request context, like the request-id middleware does. */
function inRequest<T>(work: () => Promise<T>): Promise<T> {
  return RequestContextService.run({ requestId: 'guard-spec' }, work);
}

describe('AccessTokenAuthenticationGuard', () => {
  it('lets public handlers and public controllers through without a token and without an actor', async () => {
    const { guard } = await setup();
    await inRequest(async () => {
      await expect(guard.canActivate(httpContext(undefined, 'open'))).resolves.toBe(true);
      await expect(
        guard.canActivate(httpContext(undefined, 'anything', PublicController)),
      ).resolves.toBe(true);
      expect(RequestContextService.actor()).toBeUndefined();
    });
  });

  it('ignores non-HTTP contexts (worker, queues)', async () => {
    const { guard } = await setup();
    const rpc = { getType: () => 'rpc' } as unknown as ExecutionContext;
    await expect(guard.canActivate(rpc)).resolves.toBe(true);
  });

  it.each([
    undefined,
    '',
    'Basic dXNlcjpwYXNz',
    'Bearer',
    'Bearer short',
    'bearer lower-case-scheme-is-not-accepted-aaaaaaaa',
    'Bearer two tokens-are-not-accepted-aaaaaaaaaaaaaaaa',
  ])('denies by default: Authorization %p → UNAUTHENTICATED', async (header) => {
    const { guard } = await setup();
    const error = await inRequest(() => failureOf(guard.canActivate(httpContext(header))));
    expect(error.code).toBe('UNAUTHENTICATED');
  });

  it('authenticates a valid token and attaches the request actor', async () => {
    const operatorId = new Types.ObjectId();
    const roleId = new Types.ObjectId();
    const { guard, bearer, user, session } = await setup({
      userType: 'OPERATOR_STAFF',
      operatorId,
      roleIds: [roleId],
      dataScope: { type: 'OWN_OPERATOR', operatorIds: [operatorId] },
      permissionVersion: 4,
    });

    await inRequest(async () => {
      await expect(guard.canActivate(httpContext(bearer))).resolves.toBe(true);
      const actor = RequestContextService.actor();
      expect(isAuthenticatedUserActor(actor)).toBe(true);
      expect(actor).toEqual({
        actorType: 'USER',
        userId: user._id.toHexString(),
        dataScope: { type: 'OWN_OPERATOR', operatorIds: [operatorId.toHexString()] },
        userType: 'OPERATOR_STAFF',
        sessionId: session._id.toHexString(),
        permissionVersion: 4,
        roleIds: [roleId.toHexString()],
        operatorId: operatorId.toHexString(),
        mfaEnrollmentPending: false,
      });
    });
  });

  it('takes identity from the database, not from token claims', async () => {
    // Token says CUSTOMER; the stored user is the authority for scope and type
    const { guard, bearer, user } = await setup();
    user.dataScope = { type: 'OWN_RECORDS', operatorIds: [] };
    await inRequest(async () => {
      await guard.canActivate(httpContext(bearer));
      expect(RequestContextService.actor()).toMatchObject({
        userType: 'CUSTOMER',
        dataScope: { type: 'OWN_RECORDS', operatorIds: [] },
      });
    });
  });

  it('rejects a token whose session was revoked — immediately, before the token expires', async () => {
    const { guard, bearer, sessions, session, user } = await setup();
    await sessions.revoke(session._id.toHexString(), user._id.toHexString(), 'LOGOUT');
    const error = await inRequest(() => failureOf(guard.canActivate(httpContext(bearer))));
    expect(error.code).toBe('UNAUTHENTICATED');
  });

  it.each(['SUSPENDED', 'DEACTIVATED', 'INVITED'] as const)(
    'rejects a %s user immediately',
    async (status) => {
      const { guard, bearer, user } = await setup();
      user.status = status;
      const error = await inRequest(() => failureOf(guard.canActivate(httpContext(bearer))));
      expect(error.code).toBe('UNAUTHENTICATED');
    },
  );

  it('rejects a token of a session that belongs to another user', async () => {
    const { guard, accessTokens, session } = await setup();
    const forged = await accessTokens.issue({
      userId: new Types.ObjectId().toHexString(),
      userType: 'CUSTOMER',
      sessionId: session._id.toHexString(),
      permissionVersion: 1,
    });
    const error = await inRequest(() =>
      failureOf(guard.canActivate(httpContext(`Bearer ${forged.token}`))),
    );
    expect(error.code).toBe('UNAUTHENTICATED');
  });

  it('answers PERMISSIONS_CHANGED when the account changed after the token was issued', async () => {
    const { guard, bearer, user } = await setup();
    user.permissionVersion += 1;
    const error = await inRequest(() => failureOf(guard.canActivate(httpContext(bearer))));
    expect(error.code).toBe('PERMISSIONS_CHANGED');
  });

  it('restricts a session that must enrol MFA to the enrolment endpoints', async () => {
    const { guard, bearer } = await setup({ userType: 'STAFF' }, true);
    const blocked = await inRequest(() => failureOf(guard.canActivate(httpContext(bearer))));
    expect(blocked.code).toBe('MFA_ENROLLMENT_REQUIRED');

    await inRequest(async () => {
      await expect(guard.canActivate(httpContext(bearer, 'enrollment'))).resolves.toBe(true);
      expect(RequestContextService.actor()).toMatchObject({ mfaEnrollmentPending: true });
    });
  });

  it('does not attach an actor when authentication fails', async () => {
    const { guard } = await setup();
    await inRequest(async () => {
      await failureOf(guard.canActivate(httpContext('Bearer not.a.valid-token-aaaaaaaaaaaa')));
      expect(RequestContextService.actor()).toBeUndefined();
    });
  });
});
