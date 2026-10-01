# Environment Variables

Files `.env.development`, `.env.test`, `.env.staging`, `.env.production` are **never committed**. `backend/.env.example` lists every key with dummy values. Values are validated at start-up with zod (`backend/src/config/`); the app refuses to start if a required value is missing or a `Development*` adapter is selected in production. Error messages name the variable, never its value. For local development, `npm run env:create-development` (in `backend/`) creates `.env.development` from the example with freshly generated secrets.

| Variable | Example | Required |
|---|---|---|
| NODE_ENV | development | yes |
| PORT | 4000 | yes |
| PUBLIC_API_BASE_URL | http://localhost:4000 | yes |
| CORS_ALLOWED_ORIGINS | http://localhost:3000,http://localhost:5000 | yes |
| MONGODB_URI | mongodb://localhost:27017/abra_travels?directConnection=true (local single-node rs0; `?replicaSet=rs0` also works from Windows, but not from other containers) | yes |
| REDIS_URL | redis://localhost:6379 | yes |
| REDIS_KEY_PREFIX | abra (namespace of rate-limit and sign-in lockout keys; BullMQ uses QUEUE_PREFIX) | no (default) |
| JWT_ACCESS_PRIVATE_KEY / JWT_ACCESS_PUBLIC_KEY | PEM | production |
| JWT_ACCESS_SECRET | random 64 bytes | development |
| JWT_ACCESS_TTL_SECONDS | 900 | yes |
| REFRESH_TOKEN_TTL_DAYS | 30 (customers, drivers) | yes |
| REFRESH_TOKEN_TTL_DAYS_STAFF | 7 (STAFF, OPERATOR_STAFF, PARTNER_USER) | no (default) |
| AUTH_COOKIE_DOMAIN | unset = host-only web refresh-token cookie | no |
| JWT_ISSUER / JWT_AUDIENCE | abra-travels / abra-travels-apps | yes |
| OTP_LENGTH / OTP_TTL_SECONDS / OTP_MAX_VERIFY_ATTEMPTS | 6 / 300 / 5 | yes |
| OTP_MAX_SENDS_PER_WINDOW / OTP_SEND_WINDOW_SECONDS | 3 / 900 | yes |
| OTP_RESEND_COOLDOWN_SECONDS | 30 (minimum time between two codes to one number) | no (default) |
| OTP_MAX_SENDS_PER_IP_PER_WINDOW | 20 (codes per IP per OTP window) | no (default) |
| OTP_HASH_SECRET | 32-byte base64 pepper for OTP hashes | yes |
| LOGIN_MAX_FAILED_ATTEMPTS / LOGIN_LOCKOUT_SECONDS | 5 / 900 | yes |
| LOGIN_MAX_ATTEMPTS_PER_IP_PER_WINDOW | 50 (sign-in attempts per IP within LOGIN_LOCKOUT_SECONDS) | no (default) |
| MFA_TOTP_ISSUER | Abra Travels | yes |
| MFA_REQUIRED_FOR_STAFF | false (STAFF must enrol TOTP; `false` is refused in production) | no (default false; true required in production) |
| MFA_CHALLENGE_TTL_SECONDS | 300 (token linking a correct password to the MFA step) | no (default) |
| QUEUE_PREFIX / QUEUE_DEFAULT_ATTEMPTS / QUEUE_BACKOFF_DELAY_MS / WORKER_CONCURRENCY | abra / 5 / 5000 / 5 | yes |
| QUEUE_LAG_ALERT_MS | 60000 (oldest waiting job age that marks a queue as lagging in readiness) | no (default) |
| OUTBOX_POLL_INTERVAL_MS / OUTBOX_BATCH_SIZE / OUTBOX_LEASE_MS / OUTBOX_MAX_PUBLISH_ATTEMPTS | 1000 / 100 / 30000 / 20 | no (defaults) |
| FIELD_ENCRYPTION_KEY | 32-byte base64 (bank details, licences) | yes |
| PAYMENT_GATEWAY | razorpay \| development | yes |
| RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET / RAZORPAY_WEBHOOK_SECRET | — | if razorpay |
| WHATSAPP_PROVIDER | meta \| development | yes |
| WHATSAPP_ACCESS_TOKEN / WHATSAPP_PHONE_NUMBER_ID / WHATSAPP_APP_SECRET / WHATSAPP_VERIFY_TOKEN | — | if meta |
| SMS_PROVIDER / SMS_API_KEY / SMS_SENDER_ID / SMS_DLT_ENTITY_ID | — | if not development |
| EMAIL_PROVIDER / EMAIL_API_KEY / EMAIL_FROM | — | if not development |
| PUSH_PROVIDER / FCM_SERVICE_ACCOUNT_JSON | — | if fcm |
| MAPS_PROVIDER / MAPS_API_KEY | — | for ETA |
| AI_PROVIDER / ANTHROPIC_API_KEY / AI_MODEL | claude-sonnet-5-5 | if AI enabled |
| STORAGE_DRIVER | s3 \| local | yes |
| STORAGE_LOCAL_ROOT | ./storage (folder used by the local storage driver) | no (default) |
| STORAGE_BUCKET / STORAGE_REGION / STORAGE_ENDPOINT / STORAGE_ACCESS_KEY / STORAGE_SECRET_KEY | — | if s3 |
| LOG_LEVEL | info | no |
| API_DOCS_ENABLED | true (default: true outside production; `true` is refused in production) | no |
| TRUST_PROXY_HOPS | 0 (number of reverse proxies in front of the API; needed for the real client IP) | no (default) |

Next.js (`apps/public_website/.env.local`): `NEXT_PUBLIC_API_BASE_URL`, `NEXT_PUBLIC_BOOKING_APP_URL`, `NEXT_PUBLIC_SITE_URL`, `REVALIDATE_SECRET`.

Production secrets live in the cloud secret manager and are injected at runtime.
