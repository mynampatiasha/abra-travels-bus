# System Architecture

## 1. Technology stack

| Layer | Choice | Notes |
|---|---|---|
| Customer / operator / driver / admin / partner apps | Flutter 3 + Dart, Material 3, Riverpod, go_router | Shared packages for models, network, auth, UI, localization |
| Public SEO website | Next.js (App Router, SSG/ISR) | Content, route landing pages, offers, FAQ. Deep-links into the Flutter booking app. No booking logic. |
| Backend | Node.js 24 LTS + TypeScript + NestJS | Modular monolith. One process for the API, separate processes for workers. Libraries: NestJS 12, Mongoose 9, ioredis, nestjs-pino (JSON logs), zod 4, helmet |
| Database | MongoDB 7+ **replica set** | Multi-document transactions require a replica set (Atlas or local `rs0`). |
| Cache / locks / rate limits | Redis 7 | Never the source of truth for seats or bookings. |
| Background jobs | BullMQ | Notifications, lock expiry sweeps, webhooks, refunds, reports, analytics |
| Real-time | Socket.IO (Redis adapter) | Live tracking, inventory refresh hints, admin alerts |
| API docs | OpenAPI 3 via `@nestjs/swagger` | Exported to `documentation/api/openapi.yaml` |
| Storage | S3-compatible (AWS S3 / Cloudflare R2 / MinIO in dev) | Documents, tickets, banners, attachments |
| Payments | `PaymentGateway` interface, `RazorpayPaymentGateway` first, `DevelopmentPaymentGateway` for local |
| Messaging | `WhatsAppProvider`, `SmsProvider`, `EmailProvider`, `PushProvider` interfaces + dev adapters that log to the `notification_deliveries` collection |
| Maps | `MapsProvider` interface (Google Maps / OSM) |
| AI | `AiProvider` interface (Claude API). AI calls backend tools only; it never writes inventory, bookings or payments. |
| CI/CD | GitHub Actions | lint → type-check → test → build → staging → approval → production |

## 2. High-level architecture

```
 Customer   Operator   Driver    Admin    Partner      Public website     External partner
 (Flutter)  (Flutter)  (Flutter) (Flutter)(Flutter)    (Next.js SSG)      systems
     \          |         |         |        /               |                 |
      \_________|_________|_________|_______/                |                 |
                          |  HTTPS REST /api/v1 + Socket.IO  |      Partner API (client credentials)
                          v                                  v                 v
                 +--------------------------------------------------------------------+
                 |                   NestJS API  (modular monolith)                    |
                 |  guards: auth → user status → permission → data scope → ownership   |
                 |  modules: auth, rbac, operators, fleet, routes, trips, inventory,   |
                 |  bookings, payments, refunds, tickets, notifications, partners,     |
                 |  webhooks, settlements, reports, cms, tracking, safety, chatbot ... |
                 +-------------+-------------------+-------------------+--------------+
                               |                   |                   |
                           MongoDB rs          Redis 7          S3 object storage
                        (source of truth)  (cache, rate limit,
                                            BullMQ, socket adapter)
                                                   |
                                    +--------------+---------------+
                                    |  BullMQ workers (separate    |
                                    |  process, same codebase)     |
                                    +--------------+---------------+
                                                   |
                      Payment gateway · WhatsApp · SMS · Email · Push · Maps · AI
```

## 3. Non-negotiable rules

1. **Master inventory is the source of truth.** Seat state lives only in the `trip_seat_inventory` collection and changes only through conditional atomic updates inside the inventory module. See [seat-locking.md](seat-locking.md).
2. **Payment is confirmed only by the server**, after gateway signature and amount verification (webhook or server-to-server status fetch). A client callback only triggers a verification call.
3. **Every state change is validated server-side** against the state machines in [state-machines.md](state-machines.md). An illegal transition throws `INVALID_STATE_TRANSITION`.
4. **Deny by default.** Every endpoint declares a permission. Data scope (operator tenant) is applied in the repository layer, not in controllers.
5. **History is append-only.** Fares, seat layouts and bookings are versioned or snapshotted. Nothing historical is overwritten.
6. **Side effects are asynchronous.** Booking confirmation commits first, then emits a domain event. Notifications, webhooks and tickets are processed by workers with retries.
7. **Fail safe.** If inventory cannot be verified, the seat is not sold. If payment cannot be verified, the booking is not confirmed. If a notification fails, the booking stays confirmed and the message is retried.
8. **No fake behaviour.** External providers are behind interfaces. Development adapters are named `Development*` and are enabled only when `NODE_ENV !== 'production'`.

## 4. Application map

| App | Platform targets | Primary users | Main areas |
|---|---|---|---|
| customer_app | Android, iOS, Web | Customers | Search, seat selection, booking, payment, tickets, my bookings, tracking, Women Safety, support, AI assistant |
| operator_app | Web, tablet | Operator admin, manager, booking, accounts, operations staff | Fleet, seat layouts, routes, schedules, trips, fares, inventory, bookings, manifest, settlements, reports |
| driver_app | Android | Driver, conductor | Today's trip, manifest, seat map, QR check-in, trip status, delay, GPS, SOS |
| admin_app | Web | Super admin, admin, support, accounts | Everything, permission-controlled (41 screens) |
| partner_app | Web | Partner users | Credentials, docs, usage, bookings, webhooks, settlements |
| public_website | Web (SSR/SSG) | Anonymous visitors, search engines | Home, route pages, offers, FAQ, policies, operator pages, blog |

## 5. Backend module map

Grouped by domain. Each module owns its collections; other modules call its **service**, never its repository.

| Domain | Modules |
|---|---|
| Identity | `authentication`, `users`, `rbac` (roles, permissions, overrides), `customers`, `sessions` |
| Supply | `operators`, `operator-staff`, `buses`, `bus-types`, `seat-layouts`, `cities`, `locations`, `routes`, `boarding-points`, `schedules`, `trips`, `fares`, `drivers` |
| Inventory & booking | `inventory` (trip seat inventory, seat locks), `bookings`, `passengers`, `coupons`, `tickets`, `check-in` |
| Money | `payments`, `refunds`, `commissions`, `settlements`, `reconciliation` |
| Channels | `partners`, `api-clients`, `partner-webhooks`, `whatsapp`, `chatbot`, `notifications`, `notification-templates` |
| Operations | `live-tracking`, `women-safety`, `support`, `trip-operations` (delay, bus change, trip cancellation) |
| Content | `banners`, `offers`, `content`, `translations`, `popular-routes` |
| Platform | `audit-logs`, `analytics`, `reports`, `system-settings`, `feature-flags`, `maintenance`, `health`, `files` |

## 6. Cross-cutting components (`backend/src/common`)

- `request-context` — AsyncLocalStorage holding requestId, actor, scope; used by audit logging and repositories.
- `guards` — `JwtAuthenticationGuard`, `PartnerClientGuard`, `PermissionGuard`, `MaintenanceModeGuard`.
- `decorators` — `@RequirePermission('bookings.cancel')`, `@PublicEndpoint()`, `@Idempotent()`, `@CurrentActor()`.
- `interceptors` — response envelope, idempotency, audit trail, request logging with redaction.
- `filters` — `ApiExceptionFilter` → `{ success:false, error:{ code, message, details, requestId } }`.
- `database` — `TransactionRunner` (session + retry on `TransientTransactionError`), `ScopedRepository` base that injects the operator filter.
- `events` — in-process domain event bus → transactional outbox → BullMQ.

## 7. Transactional outbox

Domain events (`booking.confirmed`, `trip.delayed`, ...) are written to the `outbox_events` collection **inside the same transaction** as the state change. An outbox relay worker publishes them to BullMQ queues (notifications, partner webhooks, analytics, settlement). This guarantees that no confirmed booking misses its notification and no notification is sent for a rolled-back booking.

## 8. Deployment architecture

```
Internet → CDN (public website, Flutter web, banner images)
        → Load balancer → API containers (N) ─┐
                         Worker containers (M) ├→ MongoDB Atlas replica set (PITR backups)
                         Socket gateway (API) ─┘→ Redis (managed) → S3
```

API and workers are the same Docker image started with a different command (`node dist/main.js` vs `node dist/worker.js`). See [deployment.md](deployment.md).

## 9. Key decisions

| Decision | Reason |
|---|---|
| Modular monolith, not microservices | One team, strong transactional needs; modules can be extracted later |
| One document per seat per trip (`trip_seat_inventory`) | Enables single-document atomic conditional updates and a unique index `(tripId, seatKey)` |
| Seat lock state stored in MongoDB, with Redis only as a fast pre-check | Redis loss must never cause a double booking |
| Fare snapshot on every booking seat | Fare changes never alter confirmed bookings |
| Seat layouts are immutable versions | Historical bookings always readable |
| Next.js only for SEO pages | Flutter Web is not indexable; booking logic stays in one client |
| Partner portal is a 5th Flutter app | Shares auth, network and UI packages |
