# Project Structure

## 1. Monorepo layout

```
abra-travels/
├── apps/
│   ├── customer_app/          Flutter
│   ├── operator_app/          Flutter
│   ├── driver_app/            Flutter
│   ├── admin_app/             Flutter
│   ├── partner_app/           Flutter
│   └── public_website/        Next.js
├── packages/                  Dart packages (pub workspace)
│   ├── shared_core/           Pure Dart: app config, Result, failures, error codes, redacting logger, storage interfaces
│   ├── shared_models/         Pure Dart: models mirrored from the API (hand-written JSON parsing, no code generation)
│   ├── shared_validation/     Pure Dart: phone, email, password, OTP, name validators (form feedback only)
│   ├── shared_network/        Dio client, response envelope, auth header, single refresh-and-retry, error mapping, idempotency keys
│   ├── shared_authentication/ Token store, session manager (restore, OTP/password/MFA sign-in, refresh, sign-out), auth API
│   ├── shared_permissions/    Backend permission/role keys (parity-tested against the backend catalogue), PermissionSet for UI visibility
│   ├── shared_storage/        Keystore/Keychain secure store (tokens) and ordinary preferences (language, settings)
│   ├── shared_theme/          Abra design tokens, light theme, status colours, breakpoints and responsive helpers
│   ├── shared_localization/   Locale config, ARB resources loaded at runtime with fallback, formatters, RTL/LTR, locale controller
│   └── shared_ui/             Buttons, cards, status badges, loading/empty/error/state views, confirm dialog
├── backend/                   NestJS
├── infrastructure/            docker-compose, mongo replica-set init, nginx, k6 load tests
├── documentation/             Architecture documents + api/openapi.yaml
├── .github/workflows/         CI pipelines
└── README.md
```

## 2. Backend layout

```
backend/src/
├── main.ts                    HTTP + Socket.IO entry point
├── worker.ts                  BullMQ worker entry point
├── app.module.ts
├── worker.module.ts
├── configure-http-application.ts  HTTP pipeline shared by main.ts and e2e tests (request id, helmet, CORS, prefix, filter, pipe, envelope, Swagger)
├── config/                    typed config + env validation (zod)
├── redis/                     shared ioredis client (cache, rate limits; never source of truth)
├── tests/                     application-level e2e tests (http-application.e2e-spec.ts)
├── common/
│   ├── guards/                jwt-authentication.guard.ts, permission.guard.ts, partner-client.guard.ts
│   ├── decorators/            require-permission.decorator.ts, current-actor.decorator.ts, idempotent.decorator.ts
│   ├── interceptors/          response-envelope.interceptor.ts, idempotency.interceptor.ts
│   ├── filters/               api-exception.filter.ts
│   ├── errors/                api-error-codes.ts, api-exception.ts
│   ├── request-context/       request-context.service.ts, request-id.middleware.ts, request-actor.ts
│   ├── logging/               logger-options.factory.ts (pino, redaction)
│   ├── openapi/               api-documentation.setup.ts (/api/docs)
│   └── pipes/                 zod-validation.pipe.ts, zod-dto.factory.ts
├── database/
│   ├── transaction-runner.service.ts, transaction-errors.ts
│   ├── scoped-repository.base.ts, data-scope.policy.ts
│   ├── index-bootstrap.service.ts, database-startup.service.ts, mongo-replica-set.verifier.ts
│   └── seeders/               permission-registry.seeder.ts, system-roles.seeder.ts, cities.seeder.ts
├── integrations/
│   ├── payment/               payment-gateway.interface.ts, razorpay-payment-gateway.ts, development-payment-gateway.ts
│   ├── whatsapp/  sms/  email/  push/  maps/  ai/  storage/
├── queues/                    queue-names.ts, queue-registry.service.ts, queue-health.service.ts, bullmq-connection.factory.ts
├── events/                    domain-event.types.ts, outbox.service.ts, outbox.repository.ts, outbox-relay.service.ts, domain-event-handler.registry.ts
├── gateways/                  live-tracking.gateway.ts, inventory-updates.gateway.ts, admin-alerts.gateway.ts
├── workers/                   queue-worker-host.service.ts, outbox-relay.worker.ts, domain-event-dispatch.processor.ts; later seat-lock-expiry.worker.ts, notification-dispatch.worker.ts ...
└── modules/<module-name>/
```

### Module layout (create only what the module needs)

```
modules/bookings/
├── bookings.module.ts
├── controllers/   booking.controller.ts, booking-admin.controller.ts
├── services/      booking-creation.service.ts, booking-confirmation.service.ts, booking-cancellation.service.ts, pnr-generator.service.ts
├── repositories/  booking.repository.ts
├── schemas/       booking.schema.ts, booking-timeline-event.schema.ts
├── dto/           create-booking.dto.ts, cancel-booking.dto.ts, booking-response.dto.ts
└── tests/         booking-confirmation.service.spec.ts, booking-cancellation.e2e-spec.ts
```

## 3. Flutter app layout (feature-first)

The layout below is the target. What exists today in the customer app is described in [customer-app.md](customer-app.md).

```
apps/customer_app/lib/
├── main.dart
├── customer_app.dart                  MaterialApp.router + theme + localization
├── routing/customer_router.dart       go_router with auth + permission redirects
└── features/
    ├── bus_search/
    │   ├── screens/bus_search_screen.dart, bus_search_results_screen.dart
    │   ├── widgets/bus_result_card.dart, bus_search_filter_sheet.dart
    │   ├── controllers/bus_search_controller.dart     (Riverpod Notifier)
    │   ├── repositories/bus_search_repository.dart     (calls API)
    │   └── models/bus_search_query.dart
    ├── seat_selection/
    ├── booking_checkout/
    ├── payment/
    ├── tickets/
    ├── my_bookings/
    ├── live_tracking/
    ├── women_safety/
    └── customer_profile/
```

Layering inside every feature: **screen → controller → repository → shared_network → API**. Screens never call Dio directly. Controllers never build widgets.

## 4. Naming rules

- Filenames describe their purpose: `seat_lock_countdown_banner.dart`, `payment-verification.service.ts`.
- Forbidden: `screen.dart`, `page.dart`, `service.dart`, `helper.dart`, `utils.dart`, `common.dart`, `manager.dart`, `data.dart`, `api.dart`, `new.dart`, `final.dart`, `test.dart`.
- Dart: `snake_case.dart`. TypeScript: `kebab-case.<kind>.ts` (`.controller`, `.service`, `.repository`, `.schema`, `.dto`, `.guard`, `.worker`, `.gateway`, `.spec`).
- Permission keys: `module.action` (e.g. `bookings.cancel`), defined once in `backend/src/modules/rbac/permissions/permission-catalog.ts` and mirrored to Flutter through `GET /api/v1/permissions`.
- No file above ~400 lines. Split by responsibility.
