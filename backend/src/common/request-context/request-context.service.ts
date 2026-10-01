import { AsyncLocalStorage } from 'node:async_hooks';
import { type RequestActor } from './request-actor';

/**
 * Per-request data available anywhere in the call chain without passing it through parameters
 * (architecture.md §6). Audit logging and scoped repositories read the actor from here.
 */
export interface RequestContext {
  readonly requestId: string;
  /** Absent until authentication has run; scoped repositories refuse to work without it. */
  actor?: RequestActor;
}

const storage = new AsyncLocalStorage<RequestContext>();

export const RequestContextService = {
  run<T>(context: RequestContext, callback: () => T): T {
    return storage.run(context, callback);
  },

  current(): RequestContext | undefined {
    return storage.getStore();
  },

  /** Request id of the current request, or undefined outside a request (workers, start-up). */
  requestId(): string | undefined {
    return storage.getStore()?.requestId;
  },

  actor(): RequestActor | undefined {
    return storage.getStore()?.actor;
  },

  /**
   * Attaches the authenticated actor to the context of the current request. A guard cannot wrap
   * the rest of the request in a callback, so the context created by the request-id middleware
   * is updated in place. An actor is set once per request and never replaced.
   */
  attachActor(actor: RequestActor): void {
    const context = storage.getStore();
    if (!context) throw new Error('attachActor needs a request context');
    if (context.actor) throw new Error('The request context already has an actor');
    context.actor = actor;
  },

  /**
   * Runs `callback` with `actor` attached, keeping the current request id. Used by the
   * authentication guard once the caller is known, and by workers for SYSTEM work.
   */
  runWithActor<T>(actor: RequestActor, callback: () => T, requestId?: string): T {
    const current = storage.getStore();
    const resolvedRequestId = requestId ?? current?.requestId;
    if (resolvedRequestId === undefined) {
      throw new Error('runWithActor needs a request id outside an HTTP request');
    }
    return storage.run({ ...current, requestId: resolvedRequestId, actor }, callback);
  },
};
