# Integration settings (WhatsApp and email)

Implemented 2026-10-07. The credentials used to message customers and bus owners are entered by an administrator in the management app (**Settings**), not edited in server files. The server's environment values remain only as a fallback.

## 1. Who can do what

| Action | Permission | Held by |
|---|---|---|
| View settings | `settings.read` | Super Admin, Admin |
| Change settings, test them | `settings.update` (sensitive) | Super Admin only |

Secrets are write-only. The API never returns an access token or a password; the screen shows only that one is set (a token also shows its last four characters, a password shows nothing). An empty secret field on save means "keep what is saved". Every change is audited with a mandatory reason (the screen fills in a default) and without the secret.

## 2. WhatsApp (`/settings/integrations/whatsapp`)

Fields: on/off, WhatsApp Business Account ID, phone number ID, access token, OTP template name and language, "send the code by SMS when WhatsApp fails". The token is stored encrypted (AES-256-GCM, `FIELD_ENCRYPTION_KEY`).

`POST /settings/integrations/whatsapp/test-connection` asks Meta (`GET /{version}/{phone-number-id}`) with the saved token and number ID. A valid answer proves the two work together and reports the number, its verified name and quality rating. No message is sent. A failure is a normal answer (`ok: false`) with a plain-language reason (wrong or expired token, wrong number ID, missing permission, rate limit, timeout). With `WHATSAPP_PROVIDER=development` it says nothing is sent to Meta.

Not built: a test message, the app secret and verify token (needed only for incoming webhooks, which do not exist yet).

## 3. Email (`/settings/integrations/email`)

Email goes out through **Nodemailer over SMTP**, so any provider works (Brevo, Resend, Gmail, Outlook, your own server). Fields: on/off, host, port, security (`SSL`, `STARTTLS`, `NONE`), username, password, sender name, from address, reply-to address. The password is stored encrypted. With no from address saved, `EMAIL_FROM` is used.

- `POST .../test-connection`: connects and signs in with the saved settings; nothing is sent.
- `POST .../test-email` `{ "to": "..." }`: sends a real test message through the saved settings.
- Failures are readable (wrong login, host not found, nothing listening on that port, secure connection could not be set up, address refused) and never contain the password.
- In production the host must be a public address (no `localhost`, private ranges or `.local`/`.internal` names), so an administrator account cannot make the server connect to its own network. Only the written host is checked, not what it resolves to.
- `EmailService.send(...)` is what the notification engine (client onboarding step 4) will call. With no server saved, the development adapter only logs; any other deployment refuses with "Email is not set up yet".

## 4. Code

Backend: `backend/src/integrations/email/` (settings schema and store, `EmailService`), `backend/src/modules/system-settings/` (controllers, admin services, WhatsApp connection check). Management app: `apps/admin_app/lib/features/settings/`.
