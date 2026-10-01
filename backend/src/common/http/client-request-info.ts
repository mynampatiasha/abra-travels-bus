import { type Request } from 'express';

export interface ClientRequestInfo {
  ip: string;
  userAgent?: string;
}

const MAX_USER_AGENT_LENGTH = 256;

/** Network facts about the caller. `request.ip` honours TRUST_PROXY_HOPS (load balancer). */
export function clientRequestInfo(request: Request): ClientRequestInfo {
  const userAgent = request.headers['user-agent'];
  return {
    ip: request.ip ?? request.socket.remoteAddress ?? 'unknown',
    ...(userAgent ? { userAgent: userAgent.slice(0, MAX_USER_AGENT_LENGTH) } : {}),
  };
}
