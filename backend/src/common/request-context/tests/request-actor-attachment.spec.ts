import { currentAuthenticatedActor } from '../../decorators/current-actor.decorator';
import { ApiException } from '../../errors/api-exception';
import {
  type AuthenticatedUserActor,
  isAuthenticatedUserActor,
  systemActor,
  type UserActor,
} from '../request-actor';
import { RequestContextService } from '../request-context.service';

const authenticated: AuthenticatedUserActor = {
  actorType: 'USER',
  userId: 'user-1',
  dataScope: { type: 'OWN_RECORDS', operatorIds: [] },
  userType: 'CUSTOMER',
  sessionId: 'session-1',
  permissionVersion: 1,
  roleIds: [],
  mfaEnrollmentPending: false,
};

describe('request actor attachment', () => {
  it('attaches the actor to the running request context and keeps the request id', async () => {
    await RequestContextService.run({ requestId: 'req-1' }, async () => {
      expect(RequestContextService.actor()).toBeUndefined();
      RequestContextService.attachActor(authenticated);
      // Still visible after an await: the same context object travels with the request
      await Promise.resolve();
      expect(RequestContextService.actor()).toBe(authenticated);
      expect(RequestContextService.requestId()).toBe('req-1');
      expect(currentAuthenticatedActor()).toBe(authenticated);
    });
  });

  it('does not leak the actor into another request', async () => {
    await Promise.all([
      RequestContextService.run({ requestId: 'req-a' }, async () => {
        RequestContextService.attachActor(authenticated);
        await new Promise((resolve) => setTimeout(resolve, 5));
        expect(RequestContextService.actor()).toBe(authenticated);
      }),
      RequestContextService.run({ requestId: 'req-b' }, async () => {
        await new Promise((resolve) => setTimeout(resolve, 2));
        expect(RequestContextService.actor()).toBeUndefined();
      }),
    ]);
  });

  it('refuses to replace an actor or to attach outside a request', () => {
    expect(() => RequestContextService.attachActor(authenticated)).toThrow('request context');
    RequestContextService.run({ requestId: 'req-2' }, () => {
      RequestContextService.attachActor(authenticated);
      expect(() => RequestContextService.attachActor(systemActor('x'))).toThrow('already has');
    });
  });

  it('distinguishes authenticated users from plain and system actors', () => {
    const plain: UserActor = {
      actorType: 'USER',
      userId: 'u',
      dataScope: { type: 'ALL', operatorIds: [] },
    };
    expect(isAuthenticatedUserActor(authenticated)).toBe(true);
    expect(isAuthenticatedUserActor(plain)).toBe(false);
    expect(isAuthenticatedUserActor(systemActor('job'))).toBe(false);
    expect(isAuthenticatedUserActor(undefined)).toBe(false);
  });

  it('currentAuthenticatedActor answers UNAUTHENTICATED without an authenticated user', () => {
    RequestContextService.run({ requestId: 'req-3' }, () => {
      expect(() => currentAuthenticatedActor()).toThrow(ApiException);
    });
    RequestContextService.run({ requestId: 'req-4', actor: systemActor('job') }, () => {
      expect(() => currentAuthenticatedActor()).toThrow('Authentication is required');
    });
  });
});
