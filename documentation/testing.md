# Testing Strategy

| Layer | Tool | Scope |
|---|---|---|
| Backend unit | Jest | State machines, fare calculation, coupon rules, commission rule matching, cancellation quote, permission resolution |
| Backend integration | Jest + `mongodb-memory-server` **replica set** + Redis | Repositories, transactions, seat lock, confirmation, webhooks, scope filtering |
| API e2e | Jest + Supertest | Full flows over HTTP incl. guards, 401/403/404, idempotency |
| Concurrency | Jest (parallel requests against a real replica set) + k6 | Scenarios in seat-locking.md §9 |
| Load | k6 (`infrastructure/load-tests/`) | 1000 concurrent searches, seat-lock storms, payment webhook spikes, partner API spikes, WebSocket tracking fan-out |
| Security | e2e + OWASP ZAP baseline in CI | Broken access control, tenant isolation (cross-operator IDs on every `:id` route), privilege escalation, NoSQL injection (`$` operators in input), XSS in CMS content, token reuse, rate limits |
| Flutter unit/widget | flutter_test | Controllers, seat map widget, permission gates, form validation, every screen rendered in all 8 locales |
| Flutter integration | integration_test against a seeded local backend | Search → seat → pay (development gateway) → ticket; operator trip publish; driver check-in |
| Next.js | Playwright + Lighthouse CI | SEO metadata, sitemap, Core Web Vitals |

## Mandatory suites before release

1. The end-to-end golden path (PDF §121) as an automated API e2e test and as a manual UAT script.
2. Repeated for: cancellation, partial cancellation, refund, failed payment, pending payment, duplicate webhook, expired lock, same-seat concurrency, trip cancellation, bus change, partner booking, WhatsApp booking assistance, multilingual customer, women safety SOS, tracking failure, notification provider failure.
3. RBAC matrix test: for each seeded role, call every endpoint and compare against the expected allow/deny table; plus DENY-override and deactivated-user cases.

## Coverage targets

Transaction-critical modules (inventory, bookings, payments, refunds, rbac): ≥ 90 % lines and every state transition. Other modules: ≥ 70 %.

## Manual checks by the project owner

After each module, a short test checklist is added to `documentation/test-checklists/<module>.md` for hands-on verification.
