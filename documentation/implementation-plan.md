# Implementation Plan

Timeline ≈ 3–5 months, in 10 phases. Phases overlap where safe (UI work runs in parallel with the backend module it depends on), but a phase touching inventory, payments or permissions is never marked done until its concurrency and security tests pass.

Status legend: ⬜ not started · 🟨 in progress · ✅ done

| # | Phase | Main deliverables | Exit criteria | Status |
|---|---|---|---|---|
| 1 | Discovery, architecture, UX | This documentation set, screen map, design tokens, infra decision | Docs reviewed; local MongoDB replica set + Redis reachable | ✅ 2026-09-30 |
| 2 | Foundation, design system, authentication | Monorepo, NestJS skeleton (config, request context, error envelope, logging, Swagger), Mongo transaction runner, outbox, BullMQ worker process; `shared_ui`, `shared_network`, `shared_authentication`, `shared_localization`; OTP + password + JWT + refresh rotation; customer login/signup screens | Login works end-to-end in customer and admin apps; CI green | 🟨 |
| 3 | RBAC + operator supply side | Permission registry, roles, overrides, data scope, PermissionGuard, ScopedRepository, audit logs, admin users/roles/permission matrix; operator registration + approval; buses, seat-layout designer (versioned), cities/locations, routes, stops, boarding/dropping points, schedules, fare rule sets; operator app screens | RBAC matrix test and cross-tenant tests pass; operator can create bus → layout → route → fare → trip | ⬜ |
| 4 | Master inventory, seat lock, booking engine | Trip publish → inventory generation, search API + customer search/results/filters/details, seat map, atomic seat locks, lock expiry worker, passenger details, booking creation with idempotency, coupons (backend) | 500-concurrent same-seat test: exactly 1 winner; idempotent replays; expiry correct | ⬜ |
| 5 | Payment, ticketing, cancellation, refunds | PaymentGateway interface, Development + Razorpay gateways, webhooks, verification, confirmation, late-payment recovery, PNR, ticket PDF + QR, my bookings, cancellation quote, partial cancellation, refunds worker, reconciliation | Duplicate-webhook, pending, failed, expired-lock-then-paid scenarios pass | ⬜ |
| 6 | Admin platform, CMS, marketing, reports | Admin dashboard, operators, trips, inventory monitor, bookings (timeline), payments, refunds, customers, global search, banners (with analytics), offers, coupons, content, popular routes, settings, feature flags, maintenance, basic reports; Next.js public website | Banner schedule/expiry works; reports match transactions | ⬜ |
| 7 | Partner API, webhooks, commission, settlement | Partner onboarding, API clients, scopes, HMAC auth, rate limits, `/partner/v1`, outgoing webhooks with retries, API monitoring, commission rules, booking financials, settlement generation/approval/payment, partner app | Partner booking + customer booking race safe; settlement numbers reconcile | ⬜ |
| 8 | Driver app, trip operations, live tracking, notifications, WhatsApp, multilingual | Driver app (manifest, QR check-in, status, delay), trip status/delay/bus change/trip cancellation workflows, Socket.IO tracking + staleness, notification engine + templates, WhatsApp provider, all 8 languages | Golden path incl. check-in and tracking; notification provider failure does not affect bookings | ⬜ |
| 9 | Women Safety, AI support, analytics | SOS, trip sharing, incidents + admin dashboard with escalation, AI assistant + WhatsApp bot with tool guardrails, analytics events + funnels | SOS escalation works end-to-end; AI never answers availability without a tool call | ⬜ |
| 10 | QA, security, load, UAT, launch | Full §121 end-to-end test + 15 variants, k6 load tests, OWASP checks, restore test, staging UAT, production deployment, monitoring, runbooks, training | All acceptance criteria in PDF §118 met | ⬜ |

## MVP cut (if phased launch is needed)

Phases 2–6 plus basic notifications (email/SMS) = MVP: customer booking, operator portal, admin portal, inventory, payment, ticket, cancellation, basic reports. Phases 7–9 add partner API, settlement, driver app, tracking, WhatsApp, AI, multilingual, Women Safety. The architecture (outbox, scopes, provider interfaces, language keys) is built in from Phase 2 so later phases do not rewrite the core.

## Build order inside Phase 2 (next step)

1. ✅ `backend/` NestJS project, config validation, request context, error envelope, logger with redaction, health endpoints, Swagger, module structure (2026-09-30).
2. ✅ MongoDB connection + `TransactionRunner` + index bootstrap + `ScopedRepository` (2026-09-30). BullMQ queues with Redis-outage recovery, worker entry point, transactional outbox + relay, readiness (queues, outbox), backend Docker image — implemented and verified 2026-10-01 ([background-jobs.md](background-jobs.md)).
3. `authentication` + `users` + `sessions` modules, OTP with development SMS adapter.
   RBAC foundation (permission catalogue, 12 roles, user overrides, data-scope integration, PermissionGuard, `/me/permissions`, administration endpoints, audit trail) — implemented and verified 2026-10-01 ([authorization.md](authorization.md)).
4. ✅ `packages/shared_*` Flutter packages (core, models, validation, network, authentication, permissions, storage, theme, localization, ui) in a pub workspace — implemented and tested 2026-10-05. Flutter permission checks are for visibility only; the backend enforces access.
   Known dependency for step 6: there is no Super Admin bootstrap yet (no way to create the first administrator account), so the Admin app cannot be signed in to against a fresh database until that is built in the backend.
5. Customer app ([customer-app.md](customer-app.md)): foundation (bootstrap, configuration, router with authentication gate, shell, language selection, error handling) — implemented and tested 2026-10-05. Sign-in with mobile number and one-time code (WhatsApp first, SMS fallback), sign-out, and the administrator API for the WhatsApp settings — implemented and tested 2026-10-05. Not built: Google and Apple sign-in (backend endpoints missing), live WhatsApp delivery (no Meta credentials yet). Discovery ([discovery.md](discovery.md)): catalogue collections, public city lookup, trip search with filters, sorting and pagination, trip details, and the customer app screens for them with guest browsing — implemented and tested 2026-10-06. Catalogue management API ([catalogue-management.md](catalogue-management.md)): cities, bus types, operators, locations, buses, routes, trips, publishing and cancelling, with permissions, operator isolation and audit — implemented and tested 2026-10-06. Super Admin bootstrap command and the management app ([admin-app.md](admin-app.md)): staff sign-in with two-step verification, permission-driven navigation, and catalogue pages for cities, bus types, operators, locations, buses, routes and trips with publishing — implemented and tested 2026-10-06. Next: run the management app against the real backend in a browser; user management (staff and operator accounts) and two-step verification set-up; then seat layouts and seat inventory.
6. Admin app: login, MFA, shell with permission-driven sidebar.
7. CI workflow for backend + Flutter.

## Open business decisions

| Topic | Needed by |
|---|---|
| Partner payment model (prepaid wallet vs. customer pays Abra) | Phase 7 |
| Cancellation policy slabs per operator (defaults above) | Phase 5 |
| Commission defaults and who funds coupons | Phase 5 / 7 |
| SMS provider (DLT registration), WhatsApp BSP, email provider | Phase 8 |
| Safety escalation contacts and legal review | Phase 9 |
| Hosting provider (AWS / GCP / Azure) | Phase 10 (staging earlier) |
