# Abra Travels

Bus booking, operations, master inventory, partner API and travel management platform.

- **Functional source of truth:** `Abra Travels.pdf` (122 sections)
- **How it is built:** see [`documentation/`](documentation/)

## Applications

| Path | Tech | Users |
|---|---|---|
| `apps/customer_app` | Flutter (Android, iOS, Web) | Travellers |
| `apps/operator_app` | Flutter (Web, tablet, mobile) | Bus operators and their staff |
| `apps/driver_app` | Flutter (Android) | Drivers, conductors |
| `apps/admin_app` | Flutter (Web) | Abra Travels admin, support, accounts |
| `apps/partner_app` | Flutter (Web) | External API partners |
| `apps/public_website` | Next.js | Public SEO pages (no booking logic) |
| `backend` | NestJS + TypeScript | Single API for all of the above |

## Infrastructure

MongoDB (replica set), Redis, BullMQ workers, Socket.IO, S3-compatible storage.

## Documentation index

| Document | Covers |
|---|---|
| [architecture.md](documentation/architecture.md) | Stack, system architecture, application/module map, key decisions |
| [project-structure.md](documentation/project-structure.md) | Monorepo folders and file naming |
| [database-architecture.md](documentation/database-architecture.md) | MongoDB collections, fields, indexes, constraints |
| [api-architecture.md](documentation/api-architecture.md) | REST API map, conventions, errors, idempotency |
| [authentication.md](documentation/authentication.md) | Login, OTP, JWT, refresh tokens, sessions, MFA |
| [authorization.md](documentation/authorization.md) | RBAC, granular permissions, user overrides, data scope |
| [state-machines.md](documentation/state-machines.md) | Seat, booking, payment, trip, refund, settlement states |
| [seat-locking.md](documentation/seat-locking.md) | Master inventory, atomic seat lock, booking confirmation |
| [background-jobs.md](documentation/background-jobs.md) | BullMQ queues, worker process, event outbox and relay, Redis recovery, readiness, backend Docker image |
| [payment-flow.md](documentation/payment-flow.md) | Payment, webhooks, verification, refunds, reconciliation |
| [notification-architecture.md](documentation/notification-architecture.md) | Event queue, SMS, email, WhatsApp, push, templates |
| [whatsapp-architecture.md](documentation/whatsapp-architecture.md) | Customer, operator and admin bots, AI guardrails |
| [live-tracking.md](documentation/live-tracking.md) | GPS, WebSocket, staleness, retention |
| [women-safety.md](documentation/women-safety.md) | SOS, trip sharing, incidents, escalation |
| [multilingual.md](documentation/multilingual.md) | i18n for UI, messages and chatbot |
| [public-website.md](documentation/public-website.md) | Next.js SEO site: pages, rendering, SEO, handoff to the booking app |
| [admin-cms.md](documentation/admin-cms.md) | Banners, offers, coupons, content, settings, feature flags |
| [testing.md](documentation/testing.md) | Unit, integration, e2e, concurrency, load, security tests |
| [deployment.md](documentation/deployment.md) | Environments, CI/CD, backups, disaster recovery |
| [environment-variables.md](documentation/environment-variables.md) | Every required variable |
| [implementation-plan.md](documentation/implementation-plan.md) | Build sequence and phase status |
| [go-live-plan.md](documentation/go-live-plan.md) | Agreed order for replacing mock data with the real platform: decisions, backend status, 16 blocks, edge cases, import/export |
| [abra-master-plan.md](documentation/abra-master-plan.md) ([PDF](documentation/abra-master-plan.pdf)) | **Start here.** The one master build plan: flow, architecture, the three-files-per-feature rule, phases 0 to 11 with test checklists, and the full demo-to-backend mapping (every page, button, field and endpoint) |
