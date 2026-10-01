# Authentication

Status legend: **implemented** (Phase 2 step 7) · **Step 8** (RBAC, next) · **Phase 7** (partner platform) · **optional / future** (added when a provider or business decision exists).

Authorization (roles, permissions, overrides, data scope) is a separate concern: see [authorization.md](authorization.md).

## 1. Methods

| User type | Methods | Status |
|---|---|---|
| Customer | Phone OTP (primary, creates the account on first use) and optional email/phone + password | implemented |
| Customer | Google / Apple sign-in | optional / future |
| Staff (platform) | Email or phone + password, TOTP MFA — mandatory when `MFA_REQUIRED_FOR_STAFF=true` (forced on in production) | implemented |
| Operator staff | Email or phone + password, optional TOTP MFA | implemented |
| Driver / conductor | Phone OTP (also password if one is set) | implemented |
| Driver / conductor | Device binding | optional / future |
| Partner portal users | Email + password + TOTP MFA (MFA optional today) | implemented; mandatory partner MFA decided in Phase 7 |
| Partner API | API key + HMAC request signature, or OAuth2 client credentials | Phase 7 |

Phone OTP sign-in is accepted only for CUSTOMER and DRIVER accounts; other user types get `PERMISSION_DENIED` and must use their password.

## 2. Tokens

- **Access token:** JWT, `typ: at+jwt`, RS256 with a key pair in staging and production, HS256 with `JWT_ACCESS_SECRET` in development and test (enforced by configuration validation). Lifetime `JWT_ACCESS_TTL_SECONDS` (15 minutes). Claims: `sub` (user id), `typ` (user type), `sid` (session id), `pv` (permission version), `op` (operator id, when set), plus `iss`, `aud`, `iat`, `exp`. No names, contact details, roles or permissions. The algorithm, issuer, audience and token type are pinned on verification.
- **Every request re-checks MongoDB:** the guard loads the session and the user, so logout, session revocation, account deactivation and permission changes (`pv` mismatch → `PERMISSIONS_CHANGED`) take effect immediately, not when the token expires.
- **Refresh token:** opaque `<sessionId>.<256-bit random secret>`; only the SHA-256 of the secret is stored in `auth_sessions`. Lifetime `REFRESH_TOKEN_TTL_DAYS` (30) for customers and drivers, `REFRESH_TOKEN_TTL_DAYS_STAFF` (7) for staff, operator staff and partner users. **Rotated on every use.** Presenting a replaced token again revokes the whole session (theft detection); the only exception is the token replaced within the last 10 seconds (two refreshes racing), which is just rejected.
- **Web clients** (`device.clientType = WEB`) receive the refresh token as an `HttpOnly; SameSite=Strict` cookie (`Secure` outside development/test, `Path=/api/v1/auth`, optional `AUTH_COOKIE_DOMAIN`) and an empty `refreshToken` in the body. Refreshing or signing out with the cookie also requires the header `X-Abra-Client: web` (CSRF defence); a cookie without it is ignored with 401. Mobile apps receive the refresh token in the body and keep it in `flutter_secure_storage`.
- **MFA challenge token:** after a correct password for an account with MFA, a short-lived JWT (`typ: mfa+jwt`, separate audience, `MFA_CHALLENGE_TTL_SECONDS`) links the password step to `/auth/mfa/verify`. It can never authenticate an API request and completes at most one sign-in.

## 3. OTP

`OTP_LENGTH` (6) digits from the OS CSPRNG, stored only as HMAC-SHA256 with `OTP_HASH_SECRET`, `OTP_TTL_SECONDS` (5 minutes) expiry, `OTP_MAX_VERIFY_ATTEMPTS` (5) attempts per code (atomic counter), single use, purpose-bound (`SIGN_IN` or `PASSWORD_RESET`), and a new code replaces any earlier unused code for the same number.

Send limits (Redis, fail closed — `SERVICE_UNAVAILABLE` if Redis is down): `OTP_MAX_SENDS_PER_WINDOW` (3) per number and `OTP_MAX_SENDS_PER_IP_PER_WINDOW` (20) per IP per `OTP_SEND_WINDOW_SECONDS` (15 minutes), plus `OTP_RESEND_COOLDOWN_SECONDS` (30) between two codes to one number. `PASSWORD_RESET` codes are only delivered to active accounts, but the response is identical either way (no account enumeration).

The development SMS adapter sends nothing; it writes the message (with the code) to the server log **only** when `NODE_ENV=development` and refuses to start in production. A real SMS provider is an open business decision.

## 4. Passwords and lockout

Argon2id (Node's built-in implementation; 19 MiB, 2 passes, 1 lane; hashes with older parameters are upgraded at the next successful sign-in). Minimum 10, maximum 128 characters; passwords containing the account's email or phone, or made of fewer than 4 distinct characters, are rejected. Breached-password check: optional / future.

- Unknown identifier, account without password and wrong password cost the same Argon2id work and all answer `INVALID_CREDENTIALS`; account status is revealed only after a correct password.
- `LOGIN_MAX_FAILED_ATTEMPTS` (5) failures for one identifier within `LOGIN_LOCKOUT_SECONDS` lock it for `LOGIN_LOCKOUT_SECONDS` (15 minutes) → `ACCOUNT_LOCKED` (423, `details.retryAfterSeconds`). Failures are counted whether or not the account exists. A successful sign-in clears the counter; a password reset clears the lock.
- Per IP: at most `LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW` (50) attempts per `LOGIN_LOCKOUT_SECONDS` → `RATE_LIMITED`. (A fixed window; exponential per-IP back-off is optional / future.)
- Wrong second-factor codes count towards a separate lockout per user with the same limits.

## 5. MFA (TOTP)

RFC 6238 TOTP (HMAC-SHA1, 6 digits, 30-second steps, ±1 step). The secret is generated by the server, stored encrypted (AES-256-GCM, `FIELD_ENCRYPTION_KEY`) and shown once at enrolment. A code for an already-used time step is rejected (replay protection). Activation returns 10 single-use recovery codes (stored as SHA-256). Enabling or disabling MFA signs out every other device and increments the account's permission version, so access tokens issued before the change answer `PERMISSIONS_CHANGED`; the current device keeps its session and simply refreshes. Disabling requires a current code or a recovery code and is refused where MFA is mandatory.

When MFA is mandatory and not yet set up, a new session is created with `mfaEnrollmentRequired: true` and may only call `GET /me`, `GET /me/mfa`, `POST /me/mfa/totp/enroll`, `POST /me/mfa/totp/activate` and `POST /auth/logout-all`; every other endpoint answers `MFA_ENROLLMENT_REQUIRED` (403).

## 6. Sessions

`auth_sessions` stores client type, device name, IP, user agent, `lastUsedAt` (updated when the refresh token is used), expiry and revocation reason, so users can see and revoke their devices. Expired sessions are removed by a TTL index. Password change signs out all other devices; password reset signs out all devices.

`TRUST_PROXY_HOPS` must match the number of reverse proxies in production so the stored IP and the per-IP limits use the real client address.

## 7. Endpoints

All paths are under `/api/v1`. Every endpoint requires a valid access token unless marked public (global guard, deny by default).

### Implemented (step 7)

```
POST   /auth/otp/send          public  { phone, purpose: SIGN_IN | PASSWORD_RESET }  → { expiresInSeconds, resendAfterSeconds }
POST   /auth/otp/verify        public  { phone, code, device? }                      → tokens, or { mfaRequired, mfaToken } (creates the customer on first use)
POST   /auth/register          public  { phone, code, name, email?, password?, preferredLanguage?, acceptTerms: true, marketingConsent?, device? } → tokens
POST   /auth/login             public  { identifier, password, device? }             → tokens, or { mfaRequired, mfaToken }
POST   /auth/mfa/verify        public  { mfaToken, code | recoveryCode, device? }    → tokens
POST   /auth/refresh           public  { refreshToken? } (or web cookie + X-Abra-Client: web) → new tokens
POST   /auth/logout            public  { refreshToken? } (or web cookie + X-Abra-Client: web) → { signedOut: true }
POST   /auth/password/reset    public  { phone, code, newPassword }                  → { passwordReset: true }
POST   /auth/logout-all        auth    revokes every session of the account
GET    /me                     auth    profile (user type, operator, partner, language, hasPassword, mfaEnabled) + current session
POST   /me/password            auth    { currentPassword?, newPassword }  set or change the password
GET    /me/mfa                 auth    { enabled, required, recoveryCodesRemaining }
POST   /me/mfa/totp/enroll     auth    → { secret, keyUri }
POST   /me/mfa/totp/activate   auth    { code } → { recoveryCodes }
POST   /me/mfa/totp/disable    auth    { code | recoveryCode }
GET    /me/sessions            auth    active sessions, `current` marks this device
DELETE /me/sessions/:sessionId auth    revoke one of my sessions (another user's session → 404)
```

`device` is `{ clientType: MOBILE | WEB (default MOBILE), deviceName? }`. "Forgot password" is `POST /auth/otp/send` with `purpose: PASSWORD_RESET` followed by `POST /auth/password/reset`. Tokens: `{ tokenType: 'Bearer', accessToken, accessTokenExpiresInSeconds, refreshToken, refreshTokenExpiresAt, sessionId, mfaEnrollmentRequired, user }`.

Error codes: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `PERMISSIONS_CHANGED`, `INVALID_CREDENTIALS`, `OTP_INVALID`, `MFA_INVALID` (401) · `ACCOUNT_DISABLED`, `MFA_ENROLLMENT_REQUIRED`, `PERMISSION_DENIED` (403) · `ALREADY_REGISTERED` (409) · `ACCOUNT_LOCKED` (423) · `RATE_LIMITED` (429) · `SERVICE_UNAVAILABLE` (503).

### Deferred

```
GET  /me/permissions          effective permissions + permissionVersion          Step 8 (RBAC)
POST /partner-auth/token      client credentials → partner access token         Phase 7
POST /auth/password/forgot    email-based reset link                            optional / future (needs an email provider)
```
