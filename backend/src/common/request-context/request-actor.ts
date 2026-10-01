/**
 * Who is acting in the current request or job, and which data they may touch
 * (documentation/authorization.md §4). Set by the authentication guards (Phase 2 step 7/8) for
 * HTTP requests, and explicitly by workers and seeders for background work.
 */

export type DataScopeType =
  | 'ALL'
  | 'OWN_OPERATOR'
  | 'SELECTED_OPERATORS'
  | 'OWN_PARTNER'
  | 'OWN_RECORDS'
  | 'ASSIGNED_RECORDS';

/** Mirrors `users.dataScope`. */
export interface DataScope {
  readonly type: DataScopeType;
  /** Operator ids for OWN_OPERATOR / SELECTED_OPERATORS. */
  readonly operatorIds: readonly string[];
}

export interface UserActor {
  readonly actorType: 'USER';
  readonly userId: string;
  /** Set for partner users (OWN_PARTNER). */
  readonly partnerId?: string;
  readonly dataScope: DataScope;
}

export type UserType = 'STAFF' | 'OPERATOR_STAFF' | 'DRIVER' | 'PARTNER_USER' | 'CUSTOMER';

/**
 * A user identified by a verified access token (set by AccessTokenAuthenticationGuard). Carries
 * what authorization (Phase 2 step 8) needs to resolve permissions without another lookup.
 */
export interface AuthenticatedUserActor extends UserActor {
  readonly userType: UserType;
  readonly sessionId: string;
  /** `users.permissionVersion` at the time the request was authenticated. */
  readonly permissionVersion: number;
  readonly roleIds: readonly string[];
  /** The operator the user belongs to (operator staff, drivers). */
  readonly operatorId?: string;
  /** The session may only be used to finish MFA enrolment. */
  readonly mfaEnrollmentPending: boolean;
}

export function isAuthenticatedUserActor(
  actor: RequestActor | undefined,
): actor is AuthenticatedUserActor {
  return actor?.actorType === 'USER' && 'sessionId' in actor;
}

/**
 * Background work with no user (workers, seeders, the outbox relay). Always unrestricted, so it
 * must be set explicitly with a reason — never as a fallback for a missing user.
 */
export interface SystemActor {
  readonly actorType: 'SYSTEM';
  readonly reason: string;
}

export type RequestActor = UserActor | SystemActor;

export function systemActor(reason: string): SystemActor {
  return { actorType: 'SYSTEM', reason };
}
