# Go-live plan: from operator onboarding to a paid, tracked trip

Agreed 2026-10-10. This is the working plan for turning the mock-data customer app into the real, connected platform. It complements [implementation-plan.md](implementation-plan.md) (phases from the original brief) with the exact order, the decisions taken, and what each block must include. Status is checked against the code, not the old docs.

> **Superseded for phases and mappings by [abra-master-plan.md](abra-master-plan.md)** (2026-10-12). This file stays as the record of the decisions and edge cases it lists.

Status legend: ✅ done · 🟨 partly · ⬜ not started

## 1. Apps

| # | App | Folder | Users | Status |
|---|---|---|---|---|
| 1 | Customer app (Flutter) | `apps/customer_app` | Travellers | 🟨 all screens built on mock data; login, search, banners, notifications are real |
| 2 | Admin app (Flutter web) | `apps/admin_app` | Abra admin, support, accounts | 🟨 login + MFA, banners, customers, KYC settings, invitations, reviews, catalogue, settings |
| 3 | Client portal (Flutter web). This is the operator app; there is no separate one | `apps/client_portal` | Bus owners and their staff | 🟨 invitation, Google sign-in, company KYC, add bus, notifications |
| 4 | Driver app (Flutter, Android) | `apps/driver_app` | Drivers, conductors | ⬜ |
| 5 | Public website (Next.js) | `apps/public_website` | Anyone on Google | ⬜ |
| 6 | Partner app (Flutter web) | `apps/partner_app` | External agents / sites using the partner API | ⬜ last phase |

All talk to one NestJS backend (`backend/`) and one MongoDB.

## 2. Decisions taken

| Topic | Decision |
|---|---|
| Commission | Agreed privately between admin and operator. The system supports a rule per operator, per route or per bus type, as a percentage or a flat amount. Only the admin edits it; the operator sees it read-only. Each booking stores the commission that applied at booking time. |
| Fares | The operator chooses the style: one price per trip, or a price per seat type and per stop pair. Both are supported. |
| Trip approval | No per-trip approval. Company KYC and bus KYC are the only gates. |
| Payouts | Both: automatic split with Razorpay Route, and manual settlement. The admin picks the mode per operator. |
| Bus location | The driver app sends GPS. |
| Seat hold | 10 minutes, held on the server. Seat limit per booking is a flat 6. |
| Guests | Browse and search without login; login is asked only at Continue to book and for personal screens. |
| Map | Placeholder until the provider and the key are chosen (see §6). |

## 3. Where the backend stands today

| Area | Backend |
|---|---|
| Authentication (WhatsApp code, password, Google, MFA), sessions | ✅ |
| Roles, permissions, audit log | ✅ |
| Company and bus KYC: document types, questionnaire, files, review, notifications | ✅ |
| Banners (admin CRUD, public list) | ✅ (no click/impression analytics, no auto-archive job) |
| Cities, locations, bus types, operators, buses, routes, trips (publish, cancel) | ✅ |
| Public city lookup, trip search, filters, trip details | ✅ |
| Notifications (in-app, live, push, email, WhatsApp) | ✅ |
| Seat layouts, seat inventory, seat lock | ⬜ empty |
| Fares, schedules | ⬜ empty |
| Commission, settlements, reconciliation | ⬜ empty |
| Bookings, passengers, coupons, offers | ⬜ empty |
| Payments, refunds, tickets, check-in | ⬜ empty |
| Drivers, trip operations, live tracking | ⬜ empty |
| Women safety (SOS, sharing) | ⬜ empty |
| Reports, analytics, support, content, feature flags, maintenance | ⬜ empty |

## 4. The flow end to end

1. **Setup (admin).** Cities, places, bus types, amenities, document types, KYC questions, banners, system settings.
2. **Operator joins.** Admin invites, or the owner signs in with Google. KYC questionnaire and documents. Admin reviews each document, approves or rejects with reasons. The owner fixes only the rejected items. Approval makes the company active. Each bus is reviewed separately and only after the company.
3. **Commercial terms.** Admin sets the commission rule and the payout mode for the operator.
4. **Supply (operator).** Buses with a real seat layout, routes with timed stops, boarding and dropping points, fares (either style), single and recurring trips, publish.
5. **Booking (customer).** Banners, search, trip details, seat map, 10-minute hold, login at Continue, boarding and dropping point, passengers, coupon, Razorpay payment.
6. **After payment.** The server confirms payment, the ticket (PNR, QR, PDF) is issued, notifications go out, the operator sees the passenger list.
7. **Travel day.** The driver checks passengers in by QR, starts the trip and sends GPS. The customer sees live tracking, SOS and trip sharing.
8. **After the trip.** Cancellation and refund, operator settlement or automatic split, reports, exports.
9. **Public website.** Route pages for search engines; booking hands over to the customer app.

## 5. Build order

Each block ends with a review by the user before the next starts. Customer app mocks are swapped for the real repository inside the block that provides the endpoint.

| Block | Work | Apps touched | Done when |
|---|---|---|---|
| **0. Connect what exists** | Run backend, admin app, client portal and customer app together on a real database. Create the Super Admin. Walk invite → KYC → approval → bus → route → trip → customer search. Fix what breaks. | all | The walk-through passes with real data and no mock |
| **1. Seat layouts** | Versioned seat-layout designer: decks, rows, columns, seater / sleeper types, ladies seats, blocked seats, seat numbers. A bus holds an active layout version. | admin, client portal | An operator draws a layout for an approved bus; trips copy it |
| **2. Fares and schedules** | Fare rule sets (per trip, or per seat type and stop pair), date rules (weekday, weekend, festival), recurring schedules (daily, selected days, date range), bulk trip creation, stop-pair pricing. | admin, client portal | An operator creates a week of trips with fares in one go |
| **3. Commission** | Commission rules per operator, route or bus type (percentage or flat), versioned, admin only. Customer price = fare + commission + fee + GST, calculated on the server. | admin | The same price shown in search, seat screen and booking, with a stored breakdown |
| **4. Operator screens** | Routes, stops, boarding and dropping points, buses, layouts, fares, schedules, trips, trip cancellation with reason, in the client portal. Place lookups for the operator (request a new place, admin approves). Staff with limited access. | client portal | An operator runs the whole supply side without the admin |
| **5. Seat inventory and lock** | Inventory generated on publish. Atomic seat lock with expiry worker. `GET /trips/:id/seats`, `POST /trips/:id/seat-locks`. Customer seat screen goes live. | backend, customer | 500 concurrent requests for one seat give exactly one winner; expiry frees seats |
| **6. Bookings and coupons** | Passengers, booking creation with idempotency, coupon validation, cancellation policy per operator, offers (admin screens, `GET /offers`, banners link to offers). | backend, customer, admin | A booking is created from held seats with a server-calculated amount |
| **7. Payments and tickets** | Payment gateway interface, development gateway, Razorpay, webhooks, verification, late-payment recovery, PNR, ticket PDF and QR, ticket endpoint. | backend, customer | Duplicate webhook, failed, pending and expired-then-paid cases all end correct |
| **8. My Trips, cancellation, refunds** | Booking list and details, cancellation quote and partial cancellation, refund worker and status, operator passenger list and manifest. | backend, customer, client portal | A cancelled booking refunds the right amount and the seats return to sale |
| **9. Settlement and payouts** | Booking financials, settlement cycles, approval, payout. Razorpay Route automatic split and manual settlement, chosen per operator. Reconciliation against the gateway. | backend, admin, client portal | Settlement totals equal the payments minus commission minus refunds |
| **10. Driver app and tracking** | Driver login, assigned trips, passenger list, QR check-in, trip status and delay, bus change, GPS sending, staleness handling. Customer live tracking replaces the mock. Map provider and key needed here. | driver app (new), backend, customer | A driver trip shows live on the customer's tracking screen and goes stale correctly |
| **11. Safety and sharing** | Emergency contacts, SOS with live location and escalation to contacts and the safety team, trip-sharing link, incident dashboard. | backend, customer, admin | SOS reaches every recipient; sharing expires after the trip |
| **12. Admin reports and CMS** | Dashboard, bookings timeline, payments, refunds, customers, global search, reports, export, banner analytics, content, popular routes, feature flags, maintenance mode. | admin, backend | Reports match the transactions |
| **13. Public website** | Next.js route and city pages, SEO, structured data, search hand-off to the customer app. | public website | Route pages indexed and booking opens in the app |
| **14. Languages and hardening** | Telugu and the other languages reviewed by native speakers, load tests, security checks, restore test, staging test, launch. | all | Acceptance criteria in the brief met |
| **15. Partner app** | Partner onboarding, API clients, scopes, signed requests, webhooks, partner app. | backend, partner app | Partner and customer bookings cannot take the same seat |

Blocks 1 to 3 can overlap. Blocks 10 and 11 can start earlier once block 7 is done.

## 6. Open items that block specific blocks

| Needed | By block | From |
|---|---|---|
| Google Maps (or Mappls) provider choice and key, from the Google Cloud project that has billing attached; kept out of git, with a budget alert | 10 | user |
| Razorpay account, test and live keys, webhook secret, Route enabled for splits | 7, 9 | user |
| Cancellation slabs and refund percentages (default proposed in the docs; operators may override) | 6, 8 | user and operators |
| Who funds coupon discounts: platform or operator | 6, 9 | user |
| SMS provider (DLT registration), WhatsApp provider credentials, email provider | 7 onward | user |
| Hosting provider and a real storage bucket for documents | 14 (staging earlier) | user |
| Safety escalation contacts and legal review | 11 | user |
| Inter font files and official logos (Google, Apple, WhatsApp, UPI, banks) | any | user |
| Telugu and other language text reviewed by native speakers | 14 | user |

## 7. Edge cases that every block must cover

- **Seats:** two people choosing the same seat; hold expiry while on the payment screen; hold released on back; seats freed on failure; limit of 6 enforced on the server, not only the app.
- **Payment:** paid but booking not confirmed; app closed during payment; duplicate webhook; webhook before the client confirmation; amount mismatch; hold expired then paid (confirm if the seat is free, otherwise refund); never trust an amount sent by the app.
- **Idempotency:** double tap on pay or book returns the same booking; every create endpoint takes an idempotency key.
- **Operator side:** company suspended with future bookings (stop new sales, keep existing); bus retired or changed after trips are published; trip cancelled by the operator (automatic refund and notification); deleting a place used by trips is refused; documents that expire while a bus is active.
- **Prices:** commission changes must never alter bookings already made; fare changes must not alter published trips unless the operator republishes; rounding rules in paise, one function used everywhere.
- **Time:** all times in India time, trips across midnight, travel date versus departure date, cut-off before departure.
- **Customer:** guest with a link to a protected page; session expiry in the middle of a booking; slow or no network with a retry; account deletion with past bookings.
- **Notifications:** a provider failure must never fail a booking; no duplicate notifications for one event.
- **Access:** an operator can only ever see their own data; staff see only what their role allows; every sensitive action is audited.

## 8. Filters, import and export per area

| Area | Filters | Export | Import |
|---|---|---|---|
| Admin: operators, KYC reviews | status, date, city, search by name | CSV | none |
| Admin: bookings, payments, refunds | date range, status, operator, route, payment mode, PNR, phone | CSV and Excel | none |
| Admin: settlements | operator, cycle, status | CSV and Excel, payout file | none |
| Admin: customers | status, date, search | CSV | none |
| Admin: places and cities | state, type, active | CSV | Excel for bulk places, with row-by-row errors |
| Admin: coupons and offers | status, validity | CSV | none |
| Client: buses | status | CSV | Excel for buses |
| Client: trips and fares | route, date, status | CSV | Excel for schedules and fares, with row-by-row errors and a dry run before saving |
| Client: bookings and passengers | trip, date, status | CSV and PDF manifest | none |
| Client: earnings | date range, route | CSV and Excel | none |
| Customer: trips | upcoming, completed, cancelled | PDF ticket | none |
| Customer: search | time of day, bus type, AC, operator, amenities, fare range, sort | none | none |

Every list is paged on the server, sorted in a stable order, and every export is limited by the same filters and permissions as the list.

## 9. Testing

- Backend: unit tests for pricing, commission, cancellation and refund maths; end-to-end tests for each flow; the concurrency test for seat locks; webhook scenarios.
- Apps: the user runs the manual checklist given at the end of each block. `flutter analyze` and the existing tests stay clean.
- Visual check against the design system for every new screen.

## 10. How we work

- One block at a time; the plan is updated after each block with the status and the date.
- The login files in the customer app are not edited without asking.
- Secrets (Razorpay, Google Maps, service accounts) live in git-ignored files, never in code.
- No fake or sample data is shipped to production; development seed data stays behind a development switch.
