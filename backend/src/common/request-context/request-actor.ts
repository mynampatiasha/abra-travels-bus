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
