import { type Request, type Response } from 'express';
import { ApiException } from '../../common/errors/api-exception';
import { type AppConfigService } from '../../config/app-config.service';
import { type AuthenticationResult } from './services/auth-session-issuer.service';

/**
 * Web clients (admin, operator, partner, Flutter web) keep the refresh token in an HttpOnly
 * cookie, where page scripts cannot read it (authentication.md §2). Mobile apps receive it in the
 * response body and keep it in the platform keystore.
 */
export const REFRESH_TOKEN_COOKIE = 'abra_refresh_token';
/** The cookie is sent only to the authentication endpoints, never with ordinary API calls. */
export const REFRESH_TOKEN_COOKIE_PATH = '/api/v1/auth';
/**
 * A request that relies on the cookie must carry this header. Browsers do not attach custom
 * headers to cross-site form posts or image loads, and a cross-origin script needs a CORS
 * preflight that only allowed origins pass — so the cookie cannot be used by another site
 * (CSRF), in addition to SameSite=Strict.
 */
export const WEB_CLIENT_HEADER = 'x-abra-client';

function cookieOptions(config: AppConfigService) {
  const environment = config.get('NODE_ENV');
  const domain = config.get('AUTH_COOKIE_DOMAIN');
  return {
    httpOnly: true,
    // Plain http://localhost in development and test; HTTPS everywhere else
    secure: environment !== 'development' && environment !== 'test',
    sameSite: 'strict' as const,
    path: REFRESH_TOKEN_COOKIE_PATH,
    ...(domain ? { domain } : {}),
  };
}

export function readCookie(request: Request, name: string): string | undefined {
  for (const part of (request.headers.cookie ?? '').split(';')) {
    const separator = part.indexOf('=');
    if (separator > 0 && part.slice(0, separator).trim() === name) {
      try {
        return decodeURIComponent(part.slice(separator + 1).trim());
      } catch {
        return undefined;
      }
    }
  }
  return undefined;
}

/** Refresh token from the body (mobile) or from the cookie (web, with the anti-CSRF header). */
export function refreshTokenFrom(
  request: Request,
  bodyToken: string | undefined,
): string | undefined {
  if (bodyToken !== undefined) return bodyToken;
  const cookieToken = readCookie(request, REFRESH_TOKEN_COOKIE);
  if (cookieToken === undefined) return undefined;
  if (request.headers[WEB_CLIENT_HEADER] !== 'web') {
    throw new ApiException('UNAUTHENTICATED', 'Authentication is required');
  }
  return cookieToken;
}

/**
 * For a WEB session: moves the refresh token into the cookie and blanks it in the body.
 * For a MOBILE session: returns the result unchanged.
 */
export function deliverRefreshToken(
  response: Response,
  config: AppConfigService,
  result: AuthenticationResult,
  clientType: 'MOBILE' | 'WEB',
): AuthenticationResult {
  if (clientType !== 'WEB') return result;
  response.cookie(REFRESH_TOKEN_COOKIE, result.refreshToken, {
    ...cookieOptions(config),
    expires: new Date(result.refreshTokenExpiresAt),
  });
  return { ...result, refreshToken: '' };
}

export function clearRefreshTokenCookie(response: Response, config: AppConfigService): void {
  response.clearCookie(REFRESH_TOKEN_COOKIE, cookieOptions(config));
}
