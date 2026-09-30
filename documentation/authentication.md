# Authentication

## 1. Methods

| User type | Methods |
|---|---|
| Customer | Mobile OTP (primary), email + password, Google / Apple (when configured) |
| Admin / operator staff | Email or phone + password, optional TOTP MFA (mandatory for SUPER_ADMIN and ADMIN in production) |
| Driver / conductor | Phone OTP, device bound |
| Partner portal users | Email + password + MFA |
| Partner API | API key + HMAC request signature, or OAuth2 client credentials → short-lived access token |

## 2. Tokens

- **Access token:** JWT (RS256 in production, HS256 in development), 15 minutes. Claims: `sub`, `typ` (user type), `sid` (session id), `pv` (permission version), `op` (operator id if any). No permissions list inside the token.
- **Refresh token:** opaque 256-bit random value, stored hashed (SHA-256) in `auth_sessions`, 30 days (7 days for staff), **rotated on every use**. Reuse of an old refresh token revokes the whole token family (theft detection).
- Web apps keep the refresh token in an `HttpOnly; Secure; SameSite=Strict` cookie. Mobile apps use `flutter_secure_storage`.
- Logout revokes the session; "log out from all devices" revokes all sessions for the user.

## 3. OTP

6 digits, stored hashed, 5-minute expiry, max 5 verification attempts, max 3 sends per 15 minutes per number and per IP. Development SMS adapter writes the OTP to the server log **only** when `NODE_ENV=development`.

## 4. Passwords

argon2id, minimum 10 characters, breached-password check optional. Failed-login lockout: 5 failures → 15-minute lock, with exponential back-off per IP.

## 5. Sessions

`auth_sessions` stores device name, IP, user agent and last activity so customers and staff can see and revoke their devices.

## 6. Endpoints

```
POST /api/v1/auth/otp/send                 { phone, purpose: LOGIN|SIGNUP }
POST /api/v1/auth/otp/verify               → tokens (creates customer on first signup)
POST /api/v1/auth/login                    { identifier, password }  → tokens or { mfaRequired, mfaToken }
POST /api/v1/auth/mfa/verify               { mfaToken, code }
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
POST /api/v1/auth/logout-all
POST /api/v1/auth/password/forgot | /password/reset
GET  /api/v1/me                            profile + user type + operator + language
GET  /api/v1/me/permissions                effective permissions + permissionVersion
GET  /api/v1/me/sessions   DELETE /api/v1/me/sessions/:sessionId
POST /api/v1/partner-auth/token            client credentials → partner access token
```
