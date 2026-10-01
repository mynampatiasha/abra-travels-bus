import { type CookieOptions, type Request, type Response } from 'express';
import { ApiException } from '../../../common/errors/api-exception';
import { configOf } from '../../../common/rate-limit/tests/in-memory-rate-limiter.fixture';
import {
  clearRefreshTokenCookie,
  deliverRefreshToken,
  readCookie,
  REFRESH_TOKEN_COOKIE,
  refreshTokenFrom,
} from '../refresh-token-cookie';
import { type AuthenticationResult } from '../services/auth-session-issuer.service';

const RESULT = {
  tokenType: 'Bearer',
  accessToken: 'access',
  accessTokenExpiresInSeconds: 900,
  refreshToken: '66f0c0ffee00000000000001.secret',
  refreshTokenExpiresAt: '2026-11-01T00:00:00.000Z',
  sessionId: '66f0c0ffee00000000000001',
  mfaEnrollmentRequired: false,
} as AuthenticationResult;

function request(headers: Record<string, string>): Request {
  return { headers } as unknown as Request;
}

function response() {
  const cookie = jest.fn<void, [name: string, value: string, options: CookieOptions]>();
  const clearCookie = jest.fn();
  return { cookie, clearCookie, asResponse: { cookie, clearCookie } as unknown as Response };
}

describe('refresh-token cookie', () => {
  it('mobile sessions keep the refresh token in the body and set no cookie', () => {
    const res = response();
    const result = deliverRefreshToken(
      res.asResponse,
      configOf({ NODE_ENV: 'production' }),
      RESULT,
      'MOBILE',
    );
    expect(result).toBe(RESULT);
    expect(res.cookie).not.toHaveBeenCalled();
  });

  it('web sessions get an HttpOnly, Secure, SameSite=Strict cookie scoped to /api/v1/auth', () => {
    const res = response();
    const result = deliverRefreshToken(
      res.asResponse,
      configOf({ NODE_ENV: 'production', AUTH_COOKIE_DOMAIN: 'abratravels.com' }),
      RESULT,
      'WEB',
    );
    expect(result.refreshToken).toBe('');
    expect(res.cookie).toHaveBeenCalledWith(REFRESH_TOKEN_COOKIE, RESULT.refreshToken, {
      httpOnly: true,
      secure: true,
      sameSite: 'strict',
      path: '/api/v1/auth',
      domain: 'abratravels.com',
      expires: new Date(RESULT.refreshTokenExpiresAt),
    });
  });

  it('is not Secure only on plain-http local development and test', () => {
    for (const [environment, secure] of [
      ['development', false],
      ['test', false],
      ['staging', true],
      ['production', true],
    ] as const) {
      const res = response();
      deliverRefreshToken(res.asResponse, configOf({ NODE_ENV: environment }), RESULT, 'WEB');
      expect(res.cookie.mock.calls[0]?.[2]).toMatchObject({ secure, httpOnly: true });
    }
  });

  it('reads cookies by exact name', () => {
    const req = request({
      cookie: `other=1; ${REFRESH_TOKEN_COOKIE}=abc%2Edef; x_${REFRESH_TOKEN_COOKIE}=no`,
    });
    expect(readCookie(req, REFRESH_TOKEN_COOKIE)).toBe('abc.def');
    expect(readCookie(request({}), REFRESH_TOKEN_COOKIE)).toBeUndefined();
    expect(
      readCookie(request({ cookie: `${REFRESH_TOKEN_COOKIE}=%E0%A4%A` }), REFRESH_TOKEN_COOKIE),
    ).toBeUndefined();
  });

  it('prefers the body token; the cookie is accepted only with the anti-CSRF header', () => {
    const cookie = `${REFRESH_TOKEN_COOKIE}=cookie-token`;
    expect(refreshTokenFrom(request({ cookie }), 'body-token')).toBe('body-token');
    expect(refreshTokenFrom(request({}), undefined)).toBeUndefined();
    expect(refreshTokenFrom(request({ cookie, 'x-abra-client': 'web' }), undefined)).toBe(
      'cookie-token',
    );
    // A cross-site form post carries the cookie but cannot add the header
    expect(() => refreshTokenFrom(request({ cookie }), undefined)).toThrow(ApiException);
  });

  it('clears the cookie with the same attributes it was set with', () => {
    const res = response();
    clearRefreshTokenCookie(res.asResponse, configOf({ NODE_ENV: 'production' }));
    expect(res.clearCookie).toHaveBeenCalledWith(REFRESH_TOKEN_COOKIE, {
      httpOnly: true,
      secure: true,
      sameSite: 'strict',
      path: '/api/v1/auth',
    });
  });
});
