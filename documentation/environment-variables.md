# Environment Variables

Files `.env.development`, `.env.test`, `.env.staging`, `.env.production` are **never committed**. `backend/.env.example` lists every key with dummy values. Values are validated at start-up with zod; the app refuses to start if a required value is missing or a `Development*` adapter is selected in production.

| Variable | Example | Required |
|---|---|---|
| NODE_ENV | development | yes |
| PORT | 4000 | yes |
| PUBLIC_API_BASE_URL | http://localhost:4000 | yes |
| CORS_ALLOWED_ORIGINS | http://localhost:3000,http://localhost:5000 | yes |
| MONGODB_URI | mongodb://localhost:27017/abra_travels?directConnection=true (local single-node rs0; `?replicaSet=rs0` also works from Windows, but not from other containers) | yes |
| REDIS_URL | redis://localhost:6379 | yes |
| JWT_ACCESS_PRIVATE_KEY / JWT_ACCESS_PUBLIC_KEY | PEM | production |
| JWT_ACCESS_SECRET | random 64 bytes | development |
| JWT_ACCESS_TTL_SECONDS | 900 | yes |
| REFRESH_TOKEN_TTL_DAYS | 30 | yes |
| JWT_ISSUER / JWT_AUDIENCE | abra-travels / abra-travels-apps | yes |
| OTP_LENGTH / OTP_TTL_SECONDS / OTP_MAX_VERIFY_ATTEMPTS | 6 / 300 / 5 | yes |
| OTP_MAX_SENDS_PER_WINDOW / OTP_SEND_WINDOW_SECONDS | 3 / 900 | yes |
| OTP_HASH_SECRET | 32-byte base64 pepper for OTP hashes | yes |
| LOGIN_MAX_FAILED_ATTEMPTS / LOGIN_LOCKOUT_SECONDS | 5 / 900 | yes |
| MFA_TOTP_ISSUER | Abra Travels | yes |
| QUEUE_PREFIX / QUEUE_DEFAULT_ATTEMPTS / QUEUE_BACKOFF_DELAY_MS / WORKER_CONCURRENCY | abra / 5 / 5000 / 5 | yes |
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
| STORAGE_BUCKET / STORAGE_REGION / STORAGE_ENDPOINT / STORAGE_ACCESS_KEY / STORAGE_SECRET_KEY | — | if s3 |
| LOG_LEVEL | info | no |

Next.js (`apps/public_website/.env.local`): `NEXT_PUBLIC_API_BASE_URL`, `NEXT_PUBLIC_BOOKING_APP_URL`, `NEXT_PUBLIC_SITE_URL`, `REVALIDATE_SECRET`.

Production secrets live in the cloud secret manager and are injected at runtime.
