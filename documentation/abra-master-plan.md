# Abra Travels: Master Build Plan

_One document for the whole project. Written 12 October 2026._


## Part 0. Start here (for anyone new, including another session)

Abra Travels is a bus booking platform: travellers book seats, bus owners (operators) sell them, Abra (admin) runs the marketplace, drivers run the trips. This document explains **what exists, how everything connects, the order to build it in, and the exact screens, buttons and endpoints to build**, so that nobody has to guess.

### 0.1 Facts you need in the first five minutes

| Item | Value |
|---|---|
| Repository | `D:\New_project\abra-travels` (monorepo) |
| Functional source of truth | `Abra Travels.pdf` (122 sections) in the repo root; the older design notes are in `documentation/` |
| The demos (the specification) | `prototypes/index.html` opens five working HTML demos: admin, client (operator), customer, driver, website. They share one data store and sync live. Everything in this document was read from them. |
| Backend | NestJS + TypeScript in `backend/`. 26 controllers and 113 routes in `*.controller.ts` files, plus 4 more controllers in `<feature>_manage` style files (access matrix, Google/Apple sign-in, client KYC, KYC configuration; see Appendix I.1). Only about 19 of the 56 module folders have real code; the rest are empty placeholders (Appendix I.2). |
| Database | MongoDB Atlas, database `abra_travels`. The connection string is in `backend/.env.development` (git-ignored). **Never put it in a document, a chat or git.** Connection tested: working. |
| Redis | Needed for seat holds, queues and live updates. Runs in Docker from `infrastructure/docker-compose.development.yml` (container `abra-redis`); start Docker Desktop first. |
| Flutter apps today | `apps/customer_app` (built on mock data, some screens missing), `apps/admin_app` and `apps/client_portal` (partly built: sign-in, KYC, banners, catalogue, settings). Shared code is in `packages/shared_*`. |
| Apps not started | Driver app, public website (Next.js), partner app |
| UI rule (mandatory) | **The real screens must look and behave exactly like the demo**: same layout, same labels and wording, same order of buttons, same colours and gradient, same dialogs and fields, same empty, error and loading states, same table and list views, same horizontal and vertical layouts. The demo is the design, not a sketch. |
| Design rule | Navy and blue palette with the brand gradient, from `documentation/design-system.md`. UI and functionality ship together. Every new screen gets a visual check. |
| Current phase | **Phase 1 is being built on its own branch** (status 13 Oct 2026: steps 1 to 4 done, see Part 4, Phase 1). **Phase 0, Foundation, in progress** (2026-10-12). Done: MongoDB connected, Redis running in Docker, backend starts with both up, access matrix built (code, 603 unit tests green). Waiting: allow the PC IP in Atlas Network Access, then run the Super Admin bootstrap and the matrix end-to-end test. See Part 4. |

### 0.2 How the demos map to the real build

| In the demo | In the real application |
|---|---|
| `AbraStore`: one shared data store in the browser | MongoDB collections behind one NestJS API (Appendix A lists every collection and field) |
| `route()`: turns an event into notifications | An event service in the backend that creates notifications, push, WhatsApp and email (Appendix B) |
| `msgSend` / message log | A message queue worker plus the `messages` collection and the WhatsApp and email providers |
| Saving to the browser and syncing between tabs | The API plus Socket.IO live updates |
| `PERM`: role access matrix (None, View, Edit, Edit+Delete) | RBAC on the server, editable by Super Admin only (Appendix C) |
| Proof attachments stored in the browser | The files service (Phase 0), with the same limits and the same viewer |
| Scripted assistant | One backend endpoint that calls Groq and answers only from the caller's own data |
| `_ver` reseed | A seed script that loads the same sample data (Phase 0) |
| Demo buttons such as "simulate a payment" | Do not exist in production; they are replaced by Razorpay and the driver app |

### 0.3 How to read this document

- **Part 1** the product and the flow. **Part 2** architecture and decisions. **Part 3** the file rule (three files per feature). **Part 4** the phases. **Part 5** the rules that apply to every feature. **Part 6** testing. **Part 7** open items and who owns them. **Part 8** how we work.
- **Appendices D to H** list every page, tab, filter, table column, button, dialog field and the endpoint behind each button, exactly as the demos show them. **Appendix J** lists the three files of every feature.
- If a number or label here and the demo ever disagree, the demo wins and this document is fixed.

### 0.4 What happens next (Phase 0 starts here)

1. Start Redis in Docker and confirm that `/health/ready` on the backend shows MongoDB and Redis up. (Claude; you confirm Docker Desktop is running.)
2. Reset the MongoDB Atlas password (it was exposed in a screenshot and in chat), allow your IP in Atlas, and put the new connection string in `backend/.env.development`. (You.)
3. Decide where proof files are stored: MongoDB GridFS or a cloud bucket. (You.)
4. Build the Phase 0 items: access matrix on the server, audit hook, event router, message log, settings, assistant endpoint, seed script and the Socket.IO channel. Each follows the three-file rule.
5. Run the Phase 0 checklist (Part 4); then Phase 1 begins.

## Part 1. The product and the flow

### 1.1 Who uses what

| Who | App | What they do |
|---|---|---|
| Traveller (customer) | Customer app (Flutter: Android, iOS, web) | Search, pick seats, pay, get the ticket, track the bus, cancel and refund, raise SOS, get support |
| Abra admin, support, accounts, Super Admin | Admin app (Flutter web) | Run the marketplace: onboard operators, set commission, watch trips and money, handle safety and support |
| Bus owner and their staff (the operator) | Client portal (Flutter web). This **is** the operator app; there is no separate one | Company KYC, buses, seat layouts, routes, fares, trips, bookings, earnings, driver rules and reports |
| Driver and conductor | Driver app (Flutter, Android) | Check passengers in, start and end the trip, send GPS, raise SOS, send reports, pass the pre-trip checklist |
| Anyone on Google | Public website (Next.js) | Route and city pages, offers, help, track-my-bus, contact, partner enquiry; booking hands over to the customer app |
| External agents | Partner app and partner API (last) | Book through the API |

### 1.2 The flow from start to payout

1. **Admin sets up the catalogue:** cities and places, bus types and amenities, required documents, KYC questions, banners, settings.
2. **An operator joins:** admin invites, or the owner signs in with Google. The owner fills the KYC questions and uploads documents. Admin reviews each document and approves it, or rejects it with a reason. The owner fixes only the rejected items. Approval makes the company active. Each bus gets its own KYC, and only after the company.
3. **Commercial terms:** admin sets the commission rule (agreed privately with the operator) and the payout mode (automatic split with Razorpay Route, or manual settlement).
4. **Supply:** the operator adds buses with a seat layout, routes with timed stops and boarding and dropping points, fares (one price per trip, or per seat type and stop pair), and single or recurring trips, then publishes. No per-trip approval: company KYC and bus KYC are the only gates.
5. **Booking:** the customer searches without logging in, picks seats (10 minute hold, at most 6 seats), logs in at Continue, chooses boarding and dropping points, enters passengers (email is required together with the mobile number), applies a coupon, and pays with Razorpay.
6. **After payment:** the server confirms, issues the ticket (PNR, QR, PDF), sends WhatsApp and email messages, notifies the operator.
7. **Travel day:** the driver passes the pre-trip checklist, checks passengers in by QR, starts the trip and sends GPS. The customer sees live tracking and has SOS and sharing. Admin and operator see the same bus on their maps.
8. **After the trip:** cancellation and refund (slabs set by admin), settlement to the operator (commission deducted), reports and exports.

### 1.3 Who sees whose data

- An operator and their staff see **only their own company's** data. This is enforced on the server.
- Admin roles see what the access matrix allows: None, View, Edit, Edit+Delete per page. Only the Super Admin edits the matrix.
- Customers see only their own bookings, support tickets and messages.
- Drivers see only the trips assigned to them and the rules their own operator set.

## Part 2. Architecture and decisions

### 2.1 The system in one picture

```
   Customer app   Admin app    Client portal   Driver app   Public website   Partner app
        \            |              |             |              |              /
         \___________|______________|_____________|______________|_____________/
                                      |  HTTPS (REST)  +  Socket.IO (live)
                              +------------------+
                              |  NestJS backend  |  one API for every app
                              +------------------+
                  |            |            |             |             |
              MongoDB        Redis        BullMQ        Files        Providers
          (all records)   (seat holds,   (workers:     (proofs,     (Razorpay, WhatsApp,
                           live data)    messages,      tickets)     email, SMS, Maps,
                                         refunds,                    Groq, Firebase push)
                                         expiry)
```

### 2.2 Technology

| Layer | Choice |
|---|---|
| Mobile and web apps | Flutter (Android, iOS, web), shared packages in `packages/shared_*` |
| Public website | Next.js |
| Backend | NestJS + TypeScript, one API |
| Database | MongoDB (Atlas). Money is stored in paise (integers). |
| Cache, locks, queues | Redis with BullMQ |
| Live data | Socket.IO (GPS, SOS, notifications, seat changes) |
| Payments | Razorpay: orders, webhooks, Route (automatic split) |
| Messages | WhatsApp provider, email provider, SMS (DLT), Firebase push (project ids are in the project memory notes) |
| Assistant | Groq, called only from the backend; admin picks the model and key |
| Maps | Placeholder until the provider and key are chosen (Part 7) |

### 2.3 Decisions already taken

| Topic | Decision |
|---|---|
| Commission | Agreed privately between admin and operator. A rule per operator, per route or per bus type; a percentage or a flat amount; versioned. Only admin edits; the operator sees it read-only. Each booking stores the rule that applied at booking time. |
| Fares | The operator chooses: one price per trip, or a price per seat type and per stop pair. Both are supported. |
| Trip approval | None. Company KYC and bus KYC are the only gates. |
| Payouts | Both modes supported; admin picks the mode per operator. |
| Bus location | From the driver app. |
| Seat hold | 10 minutes on the server. At most 6 seats per booking, enforced on the server. |
| Guests | Search without login; login only at Continue to book and on personal screens. |
| Customer contact | Mobile and email are both required. Google and Apple sign-in are offered next to the WhatsApp code. |
| Languages | All 8 in the first release: English, Telugu, Hindi, Kannada, Tamil, Malayalam, Marathi, Bengali. Language names are always shown in English next to the native script. |
| Proofs | Every sensitive admin action asks for a proof file (picture, PDF or text, up to 5 files, 600 KB each) that Abra and the person concerned can view and download. |
| Number cards | Every number card opens the records behind it. A card that says 1 must show that one record. |
| UI | The real UI is the same as the demo in every app. Nothing is redesigned, reworded or rearranged while connecting the backend. Any change to a screen is agreed with the user first and the demo is updated at the same time. |
| Operator app | The client portal is the operator app. One app, not two. |
| Driver rules | The operator maintains pre-trip and end-of-trip checklists and the report types. Abra provides default templates and a locked minimum that operators cannot remove. |
| Driver reports | Daily and weekly numbers come from the system and are frozen when the driver sends the report. The driver only adds what the system cannot know. |
| Shared catalogue mechanism (decided 12 Oct 2026) | One soft-delete field + restore route + audit hook, written once and used by every catalogue feature, built before the Phase 1 features. Per-module delete and export permission keys are added first so the access matrix can tell Edit from Edit+Delete; every new route gets its own key. |
| Export and import (decided 12 Oct 2026) | Server-side as in the plan: `GET .../export?format=csv\|xlsx` with the list's filters and permissions; import = template + dry run with row-by-row errors + save. The current client-side CSV import stays until the new one replaces it. |
| Proof files (decided 12 Oct 2026) | The existing files service: local storage in development, an S3-style bucket before staging. Not GridFS. |
| Three-file rule (decided 12 Oct 2026) | New code only. Working files are not rewritten. New endpoints on an existing module go in the new `<feature>_<app>_manage` `.ts` and `.service.ts` files. |
| KYC questionnaire (decided 12 Oct 2026) | Keep the one-configuration design at `/settings/kyc-configuration`; add only what the demo's three tabs need. |
| Database separation | This project uses its own database (`abra_travels`) on the Atlas cluster the user shared. Keep it separate from the databases of other Abra projects. |

## Part 3. The file rule: three files per feature

> **Rule:** Every feature is built as a small, complete package: **one screen file**, **one backend file**, **one service file**. Nothing is split into many small files. A feature is finished from the screen to the database before the next feature starts.

### 3.1 The three files

| # | File | Where | What is inside it |
|---|---|---|---|
| 1 | `<feature>_<app>_screen.dart` | `apps/<app>/lib/features/<feature>/` | Everything the user sees for this feature, in this order inside the one file: (1) data models, (2) state and controller, (3) API calls through the shared client, (4) every widget the screen needs (cards, tables, dialogs, forms, charts), (5) the screen itself. **No widgets in other files.** |
| 2 | `<feature>_<app>.ts` | `backend/src/modules/<module>/` | Everything the API needs for this feature, in this order: (1) Mongoose schema, (2) request and response types with validation, (3) the controller with every endpoint, (4) the Nest module wiring. **No other backend files for the feature.** |
| 3 | `<feature>_<app>.service.ts` | `backend/src/modules/<module>/` | All business logic: rules, calculations, permission checks, events, notifications, queries. The controller only calls the service. |

`<app>` is the audience: `admin_manage` for the admin portal, `client_manage` for the operator portal, `customer` for the customer app, `driver` for the driver app, `public` for the website. The SOS feature therefore has, for the admin: `sos_admin_manage_screen.dart`, `sos_admin_manage.ts`, `sos_admin_manage.service.ts`; for the customer: `sos_customer_screen.dart`, `sos_customer.ts`, `sos_customer.service.ts`; for the driver: the same with `driver`.

### 3.2 What is allowed to be shared

- **Flutter:** the shared packages already in `packages/` (network client, authentication, permissions, theme, UI kit, localization, validation, storage, notifications). A feature never copies them.
- **Backend:** authentication guards, the permission decorator, the audit service, the notification service, the files service, the Mongoose connection, and shared helper functions (money, dates, pagination). Written once, imported by every feature.
- **Collections:** the schema of a collection lives in the file of the feature that owns it (the `*_admin_manage.ts` file). Other audiences import it.
- **Tests** live in `test/` folders and are not counted as feature files.

### 3.3 Rules for the files

- Section banners inside each file (`// ===== 1. MODELS =====`) keep a long file easy to read. A file can be long; it must stay in order.
- The existing backend modules (cities, buses, trips, onboarding and so on) keep their present structure. The three-file rule applies to everything new. When an existing module needs new endpoints, they go into the new `<feature>_<app>.ts`.
- Every endpoint in the `.ts` file carries the permission it needs, the audit event it writes, and the notification it sends, written in a comment line above it so a reader sees the whole behaviour in one place.
- Every screen file shows loading, empty, error, no-permission and offline states. These are part of the screen, not extras.
- Money is shown in rupees, stored in paise. Dates are shown in India time.
- **The screen file reproduces the demo screen exactly:** the same sections in the same order, the same labels, buttons, filters, table columns, dialogs and form fields that Appendices D to H list, the same table / list toggle, the same horizontal / vertical layout option, the same number-card behaviour, the same 8-language switching and the same proof attachment box. If the demo and the screen file differ, the screen file is wrong.
- Naming: feature names are lower snake case and are the same in all three files and in Appendix J.

### 3.4 Example: the SOS feature for the admin

```
apps/admin_app/lib/features/sos/sos_admin_manage_screen.dart     <- models, controller, API calls, every widget, the screen
backend/src/modules/women-safety/sos_admin_manage.ts             <- schema, DTOs, controller (list, detail, acknowledge,
                                                                    escalate, resolve, false alarm, note), module
backend/src/modules/women-safety/sos_admin_manage.service.ts     <- rules: status changes, contact alerts, escalation timers,
                                                                    audit, notifications to customer, driver, operator
```

## Part 4. The phases

Each phase builds backend and screens together for the features inside it, so every phase can be tested end to end. The customer app is finished inside Phases 3 to 5; the admin portal and the client portal are built page by page in the phase of their feature and completed in Phases 7 and 8; the driver app starts in Phase 5 and is completed in Phase 9; the public website is Phase 10.

| Phase | Name | Apps | Features |
|---|---|---|---|
| 0 | Foundation | backend, shared Flutter packages | 8 |
| 1 | Catalogue, operators and KYC | backend, admin app, client portal (sign-up and KYC), customer app (banners) | 7 |
| 2 | Supply and commercial terms | backend, admin app, client portal | 7 |
| 3 | Customer booking journey | backend, customer app, admin app (bookings, payments, offers), client portal (bookings, offers) | 6 |
| 4 | After booking | backend, customer app, admin app (refunds, tickets, customers, content), client portal | 5 |
| 5 | Safety, driver GPS and live tracking | backend, driver app (new), customer app, admin app, client portal | 5 |
| 6 | Money out: settlements and payouts | backend, admin app, client portal | 1 |
| 7 | Rest of the admin portal | admin app, backend | 3 |
| 8 | Rest of the client (operator) portal | client portal, backend | 0 |
| 9 | Driver app in full: rules, reports and checklists | driver app, client portal, admin app, backend | 2 |
| 10 | Public website, then partner app | public website, backend, partner app | 2 |
| 11 | Languages, hardening and launch | all | 0 |

> **Note:** Why this order and not "all backend first": a mistake in an early endpoint stays hidden until a screen uses it. Building each feature with its screen finds mistakes the same day. The order still follows your plan: foundation and backend first, customer app, then admin, client, driver, website.

### 4.1 Customer app: what to check before building (found by comparing the Flutter code with the demo)

| Item in the demo | In the Flutter app today | Phase |
|---|---|---|
| Search, trip details, seats, boarding, passengers, review, payment, ticket, My Trips, cancel, refund, tracking, trip sharing, women safety, notifications and offers | Screens exist; their data comes from `Mock...Repository` classes with `Api...` stubs waiting | 3, 4, 5 |
| Home banners, city lookup, trip search | Real (call the backend today) | done |
| Messages page (copies of WhatsApp and email) | Not found in `features/`; check | 3 |
| Google and Apple sign-in buttons; email required together with mobile | Check the login and passenger screens (login files must not be edited without asking) | 3 |
| Per-seat-type prices on the seat map and in the fare breakup | Check | 3 |
| Running-trip banner on Home with Track and SOS | Check | 5 |
| SOS button on the tracking screen | Check | 5 |
| Support tickets with proof files and a reply thread | `support_screen.dart` looks static; check | 4 |
| Notification settings, delete account, 8 languages, AI assistant | Check each | 4, 11 |

### Phase 0. Foundation

|  |  |
|---|---|
| Goal | One working backend on real MongoDB and Redis, with sign-in, access rules, audit, notifications, files and seed data. Nothing else can start without this. |
| Apps touched | backend, shared Flutter packages |
| Done when | Backend starts clean; health check shows MongoDB and Redis up; a Super Admin can sign in; seed script loads the demo data; one notification travels from the backend to a phone and to the admin bell. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Sign-in and access control** (`auth_access`) | Customer: login sheet<br>Driver: login | Partly built (authentication, sessions, rbac, users) | users, sessions | 0 new / 1 existing | WhatsApp code, password, Google, Apple, MFA, sessions are built. Access matrix (None / View / Edit / Edit+Delete per role per page, Super Admin only, audited) built 2026-10-12 as access_matrix_admin_manage; waiting for a database test. Still to add: Apple sign-in. |
| **Audit log** (`audit`) | Admin: audit | Partly built (audit-logs) | audit | 2 new / 0 existing | Read endpoint exists. Add the write hook every sensitive action must call, filters, detail view and export. |
| **Notifications and event router** (`notifications`) | Admin: notifications<br>Client: notifications<br>Customer: notifs, nset<br>Driver: alerts | Partly built (notifications) | notifs, inbox | 12 new / 12 existing | In-app, push and live delivery exist. Add the event router that turns a business event into the right notification for the right person (see Appendix B). |
| **File storage and proof attachments** (`files`) | backend only | Done (files) | - | 0 new / 0 existing | Upload and download exist. Proofs use the same service: picture, PDF or text, up to 5 files and 600 KB each, viewable and downloadable by Abra and the person concerned. |
| **WhatsApp and email messages** (`messages`) | Admin: messages<br>Customer: msgs | Partly built (whatsapp, notification-templates, notifications) | messages | 6 new / 0 existing | Provider settings exist. Add the message log, the templates per event and the resend action. |
| **Integrations, feature flags and maintenance** (`settings`) | Admin: settings, flags | Partly built (system-settings, feature-flags, maintenance) | settings, flags, maint | 9 new / 2 existing | Email and WhatsApp settings exist. Add Razorpay, Maps, Groq, SMS, feature flags and the maintenance switch. |
| **AI assistant (Groq)** (`assistant`) | Admin: ai<br>Customer: assistant<br>Driver: assistant | New (chatbot) | - | 5 new / 0 existing | One backend endpoint calls Groq and answers only from the caller's own data. Admin chooses the model and key in settings. Spoken input uses the phone or browser speech service. |
| **Seed data and live updates** (`seed`) | backend only | New (database, events) | - | 0 new / 0 existing | A script loads the demo data into MongoDB. A socket channel replaces the demo's browser-to-browser sync. |

#### Phase 0: your test checklist

- Driver app, **Sign in**: Sign in.
- Admin, **Audit log**: the list loads; try the filters (Search, Person, Type, Action); press Export CSV, View; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Notifications**: the list loads; try the filters (Search, Status); press Mark all read, View, Save changes, Delete, History, Reject submission, Approve; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Notifications**: the list loads; try the filters (Search); press Mark all read, Send for approval, Import, Export CSV, View, Mark maintenance; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Notifications**: List / open; Mark all read. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Driver app, **Notifications**: List / read all.
- Admin, **Messages sent**: the list loads; try the filters (Customer, phone, email, PNR, Channel, Type); each number card opens its records; press Export CSV, Send again, View, Save changes, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Messages sent to me**: List / open. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Settings and integrations**: the list loads; press Save, Test connection, Confirm, Preview; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Feature flags and maintenance**: the list loads; try the filters (Starts, Ends); press Turn off, Turn on, Save message and schedule; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **AI assistant**: the list loads; try the filters (Provider, Model, Messages per admin per day, Saved on the server only); each number card opens its records; press Test connection, Save, Export CSV; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **AI assistant**: Send / voice. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Driver app, **AI assistant**: Send / voice.

### Phase 1. Catalogue, operators and KYC

|  |  |
|---|---|
| Goal | Everything admin sets up before a bus owner can join: places, bus types, required documents, KYC questions, invitations, KYC review, operators, banners. |
| Apps touched | backend, admin app, client portal (sign-up and KYC), customer app (banners) |
| Done when | Admin invites an operator; the owner signs in, fills the KYC, admin approves or rejects document by document; the owner fixes only the rejected items. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Cities and places** (`places`) | Admin: places<br>Client: places<br>Customer: city | Partly built (cities, locations) | cities, places, placeReqs | 8 new / 3 existing | Cities and locations exist. Add operator place requests with approval, import, usage counts and delete protection. |
| **Bus types and amenities** (`bus_types`) | Admin: bustypes | Partly built (bus-types) | busTypes, amenities | 5 new / 1 existing | Bus types exist. Add amenities. |
| **Required documents and KYC questionnaire** (`kyc_config`) | Admin: documents, questions | Partly built (document-types, onboarding) | docTypes, questions | 12 new / 2 existing | Document types exist. Add the questionnaire builder, preview and export. |
| **Operator invitations** (`invitations`) | Admin: invitations | Done (onboarding) | invitations | 4 new / 2 existing | Send, resend, revoke, accept exist. Add edit, delete, export. |
| **KYC review and company onboarding** (`kyc`) | Admin: kyc<br>Client: kyc, company | Done (onboarding) | submissions | 4 new / 2 existing | Submissions, per-document review, approve and reject exist. Add history, export, bus-level KYC from the client portal. |
| **Operators** (`operators`) | Admin: operators | Partly built (operators) | operators | 6 new / 2 existing | List, read, update, status exist. Add suspend and reactivate with reason and proof, message to owner, bank verification. |
| **Banners** (`banners`) | Admin: banners<br>Customer: home banner<br>Website: home | Done (admin-banners) | banners | 5 new / 5 existing | Done. Add click and impression counts and the archive job. |

#### Phase 1: build order (approved 12 October 2026)

0. Checkpoint commit (done) and this document corrected. 1. Per-module delete and export permission keys, then the shared mechanism (soft delete, restore, audit hook, shared list query, "in use" check). 2. Small items: banner duplicate, archive and reorder; read-one routes; invitation edit and expiry. 3. Server-side export for every list, then import with template and dry run. 4. Amenities. 5. Place requests (backend, admin tabs, client Places page). 6. Operator detail page with tabs, suspend with proof, message owner. 7. Payout mode and bank verification. 8. Company profile and bank details (client portal). 9. Bus KYC (client portal) and KYC history. 10. KYC questionnaire compared with the demo's three tabs (can run early, in parallel). One step at a time; you test after each.

**Status on 13 October 2026.** Phase 1 is being built on the branch `phase1-catalogue-kyc` (its own working folder, `D:/New_project/abra-wt-p1`). It is not merged into `main` yet; the coordinator merges it.

| Step | What | Status | Commits |
|---|---|---|---|
| 0 | Checkpoint commit and this document corrected | Done 12 Oct | on `main` |
| 1 | Delete and export permission keys; one shared soft delete with restore, audit and "in use" refusal | Done 12 Oct | 276be54, 501667f |
| 2 | Banner duplicate, archive and reorder; read-one routes; invitation edit and the Expired status | Done 13 Oct | b982a60 |
| 2b | Admin screens for step 2; banner fields as in the demo (colour style, shown to, operator link, higher order first) | Done 13 Oct | 2001676, edbd087 |
| 3 | Server-side export of eight lists (CSV and Excel); import with template and dry run for cities and places | Done 13 Oct | 39e7ee4, fe15857 |
| 4 | Amenities as a managed list; Amenities card on the Bus types page | Done 13 Oct | 6f75cb4, 222913e |
| 5 | Place requests (backend, admin tab, client page) | Not started | |
| 6 | Operator detail with tabs; suspend with reason and proof; message owner | Not started | |
| 7 | Payout mode and bank details with verification | Not started | |
| 8 | Company profile and bank details (client portal) | Not started | |
| 9 | Bus KYC (client portal) and KYC history | Not started | |
| 10 | KYC questionnaire compared with the demo's three tabs, and its export | Not started | |

**What works now**

- **Delete and Undo** on cities, places, bus types, required documents, operators, invitations and banners. A record that other records use is refused with a sentence that names what uses it ("This city is used by 3 routes and 5 trips, so it cannot be deleted. Disable it instead."). Undo is the restore route. Needs the module's delete key (Edit+Delete level). Audited.
- **View** (read-only window) on cities, places, bus types, required documents, operators and invitations.
- **Banners** as in the demo: columns Banner, Status (Draft, Scheduled, Published, Expired, Archived), Runs, Shown to, Opens, Order with arrows; the form with colour style, Opens (offer, route search, operator, web link), offer code, shown to (everyone, new users, signed-in users), dates, order, pictures and a home-screen preview; Save draft and Publish; Unpublish, Duplicate, Archive (with Undo and a way back), Delete (with Undo).
- **Invitations**: open one, edit a pending one (a new email makes the old link stop working; the closing date can be moved up to 30 days ahead), Expired filter and card, search, delete a withdrawn one.
- **Export** (CSV or Excel, the list's own filters, at most 20,000 rows, audited) for cities, places, bus types, required documents, operators, invitations, KYC reviews and banners.
- **Import** for cities and places: template download (the headings match the export), a check of the whole file that lists the problem of every row, then a save of the rows that are right (at most 500 rows and 1 MB). The old on-device CSV import remains for bus types, required documents and banners until they get the same.
- **Amenities** are a list staff manage (add, switch on or off; never deleted). A bus can be given only amenities that are switched on; a bus keeps an amenity that was switched off later. The 13 amenities that were fixed before are the starting list.

**Decisions taken while building (13 October 2026)**

- Soft delete is one mechanism for all catalogue records (`deletedAt`, `deletedBy`; `backend/src/database/soft-delete.plugin.ts`). A deleted record is hidden from every query. Known limit: the unique key or slug of a deleted city, bus type or document type stays taken; restore it instead of adding it again.
- Delete and restore both need the module's delete key. Export is a View-level action in the access matrix (the demo shows Export to everyone who can open the page); delete is Edit+Delete only.
- Only a withdrawn invitation can be deleted. A pending or accepted one is refused.
- Banner order: a higher number shows first (as in the demo; this reversed the old lower-first rule). Banner pictures: desktop 1920 x 600, phone 800 x 600, at most 1 MB. The customer app asks for `GET /banners?viewer=GUEST|NEW_USER|RETURNING` so audiences reach the right people; it must also draw `colourStyle`.
- An import saves the rows that are right and leaves out the others, saying why for each row; a file is never refused as a whole because of one bad row (only for missing columns, size or row count).
- Export and import controllers are registered before a module's other controllers, because those have `GET <list>/:id` routes.
- Tests that need the database run on the local Docker MongoDB in a throw-away database whose name ends in `_test`, not on Atlas.

**Where the real screens still differ from the demo**

- Banners: no Analytics tab yet (impressions and clicks are not counted); the offer code is a text field until the offers module exists (Phase 3); the route, operator and web-link inputs are extra, because the demo form has no place to enter them; Expired and "Put back as draft" are extra statuses and buttons.
- Cities and places: the lists lack the demo's Search, City, Used-for and Status filters, the Operator requests tab and the "Trips using it" column (step 5 and later).
- Operators: no detail page with tabs, and no Buses, Trips or Rating columns (step 6).
- Required documents and KYC questionnaire: export of the questionnaire, delete of questions and the three-tab comparison wait for step 10.
- Screens were checked with automated tests and the analyzer, not yet looked at in a browser against the demo.

**Known problems that are not caused by Phase 1**

- 13 end-to-end tests in the rbac module and 2 in document types fail on plain `main` too (an operator administrator gets 403). One queue unit test is flaky.

**Shared files changed on this branch** (appended only; the coordinator keeps them when merging): the permission catalogue (`catalogue.delete`, `catalogue.export`, `documents.delete`, `documents.export`, `operators.delete`, `operators.export`, `banners.read`, `banners.export`), the access pages (`export` counts as a View action), the audit actions (`catalogue.deleted`, `catalogue.restored`, `catalogue.exported`, `catalogue.imported`, `onboarding.invitation-updated`), the error codes (`RESOURCE_IN_USE`), the domain module list (`CatalogueSharedModule`, `AmenitiesModule`), the Dart permission keys and error codes, `ApiClient.patch`, and the backend package list (`exceljs`).

Boundaries: do not run prettier or eslint --fix across `rbac` or `users`; the audit action list is shared, so only add actions; stay out of `whatsapp`, `notifications`, `system-settings` and `chatbot` (another session works there).

#### Phase 1: your test checklist

- Admin, **Cities and places**: the list loads; try the filters (Search, City, Used for, Status); press Export CSV, Save, Import, View, Delete, Approve, Reject; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Places**: the list loads; try the filters (Search, City); press Send request, View, Export CSV; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Bus types and amenities**: the list loads; press Save, Export CSV, View, Delete, Add, Toggle Charging point; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Required documents**: the list loads; try the filters (Search, For); press Save, Export CSV, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **KYC questionnaire**: the list loads; try the filters (Search); press Export CSV, Save, Export config, View, Delete, Show checklist; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Invitations**: the list loads; try the filters (Search, Status); press Send invitation, Export CSV, Resend, Revoke, View, Save changes, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **KYC reviews**: the list loads; try the filters (Search, Status, Type); press Export CSV, View, History; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **KYC verification**: the list loads; press each button; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Company profile**: the list loads; try the filters (Company name *, Owner name *, Email *, Support phone); press Save, Save bank details; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Operators**: the list loads; try the filters (Search, Status, Payout mode); press Export CSV, View, Save changes, Delete, Suspend, Send, Save; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Banners**: the list loads; try the filters (Search, Status); press Export CSV, Save draft, Publish, Unpublish, Duplicate, Archive, View; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Website, **Home**: Search; Banners / offers / popular routes.

### Phase 2. Supply and commercial terms

|  |  |
|---|---|
| Goal | Buses, seat layouts, crew, routes, fares, schedules, trips, seat inventory, commission rules and payout settings. |
| Apps touched | backend, admin app, client portal |
| Done when | An operator runs the whole supply side alone and publishes a week of trips; admin sets commission and payout mode; the customer price is calculated on the server. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Buses and seat layouts** (`buses`) | Admin: buses<br>Client: buses, layouts | Partly built (buses, seat-layouts) | buses, busList | 5 new / 3 existing | Buses exist. Layouts (versioned, decks, rows, seater and sleeper, ladies and blocked seats) are new. |
| **Crew: drivers and conductors** (`crew`) | Client: crew | New (operator-staff, drivers) | opStaff | 4 new / 0 existing | Driver and conductor records with licence, expiry, phone and the trips assigned. |
| **Routes, stops and boarding points** (`routes`) | Client: routes | Partly built (routes, boarding-points) | routes | 2 new / 2 existing | Routes exist. Add timed stops, boarding and dropping points, and copy-from-public-route. |
| **Fares and schedules** (`fares`) | Client: fares, schedules | New (fares, schedules) | fares, schedules | 6 new / 0 existing | Two styles chosen by the operator: one price per trip, or per seat type and stop pair. Recurring schedules generate trips. |
| **Trips and seat inventory** (`trips`) | Admin: trips, inventory<br>Client: trips | Partly built (trips, inventory) | trips | 12 new / 3 existing | Create, publish and cancel exist. Add delay, driver change, seat blocking, release of expired holds, manifest. |
| **Commission rules** (`commission`) | Admin: commission<br>Client: commission | New (commissions) | commissions, commissionDefault, commissionHist | 8 new / 0 existing | Rule per operator, route or bus type; percent or flat; versioned; admin edits only; the operator sees it read-only; each booking stores the rule that applied. |
| **Payout and fee settings** (`payout_cfg`) | Admin: payout | New (settlements, payments) | payoutCfg, cancelSlabs | 8 new / 0 existing | Default payout mode, cycle, minimum payout, hold days, convenience fee, refund slabs, per-operator mode and bank verification. |

#### Phase 2: your test checklist

- Admin, **Buses**: the list loads; try the filters (Search, Status, Operator, Type); press Import buses, Export CSV, Mark maintenance, Retire bus, View, Save changes, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Buses**: the list loads; try the filters (Search, Status); each number card opens its records; press Send for approval, Import, Export CSV, Mark maintenance, View; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Seat layouts**: the list loads; try the filters (Bus); press Save layout; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Drivers and crew**: the list loads; try the filters (Search, Role, Status); each number card opens its records; press Add, Export CSV, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Routes and stops**: the list loads; try the filters (Search); press Add, Export CSV, View, Save, Copy as my route; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Fares**: the list loads; try the filters (Search, Status); press Save fare, Export CSV, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Schedules**: the list loads; try the filters (Search); press Save, Export CSV; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Trips**: the list loads; try the filters (Search, Status, Operator, Route); press Create draft, Export CSV, View, Save changes, Delete, 1A, Block; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Seat inventory**: the list loads; try the filters (Search, Operator, Occupancy); each number card opens its records; press Release expired holds, Export CSV, View, Save changes, Delete, Delay and notify, Save; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Trips**: the list loads; try the filters (Search, Status, When); each number card opens its records; press Create trip, Export CSV, Download manifest, View, Save changes; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Commission**: the list loads; try the filters (Search, Applies to, Status); press Save, Export CSV, Save rule, Save as new version, Deactivate, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Commission**: the list loads; try the filters (Your fare per seat (Rs), Route, Seat type); press Calculate; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Payout and fees**: the list loads; try the filters (Default mode for new operators, Settlement cycle (days), Minimum payout (Rs), Hold days after trip); press Save changes, Add, Remove, View, Delete, Export CSV, Save; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.

### Phase 3. Customer booking journey

|  |  |
|---|---|
| Goal | Search, trip details, seat map with a 10 minute hold, boarding and dropping, passengers, coupons, Razorpay payment, ticket, WhatsApp and email messages. |
| Apps touched | backend, customer app, admin app (bookings, payments, offers), client portal (bookings, offers) |
| Done when | A real customer books a real seat and pays in Razorpay test mode; the ticket, the messages and the operator notification all arrive; 500 concurrent requests for one seat give exactly one winner. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Search and trip details** (`discovery`) | Customer: results, trip<br>Website: home, results, routes | Partly built (trips (public search)) | - | 4 new / 4 existing | City lookup, search, filters and trip details exist. Add per-seat-type prices and the commission-inclusive price. |
| **Seat selection and hold** (`seats`) | Customer: seats | New (inventory) | - | 3 new / 0 existing | 10 minute hold on the server, at most 6 seats, atomic lock in Redis, expiry worker. |
| **Booking, passengers and bookings lists** (`booking`) | Admin: bookings<br>Client: bookings<br>Customer: points, pax, review | New (bookings, passengers) | bookings | 16 new / 0 existing | Server-calculated amount, idempotent create, GST details, email required with the mobile number. |
| **Offers and coupons** (`offers`) | Admin: offers<br>Client: offers<br>Customer: offers<br>Website: offers | New (coupons, offers) | offers | 12 new / 0 existing | Admin owns offers; an operator can request one; who funds the discount is stored per offer. |
| **Payments** (`payments`) | Admin: payments<br>Customer: pay | New (payments) | payments | 8 new / 0 existing | Razorpay orders, verification, webhooks, late payment recovery, reconciliation tab. |
| **Ticket, PNR and QR** (`tickets_pdf`) | Customer: conf, ticket | New (tickets, check-in) | - | 5 new / 0 existing | PNR, QR, PDF, calendar file, share, resend from admin. |

#### Phase 3: your test checklist

- Customer app, **Search results**: Day chips; Sort / Filters / Apply; Trip card. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **Trip details**: Select seats; Bus no longer available. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Website, **Home**: Search; Banners / offers / popular routes.
- Website, **Search results**: Book in app.
- Website, **Popular routes**: Route page.
- Customer app, **Select seats**: Tap a seat; Continue (hold); Back / timer end; Live seat changes. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Bookings**: the list loads; try the filters (PNR, name, phone, route, Status, Operator, Route); press Export CSV, View, Save changes, Cancel and refund, Resend ticket, Save; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Bookings**: the list loads; try the filters (Search, Status, Route); each number card opens its records; press Export CSV, View, Save changes; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Boarding and dropping**: Boarding / Dropping tabs; Open in maps; Continue. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **Passenger details**: Use my profile; Continue. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **Review booking**: Apply coupon; Remove coupon; Fare breakup; Proceed to pay. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Offers and coupons**: the list loads; try the filters (Search, Status, Funded by); press Export CSV, Save offer, Pause, View, Delete, Resume, Check; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Offers**: the list loads; try the filters (Search); press Send to Abra, Export CSV, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Offers and promotions**: List; Terms. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Website, **Offers**: List.
- Admin, **Payments**: the list loads; try the filters (Search, Status, Mode); each number card opens its records; press Export CSV, View, Mark reconciled, Check with gateway, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Payment**: Pay now; Payment result; Retry / Change method. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **Booking confirmed**: Copy PNR; View ticket; Add to calendar; View the messages. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **E-ticket**: Call operator; Download PDF; Share trip. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.

### Phase 4. After booking

|  |  |
|---|---|
| Goal | My Trips, cancellation and refund, support tickets, profile, notification settings, account deletion, languages, information pages. |
| Apps touched | backend, customer app, admin app (refunds, tickets, customers, content), client portal |
| Done when | A cancelled booking refunds the right amount through the admin slabs and the seat returns to sale; a ticket raised with a proof file is answered by admin and seen by the customer. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **My Trips** (`my_trips`) | Customer: trips tab, bk | New (bookings) | - | 3 new / 0 existing | Upcoming, completed, cancelled, booking details. |
| **Cancellation and refunds** (`refunds`) | Admin: refunds<br>Customer: cancel, refund | New (refunds) | refunds | 6 new / 0 existing | Refund quote from the admin slabs, partial cancellation, refund worker, bulk approve, retry, reject with proof. |
| **Support tickets** (`support`) | Admin: tickets<br>Customer: support, tk<br>Website: help | New (support) | tickets, replies | 12 new / 0 existing | Ticket with proof files, assignment, canned replies, time limit, reopen. |
| **Customers and profile** (`customers`) | Admin: customers<br>Customer: profile, pedit, lang, del, me tab | New (customers) | customers | 10 new / 1 existing | Profile, email required, block and unblock with proof, sign-out of all devices, account deletion. |
| **Information pages and FAQs** (`content`) | Admin: content<br>Customer: info<br>Website: help, contact | New (content) | faqs, pages, contact | 11 new / 0 existing | Terms, privacy, about, FAQs and contact details edited by admin, shown in every app and on the website. |

#### Phase 4: your test checklist

- Customer app, **Booking details**: Track; Cancel booking; Refund status. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Refunds**: the list loads; try the filters (Search, Status, Paid by); each number card opens its records; press Export CSV, View, Mark paid; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Cancel booking**: Refund estimate; Cancel. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **Refund status**: Open. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Support tickets**: the list loads; try the filters (Search, Status, Category, Priority); each number card opens its records; press Export CSV, View, Save changes, Delete, Assign, Mark resolved, Send reply; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Support (tab) and ticket**: FAQs; New ticket; My tickets; Reply; Contact support. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Website, **Help and FAQs**: FAQs.
- Admin, **Customers**: the list loads; try the filters (Name, phone, email, Status, Sign-in method); press Export CSV, View, Save changes, Delete, Block, Sign out all devices; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Profile (tab), edit, notification settings**: Save profile; Notification settings; Language; Sign out; Delete account. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Help content and contact**: the list loads; try the filters (Search, Status, Category); press Export CSV, Save, Unpublish, View, Delete, Publish, Save draft; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Information pages**: Open page. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Website, **Help and FAQs**: FAQs.
- Website, **Contact us**: Send.

### Phase 5. Safety, driver GPS and live tracking

|  |  |
|---|---|
| Goal | The driver app (sign-in, trips, check-in, start and end, delay, GPS, SOS), live tracking for customer, admin and operator, SOS board, trip sharing, incidents, safety settings. |
| Apps touched | backend, driver app (new), customer app, admin app, client portal |
| Done when | A driver trip shows live on the customer, admin and operator maps; SOS reaches the safety team, the operator, the driver and the customer's contacts; sharing expires after the trip. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Driver app: trips and check-in** (`driver_core`) | Driver: home, trip, profile | New (drivers, trip-operations, check-in) | opStaff, trips | 10 new / 1 existing | Driver sign-in, assigned trips, passenger list, QR check-in, board, start, end, delay. |
| **Live tracking** (`tracking`) | Admin: tracking<br>Client: live<br>Customer: track<br>Driver: gps<br>Website: track | New (live-tracking) | live | 4 new / 0 existing | GPS from the driver app every few seconds, stale-position handling, replay. |
| **SOS and women safety** (`sos`) | Admin: sos, safety<br>Customer: safety<br>Driver: sos | New (women-safety) | sos, safetyCfg | 13 new / 0 existing | SOS raised by customer or driver, acknowledge, escalate, resolve or false alarm with proof, contacts alerted by SMS and WhatsApp. |
| **Trip sharing** (`sharing`) | Customer: share | New (women-safety) | sharing | 4 new / 0 existing | Share link by WhatsApp, SMS or copy; stops at trip end; admin can revoke. |
| **Incidents** (`incidents`) | Admin: incidents | New (women-safety) | incidents | 6 new / 0 existing | Complaints logged by support; severity, status, proof. |

#### Phase 5: your test checklist

- Driver app, **Home (tab)**: Trip cards; Reports to send banner; SOS.
- Driver app, **Your trip (tab)**: Passenger list; Check in; Board; Start (opens pre-trip checklist); Delay.
- Driver app, **Profile**: Sign out.
- Admin, **Live tracking**: the list loads; try the filters (Operator, State); press TN38 EF 7890, AP16 CD 7939, TS07 EF 3887, AP39 AB 9725, KA01 AB 3469; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Live buses and safety**: the list loads; press each button; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Live tracking**: Live position; SOS and safety; Call driver or operator. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Website, **Track my bus**: Track.
- Admin, **SOS board**: the list loads; press Acknowledge, Save, Escalate, Resolve, Mark false alarm; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Safety settings**: the list loads; try the filters (Acknowledge within (minutes), Escalate to safety lead after (minutes), Police control room number); press Save, Add, Remove; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Customer app, **Women safety and SOS**: Hold SOS; I am safe; Add / remove contact; Status updates. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Customer app, **Trip sharing**: Start sharing; WhatsApp / SMS / Copy; Stop sharing; Family view (public link). Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.
- Admin, **Incidents and sharing**: the list loads; try the filters (Search, Status, Severity); press Export CSV, Log, Save, View, Save changes, Revoke link, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.

### Phase 6. Money out: settlements and payouts

|  |  |
|---|---|
| Goal | Booking financials, settlement cycles, adjustments, holds, Razorpay Route automatic split and manual payout, GST statement, payout file, operator earnings screen. |
| Apps touched | backend, admin app, client portal |
| Done when | Settlement totals equal payments minus commission minus refunds, to the paisa, for every operator in the seed data. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Settlements and earnings** (`settlements`) | Admin: settlements<br>Client: earnings | New (settlements, reconciliation) | settlements | 12 new / 0 existing | Generate, approve, hold, release, pay, adjust, query and reply, statements, payout file, GST statement. |

#### Phase 6: your test checklist

- Admin, **Settlements**: the list loads; try the filters (Search, Status, Operator, Mode); each number card opens its records; press Generate, Payout file, GST statement, Export CSV, View, Release hold, Download statement; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Earnings and settlements**: the list loads; try the filters (Search); each number card opens its records; press Export CSV, Download statement, View, Save changes; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.

### Phase 7. Rest of the admin portal

|  |  |
|---|---|
| Goal | Dashboard, reports, announcements, popular routes, staff and roles, global search, AI assistant, demo-to-real clean-up. Every admin page is now live and no mock remains. |
| Apps touched | admin app, backend |
| Done when | All 38 admin pages pass the click-through against the real backend; reports match the transactions. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Dashboards and reports** (`dashboard`) | Admin: dashboard, reports<br>Client: dashboard | New (reports, analytics) | series | 7 new / 0 existing | Every number card opens the records behind it. Reports render on the page and export to CSV, Excel and PDF. |
| **Announcements and popular routes** (`announce`) | Admin: announce, popular<br>Website: home | New (content, popular-routes) | announce, popular | 11 new / 1 existing | Broadcast to customers, operators or drivers; ordered popular routes. |
| **Staff, roles and access matrix** (`staff`) | Admin: staff<br>Client: staff | Partly built (rbac, users) | staff, opUsers | 9 new / 1 existing | Staff invitations, roles, and the matrix editable by Super Admin only. Operator staff are limited to their own company. |

#### Phase 7: your test checklist

- Admin, **Dashboard**: the list loads; each number card opens its records; press Today, 7 days, 30 days, Export; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Reports**: the list loads; try the filters (Search); press 7 days, 30 days, 90 days, Export CSV, Excel (CSV), Export these rows, View; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Dashboard**: the list loads; each number card opens its records; press each button; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Announcements**: the list loads; try the filters (Search, Status); press Save draft, Send, Export CSV, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Admin, **Popular routes**: the list loads; press Add, Export CSV, View, Delete; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Website, **Home**: Search; Banners / offers / popular routes.
- Admin, **Staff and roles**: the list loads; try the filters (Search, Role, Status); press Export CSV, Send invitation, Save, Deactivate, View, Activate, Add role; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Staff and roles**: the list loads; try the filters (Search); press Export CSV, Send invitation, View, Add role; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.

### Phase 8. Rest of the client (operator) portal

|  |  |
|---|---|
| Goal | Operator dashboard, staff and roles, earnings, live view, offers requests, anything left. The portal is the operator app: there is no separate operator app. |
| Apps touched | client portal, backend |
| Done when | All 20 client pages pass the click-through; an operator can only ever see their own data. |

#### Phase 8: your test checklist

- Backend only: Claude shows you the results of the automatic tests; there is nothing to press.

### Phase 9. Driver app in full: rules, reports and checklists

|  |  |
|---|---|
| Goal | Operator-maintained pre-trip and end-of-trip checklists, daily and weekly reports built from system numbers, incident, bus problem and expense reports, review by the operator, minimum rules set by Abra. |
| Apps touched | driver app, client portal, admin app, backend |
| Done when | A driver cannot start a trip past a blocking check; a daily report shows the system numbers and the owner approves or sends it back. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Driver rules and trip checklists** (`driver_rules`) | Admin: drules<br>Client: drules<br>Driver: pre-trip checklist, end-trip checklist | New (drivers, trip-operations) | ruleDefaults, driverRules, tripChecks | 25 new / 0 existing | Abra defaults and a locked minimum; each operator edits its own copy; blocking, warning and automatic checks. |
| **Driver reports** (`driver_reports`) | Admin: dreports<br>Client: dreports<br>Driver: reports tab | New (drivers, reports) | driverReports | 9 new / 0 existing | Daily and weekly reports use numbers computed by the system and frozen at send; the driver adds fuel, expenses, incidents and notes; the owner approves or sends back. |

#### Phase 9: your test checklist

- Admin, **Driver rules (defaults)**: the list loads; press Push the minimum to every operator, Push, Export CSV, Add, Save, Remove, Add this question; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Driver rules**: the list loads; press Reset to Abra defaults, Reset, Export CSV, Add, Save, Remove, Add this question; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Driver app, **Before you start**: Automatic checks; Answer items; Start trip.
- Driver app, **End of trip**: End trip.
- Admin, **Driver reports**: the list loads; try the filters (Driver or report, Status, Report, Driver); each number card opens its records; press Export CSV, Tell the operator; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.
- Client portal, **Driver reports**: the list loads; try the filters (Driver or report, Status, Report, Driver); each number card opens its records; press Export CSV, Approve, Remind the driver; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.

### Phase 10. Public website, then partner app

|  |  |
|---|---|
| Goal | Next.js route and city pages with SEO, search hand-off to the customer app, help, offers, track-my-bus, contact and partner enquiry. The partner app and partner API come last. |
| Apps touched | public website, backend, partner app |
| Done when | Route pages are indexed and booking opens in the customer app; partner and customer bookings cannot take the same seat. |

| Feature | Screens in the demo | Backend today | Collections | Endpoints (new / existing) | What to build |
|---|---|---|---|---|---|
| **Public website** (`website`) | Website: about, partner, contact, footer pages | New (public API, content) | - | 3 new / 0 existing | Next.js pages with SEO; partner and contact enquiries land in admin. |
| **Partner app and partner API** (`partner`) | backend only | New (partners, api-clients, partner-webhooks) | - | 0 new / 0 existing | Last: API clients, scopes, signed requests, webhooks. |

#### Phase 10: your test checklist

- Website, **Partner with us**: Send.
- Website, **Contact us**: Send.
- Website, **About, Terms, Privacy**: Open.

### Phase 11. Languages, hardening and launch

|  |  |
|---|---|
| Goal | All 8 languages reviewed by native speakers, load and security tests, backup restore test, staging run, store release. |
| Apps touched | all |
| Done when | Acceptance criteria in the functional PDF are met and signed off. |

#### Phase 11: your test checklist

- Backend only: Claude shows you the results of the automatic tests; there is nothing to press.

## Part 5. Rules that apply to every feature

| Area | Rule |
|---|---|
| UI matches the demo | Every screen is built to look and behave like its demo page: layout, wording, colours, spacing, icons, dialogs, states and responsive behaviour at phone, tablet and desktop widths. The demo files in `prototypes/` are opened side by side with the real screen during the check. Only real data replaces the sample data. |
| Access | Server-side permission check on every endpoint using the matrix (None, View, Edit, Edit+Delete). A view-only user can open and copy but not change; the buttons are hidden **and** the server refuses. |
| Audit | Every create, edit, delete, status change, block, refund, payout and permission change writes an audit entry: who, what, when, from where, before and after. |
| Proofs | SOS resolve, false alarm, refund reject, trip cancel, booking cancel, customer block, settlement hold, incident, ticket replies, delay and driver override need a proof (file or note) as the demos show. Stored with the record. |
| Money | Integers in paise. One rounding function used everywhere. Customer price = fare + commission + convenience fee + GST, always calculated on the server, never taken from the app. Commission changes never alter bookings already made. |
| Time | India time everywhere; trips across midnight; cut-off before departure; travel date versus departure date. |
| Idempotency | Every create that costs money or changes stock takes an idempotency key. A double tap returns the same booking. |
| Seat stock | Held, sold and blocked seats are separate; 10 minute hold; expiry worker; the booked count always equals the real bookings. |
| Lists | Server-side paging, stable sorting, the filters shown in the demo, search, export (CSV, Excel, PDF where the demo has it) limited by the same filters and permissions. Table and list view are two views of the same data. |
| Import | Excel import with a template download, a dry run, row-by-row errors, then save (places, buses, schedules, fares). |
| Delete | Soft delete wherever a record is referenced. Deleting a place used by trips is refused. |
| Notifications | Created by the event service, never by the app. A provider failure never fails the business action. No duplicates for one event. See Appendix B for every event, recipient and message. |
| Messages | WhatsApp and email after booking, cancellation, refund, payment failure, delay and boarding; logged; resendable by admin. |
| Languages | All text through one translation system; 8 languages; names shown in English; the assistant answers in the language the user used. |
| Number cards | Each card links to the filtered list behind it; the count and the list always agree. |
| Realtime | GPS, SOS, notifications, seat changes and report status arrive by Socket.IO; the screen updates without a reload. |
| Privacy | Phone numbers and emails are masked in lists for roles that only need to see the record. Account deletion keeps past financial records but removes personal data. |
| Errors | One error format with a code and a human sentence; the app shows the sentence, not the code. |
| Security | Secrets only in git-ignored environment files; rate limits on OTP and login; webhooks verified by signature; files served by short-lived signed links; no trust of amounts from the app. |

## Part 6. Testing plan

| Layer | What | Who |
|---|---|---|
| Unit | Pricing, commission, cancellation and refund maths, settlement totals, driver report numbers, rule evaluation | Claude, automatic |
| Endpoint | Every endpoint in Appendices D to H: allowed role works, forbidden role is refused, bad input gives a clear error, an audit entry is written | Claude, automatic (Jest end-to-end) |
| Concurrency | 500 parallel requests for one seat give exactly one winner; hold expiry frees seats | Claude, automatic |
| Payments | Duplicate webhook, failed, pending, expired-then-paid, amount mismatch | Claude, automatic |
| Apps | `flutter analyze` clean and existing tests green | Claude, automatic |
| Screen walk | The same click-through that passes on the demo (every page, every button) must pass on the real app. The demo test scripts are the acceptance spec. | Claude runs a minimum; **you test with the checklist** |
| Visual | Every new screen is compared side by side with its demo page (layout, wording, colours, dialogs, states) and checked against the design system at phone, tablet and desktop widths. A screen that differs from the demo is not done. | Claude, then you |
| User test | At the end of each phase you receive a short checklist in plain language: what to open, what to press, what you should see | You |

> **Rule:** To keep effort and cost sensible, Claude runs only the minimum self-tests and hands you the checklist; you do the full manual test of each phase. Nothing moves to the next phase until you say so.

### Definition of done for one feature

1. The three files exist and nothing else was needed.
2. Every button in the demo page has a working endpoint (Appendices D to H show them).
3. Permissions, audit, notifications and messages work as described.
4. Loading, empty, error, no-permission and offline states show.
5. The screen matches the demo page side by side: same layout, wording, buttons, colours, dialogs and fields.
6. Automatic tests pass; analyzer clean.
7. You tested the checklist and said it is good.
8. Appendix J is updated (status, date).

## Part 7. Open items and who owns them

| Needed | Phase | From |
|---|---|---|
| Redis running (Docker is installed) | 0 | Claude to set up; you confirm Docker Desktop is running |
| New MongoDB Atlas password (the current one was shown in a screenshot and in chat) and your IP allowed in Atlas | 0 | You |
| Razorpay account: test and live keys, webhook secret, Route enabled for splits | 3, 6 | You |
| Google Maps (or Mappls) provider decision and key, from the Google Cloud project with billing and a budget alert | 5 | You |
| Groq API key for the assistant | 0 or 7 | You |
| WhatsApp provider credentials, SMS provider (DLT registration), email provider | 3 onward | You |
| Cancellation slabs and refund percentages (defaults are in the demo; operators may override) | 4 | You and operators |
| Who funds coupon discounts: platform or operator | 3, 6 | You |
| Hosting provider and a real storage bucket for documents | 11 (staging earlier) | You |
| Safety escalation contacts and legal review | 5 | You |
| Inter font files and official logos (Google, Apple, WhatsApp, UPI, banks) and the Abra logo as transparent PNG or SVG | any | You |
| Native-speaker review of Kannada, Tamil, Malayalam, Marathi and Bengali (machine-written so far); Telugu and Hindi also reviewed | 11 | You |
| Decision: where proof files live (MongoDB GridFS or a cloud bucket such as S3) | 0 | You |
| Report reminders on a timer (the demo only reminds on a button press) | 9 | You to confirm |

## Part 8. How we work

- One phase at a time. At the end of each phase you get the checklist; the next phase starts when you say so. This document is updated after each phase with the status and the date.
- You prefer short, simple English. When you say "just tell me", Claude explains and does not code. When you give a clear build instruction, Claude builds.
- You test; Claude keeps self-testing to the minimum and gives you the checklist.
- The login files of the customer app are not edited without asking.
- Secrets live in git-ignored files, never in code, documents or chat.
- No fake or sample data ships to production; development seed data stays behind a development switch.
- The demos in `prototypes/` stay as the specification and are not deleted. `prototypes/_build/build_client.py` is stale and must not be run.
- Keep the three-file rule (Part 3) in every new feature.

## Appendix A. Collections (the database)

> **Phase 1 change (13 Oct 2026):** cities, places (`locations`), bus types, required documents, operators, invitations and banners now carry `deletedAt` and `deletedBy` (soft delete; a deleted record is hidden from every query and can be restored). A record without the field counts as not deleted, so nothing had to be migrated.

The demo store has 62 keys. This table maps each to a real MongoDB collection. Collection names are plural snake case. Every collection also gets `_id`, `createdAt`, `updatedAt`, `createdBy`, and `deletedAt` where soft delete applies. Operator-owned collections carry `operatorId` and every query for an operator user is filtered by it on the server. Money fields are integers in paise. "Demo fields" are the fields of the first record in the demo store, with their types.

| Demo key | Collection | Backend today | Phase | Owner module | Purpose | Relations | Indexes |
|---|---|---|---|---|---|---|---|
| users | `users` | exists | 0 | users | Every person who can sign in: admin staff, operator users, drivers, customers (identity only). | roles, sessions | email unique, phone unique |
| (sessions) | `sessions` | exists | 0 | sessions | Signed-in devices; used by "sign out of all devices". | users | userId, expiresAt (TTL) |
| customers | `customers` | new | 4 | customers | Traveller profile: name, email (required), phone, sign-in method, status, language, emergency contacts, notification settings. | users, bookings | phone, email, status |
| operators | `operators` | exists | 1 | operators | Bus companies: owner, contact, GST, bank details (with verification), payout mode, status, KYC state, rating. | buses, trips, settlements, commissions | status, name text |
| opUsers | `operator_users` | new | 8 | operator-staff | Operator portal users and their roles. | operators, users | operatorId+email |
| opStaff | `operator_crew` | new | 2 | operator-staff, drivers | Drivers and conductors: licence, licence expiry, phone, status. | operators, trips | operatorId+role, licExp |
| cities | `cities` | exists | 1 | cities | Cities with state, popular flag, Telugu and Hindi names and the other language names. | places | name text, active |
| places | `places (locations)` | exists | 1 | locations | Boarding and dropping places with address, landmark, latitude, longitude, phone and instructions. | cities, routes | cityId, type, active |
| placeReqs | `place_requests` | new | 1 | locations | An operator asks Abra to add a place; approve or reject with a reason. | operators, places | status |
| busTypes | `bus_types` | exists | 1 | bus-types | AC Sleeper, Seater and so on, with a permanent key. | buses | key unique |
| amenities | `amenities` | built in Phase 1 (13 Oct 2026) | 1 | amenities | Charging point, blanket, water and so on; staff add and switch them on or off. Fields: key (permanent, unique), name, isActive, sortOrder. Never deleted. | buses (by key) | key unique |
| docTypes | `document_types` | exists | 1 | document-types | Required KYC documents for operator or bus: file types, size, count, expiry, instructions, order. | kyc_submissions | applies, active |
| questions | `kyc_questions` | new | 1 | onboarding | KYC questionnaire items with answer type and options. | kyc_submissions | applies, order |
| rules | `kyc_document_rules` | new | 1 | onboarding | Conditions that make a document required (for example GST when turnover is above a limit). | document_types, questions | active |
| invitations | `operator_invitations` | exists | 1 | onboarding | Invitation to an operator: company, owner, email, status, expiry. | operators | email, status |
| submissions | `kyc_submissions` | exists | 1 | onboarding | Company or bus KYC: documents with review state and rejection reason, answers, history. | operators, buses, files | operatorId, status, type |
| buses | `buses` | exists | 2 | buses | Registered buses: registration, type, seats, layout, insurance expiry, status (pending, active, maintenance, retired). | operators, seat_layouts, trips | operatorId, reg unique, status |
| (layouts) | `seat_layouts` | new | 2 | seat-layouts | Versioned layout: decks, rows, columns, seater and sleeper, ladies seats, blocked seats, seat numbers and seat category. | buses, trips | busId+version |
| routes | `routes` | exists | 2 | routes, boarding-points | Route with timed stops, boarding and dropping points, distance and hours. | places, trips | operatorId, from+to |
| fares | `fares` | new | 2 | fares | Fare rules per route and seat type: weekday, weekend, festival, date ranges, stop pairs. | routes, operators | operatorId+routeId |
| schedules | `schedules` | new | 2 | schedules | Recurring trips: route, bus, time, days, date range, fare; generates trips. | routes, buses, trips | operatorId, status |
| trips | `trips` | exists | 2 | trips | A dated departure: bus, driver, conductor, status, delay, fares by seat category, counts. | routes, buses, seat_inventory, bookings | depart, status, operatorId, routeId |
| (inventory) | `seat_inventory` | new | 2 | inventory | One record per seat per trip: free, held, sold, blocked; holds also live in Redis with a 10 minute expiry. | trips, bookings | tripId+seat unique |
| commissions | `commission_rules` | new | 2 | commissions | Rules per operator, route or bus type; percent or flat; version; effective date; agreed note. | operators | scope+target, status |
| commissionDefault | `commission_default (in payout_settings)` | new | 2 | commissions | The fallback rule. | - | - |
| commissionHist | `commission_history` | new | 2 | commissions | Every change to a rule: who, when, before, after. | commission_rules | ruleId |
| payoutCfg | `payout_settings` | new | 2 | settlements | Default payout mode, cycle days, minimum payout, hold days, convenience fee, GST percent, coupon funding. | - | singleton |
| cancelSlabs | `cancellation_slabs` | new | 2 | refunds | Refund percent by hours before departure. | refunds | hours |
| bookings | `bookings` | new | 3 | bookings, passengers | A booking with passengers, seats, boarding and dropping points, amounts in paise (fare, commission, fee, GST, discount), commission rule snapshot, contact, GST details, status. | customers, trips, payments, refunds | pnr unique, customerId, tripId, operatorId, status |
| payments | `payments` | new | 3 | payments | Gateway order and payment: mode, status, gateway ids, failure reason, settled flag, reconciliation state. | bookings | bookingId, gatewayOrderId unique, status |
| offers | `offers` | new | 3 | coupons, offers | Coupons and offers: code, type, value, maximum discount, minimum amount, validity, limits, funder (platform or operator), terms. | bookings | code unique, status |
| refunds | `refunds` | new | 4 | refunds | Refund of a cancellation: amount, percent, bearer (platform or operator), status, gateway reference, reason, proof. | bookings, payments | bookingId, status |
| tickets | `support_tickets` | new | 4 | support | Customer support tickets with category, priority, assignee, time limit and the message thread with proof files. | customers, bookings | status, assignee, customerId |
| faqs | `faqs` | new | 4 | content | Help centre questions. | - | status |
| pages | `cms_pages` | new | 4 | content | Terms, privacy, about and other pages with versions. | - | slug unique |
| contact | `contact_info (in system_settings)` | new | 4 | content | Support phone, WhatsApp, email, hours, emergency number. | - | singleton |
| banners | `banners` | exists; extended in Phase 1 | 1 | admin-banners | Home banners with window, placement, audience (everyone, new users, signed-in users), colour style, link kind (offer, route search, operator, web link), order (higher shows first), archivedAt, soft delete. Impressions and clicks come later. | offers | status, placement |
| announce | `announcements` | new | 7 | content | Broadcasts to customers, operators or drivers. | - | status |
| popular | `popular_routes` | new | 7 | popular-routes | Ordered routes shown on home and the website with search and booking counts. | routes | order |
| sos | `sos_alerts` | new | 5 | women-safety | SOS raised by a customer or a driver: trip, bus, driver, operator, location, contacts alerted, status log, assignee, proof on resolve. | trips, customers | status, tripId, at |
| incidents | `incidents` | new | 5 | women-safety | Complaints logged by support: severity, against, status, notes, proof. | trips, customers | status, severity |
| sharing | `trip_shares` | new | 5 | women-safety | Live trip links shared with family: token, opens, expiry, status. | bookings | token unique, expiresAt (TTL) |
| safetyCfg | `safety_settings` | new | 5 | women-safety | Acknowledge and escalate minutes, police number, safety team, SMS and WhatsApp switches, SOS hold seconds. | - | singleton |
| live | `live_positions (latest in Redis, history in Mongo)` | new | 5 | live-tracking | Bus position, speed, progress, ETA, checked-in count. | trips | tripId+at |
| settlements | `settlements` | new | 6 | settlements | Per operator per cycle: gross, commission, refunds, adjustments, net, mode, status, lines, query thread, hold reason, payment reference. | operators, bookings | operatorId+cycle unique, status |
| staff | `admin_staff (users with admin roles)` | exists | 7 | users, rbac | Admin team: role, MFA state, last sign-in, overrides to the matrix. | users | email |
| (matrix) | `roles (fields pageLevels, operatorId)` | exists | 0 | rbac | Level per role per page: None, View, Edit, Edit+Delete, stored on the role and turned into its permission keys. Editable by Super Admin only. Built 2026-10-12. | roles | role+page unique |
| audit | `audit_logs` | exists | 0 | audit-logs | Who did what, when, from where, with before and after. | users | at, who, target |
| flags | `feature_flags` | new | 0 | feature-flags | Switches such as maintenance scopes and optional features. | - | key unique |
| maint | `maintenance (in system_settings)` | new | 0 | maintenance | Maintenance message, window and which apps it affects. | - | singleton |
| settings | `system_settings` | exists | 0 | system-settings | Company, booking, integrations and security settings. Secrets are encrypted. | - | key unique |
| notifs / inbox | `notifications` | exists | 0 | notifications | In-app notifications for admin, operator, customer and driver; read state; deep link. | users | userId+read, at |
| messages | `messages` | new | 0 | whatsapp, notifications | Log of WhatsApp and email messages: channel, address, subject, body, booking, status, resend. | bookings, customers | bookingId, at |
| ruleDefaults / driverRules | `driver_rule_sets` | new | 9 | drivers | Abra default checklists and report types plus one editable copy per operator; locked items cannot be removed. | operators | operatorId unique |
| driverReports | `driver_reports` | new | 9 | drivers, reports | A driver's report: type, period, answers, files, frozen system snapshot, status, review comment. | operators, opStaff | operatorId+driver+type+period unique, status |
| tripChecks | `trip_checks` | new | 9 | trip-operations | Pre-trip and end-of-trip checklist results with items, odometer, warnings and override with reason and proof. | trips, opStaff | tripId+kind |
| series | `(not stored)` | new | 7 | reports, analytics | Dashboard series: computed from bookings and payments, cached in Redis. | - | - |
| (files) | `files` | exists | 0 | files | Uploaded files and proof attachments with owner, type, size and access list. | any | ownerId |

### A.2 Demo fields per collection

| Demo key | Fields (name:type) |
|---|---|
| cities (20 in the demo) | id:string, name:string, state:string, active:boolean, popular:boolean, te:string, hi:string, places:number |
| places (52 in the demo) | id:string, city:string, name:string, address:string, landmark:string, lat:string, lng:string, phone:string, type:string, source:string, active:boolean, trips:number |
| placeReqs (6 in the demo) | id:string, operator:string, city:string, name:string, address:string, status:string, at:string, reason:string |
| busTypes (6 in the demo) | id:string, name:string, key:string, ac:boolean, berth:string, active:boolean, buses:number |
| amenities (10 in the demo) | id:string, name:string, active:boolean |
| operators (14 in the demo) | id:string, name:string, owner:string, email:string, phone:string, city:string, status:string, buses:number, trips:number, joined:string, payout:string, gst:string, rating:string, bank:object, kyc:string, fund:string |
| invitations (6 in the demo) | id:string, company:string, owner:string, email:string, status:string, sentAt:string, expiresAt:string, email_status:string |
| submissions (6 in the demo) | id:string, operatorId:string, operator:string, type:string, bus:string, status:string, submittedAt:string, docs:array, answers:array, history:array |
| buses (31 in the demo) | id:string, operatorId:string, operator:string, reg:string, name:string, type:string, ac:boolean, seats:number, status:string, insExp:string, layout:string, added:string, decks:number, ladies:array |
| routes (12 in the demo) | id:string, from:string, to:string, name:string, km:number, hours:number, operatorId:null, status:string, stops:array |
| trips (64 in the demo) | id:string, routeId:string, route:string, operatorId:string, operator:string, busId:string, bus:string, busName:string, type:string, depart:string, status:string, seats:number, booked:number, held:number, blocked:number, fare:number, driver:string, conductor:string, taken:array, checkedIn:array, ladies:number, blockedSeats:array |
| customers (36 in the demo) | id:string, name:string, email:string, phone:string, status:string, joined:string, bookings:number, spent:number, method:string, city:string, lastActive:string |
| bookings (326 in the demo) | id:string, pnr:string, customerId:string, customer:string, phone:string, tripId:string, route:string, operator:string, operatorId:string, travelDate:string, seatList:string, seatsN:number, amount:number, commission:number, gst:number, fee:number, discount:number, status:string, mode:string, at:string, coupon:string |
| payments (326 in the demo) | id:string, bookingId:string, pnr:string, customer:string, operator:string, amount:number, mode:string, status:string, gw:string, at:string, reason:string, settled:boolean |
| refunds (5 in the demo) | id:string, bookingId:string, pnr:string, customer:string, operator:string, amount:number, pct:number, status:string, utr:string, at:string, bearer:string, reason:string |
| settlements (11 in the demo) | id:string, operatorId:string, operator:string, cycle:string, gross:number, commission:number, refunds:number, adj:number, net:number, status:string, mode:string, lines:number, paidAt:null, query:string |
| commissions (7 in the demo) | id:string, scope:string, target:string, mode:string, value:number, note:string, from:string, version:number, status:string, by:string |
| commissionDefault (2 in the demo) | mode:string, value:number |
| commissionHist (4 in the demo) | 0:string, 1:string, 2:string, 3:string |
| payoutCfg (8 in the demo) | defaultMode:string, cycleDays:number, minPayout:number, holdDays:number, razorpayRoute:boolean, gstPct:number, fee:number, couponFunding:string |
| cancelSlabs (5 in the demo) | id:string, hours:number, pct:number |
| docTypes (12 in the demo) | id:string, key:string, name:string, applies:string, required:boolean, expires:boolean, types:string, maxMb:number, maxFiles:number, active:boolean, order:number, instr:string |
| questions (6 in the demo) | id:string, key:string, label:string, applies:string, type:string, opts:string, required:boolean, active:boolean, order:number |
| rules (5 in the demo) | id:string, name:string, doc:string, cond:string, required:boolean, active:boolean |
| tickets (10 in the demo) | id:string, customer:string, customerId:string, subject:string, category:string, priority:string, status:string, assignee:string, at:string, sla:string, bookingId:string, msgs:array |
| faqs (8 in the demo) | id:string, q:string, cat:string, status:string, a:string, updated:string, views:number |
| pages (5 in the demo) | id:string, title:string, status:string, version:number, updated:string |
| contact (5 in the demo) | phone:string, whatsapp:string, email:string, hours:string, emergency:string |
| banners (6 in the demo) | id:string, title:string, sub:string, code:string, status:string, style:number, from:string, to:string, placement:string, audience:string, priority:number, imp:number, clicks:number, link:string |
| offers (8 in the demo) | id:string, code:string, desc:string, type:string, value:number, maxDisc:number, minAmt:number, status:string, funder:string, perUser:number, limit:number, used:number, from:string, to:string, scope:string, newOnly:boolean, terms:array |
| announce (4 in the demo) | id:string, title:string, body:string, audience:string, status:string, channel:string, at:string, reach:number |
| popular (8 in the demo) | id:string, route:string, order:number, active:boolean, searches:number, bookings:number |
| sos (5 in the demo) | id:string, customer:string, phone:string, trip:string, route:string, bus:string, driver:string, operator:string, status:string, at:string, note:string, x:number, y:number, contacts:array, log:array, assignee:string |
| incidents (5 in the demo) | id:string, title:string, customer:string, against:string, severity:string, status:string, at:string, trip:string, notes:string |
| sharing (10 in the demo) | id:string, customer:string, trip:string, link:string, opened:number, created:string, expires:string, status:string |
| safetyCfg (8 in the demo) | ackMinutes:number, escalateMinutes:number, police:string, team:array, smsOn:boolean, whatsOn:boolean, notifyOperator:boolean, sosHold:number |
| live (5 in the demo) | tripId:string, route:string, bus:string, operator:string, driver:string, state:string, ping:string, speed:number, progress:number, eta:string, x:number, y:number, pax:number, checkedIn:number, stops:array |
| staff (8 in the demo) | id:string, name:string, title:string, role:string, status:string, email:string, mfa:boolean, last:string, overrides:number |
| audit (60 in the demo) | id:string, at:string, who:string, role:string, action:string, target:string, ip:string, sensitive:boolean |
| flags (9 in the demo) | key:string, name:string, on:boolean, desc:string |
| maint (4 in the demo) | scopes:object, msg:string, from:string, to:string |
| settings (4 in the demo) | company:object, booking:object, integrations:object, security:object |
| notifs (6 in the demo) | id:string, t:string, b:string, i:string, go:string, at:string, read:boolean |
| opStaff (70 in the demo) | id:string, operatorId:string, name:string, role:string, phone:string, licence:string, licExp:string, status:string, joined:string, pin:string |
| fares (43 in the demo) | id:string, operatorId:string, routeId:string, route:string, seatType:string, weekday:number, weekend:number, festival:number, from:string, status:string |
| schedules (8 in the demo) | id:string, operatorId:string, routeId:string, route:string, busId:string, bus:string, time:string, days:array, from:string, to:string, status:string, fare:number |
| inbox (3 in the demo) | id:string, to:string, t:string, b:string, go:string, at:string, read:boolean |
| opUsers (56 in the demo) | id:string, operatorId:string, name:string, email:string, role:string, status:string, last:string |
| ruleDefaults (3 in the demo) | pre:array, end:array, reports:array |
| driverRules (14 in the demo) | operatorId:string, updated:string, pre:array, end:array, reports:array |
| driverReports (4 in the demo) | id:string, operatorId:string, driver:string, typeId:string, typeName:string, period:string, status:string, answers:object, files:object, submittedAt:string, dueAt:string, late:boolean, reviewComment:string, reviewedBy:string, snapshot:object |
| tripChecks (12 in the demo) | id:string, operatorId:string, tripId:string, route:string, driver:string, kind:string, at:string, items:array, odometer:number, result:string, warnings:array, override:null |
| messages (18 in the demo) | id:string, at:string, to:string, name:string, address:string, channel:string, kind:string, subject:string, body:string, bookingId:string, status:string |

## Appendix B. Events, notifications and messages

These are the rules the demo's event router applies. In the real build the backend event service does exactly this, once per event, and never from the app. "Go to" is the page or screen the notification opens.

| Event | Who is told | Title | Message | Go to |
|---|---|---|---|---|
| Operator sends KYC documents (company or bus) | Admin | New KYC submission | <operator> sent company documents / documents for bus <reg> | KYC detail |
| Admin approves KYC | Operator | Company approved / Bus approved | Verified; buses, trips and staff are open / you can schedule trips on the bus | Dashboard / Buses |
| Admin rejects KYC | Operator | Documents need fixing | Each rejected document with its reason | KYC |
| Operator resends corrected documents | Admin | KYC corrections sent | <operator> replaced the rejected documents | KYC detail |
| Operator requests a place | Admin | Place request | <operator> wants to add <place>, <city> | Places |
| Admin approves or rejects a place request | Operator | Place request approved / rejected | Can be used in routes / reason | Routes |
| Settlement status changes | Operator | Settlement <status> | <id> for <cycle> | Earnings |
| Operator raises a settlement query | Admin | Settlement query | <operator>: <query> | Settlement detail |
| Admin answers the query | Operator | Query answered | Abra replied to your query on <id> | Earnings |
| Operator accepts the invitation | Admin | New operator signed up | <company> accepted the invitation | Operator detail |
| Operator suspended or status changes | Operator | Account suspended / status changed | Trips hidden from customers; contact Abra support | Dashboard |
| Bus marked for maintenance | Operator | Bus marked for maintenance | <reg> cannot be used for trips until it returns to service | Buses |
| Driver assigned or changed on a trip | Driver, Operator | New trip assigned / Driver changed | <trip> and time / <driver> now drives <trip> | Trip |
| Trip cancelled | Customers (booked and cancelled), Driver, Operator | Trip cancelled | Route and date; full refund has started | My trips / Home / Trips |
| Trip delayed | Customers, Admin, Operator | Bus running late / Trip delayed | Route, minutes, reason | My trips / Tracking / Trip |
| Trip boarding | Customers | Boarding started | Your bus <reg> is boarding now | My trips |
| Trip starts | Customers | Your trip has started | Track your bus live | My trips |
| Trip arrives | Customers | You have arrived | Thanks for travelling; rate your trip | My trips |
| Booking created | Operator | New booking | <PNR> - seats on <route> | Bookings |
| Booking cancelled | Operator, Customer | Booking cancelled | <PNR> on <route>; your refund has started | Bookings / My trips |
| Refund status changes | Customer | Refund <status> | Refund of Rs <amount> is <status> | My trips |
| SOS raised by a customer | Admin, Operator, Driver | SOS from <name> / SOS on your bus | Note and route; "stop safely and check, Abra safety team is calling" | SOS board / Live / Trip |
| SOS raised by a driver | Admin, Operator | SOS from Driver <name> | Note and route | SOS board / Live |
| SOS status changes (acknowledged, resolved, false alarm) | Customer or Driver who raised it | SOS <status> | Our safety team has your alert and is calling you / your SOS is now <status> | SOS |
| New support ticket | Admin | New support ticket | <id> - <subject> | Ticket detail |
| Agent replies / customer replies | Customer / Admin | Support replied / Customer replied | <subject> | Support / Ticket detail |
| Operator asks for an offer | Admin | Offer request | <code> from an operator needs approval | Offers |
| Driver sends a report | Operator | Driver report received | <driver> sent the <type> for <period> (late if late) | Driver reports |
| Driver sends a returned report again | Operator | Driver report sent again | <driver> fixed the <type> | Driver reports |
| Operator approves or returns a report | Driver | Report approved / Report sent back | Type and period / the review note | Reports |
| Trip started past a failed check | Operator, Admin | Trip started with a failed check | <driver> started <trip> after overriding: <checks> | Driver reports |
| Trip started with warnings | Operator | Trip checklist has warnings | <driver> started <trip> with: <warnings> | Driver reports |
| Missing report reminder (button) | Operator or Driver | Driver report missing / Please send your report | Which report and period | Driver reports / Reports |

### B.2 WhatsApp and email messages to the customer

| Event | Channels | Subject | Body (in the customer's language) |
|---|---|---|---|
| Booking confirmed | WhatsApp and email, to the booking's contact (not only the account) | Booking confirmed: <PNR> | Route, date and time, seats, boarding point, amount, how to track, link to the ticket |
| Booking cancelled | WhatsApp and email | Booking cancelled: <PNR> | Cancelled; the refund starts and arrives in 5 to 7 working days |
| Refund paid | WhatsApp and email | Refund processed: <PNR> | Amount and reference number |
| Payment failed | WhatsApp and email | Payment failed | Amount and reason; seats are held for a short time; try again |
| Bus delayed | WhatsApp and email | Bus delayed: <PNR> | Minutes and reason; track live in the app |
| Boarding started | WhatsApp and email | Boarding now: <PNR> | Bus number, reach your boarding point |

> **Note:** The demo stores English text only. The real build uses templates per language (Appendix K lists the 8 languages) and logs every message in the `messages` collection.

## Appendix C. Access matrix (starting values)

Levels: None, View, Edit, Edit+Delete. These are the demo's starting values. The Super Admin can change them in Staff and roles. Operators have their own matrix for their staff.

### C.1 Admin portal

| Page | Super Admin | Admin | Support | Accounts |
|---|---|---|---|---|
| Dashboard (`dashboard`) | Edit+Delete | Edit+Delete | View | View |
| Invitations (`invitations`) | Edit+Delete | Edit+Delete | None | None |
| KYC reviews (`kyc`) | Edit+Delete | Edit+Delete | None | None |
| Operators (`operators`) | Edit+Delete | Edit+Delete | View | View |
| Commission (`commission`) | Edit+Delete | Edit+Delete | None | View |
| Payout and fees (`payout`) | Edit+Delete | View | None | View |
| Cities and places (`places`) | Edit+Delete | Edit+Delete | View | None |
| Bus types and amenities (`bustypes`) | Edit+Delete | Edit+Delete | None | None |
| Required documents (`documents`) | Edit+Delete | Edit+Delete | None | None |
| KYC questionnaire (`questions`) | Edit+Delete | Edit+Delete | None | None |
| Buses (`buses`) | Edit+Delete | Edit+Delete | View | None |
| Trips (`trips`) | Edit+Delete | Edit+Delete | View | None |
| Seat inventory (`inventory`) | Edit+Delete | Edit+Delete | View | None |
| Live tracking (`tracking`) | Edit+Delete | Edit+Delete | View | None |
| Bookings (`bookings`) | Edit+Delete | Edit+Delete | View | View |
| Payments (`payments`) | Edit+Delete | Edit+Delete | None | Edit |
| Refunds (`refunds`) | Edit+Delete | Edit+Delete | None | Edit |
| Settlements (`settlements`) | Edit+Delete | Edit+Delete | None | Edit |
| Customers (`customers`) | Edit+Delete | Edit+Delete | Edit | None |
| Support tickets (`tickets`) | Edit+Delete | Edit+Delete | Edit | None |
| Help content and contact (`content`) | Edit+Delete | Edit+Delete | Edit | None |
| Banners (`banners`) | Edit+Delete | Edit+Delete | None | None |
| Offers and coupons (`offers`) | Edit+Delete | Edit+Delete | None | None |
| Announcements (`announce`) | Edit+Delete | Edit+Delete | Edit | None |
| Popular routes (`popular`) | Edit+Delete | Edit+Delete | None | None |
| SOS board (`sos`) | Edit+Delete | Edit+Delete | Edit | None |
| Incidents and sharing (`incidents`) | Edit+Delete | Edit+Delete | Edit | None |
| Safety settings (`safety`) | Edit+Delete | Edit+Delete | None | None |
| Reports (`reports`) | Edit+Delete | Edit+Delete | None | View |
| Settings and integrations (`settings`) | Edit+Delete | View | None | None |
| Staff and roles (`staff`) | Edit+Delete | None | None | None |
| Feature flags and maintenance (`flags`) | Edit+Delete | Edit+Delete | None | None |
| Audit log (`audit`) | Edit+Delete | View | None | None |
| Notifications (`notifications`) | Edit+Delete | Edit+Delete | Edit | Edit |
| AI assistant (`ai`) | Edit+Delete | Edit | View | View |
| Messages sent (`messages`) | Edit+Delete | Edit+Delete | View | None |
| Driver rules (defaults) (`drules`) | Edit+Delete | Edit+Delete | None | None |
| Driver reports (`dreports`) | Edit+Delete | Edit+Delete | View | None |

### C.2 Client (operator) portal

| Page | Owner | Manager | Booking staff | Accounts |
|---|---|---|---|---|
| Dashboard (`dashboard`) | Edit+Delete | Edit+Delete | View | View |
| KYC verification (`kyc`) | Edit+Delete | Edit+Delete | View | View |
| Company profile (`company`) | Edit+Delete | Edit+Delete | View | View |
| Buses (`buses`) | Edit+Delete | Edit+Delete | View | None |
| Seat layouts (`layouts`) | Edit+Delete | Edit+Delete | None | None |
| Drivers and crew (`crew`) | Edit+Delete | Edit+Delete | View | None |
| Routes and stops (`routes`) | Edit+Delete | Edit+Delete | View | None |
| Places (`places`) | Edit+Delete | Edit+Delete | None | None |
| Fares (`fares`) | Edit+Delete | Edit+Delete | None | View |
| Schedules (`schedules`) | Edit+Delete | Edit+Delete | None | None |
| Trips (`trips`) | Edit+Delete | Edit+Delete | Edit | None |
| Bookings (`bookings`) | Edit+Delete | Edit+Delete | Edit | View |
| Offers (`offers`) | Edit+Delete | Edit+Delete | None | None |
| Earnings and settlements (`earnings`) | Edit+Delete | Edit+Delete | None | Edit |
| Commission (`commission`) | Edit+Delete | Edit+Delete | None | View |
| Live buses and safety (`live`) | Edit+Delete | Edit+Delete | View | None |
| Notifications (`notifications`) | Edit+Delete | Edit+Delete | Edit | Edit |
| Staff and roles (`staff`) | Edit+Delete | None | None | None |
| Driver rules (`drules`) | Edit+Delete | Edit+Delete | None | None |
| Driver reports (`dreports`) | Edit+Delete | Edit+Delete | View | None |

## Appendix D. Admin portal: every page, button and endpoint

How to read each page: first its facts (feature, base path, files), then what is on the screen, then one row per button. "Where" says whether the button is on the page, on a tab, in a dialog or on a detail page. "Opens" lists the dialog and its fields (a star marks a required field). "Status" is **Exists** when the backend already has the route, **New** when it must be built, **UI** when no server call is needed. Row actions (View, Edit, Delete) exist on every table as in the demo; where changing a field would be unsafe (money, KYC status) the server refuses and says why.

> **Rule:** Build the real screen to look and behave exactly like the demo page of the same name. This appendix lists what the demo page contains; the demo file itself (`prototypes/admin_demo_model.html`) is the visual reference.

### D.1 Dashboard (`dashboard`)

| Item | Value |
|---|---|
| Menu group | Overview |
| Feature / phase | Dashboards and reports / Phase 7 |
| API base | `/admin/dashboard` |
| Files | `dashboard_admin_manage_screen.dart`, `dashboard_admin_manage.ts`, `dashboard_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | Needs your attention \| Bookings over time (chart, today / 7 days / 30 days) \| Booking status (chart) \| Revenue and commission (chart) \| Top routes by bookings \| Top operators by sales \| Latest activity |
| Number cards (each opens the records behind it) | Bookings \| Gross sales \| ommission earned \| Active operators2 joined this month \| Active trips \| Buses live now \| Refunds pending \| Average occupancy |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Today |  | GET /admin/dashboard?range=today\|7d\|30d | New |  |
| Page | 7 days |  | GET /admin/dashboard?range=today\|7d\|30d | New |  |
| Page | 30 days |  | GET /admin/dashboard?range=today\|7d\|30d | New |  |
| Page | Export |  | GET /admin/dashboard/export | New |  |

### D.2 Invitations (`invitations`)

| Item | Value |
|---|---|
| Menu group | Operators |
| Feature / phase | Operator invitations / Phase 1 |
| API base | `/onboarding/invitations` |
| Files | `invitations_admin_manage_screen.dart`, `invitations_admin_manage.ts`, `invitations_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Pending / Accepted / Expired / Revoked] |
| Table columns | ID \| Company \| Owner \| Email \| Status \| Sent ▼ \| Expires \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Invite operator | Invite operator: Company name*; Owner name*; Email*; Phone (optional) | No server call | UI | opens the invite form |
| Page > dialog | Send invitation |  | POST /onboarding/invitations | Exists | sends the email and WhatsApp link |
| Page | Export CSV |  | GET /onboarding/invitations/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Invitation INV-205 (CompanyPearl TravelsOwnerJose ThomasEmailjose@pearl.exampleStatusPendingEmail de) | GET /onboarding/invitations/:id | New | detail |
| Page > dialog | Copy link |  | No server call | UI | copies text to the clipboard |
| Page | Resend |  | POST /onboarding/invitations/:id/resend | Exists |  |
| Page | Revoke | Revoke invitation (The link will stop working. The operator will not be able to join with it.) | No server call | UI | opens the revoke confirmation |
| Page > dialog | Revoke |  | DELETE /onboarding/invitations/:id | New | confirm of a delete or revoke; audit |
| Page | View | Invitation INV-205 (CompanyPearl TravelsOwnerJose ThomasEmailjose@pearl.exampleStatusPendingEmail de) | GET /onboarding/invitations/:id | New | detail |
| Page | Edit | Edit INV-205: Company*; Owner*; Email*; Status [Pending / Accepted / Expired / Revoked]; Sent*; Expires* | No server call | UI | opens the edit form, filled from GET /onboarding/invitations/:id |
| Page > dialog | Save changes |  | PATCH /onboarding/invitations/:id | New | save changes; audit before and after |
| Page | Delete | Delete INV-205? (This removes it from every list. You can undo for a few seconds.) | DELETE /onboarding/invitations/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /onboarding/invitations/:id/restore |
| Page > dialog | Delete |  | DELETE /onboarding/invitations/:id | New | confirm of a delete or revoke; audit |

### D.3 KYC reviews (`kyc`)

| Item | Value |
|---|---|
| Menu group | Operators |
| Feature / phase | KYC review and company onboarding / Phase 1 |
| API base | `/onboarding/submissions` |
| Files | `kyc_admin_manage_screen.dart`, `kyc_admin_manage.ts`, `kyc_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Pending / Approved / Rejected] \| Type [All / Company / Bus] |
| Table columns | ID \| Operator \| Type \| Status \| Documents \| Waiting ▲ \| Actions |
| Detail page #/kyc/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /onboarding/submissions/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/kyc/:id | GET /onboarding/submissions/:id | Exists |  |
| Page | View | Opens page #/kyc/:id | GET /onboarding/submissions/:id | Exists |  |
| Page | Edit | Edit SUB-1006: Operator*; Type [Company / Bus]; Status [Pending / Rejected / Approved]; Waiting* | No server call | UI | opens the edit form, filled from GET /onboarding/submissions/:id |
| Page > dialog | Save changes |  | No server call | UI | not allowed to edit KYC status; use review, approve or reject |
| Detail page #/kyc/:id | History | History (Submitted10 Oct 2026, 02:37 amApproved10 Oct 2026, 05:37 pm) | GET /onboarding/submissions/:id/history | New | new |
| Detail page #/kyc/:id | View | GST certificate (GST_scan.pdfDocument preview placeholder. The real portal shows the uploaded PDF) | GET /files/:id/content | Exists |  |

### D.4 Operators (`operators`)

| Item | Value |
|---|---|
| Menu group | Operators |
| Feature / phase | Operators / Phase 1 |
| API base | `/catalogue/operators` |
| Files | `operators_admin_manage_screen.dart`, `operators_admin_manage.ts`, `operators_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Active / Pending approval / Suspended] \| Payout mode [All / Automatic / Manual] |
| Table columns | Operator \| Status \| KYC \| Buses \| Trips \| Payout \| Rating \| Joined \| Actions |
| Detail page #/operators/:id | tabs: Overview, Buses, Commission and payout, Bookings, Activity. cards: Buses, Trips, Bookings, Sales |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /catalogue/operators/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/operators/:id | GET /catalogue/operators/:id | Exists | plus tabs Overview, Buses, Bookings, Commission and payout |
| Page | View | Opens page #/operators/:id | GET /catalogue/operators/:id | Exists | plus tabs Overview, Buses, Bookings, Commission and payout |
| Page | Edit | Edit Kaveri Express: Operator*; Status [Active / Suspended / Pending approval]; KYC [Approved / Pending / Rejected / Draft]; Buses*; Trips*; Payout [Auto / Manual]; Rating*; Joined* | No server call | UI | opens the edit form, filled from GET /catalogue/operators/:id |
| Page > dialog | Save changes |  | PATCH /catalogue/operators/:id | New | save changes; audit before and after |
| Page | Delete | Delete Kaveri Express? (This removes it from every list. You can undo for a few seconds.) | DELETE /catalogue/operators/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/operators/:id/restore |
| Page > dialog | Delete |  | DELETE /catalogue/operators/:id | New | confirm of a delete or revoke; audit |
| Detail page #/operators/:id | Suspend | Suspend Kaveri Express: Reason (shown to the owner)* | No server call | UI | opens reason form (proof allowed) |
| Detail page #/operators/:id > dialog | Suspend |  | POST /catalogue/operators/:id/status | Exists | body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator |
| Detail page #/operators/:id | Message owner | Message owner: Message* | No server call | UI | opens message form |
| Detail page #/operators/:id > dialog | Send |  | POST /admin/operators/:id/messages | New | in-app and WhatsApp to the owner |
| Detail page #/operators/:id / tab Overview | Suspend | Suspend Kaveri Express: Reason (shown to the owner)* | No server call | UI | opens reason form (proof allowed) |
| Detail page #/operators/:id / tab Overview > dialog | Suspend |  | POST /catalogue/operators/:id/status | Exists | body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator |
| Detail page #/operators/:id / tab Overview | Message owner | Message owner: Message* | No server call | UI | opens message form |
| Detail page #/operators/:id / tab Overview > dialog | Send |  | POST /admin/operators/:id/messages | New | in-app and WhatsApp to the owner |
| Detail page #/operators/:id / tab Buses | Suspend | Suspend Kaveri Express: Reason (shown to the owner)* | No server call | UI | opens reason form (proof allowed) |
| Detail page #/operators/:id / tab Buses > dialog | Suspend |  | POST /catalogue/operators/:id/status | Exists | body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator |
| Detail page #/operators/:id / tab Buses | Message owner | Message owner: Message* | No server call | UI | opens message form |
| Detail page #/operators/:id / tab Buses > dialog | Send |  | POST /admin/operators/:id/messages | New | in-app and WhatsApp to the owner |
| Detail page #/operators/:id / tab Buses | Export CSV |  | GET /catalogue/operators/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/operators/:id / tab Buses | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/operators/:id / tab Buses | List |  | No server call | UI | table or list view of the same data |
| Detail page #/operators/:id / tab Buses | View | Kaveri Prime 39 (IdBUS1OperatoridOP1OperatorKaveri ExpressRegistrationKA01 AB 3469NameKaveri Prim) | GET /catalogue/operators/:id | Exists | read one record for the detail window |
| Detail page #/operators/:id / tab Buses > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /catalogue/operators/:id |
| Detail page #/operators/:id / tab Buses > dialog | Delete |  | DELETE /catalogue/operators/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/operators/:id/restore |
| Detail page #/operators/:id / tab Commission and payout | Suspend | Suspend Kaveri Express: Reason (shown to the owner)* | No server call | UI | opens reason form (proof allowed) |
| Detail page #/operators/:id / tab Commission and payout > dialog | Suspend |  | POST /catalogue/operators/:id/status | Exists | body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator |
| Detail page #/operators/:id / tab Commission and payout | Message owner | Message owner: Message* | No server call | UI | opens message form |
| Detail page #/operators/:id / tab Commission and payout > dialog | Send |  | POST /admin/operators/:id/messages | New | in-app and WhatsApp to the owner |
| Detail page #/operators/:id / tab Commission and payout | Change payout mode | Payout mode - Kaveri Express: Payout mode [Automatic - Razorpay Route splits each payment / Manual - Abra collects and settles each cycle] | No server call | UI | opens payout mode form |
| Detail page #/operators/:id / tab Commission and payout > dialog | Save |  | PUT /admin/operators/:id/payout-mode | New | AUTO_SPLIT or MANUAL; audit |
| Detail page #/operators/:id / tab Bookings | Suspend | Suspend Kaveri Express: Reason (shown to the owner)* | No server call | UI | opens reason form (proof allowed) |
| Detail page #/operators/:id / tab Bookings > dialog | Suspend |  | POST /catalogue/operators/:id/status | Exists | body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator |
| Detail page #/operators/:id / tab Bookings | Message owner | Message owner: Message* | No server call | UI | opens message form |
| Detail page #/operators/:id / tab Bookings > dialog | Send |  | POST /admin/operators/:id/messages | New | in-app and WhatsApp to the owner |
| Detail page #/operators/:id / tab Bookings | Export CSV |  | GET /catalogue/operators/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/operators/:id / tab Bookings | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/operators/:id / tab Bookings | List |  | No server call | UI | table or list view of the same data |
| Detail page #/operators/:id / tab Bookings | View | Opens page #/bookings/:id | GET /admin/bookings/:id | New | detail with passengers, payment, refund, messages |
| Detail page #/operators/:id / tab Bookings | Edit | Edit ABRK1563A: PNR*; Customer*; Route*; Amount (Rs)*; Status [Confirmed / Completed / Cancelled] | No server call | UI | opens the edit form, filled from GET /catalogue/operators/:id |
| Detail page #/operators/:id / tab Bookings > dialog | Save changes |  | PATCH /catalogue/operators/:id | New | save changes; audit before and after |
| Detail page #/operators/:id / tab Activity | Suspend | Suspend Kaveri Express: Reason (shown to the owner)* | No server call | UI | opens reason form (proof allowed) |
| Detail page #/operators/:id / tab Activity > dialog | Suspend |  | POST /catalogue/operators/:id/status | Exists | body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator |
| Detail page #/operators/:id / tab Activity | Message owner | Message owner: Message* | No server call | UI | opens message form |
| Detail page #/operators/:id / tab Activity > dialog | Send |  | POST /admin/operators/:id/messages | New | in-app and WhatsApp to the owner |

### D.5 Driver rules (defaults) (`drules`)

| Item | Value |
|---|---|
| Menu group | Operators |
| Feature / phase | Driver rules and trip checklists / Phase 9 |
| API base | `/admin/driver-rules` |
| Files | `driver_rules_admin_manage_screen.dart`, `driver_rules_admin_manage.ts`, `driver_rules_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Before the trip \| After the trip \| Reports |
| Table columns | Item \| Rule \| Photo \| Applies to \| On |
| Tab "Before the trip" | columns: Item, Rule, Photo, Applies to, On |
| Tab "After the trip" | columns: Item, Rule, Photo, Applies to, On |
| Tab "Reports" | columns: Report, How often, Due, Questions, On |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Push the minimum to every operator | Push the minimum to every operator (Every operator gets the locked items (added if missing). Their own extra items s) | POST /admin/driver-rules/push-minimum | New | adds the locked items to every operator's copy; audit |
| Page > dialog | Push |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Page | Export CSV |  | GET /admin/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add an item | Add an item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses]; Abra minimum (operators cannot remove it) [No / Yes, locked] | No server call | UI | opens item form |
| Page > dialog | Add |  | POST /admin/driver-rules/defaults/items or PATCH .../items/:id | New | defaults every new operator starts from |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | (icon) |  | PATCH /admin/driver-rules/defaults/items/:id/active | New | locked items cannot be switched off |
| Page | (icon) |  | PATCH /admin/driver-rules/defaults/order | New |  |
| Page | Edit | Edit item: Item (what the driver reads)*; If it is a problem [Blocks the trip / Warns only]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses]; Abra minimum (operators cannot remove it) [No / Yes, locked] | No server call | UI | opens item form |
| Page > dialog | Save |  | POST /admin/driver-rules/defaults/items or PATCH .../items/:id | New | defaults every new operator starts from |
| Page | Remove | Remove this item (Drivers will no longer be asked: Your driving licence is valid. Old checklists k) | DELETE /admin/driver-rules/defaults/items/:id | New | locked items cannot be removed |
| Page > dialog | Remove |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Before the trip | Push the minimum to every operator | Push the minimum to every operator (Every operator gets the locked items (added if missing). Their own extra items s) | POST /admin/driver-rules/push-minimum | New | adds the locked items to every operator's copy; audit |
| Tab: Before the trip > dialog | Push |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Before the trip | Export CSV |  | GET /admin/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Before the trip | Add an item | Add an item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses]; Abra minimum (operators cannot remove it) [No / Yes, locked] | No server call | UI | opens item form |
| Tab: Before the trip > dialog | Add |  | POST /admin/driver-rules/defaults/items or PATCH .../items/:id | New | defaults every new operator starts from |
| Tab: Before the trip | Table |  | No server call | UI | table or list view of the same data |
| Tab: Before the trip | List |  | No server call | UI | table or list view of the same data |
| Tab: Before the trip | (icon) |  | PATCH /admin/driver-rules/defaults/items/:id/active | New | locked items cannot be switched off |
| Tab: Before the trip | (icon) |  | PATCH /admin/driver-rules/defaults/order | New |  |
| Tab: Before the trip | Edit | Edit item: Item (what the driver reads)*; If it is a problem [Blocks the trip / Warns only]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses]; Abra minimum (operators cannot remove it) [No / Yes, locked] | No server call | UI | opens item form |
| Tab: Before the trip > dialog | Save |  | POST /admin/driver-rules/defaults/items or PATCH .../items/:id | New | defaults every new operator starts from |
| Tab: Before the trip | Remove | Remove this item (Drivers will no longer be asked: Your driving licence is valid. Old checklists k) | DELETE /admin/driver-rules/defaults/items/:id | New | locked items cannot be removed |
| Tab: Before the trip > dialog | Remove |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: After the trip | Push the minimum to every operator | Push the minimum to every operator (Every operator gets the locked items (added if missing). Their own extra items s) | POST /admin/driver-rules/push-minimum | New | adds the locked items to every operator's copy; audit |
| Tab: After the trip > dialog | Push |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: After the trip | Export CSV |  | GET /admin/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: After the trip | Add an item | Add an item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses]; Abra minimum (operators cannot remove it) [No / Yes, locked] | No server call | UI | opens item form |
| Tab: After the trip > dialog | Add |  | POST /admin/driver-rules/defaults/items or PATCH .../items/:id | New | defaults every new operator starts from |
| Tab: After the trip | Table |  | No server call | UI | table or list view of the same data |
| Tab: After the trip | List |  | No server call | UI | table or list view of the same data |
| Tab: After the trip | (icon) |  | PATCH /admin/driver-rules/defaults/items/:id/active | New | locked items cannot be switched off |
| Tab: After the trip | (icon) |  | PATCH /admin/driver-rules/defaults/order | New |  |
| Tab: After the trip | Edit | Edit item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses]; Abra minimum (operators cannot remove it) [No / Yes, locked] | No server call | UI | opens item form |
| Tab: After the trip > dialog | Save |  | POST /admin/driver-rules/defaults/items or PATCH .../items/:id | New | defaults every new operator starts from |
| Tab: After the trip | Remove | Remove this item (Drivers will no longer be asked: End odometer reading (km). Old checklists keep ) | DELETE /admin/driver-rules/defaults/items/:id | New | locked items cannot be removed |
| Tab: After the trip > dialog | Remove |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Reports | Push the minimum to every operator | Push the minimum to every operator (Every operator gets the locked items (added if missing). Their own extra items s) | POST /admin/driver-rules/push-minimum | New | adds the locked items to every operator's copy; audit |
| Tab: Reports > dialog | Push |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Reports | Export CSV |  | GET /admin/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Reports | Add a report | Add a report: Report name*; How often [Every day / Every week / When needed]; Due time (daily and weekly); Due day (weekly) [Mon / Tue / Wed / Thu / Fri / Sat ...] | No server call | UI | opens report type form |
| Tab: Reports > dialog | Add |  | POST /admin/driver-rules/defaults/reports or PATCH .../reports/:id | New |  |
| Tab: Reports | Table |  | No server call | UI | table or list view of the same data |
| Tab: Reports | List |  | No server call | UI | table or list view of the same data |
| Tab: Reports | (icon) |  | PATCH /admin/driver-rules/defaults/reports/:id/active | New |  |
| Tab: Reports | Questions | Questions: Question; Answer type [Text / Number / Yes or no / Choose one / Photo / File]; Choices (for "Choose one"); Required [Optional / Required] | No server call | UI | opens the question list of a report type |
| Tab: Reports > dialog | Add this question |  | POST /admin/driver-rules/defaults/reports/:id/questions | New |  |
| Tab: Reports | Edit | Edit report: Report name*; How often [Every day / Every week / When needed]; Due time (daily and weekly); Due day (weekly) [Mon / Tue / Wed / Thu / Fri / Sat ...] | No server call | UI | opens report type form |
| Tab: Reports > dialog | Save |  | POST /admin/driver-rules/defaults/reports or PATCH .../reports/:id | New |  |
| Tab: Reports | Remove | Remove this report (Drivers will no longer see Daily report. Reports already sent are kept.) | DELETE /admin/driver-rules/defaults/reports/:id | New |  |
| Tab: Reports > dialog | Remove |  | DELETE /admin/driver-rules/:id | New | confirm of a delete or revoke; audit |

### D.6 Driver reports (`dreports`)

| Item | Value |
|---|---|
| Menu group | Operators |
| Feature / phase | Driver reports / Phase 9 |
| API base | `/admin/driver-reports` |
| Files | `driver_reports_admin_manage_screen.dart`, `driver_reports_admin_manage.ts`, `driver_reports_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Reports due or late20 overdue \| Waiting for review \| Sent back to drivers \| Trips started past a failed check |
| Tabs | Reports \| Missing \| Trip checklists |
| Filters | Driver or report \| Status [All / Waiting for review / Approved / Sent back] \| Report [All / Daily report / Weekly report] \| Driver [All / Ramesh k / Sunil y] \| Operator [All / Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours / Tungabhadra Express / Konkan Rider / Vindhya Travels] |
| Table columns | Report \| Driver \| Operator \| Sent ▼ \| Status \| Files |
| Tab "Reports" | cards: Reports due or late20 overdue, Waiting for review, Sent back to drivers, Trips started past a failed check. filters: Driver or report, Status [All / Waiting for review / Approved / Sent back], Report [All / Daily report / Weekly report], Driver [All / Ramesh k / Sunil y], Operator [All / Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours / Tungabhadra Express / Konkan Rider / Vindhya Travels]. columns: Report, Driver, Operator, Sent ▼, Status, Files |
| Tab "Missing" | cards: Reports due or late20 overdue, Waiting for review, Sent back to drivers, Trips started past a failed check. filters: Status [All / Overdue / Due soon]. columns: Driver, Operator, Report, Due, Status |
| Tab "Trip checklists" | cards: Reports due or late20 overdue, Waiting for review, Sent back to drivers, Trips started past a failed check. filters: Search, Result [All / Passed / Warnings / Started anyway], When [All / Before the trip / After the trip], Operator [All / Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours / Tungabhadra Express / Konkan Rider / Vindhya Travels]. columns: Trip, Driver, Operator, When, Time ▼, Odometer, Result |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Daily report - Ramesh K (DriverRamesh KOperatorKaveri ExpressReport11 Oct 2026Sent11 Oct 2026, 07:42 pmSt) | GET /admin/driver-reports/:id | New | read-only: system numbers (frozen at send) and the driver's answers |
| Tab: Reports | Export CSV |  | GET /admin/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Reports | Table |  | No server call | UI | table or list view of the same data |
| Tab: Reports | List |  | No server call | UI | table or list view of the same data |
| Tab: Reports | Row (open the record) | Daily report - Ramesh K (DriverRamesh KOperatorKaveri ExpressReport11 Oct 2026Sent11 Oct 2026, 07:42 pmSt) | GET /admin/driver-reports/:id | New | read-only: system numbers (frozen at send) and the driver's answers |
| Tab: Missing | Export CSV |  | GET /admin/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Missing | Table |  | No server call | UI | table or list view of the same data |
| Tab: Missing | List |  | No server call | UI | table or list view of the same data |
| Tab: Missing | Tell the operator |  | POST /admin/driver-reports/remind | New | tells the operator which report is missing |
| Tab: Trip checklists | Export CSV |  | GET /admin/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Trip checklists | Table |  | No server call | UI | table or list view of the same data |
| Tab: Trip checklists | List |  | No server call | UI | table or list view of the same data |
| Tab: Trip checklists | Row (open the record) | After the trip: TRP-3018 (DriverRamesh KTripTRP-3018 Vijayawada to VisakhapatnamWhen11 Oct 2026, 07:42 amO) | GET /admin/trip-checks/:id | New | read-only checklist result |

### D.7 Commission (`commission`)

| Item | Value |
|---|---|
| Menu group | Commercial |
| Feature / phase | Commission rules / Phase 2 |
| API base | `/admin/commission/rules` |
| Files | `commission_admin_manage_screen.dart`, `commission_admin_manage.ts`, `commission_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: View |

| On the screen | Contents |
|---|---|
| Tabs | Rules \| Price calculator \| Change history |
| Filters | Search \| Applies to [All / Operator / Route / Bus type] \| Status [All / Active / Inactive] |
| Table columns | ID \| Applies to \| Target \| Commission \| Effective from \| Version \| Status \| Agreed note \| Actions |
| Tab "Rules" | filters: Search, Applies to [All / Operator / Route / Bus type], Status [All / Active / Inactive]. columns: ID, Applies to, Target, Commission, Effective from, Version, Status, Agreed note, Actions |
| Tab "Price calculator" | filters: Operator fare per seat (Rs), Seats, Operator [Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours / Tungabhadra Express / Konkan Rider / Vindhya Travels / Malabar Lines], Route [Hyderabad to Bengaluru / Bengaluru to Hyderabad / Hyderabad to Chennai / Chennai to Coimbatore / Vijayawada to Visakhapatnam / Hyderabad to Vijayawada / Bengaluru to Mysuru / Chennai to Madurai / Mumbai to Pune / Hyderabad to Tirupati], Bus type [AC Sleeper / Non-AC Sleeper / AC Seater / Non-AC Seater / Volvo Multi-Axle AC / Semi-Sleeper AC] |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Change | Default commission: Type [Percentage / Flat per seat]; Value (percent, or rupees per seat) | No server call | UI | opens default form |
| Page > dialog | Save |  | PUT /admin/commission/default | New | audit |
| Page | Export CSV |  | GET /admin/commission/rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | New rule | New commission rule: Applies to [One operator / One route / One bus type]; Which one [Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours ...]; Type [Percentage / Flat per seat]; Value; Effective from; Agreed note | No server call | UI | opens the rule form |
| Page > dialog | Save rule |  | POST /admin/commission/rules | New | new rule, or POST /admin/commission/rules/:id/versions for "Save as new version"; history row written; never changes past bookings |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Edit | Edit rule CR-1: Applies to [One operator / One route / One bus type]; Which one [Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours ...]; Type [Percentage / Flat per seat]; Value; Effective from; Agreed note | No server call | UI | opens the rule form |
| Page > dialog | Save as new version |  | POST /admin/commission/rules | New | new rule, or POST /admin/commission/rules/:id/versions for "Save as new version"; history row written; never changes past bookings |
| Page | Deactivate |  | PATCH /admin/commission/rules/:id/active | New | activate or deactivate; audit |
| Page | View | CR-1 (IDCR-1Applies toOperatorTargetKaveri ExpressModePercentCommission1000Agreed note) | GET /admin/commission/rules/:id | New | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /admin/commission/rules/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/commission/rules/:id/restore |
| Page | Activate |  | PATCH /admin/commission/rules/:id/active | New | activate or deactivate; audit |
| Tab: Rules | Change | Default commission: Type [Percentage / Flat per seat]; Value (percent, or rupees per seat) | No server call | UI | opens default form |
| Tab: Rules > dialog | Save |  | PUT /admin/commission/default | New | audit |
| Tab: Rules | Export CSV |  | GET /admin/commission/rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Rules | New rule | New commission rule: Applies to [One operator / One route / One bus type]; Which one [Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours ...]; Type [Percentage / Flat per seat]; Value; Effective from; Agreed note | No server call | UI | opens the rule form |
| Tab: Rules > dialog | Save rule |  | POST /admin/commission/rules | New | new rule, or POST /admin/commission/rules/:id/versions for "Save as new version"; history row written; never changes past bookings |
| Tab: Rules | Table |  | No server call | UI | table or list view of the same data |
| Tab: Rules | List |  | No server call | UI | table or list view of the same data |
| Tab: Rules | Edit | Edit rule CR-1: Applies to [One operator / One route / One bus type]; Which one [Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours ...]; Type [Percentage / Flat per seat]; Value; Effective from; Agreed note | No server call | UI | opens the rule form |
| Tab: Rules > dialog | Save as new version |  | POST /admin/commission/rules | New | new rule, or POST /admin/commission/rules/:id/versions for "Save as new version"; history row written; never changes past bookings |
| Tab: Rules | Deactivate |  | PATCH /admin/commission/rules/:id/active | New | activate or deactivate; audit |
| Tab: Rules | View | CR-1 (IDCR-1Applies toOperatorTargetKaveri ExpressModePercentCommission1000Agreed note) | GET /admin/commission/rules/:id | New | read one record for the detail window |
| Tab: Rules > dialog | Delete |  | DELETE /admin/commission/rules/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/commission/rules/:id/restore |
| Tab: Rules | Activate |  | PATCH /admin/commission/rules/:id/active | New | activate or deactivate; audit |
| Tab: Price calculator | Calculate |  | POST /admin/commission/calculate | New | price calculator: fare in, customer price and operator payable out (same function the booking uses) |

### D.8 Payout and fees (`payout`)

| Item | Value |
|---|---|
| Menu group | Commercial |
| Feature / phase | Payout and fee settings / Phase 2 |
| API base | `/admin/payout/refund-slabs` |
| Files | `payout_cfg_admin_manage_screen.dart`, `payout_cfg_admin_manage.ts`, `payout_cfg_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: View; Support: None; Accounts: View |

| On the screen | Contents |
|---|---|
| Filters | Default mode for new operators [Automatic (Razorpay Route) / Manual settlement] \| Settlement cycle (days) \| Minimum payout (Rs) \| Hold days after trip \| GST on fare (%) \| Convenience fee (Rs) \| Who funds coupon discounts [Abra Travels / The operator / Shared 50/50] \| Search \| Mode [All / Automatic / Manual] |
| Table columns 1 | Cancel at least (hours before) \| Refund \| Actions |
| Table columns 2 | Operator \| Mode \| Bank account \| Verification \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Save changes |  | PUT /admin/payout/settings | New | cycle days, minimum payout, hold days, convenience fee, GST percent, coupon funding; audit |
| Page | (icon) |  | PUT /admin/payout/settings/default-mode | New | automatic (Razorpay Route) or manual |
| Page | Add slab | Add refund slab: Hours before departure*; Refund percent* | No server call | UI | opens slab form |
| Page > dialog | Add |  | POST /admin/payout/refund-slabs | New | audit |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Remove |  | DELETE /admin/payout/refund-slabs/:id | New | audit |
| Page | View | CS1 (IdCS1Cancel at least (hours before)24Refund75) | GET /admin/payout/refund-slabs/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/payout/refund-slabs/:id |
| Page > dialog | Delete |  | DELETE /admin/payout/refund-slabs/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/payout/refund-slabs/:id/restore |
| Page | Export CSV |  | GET /admin/payout/refund-slabs/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Change mode | Payout mode - Kaveri Express: Payout mode [Automatic - Razorpay Route splits each payment / Manual - Abra collects and settles each cycle] | No server call | UI | opens payout mode form |
| Page > dialog | Save |  | PUT /admin/operators/:id/payout-mode | New | AUTO_SPLIT or MANUAL; audit |
| Page | Verify bank |  | POST /admin/operators/:id/bank/verify | New | penny-drop or manual check; audit |

### D.9 Cities and places (`places`)

| Item | Value |
|---|---|
| Menu group | Catalogue |
| Feature / phase | Cities and places / Phase 1 |
| API base | `/catalogue/locations` |
| Files | `places_admin_manage_screen.dart`, `places_admin_manage.ts`, `places_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Places \| Cities \| Operator requests |
| Filters | Search \| City [All / Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore / Kochi / Mumbai / Pune] \| Used for [All / Boarding / Dropping / Both] \| Status [All / Active / Inactive] |
| Table columns | Place \| City \| Used for \| Added by \| Trips using it \| Status \| Actions |
| Tab "Places" | filters: Search, City [All / Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore / Kochi / Mumbai / Pune], Used for [All / Boarding / Dropping / Both], Status [All / Active / Inactive]. columns: Place, City, Used for, Added by, Trips using it, Status, Actions |
| Tab "Cities" | filters: Search, State [All / Telangana / Karnataka / Tamil nadu / Andhra pradesh / Kerala / Maharashtra / Goa / Gujarat], Status [All / Active / Inactive]. columns: City, State, Places, Popular, Status, Actions |
| Tab "Operator requests" | filters: Search, Status [All / Pending / Approved / Rejected]. columns: Requested place, City, Operator, Requested, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /catalogue/locations/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add place | Add place: Place name*; City [Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore ...]; Address*; Landmark; Used for [Boarding only / Dropping only / Both]; Latitude; Longitude; Contact phone; Instructions for passengers | No server call | UI | opens place form |
| Page > dialog | Save |  | POST /catalogue/locations or PUT /catalogue/locations/:id | Exists |  |
| Page | Import | Import places (Upload a CSV file with these columns: name, city, address, landmark. Excel files) | POST /catalogue/locations/import?dryRun=true then false | New | upload, row-by-row errors, then save; GET /catalogue/locations/import-template for the file |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Edit | Edit place: Place name*; City [Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore ...]; Address*; Landmark; Used for [Boarding only / Dropping only / Both]; Latitude; Longitude; Contact phone; Instructions for passengers | No server call | UI | opens place form |
| Page | View | Hyderabad Bus Stand (IdPL1CityHyderabadPlaceHyderabad Bus StandAddress12, Main Road, HyderabadLandmar) | GET /catalogue/locations/:id | Exists | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /catalogue/locations/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/locations/:id/restore |
| Tab: Places | Export CSV |  | GET /catalogue/locations/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Places | Add place | Add place: Place name*; City [Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore ...]; Address*; Landmark; Used for [Boarding only / Dropping only / Both]; Latitude; Longitude; Contact phone; Instructions for passengers | No server call | UI | opens place form |
| Tab: Places > dialog | Save |  | POST /catalogue/locations or PUT /catalogue/locations/:id | Exists |  |
| Tab: Places | Import | Import places (Upload a CSV file with these columns: name, city, address, landmark. Excel files) | POST /catalogue/locations/import?dryRun=true then false | New | upload, row-by-row errors, then save; GET /catalogue/locations/import-template for the file |
| Tab: Places | Table |  | No server call | UI | table or list view of the same data |
| Tab: Places | List |  | No server call | UI | table or list view of the same data |
| Tab: Places | Edit | Edit place: Place name*; City [Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore ...]; Address*; Landmark; Used for [Boarding only / Dropping only / Both]; Latitude; Longitude; Contact phone; Instructions for passengers | No server call | UI | opens place form |
| Tab: Places | View | Hyderabad Bus Stand (IdPL1CityHyderabadPlaceHyderabad Bus StandAddress12, Main Road, HyderabadLandmar) | GET /catalogue/locations/:id | Exists | read one record for the detail window |
| Tab: Places > dialog | Delete |  | DELETE /catalogue/locations/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/locations/:id/restore |
| Tab: Cities | Export CSV |  | GET /catalogue/locations/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Cities | Add city | Add city: City name*; State*; Telugu name; Hindi name; Status [Active / Inactive]; Show as popular [Yes / No] | No server call | UI | opens city form |
| Tab: Cities > dialog | Save |  | POST /catalogue/cities or PUT /catalogue/cities/:id | Exists |  |
| Tab: Cities | Import | Import cities (Upload a CSV file with these columns: name, state. Excel files can be saved as C) | POST /catalogue/locations/import?dryRun=true then false | New | upload, row-by-row errors, then save; GET /catalogue/locations/import-template for the file |
| Tab: Cities | Table |  | No server call | UI | table or list view of the same data |
| Tab: Cities | List |  | No server call | UI | table or list view of the same data |
| Tab: Cities | Edit | Edit city: City name*; State*; Telugu name; Hindi name; Status [Active / Inactive]; Show as popular [Yes / No] | No server call | UI | opens city form |
| Tab: Cities | View | Hyderabad (IdCT1CityHyderabadStateTelanganaStatusYesPopularYesTeహైదరాబాద్HiहैदराबादPlaces2) | GET /catalogue/locations/:id | Exists | read one record for the detail window |
| Tab: Cities > dialog | Delete |  | DELETE /catalogue/locations/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/locations/:id/restore |
| Tab: Operator requests | Export CSV |  | GET /catalogue/locations/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Operator requests | Table |  | No server call | UI | table or list view of the same data |
| Tab: Operator requests | List |  | No server call | UI | table or list view of the same data |
| Tab: Operator requests | Approve |  | POST /admin/place-requests/:id/approve | New | creates the place for every operator; notifies the operator |
| Tab: Operator requests | Reject | Reject request: Reason (the operator reads it)* | No server call | UI | opens reason form |
| Tab: Operator requests > dialog | Reject |  | POST /admin/place-requests/:id/reject | New | reason; notifies the operator |
| Tab: Operator requests | View | Hosur Bus Stand Gate 2 (IdPR-100OperatorKaveri ExpressCityHosurRequested placeHosur Bus Stand Gate 2Addr) | GET /catalogue/locations/:id | Exists | read one record for the detail window |
| Tab: Operator requests > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /catalogue/locations/:id |
| Tab: Operator requests > dialog | Delete |  | DELETE /catalogue/locations/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/locations/:id/restore |

### D.10 Bus types and amenities (`bustypes`)

| Item | Value |
|---|---|
| Menu group | Catalogue |
| Feature / phase | Bus types and amenities / Phase 1 |
| API base | `/catalogue/bus-types` |
| Files | `bus_types_admin_manage_screen.dart`, `bus_types_admin_manage.ts`, `bus_types_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Table columns | Bus type \| Key \| AC \| Seating \| Buses \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Add bus type | Add bus type: Name*; Key (cannot change later)*; Air conditioned [Yes / No]; Seating [Seater / Sleeper / Semi-sleeper] | No server call | UI | opens bus type form |
| Page > dialog | Save |  | POST /catalogue/bus-types or PUT /catalogue/bus-types/:id | Exists |  |
| Page | Export CSV |  | GET /catalogue/bus-types/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Edit | Edit bus type: Name*; Key (cannot change later)*; Air conditioned [Yes / No]; Seating [Seater / Sleeper / Semi-sleeper] | No server call | UI | opens bus type form |
| Page | View | AC Sleeper (IdBT1Bus typeAC SleeperKeyAc sleeperACYesSeatingSleeperStatusYesBuses2) | GET /catalogue/bus-types/:id | New | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /catalogue/bus-types/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/bus-types/:id/restore |
| Page | Add amenity | Add amenity: Amenity name* | No server call | UI | opens amenity form |
| Page > dialog | Add |  | POST /admin/amenities | New | new |
| Page | Toggle Charging point |  | PATCH /admin/amenities/:id/active | New | new |

### D.11 Required documents (`documents`)

| Item | Value |
|---|---|
| Menu group | Catalogue |
| Feature / phase | Required documents and KYC questionnaire / Phase 1 |
| API base | `/catalogue/document-types` |
| Files | `kyc_config_admin_manage_screen.dart`, `kyc_config_admin_manage.ts`, `kyc_config_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| For [All / Operator / Bus] |
| Table columns | Document \| For \| Required \| Has expiry \| File types \| Max size \| Max files \| Active \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Add document type | Add document type: Name*; Key (permanent)*; For [Company / Bus]; Required [Required / Optional]; Has expiry date [Yes / No]; Accepted file types [PDF / PDF, JPG / PDF, JPG, PNG / JPG, PNG]; Largest file (MB, 1 to 25); Most files (1 to 10); Instructions shown to the owner | No server call | UI | opens document type form |
| Page > dialog | Save |  | POST /catalogue/document-types or PUT /catalogue/document-types/:id | Exists |  |
| Page | Export CSV |  | GET /catalogue/document-types/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | (icon) |  | POST /catalogue/document-types/:id/active | Exists |  |
| Page | Edit | Edit document type: Name*; Key (permanent)*; For [Company / Bus]; Required [Required / Optional]; Has expiry date [Yes / No]; Accepted file types [PDF / PDF, JPG / PDF, JPG, PNG / JPG, PNG]; Largest file (MB, 1 to 25); Most files (1 to 10); Instructions shown to the owner | No server call | UI | opens document type form |
| Page | View | GST certificate (IdDT1KeygstDocumentGST certificateForOperatorRequiredYesHas expiryNoFile typesPD) | GET /catalogue/document-types/:id | New | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /catalogue/document-types/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/document-types/:id/restore |

### D.12 KYC questionnaire (`questions`)

| Item | Value |
|---|---|
| Menu group | Catalogue |
| Feature / phase | Required documents and KYC questionnaire / Phase 1 |
| API base | `/admin/kyc/questions` |
| Files | `kyc_config_admin_manage_screen.dart`, `kyc_config_admin_manage.ts`, `kyc_config_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Questions \| Document rules \| Preview checklist |
| Filters | Search |
| Table columns | Question \| Answer type \| Required \| Active \| Actions |
| Tab "Questions" | filters: Search. columns: Question, Answer type, Required, Active, Actions |
| Tab "Document rules" | columns: Rule, When, Document asked, Required, Active, Actions |
| Tab "Preview checklist" | filters: Business type [Company / Individual / Partnership], GST registered [Yes / No], Services [Seat bookings / Charters / Parcel] |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/kyc/questions/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add question | Add question: Question text*; Key (permanent)*; Answer type [TEXT / NUMBER / BOOLEAN / SINGLE_CHOICE / MULTI_CHOICE]; Options (comma separated); Required [Required / Optional] | No server call | UI | opens question form |
| Page > dialog | Save |  | POST /admin/kyc/questions or PATCH /admin/kyc/questions/:id | New | new |
| Page | Export config |  | GET /admin/kyc/config/export | New | questions and document rules as a file |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | (icon) |  | PATCH /admin/kyc/questions/:id/active | New | new |
| Page | Edit | Edit question: Question text*; Key (permanent)*; Answer type [TEXT / NUMBER / BOOLEAN / SINGLE_CHOICE / MULTI_CHOICE]; Options (comma separated); Required [Required / Optional] | No server call | UI | opens question form |
| Page | View | Q1 (IdQ1Keybusiness_typeQuestionWhat is your business type?AppliesOperatorAnswer typ) | GET /admin/kyc/questions/:id | New | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /admin/kyc/questions/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/kyc/questions/:id/restore |
| Tab: Questions | Export CSV |  | GET /admin/kyc/questions/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Questions | Add question | Add question: Question text*; Key (permanent)*; Answer type [TEXT / NUMBER / BOOLEAN / SINGLE_CHOICE / MULTI_CHOICE]; Options (comma separated); Required [Required / Optional] | No server call | UI | opens question form |
| Tab: Questions > dialog | Save |  | POST /admin/kyc/questions or PATCH /admin/kyc/questions/:id | New | new |
| Tab: Questions | Export config |  | GET /admin/kyc/config/export | New | questions and document rules as a file |
| Tab: Questions | Table |  | No server call | UI | table or list view of the same data |
| Tab: Questions | List |  | No server call | UI | table or list view of the same data |
| Tab: Questions | (icon) |  | PATCH /admin/kyc/questions/:id/active | New | new |
| Tab: Questions | Edit | Edit question: Question text*; Key (permanent)*; Answer type [TEXT / NUMBER / BOOLEAN / SINGLE_CHOICE / MULTI_CHOICE]; Options (comma separated); Required [Required / Optional] | No server call | UI | opens question form |
| Tab: Questions | View | Q1 (IdQ1Keybusiness_typeQuestionWhat is your business type?AppliesOperatorAnswer typ) | GET /admin/kyc/questions/:id | New | read one record for the detail window |
| Tab: Questions > dialog | Delete |  | DELETE /admin/kyc/questions/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/kyc/questions/:id/restore |
| Tab: Document rules | Export CSV |  | GET /admin/kyc/questions/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Document rules | Add rule | Add document rule: Rule name*; Document [GST certificate / PAN card / Company registration / Owner ID proof / Bank proof / Interstate permit]; Question [What is your business type? / Do you own the buses you operate? / Which services do you offer? / Are you GST registered? / How many buses do you run? / Routes you plan to operate]; Answer that triggers it*; Required [Required / Optional] | No server call | UI | opens rule form |
| Tab: Document rules > dialog | Save |  | POST /admin/kyc/document-rules or PATCH /admin/kyc/document-rules/:id | New | new |
| Tab: Document rules | Table |  | No server call | UI | table or list view of the same data |
| Tab: Document rules | List |  | No server call | UI | table or list view of the same data |
| Tab: Document rules | (icon) |  | PATCH /admin/kyc/document-rules/:id/active | New | new |
| Tab: Document rules | View | GST certificate for GST-registered operators (IdR1RuleGST certificate for GST-registered operatorsDocument askedgstWhengst_reg) | GET /admin/kyc/questions/:id | New | read one record for the detail window |
| Tab: Document rules > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/kyc/questions/:id |
| Tab: Document rules > dialog | Delete |  | DELETE /admin/kyc/questions/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/kyc/questions/:id/restore |
| Tab: Preview checklist | Show checklist |  | POST /admin/kyc/preview | New | evaluates which documents a sample answer set would require |

### D.13 Buses (`buses`)

| Item | Value |
|---|---|
| Menu group | Operations |
| Feature / phase | Buses and seat layouts / Phase 2 |
| API base | `/catalogue/buses` |
| Files | `buses_admin_manage_screen.dart`, `buses_admin_manage.ts`, `buses_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Active / Pending approval / Maintenance / Retired] \| Operator [All / Kaveri express / Godavari lines / Deccan voyager / Sahyadri coaches / Nilgiri travels / Charminar tours / Tungabhadra express / Konkan rider / Vindhya travels] \| Type [All / Ac sleeper / Non-ac sleeper / Ac seater / Non-ac seater / Volvo multi-axle ac / Semi-sleeper ac] \| Documents [All / Documents expired] |
| Table columns | Registration \| Operator \| Type \| Seats \| Layout \| Insurance \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Import buses | Import buses (Upload a CSV file with these columns: registration, name, type, seats. Excel fil) | POST /catalogue/buses/import?dryRun=true then false | New | upload, row-by-row errors, then save; GET /catalogue/buses/import-template for the file |
| Page | Export CSV |  | GET /catalogue/buses/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | KA01 AB 3469 - Kaveri Prime 39 (OperatorKaveri ExpressTypeSemi-Sleeper ACAir conditionedYesSeats45Seat layout2+2) | GET /catalogue/buses/:id | Exists |  |
| Page > dialog | Mark maintenance |  | POST /catalogue/buses/:id/status | Exists | MAINTENANCE or back to ACTIVE; notifies operator |
| Page > dialog | Retire bus |  | POST /catalogue/buses/:id/status | Exists | RETIRED |
| Page | View | KA01 AB 3469 - Kaveri Prime 39 (OperatorKaveri ExpressTypeSemi-Sleeper ACAir conditionedYesSeats45Seat layout2+2) | GET /catalogue/buses/:id | Exists |  |
| Page | Edit | Edit Kaveri Prime 39: Registration*; Operator*; Type*; Seats*; Layout*; Insurance*; Status [Active / Maintenance / Pending approval] | No server call | UI | opens the edit form, filled from GET /catalogue/buses/:id |
| Page > dialog | Save changes |  | PATCH /catalogue/buses/:id | New | save changes; audit before and after |
| Page | Delete | Delete Kaveri Prime 39? (This removes it from every list. You can undo for a few seconds.) | DELETE /catalogue/buses/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/buses/:id/restore |
| Page > dialog | Delete |  | DELETE /catalogue/buses/:id | New | confirm of a delete or revoke; audit |

### D.14 Trips (`trips`)

| Item | Value |
|---|---|
| Menu group | Operations |
| Feature / phase | Trips and seat inventory / Phase 2 |
| API base | `/catalogue/trips` |
| Files | `trips_admin_manage_screen.dart`, `trips_admin_manage.ts`, `trips_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Draft / Scheduled / Boarding / Departed / In transit / Delayed / Arrived / Cancelled] \| Operator [All / Kaveri express / Godavari lines / Deccan voyager / Sahyadri coaches / Nilgiri travels / Charminar tours / Tungabhadra express / Konkan rider / Vindhya travels] \| Route [All / Hyderabad to bengaluru / Bengaluru to hyderabad / Hyderabad to chennai / Chennai to coimbatore / Vijayawada to visakhapatnam / Hyderabad to vijayawada / Bengaluru to mysuru / Chennai to madurai / Mumbai to pune] \| When [All / Today / Upcoming / Past] |
| Table columns | Trip \| Route \| Bus \| Departs ▼ \| Status \| Seats \| From \| Actions |
| Detail page #/trips/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Add trip for operator | Add trip for an operator: Operator [Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Tungabhadra Express ...]; Bus [KA01 AB 3469 - Kaveri Express / KA01 AB 4945 - Kaveri Express / KA01 AB 8721 - Godavari Lines / TS09 TX 1487 - Deccan Voyager / AP39 TX 6954 - Deccan Voyager / AP39 UB 4422 - Deccan Voyager ...]; Route [Hyderabad to Bengaluru / Bengaluru to Hyderabad / Hyderabad to Chennai / Chennai to Coimbatore / Vijayawada to Visakhapatnam / Hyderabad to Vijayawada ...]; Date*; Departure time*; Lowest fare (Rs)* | No server call | UI | opens the trip form |
| Page > dialog | Create draft |  | POST /catalogue/trips | Exists | creates a draft for an operator |
| Page | Export CSV |  | GET /catalogue/trips/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/trips/:id | GET /catalogue/trips/:id | Exists | plus seat map GET /admin/trips/:id/seats |
| Page | View | Opens page #/trips/:id | GET /catalogue/trips/:id | Exists | plus seat map GET /admin/trips/:id/seats |
| Page | Edit | Edit Hyderabad to Chennai: Route*; Bus*; Departs*; Status [Arrived / Scheduled / Delayed / In transit / Draft / Cancelled]; From (Rs)* | No server call | UI | opens the edit form, filled from GET /catalogue/trips/:id |
| Page > dialog | Save changes |  | PATCH /catalogue/trips/:id | New | save changes; audit before and after |
| Page | Delete | Delete Hyderabad to Chennai? (This removes it from every list. You can undo for a few seconds.) | DELETE /catalogue/trips/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /catalogue/trips/:id/restore |
| Page > dialog | Delete |  | DELETE /catalogue/trips/:id | New | confirm of a delete or revoke; audit |
| Detail page #/trips/:id | 1A | Block seat 1A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id > dialog | Block |  | DELETE /catalogue/trips/:id | New | confirm of a delete or revoke; audit |
| Detail page #/trips/:id | 1B | Block seat 1B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 1C | Block seat 1C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 1D | Block seat 1D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2A | Block seat 2A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2B | Block seat 2B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2C | Block seat 2C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2D | Block seat 2D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3A | Block seat 3A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3B | Block seat 3B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3C | Block seat 3C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3D | Block seat 3D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4A | Block seat 4A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4B | Block seat 4B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4C | Block seat 4C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4D | Block seat 4D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5A | Block seat 5A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5B | Block seat 5B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5C | Block seat 5C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5D | Block seat 5D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6A | Block seat 6A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6B | Block seat 6B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6C | Block seat 6C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6D | Block seat 6D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7A | Block seat 7A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7B | Block seat 7B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7C | Block seat 7C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7D | Block seat 7D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8A | Block seat 8A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8B | Block seat 8B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8C | Block seat 8C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8D | Block seat 8D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9A | Block seat 9A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9B | Block seat 9B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9C | Block seat 9C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9D | Block seat 9D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10A | Block seat 10A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10B | Block seat 10B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10C | Block seat 10C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10D | Block seat 10D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | Export CSV |  | GET /catalogue/trips/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/trips/:id | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/trips/:id | List |  | No server call | UI | table or list view of the same data |

### D.15 Seat inventory (`inventory`)

| Item | Value |
|---|---|
| Menu group | Operations |
| Feature / phase | Trips and seat inventory / Phase 2 |
| API base | `/admin/inventory` |
| Files | `trips_admin_manage_screen.dart`, `trips_admin_manage.ts`, `trips_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Cards: trips on sale, seats sold, seats held right now, low-occupancy trips; table of trips with seat counts |
| Number cards (each opens the records behind it) | Trips on sale \| Seats sold \| Seats held right nowHold time is 10 minutes \| ow occupancy, leaving in 2 daysCheck pricing |
| Filters | Search \| Operator [All / Kaveri express / Godavari lines / Deccan voyager / Sahyadri coaches / Nilgiri travels / Charminar tours / Tungabhadra express / Konkan rider / Vindhya travels] \| Occupancy [All / Under 25% / Over 80%] |
| Table columns | Trip \| Route \| Departs \| Sold \| Held \| Blocked \| Free \| Occupancy \| Actions |
| Detail page #/trips/:id | columns: PNR, Customer, Seats, Amount, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Release expired holds |  | POST /admin/inventory/release-expired-holds | New | frees holds past 10 minutes (also runs by itself every minute) |
| Page | Export CSV |  | GET /admin/inventory/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/trips/:id | GET /catalogue/trips/:id | Exists | plus seat map GET /admin/trips/:id/seats |
| Page | View | Opens page #/trips/:id | GET /catalogue/trips/:id | Exists | plus seat map GET /admin/trips/:id/seats |
| Page | Edit | Edit Hyderabad to Chennai: Route*; Departs*; Held*; Blocked* | No server call | UI | opens the edit form, filled from GET /admin/inventory/:id |
| Page > dialog | Save changes |  | PATCH /admin/trips/:id/inventory | New | held and blocked seats (generic row edit) |
| Page | Delete | Delete Hyderabad to Chennai? (This removes it from every list. You can undo for a few seconds.) | No server call | UI | not allowed: inventory is derived from bookings; the server refuses |
| Page > dialog | Delete |  | DELETE /admin/inventory/:id | New | confirm of a delete or revoke; audit |
| Detail page #/trips/:id | Delay | Delay trip: Delay (minutes)*; Reason* | No server call | UI | opens delay form |
| Detail page #/trips/:id > dialog | Delay and notify |  | POST /admin/trips/:id/delay | New | minutes, reason, proof; notifies customers, operator, admin |
| Detail page #/trips/:id | Change driver | Change driver: Driver [Ramesh K / Sunil Y / Anwar S / Prakash M / Naveen B] | No server call | UI | opens driver form |
| Detail page #/trips/:id > dialog | Save |  | PUT /admin/trips/:id/driver | New | notifies the new driver and the operator |
| Detail page #/trips/:id | Cancel trip | Cancel trip TRP-3002: Reason (customers see it)* | No server call | UI | opens reason form (proof) |
| Detail page #/trips/:id > dialog | Cancel trip and refund |  | POST /catalogue/trips/:id/cancel | Exists | refunds all bookings, notifies customers, operator and driver; audit |
| Detail page #/trips/:id | 1A | Seat 1A is booked (PNRABRM31016BPassengerSneha JoshiPhone+91 9352721339All seats in this booking6D,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id > dialog | Open booking |  | No server call | UI | opens the booking from the trip |
| Detail page #/trips/:id | 1B | Seat 1B is booked (PNRABRK31025APassengerAarav SharmaPhone+91 9622428883All seats in this booking10) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 1C | Seat 1C is held (A customer is paying for this seat right now. It cannot be changed until the hol) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 1D | Seat 1D is booked (PNRABRT31023DPassengerHarish ChandraPhone+91 9906697386All seats in this booking) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2A | Block seat 2A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id > dialog | Block |  | DELETE /admin/inventory/:id | New | confirm of a delete or revoke; audit |
| Detail page #/trips/:id | 2B | Seat 2B is booked (PNRABRM31021BPassengerImran KhanPhone+91 9519223342All seats in this booking2B, ) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2C | Block seat 2C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 2D | Seat 2D is booked (PNRABRQ31017CPassengerSanjay GuptaPhone+91 9377021306All seats in this booking2D) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3A | Seat 3A is booked (PNRABRK31025APassengerAarav SharmaPhone+91 9622428883All seats in this booking10) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3B | Seat 3B is booked (PNRABRT9609CPassengerAnjali DasPhone+91 9477076400All seats in this booking3B, 5) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3C | Seat 3C is booked (PNRABRT31023DPassengerHarish ChandraPhone+91 9906697386All seats in this booking) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 3D | Block seat 3D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4A | Seat 4A is booked (PNRABRM31021BPassengerImran KhanPhone+91 9519223342All seats in this booking2B, ) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4B | Block seat 4B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4C | Seat 4C is booked (PNRABRT31018DPassengerFatima BegumPhone+91 9886431792All seats in this booking4C) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 4D | Seat 4D is booked (PNRABRK31025APassengerAarav SharmaPhone+91 9622428883All seats in this booking10) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5A | Seat 5A is booked (PNRABRT9609CPassengerAnjali DasPhone+91 9477076400All seats in this booking3B, 5) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5B | Seat 5B is booked (PNRABRX31024EPassengerBhavana SPhone+91 9496509971All seats in this booking5B, 7) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5C | Block seat 5C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 5D | Seat 5D is booked (PNRABRM31021BPassengerImran KhanPhone+91 9519223342All seats in this booking2B, ) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6A | Block seat 6A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6B | Seat 6B is booked (PNRABRX31019EPassengerYash ThakurPhone+91 9188923686All seats in this booking6B,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6C | Seat 6C is booked (PNRABRM31026BPassengerKavya MenonPhone+91 9192297973All seats in this booking6CA) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 6D | Seat 6D is booked (PNRABRM31016BPassengerSneha JoshiPhone+91 9352721339All seats in this booking6D,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7A | Seat 7A is booked (PNRABRX31024EPassengerBhavana SPhone+91 9496509971All seats in this booking5B, 7) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7B | Block seat 7B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7C | Seat 7C is booked (PNRABRQ31022CPassengerLakshmi NarayanPhone+91 9851157211All seats in this bookin) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 7D | Block seat 7D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8A | Seat 8A is booked (PNRABRX31019EPassengerYash ThakurPhone+91 9188923686All seats in this booking6B,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8B | Block seat 8B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8C | Seat 8C is booked (PNRABRM31016BPassengerSneha JoshiPhone+91 9352721339All seats in this booking6D,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 8D | Seat 8D is booked (PNRABRX31024EPassengerBhavana SPhone+91 9496509971All seats in this booking5B, 7) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9A | Block seat 9A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9B | Seat 9B is booked (PNRABRQ31022CPassengerLakshmi NarayanPhone+91 9851157211All seats in this bookin) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9C | Block seat 9C (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 9D | Seat 9D is booked (PNRABRX31019EPassengerYash ThakurPhone+91 9188923686All seats in this booking6B,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10A | Block seat 10A (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10B | Seat 10B is booked (PNRABRM31016BPassengerSneha JoshiPhone+91 9352721339All seats in this booking6D,) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10C | Seat 10C is booked (PNRABRK31025APassengerAarav SharmaPhone+91 9622428883All seats in this booking10) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 10D | Block seat 10D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 11A | Seat 11A is booked (PNRABRT31023DPassengerHarish ChandraPhone+91 9906697386All seats in this booking) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 11B | Block seat 11B (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 11C | Seat 11C is booked (PNRABRK31020APassengerPriya NairPhone+91 9950575426All seats in this booking11CA) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | 11D | Block seat 11D (The seat is removed from sale. Use it for a counter sale or a damaged seat. Cust) | POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | New | audit; a held seat only explains who holds it |
| Detail page #/trips/:id | Export CSV |  | GET /admin/inventory/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/trips/:id | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/trips/:id | List |  | No server call | UI | table or list view of the same data |
| Detail page #/trips/:id | View | Opens page #/bookings/:id | GET /admin/bookings/:id | New | detail with passengers, payment, refund, messages |
| Detail page #/trips/:id | Edit | Edit ABRT9609C: PNR*; Customer*; Seats*; Amount (Rs)*; Status [Confirmed / Completed / Cancelled] | No server call | UI | opens the edit form, filled from GET /admin/inventory/:id |
| Detail page #/trips/:id > dialog | Save changes |  | PATCH /admin/trips/:id/inventory | New | held and blocked seats (generic row edit) |

### D.16 Live tracking (`tracking`)

| Item | Value |
|---|---|
| Menu group | Operations |
| Feature / phase | Live tracking / Phase 5 |
| API base | `/admin/tracking` |
| Files | `tracking_admin_manage_screen.dart`, `tracking_admin_manage.ts`, `tracking_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Map with every running bus, list of buses with state, speed, progress and ETA, filter by operator and state, route replay |
| Filters | Operator [All operators / Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels / Charminar Tours / Tungabhadra Express / Konkan Rider / Vindhya Travels] \| State [All states / Live / Delayed / Signal lost] |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | TN38 EF 7890 |  | GET /admin/tracking/trips/:id | New | live card; position by Socket.IO tracking:{tripId} |
| Page | AP16 CD 7939 |  | GET /admin/tracking/trips/:id | New | live card; position by Socket.IO tracking:{tripId} |
| Page | TS07 EF 3887 |  | GET /admin/tracking/trips/:id | New | live card; position by Socket.IO tracking:{tripId} |
| Page | AP39 AB 9725 |  | GET /admin/tracking/trips/:id | New | live card; position by Socket.IO tracking:{tripId} |
| Page | KA01 AB 3469 |  | GET /admin/tracking/trips/:id | New | live card; position by Socket.IO tracking:{tripId} |
| Page | Row (open the record) |  | GET /admin/tracking/trips/:id | New | live card; position by Socket.IO tracking:{tripId} |

### D.17 Bookings (`bookings`)

| Item | Value |
|---|---|
| Menu group | Sales |
| Feature / phase | Booking, passengers and bookings lists / Phase 3 |
| API base | `/admin/bookings` |
| Files | `booking_admin_manage_screen.dart`, `booking_admin_manage.ts`, `booking_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Filters | PNR, name, phone, route \| Status [All / Confirmed / Completed / Cancelled] \| Operator [All / Kaveri express / Godavari lines / Deccan voyager / Sahyadri coaches / Nilgiri travels / Charminar tours / Tungabhadra express / Konkan rider / Vindhya travels] \| Route [All / Hyderabad to bengaluru / Bengaluru to hyderabad / Hyderabad to chennai / Chennai to coimbatore / Vijayawada to visakhapatnam / Hyderabad to vijayawada / Bengaluru to mysuru / Chennai to madurai / Mumbai to pune] \| Payment mode [All / Upi / Card / Netbanking / Wallet] \| Booked [All / Last 7 days / Last 14 days] |
| Table columns | PNR \| Customer \| Route \| Travel \| Seats \| Amount \| Paid by \| Status \| Actions |
| Detail page #/bookings/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/bookings/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/bookings/:id | GET /admin/bookings/:id | New | detail with passengers, payment, refund, messages |
| Page | View | Opens page #/bookings/:id | GET /admin/bookings/:id | New | detail with passengers, payment, refund, messages |
| Page | Edit | Edit ABRX7058A: PNR*; Customer*; Route*; Travel*; Seats*; Amount (Rs)*; Paid by [Wallet / Upi / Card / Netbanking]; Status [Confirmed / Completed / Cancelled] | No server call | UI | opens the edit form, filled from GET /admin/bookings/:id |
| Page > dialog | Save changes |  | PATCH /admin/bookings/:id | New | only notes and contact fields are editable; amounts and seats are refused |
| Detail page #/bookings/:id | Cancel booking | Cancel booking ABRX7058A: Refund percent (admin override); Reason* | No server call | UI | opens cancel form (refund percent override, reason, proof) |
| Detail page #/bookings/:id > dialog | Cancel and refund |  | POST /admin/bookings/:id/cancel | New | frees the seats, starts the refund, messages the customer; audit |
| Detail page #/bookings/:id | Resend ticket |  | POST /admin/bookings/:id/resend-ticket | New | WhatsApp and email again |
| Detail page #/bookings/:id | Add note | Add internal note: Note (only staff see it)* | No server call | UI | opens note form |
| Detail page #/bookings/:id > dialog | Save |  | POST /admin/bookings/:id/notes | New | staff-only note |

### D.18 Payments (`payments`)

| Item | Value |
|---|---|
| Menu group | Sales |
| Feature / phase | Payments / Phase 3 |
| API base | `/admin/payments` |
| Files | `payments_admin_manage_screen.dart`, `payments_admin_manage.ts`, `payments_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: Edit |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Successful \| Failed \| Pending \| ollected |
| Tabs | All payments \| Failed and stuck \| Reconciliation |
| Filters | Search \| Status [All / Success / Failed / Pending / Refunded] \| Mode [All / Upi / Card / Netbanking / Wallet] |
| Table columns | Payment \| PNR \| Customer \| Amount \| Mode \| Status \| Time ▼ \| Actions |
| Tab "All payments" | cards: Successful, Failed, Pending, ollected. filters: Search, Status [All / Success / Failed / Pending / Refunded], Mode [All / Upi / Card / Netbanking / Wallet]. columns: Payment, PNR, Customer, Amount, Mode, Status, Time ▼, Actions |
| Tab "Failed and stuck" | cards: Successful, Failed, Pending, ollected. filters: Search, Status [All / Failed / Pending]. columns: Payment, PNR, Customer, Amount, Mode, Status, Time, Actions |
| Tab "Reconciliation" | cards: Successful, Failed, Pending, ollected. filters: Search, Status [All / Open / Done]. columns: Case, Payment, PNR, Problem, Amount, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/payments/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Payment PAY-9652 (BookingBK-8153PNRABRK5152ACustomerRahul VermaOperatorKaveri ExpressAmount₹2,044M) | GET /admin/payments/:id | New | detail with gateway ids |
| Page | View | Payment PAY-9652 (BookingBK-8153PNRABRK5152ACustomerRahul VermaOperatorKaveri ExpressAmount₹2,044M) | GET /admin/payments/:id | New | detail with gateway ids |
| Tab: All payments | Export CSV |  | GET /admin/payments/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: All payments | Table |  | No server call | UI | table or list view of the same data |
| Tab: All payments | List |  | No server call | UI | table or list view of the same data |
| Tab: All payments | Row (open the record) | Payment PAY-9652 (BookingBK-8153PNRABRK5152ACustomerRahul VermaOperatorKaveri ExpressAmount₹2,044M) | GET /admin/payments/:id | New | detail with gateway ids |
| Tab: All payments | View | Payment PAY-9652 (BookingBK-8153PNRABRK5152ACustomerRahul VermaOperatorKaveri ExpressAmount₹2,044M) | GET /admin/payments/:id | New | detail with gateway ids |
| Tab: Failed and stuck | Export CSV |  | GET /admin/payments/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Failed and stuck | Table |  | No server call | UI | table or list view of the same data |
| Tab: Failed and stuck | List |  | No server call | UI | table or list view of the same data |
| Tab: Failed and stuck | Row (open the record) | Payment PAY-9004 (BookingBK-7004PNRABRT9471ECustomerNeha BhatOperatorTungabhadra ExpressAmount₹2,7) | GET /admin/payments/:id | New | detail with gateway ids |
| Tab: Failed and stuck | View | Payment PAY-9004 (BookingBK-7004PNRABRT9471ECustomerNeha BhatOperatorTungabhadra ExpressAmount₹2,7) | GET /admin/payments/:id | New | detail with gateway ids |
| Tab: Reconciliation | Export CSV |  | GET /admin/payments/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Reconciliation | Table |  | No server call | UI | table or list view of the same data |
| Tab: Reconciliation | List |  | No server call | UI | table or list view of the same data |
| Tab: Reconciliation | Mark reconciled |  | POST /admin/payments/reconciliation/:id/resolve | New | marks reconciled; audit |
| Tab: Reconciliation | Check with gateway |  | POST /admin/payments/:id/verify | New | asks Razorpay for the real status and updates |
| Tab: Reconciliation | View | ABRX7058A (CaseRC-100PaymentPAY-9001PNRABRX7058AProblemAmount differs by Rs 49Amount₹1,317.) | GET /admin/payments/:id | New | read one record for the detail window |
| Tab: Reconciliation > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/payments/:id |
| Tab: Reconciliation > dialog | Delete |  | DELETE /admin/payments/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/payments/:id/restore |

### D.19 Refunds (`refunds`)

| Item | Value |
|---|---|
| Menu group | Sales |
| Feature / phase | Cancellation and refunds / Phase 4 |
| API base | `/admin/refunds` |
| Files | `refunds_admin_manage_screen.dart`, `refunds_admin_manage.ts`, `refunds_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: Edit |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Waiting for approval \| Processing \| ompleted \| Failed |
| Filters | Search \| Status [All / Initiated / Processing / Completed / Failed] \| Paid by [All / Operator / Platform] |
| Table columns | Refund \| Customer \| Amount \| Reason \| Proof \| Paid by \| Status \| Started ▼ \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/refunds/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | ABRX7013B (RefundRF-4001BookingidBK-7011PnrABRX7013BCustomerAnjali DasOperatorVindhya Trave) | GET /admin/refunds/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/refunds/:id |
| Page | Mark paid |  | POST /admin/refunds/:id/mark-paid | New | for manual refunds; reference required; messages the customer |

### D.20 Settlements (`settlements`)

| Item | Value |
|---|---|
| Menu group | Sales |
| Feature / phase | Settlements and earnings / Phase 6 |
| API base | `/admin/settlements` |
| Files | `settlements_admin_manage_screen.dart`, `settlements_admin_manage.ts`, `settlements_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: Edit |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Still to pay \| Paid this cycle \| Waiting for approval \| On hold |
| Filters | Search \| Status [All / Draft / Approved / Paid / On hold] \| Operator [All / Kaveri express / Godavari lines / Deccan voyager / Sahyadri coaches / Nilgiri travels / Charminar tours / Tungabhadra express / Konkan rider / Vindhya travels] \| Mode [All / Automatic / Manual] |
| Table columns | Settlement \| Operator \| Gross \| Commission \| Refunds \| Net payable \| Mode \| Status \| Actions |
| Detail page #/settlements/:id | columns: PNR, Route, Fare, Commission, Operator gets, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Generate settlements | Generate settlements: Cycle [Last 7 days / Last 14 days / Custom range]; Operator [All operators / Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels ...] | No server call | UI | opens generate form |
| Page > dialog | Generate |  | POST /admin/settlements/generate | New | cycle and operator; gross minus commission minus refunds plus adjustments |
| Page | Payout file |  | GET /admin/settlements/payout-file?cycle= | New | bank file for manual mode |
| Page | GST statement |  | GET /admin/settlements/gst-statement?cycle= | New | file |
| Page | Export CSV |  | GET /admin/settlements/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/settlements/:id | GET /admin/settlements/:id | New | with booking lines |
| Page | View | Opens page #/settlements/:id | GET /admin/settlements/:id | New | with booking lines |
| Page | Edit | Edit ST-6001: Operator*; Gross (Rs)*; Commission (Rs)*; Refunds (Rs)*; Net payable (Rs)*; Mode [Auto / Manual]; Status [Draft / Paid / Approved / On hold] | No server call | UI | opens the edit form, filled from GET /admin/settlements/:id |
| Page > dialog | Save changes |  | No server call | UI | not allowed to edit totals; use adjustments |
| Detail page #/settlements/:id | Release hold |  | POST /admin/settlements/:id/release-hold | New | audit |
| Detail page #/settlements/:id | Download statement |  | GET /admin/settlements/:id/statement.pdf | New |  |
| Detail page #/settlements/:id | Add adjustment | Add adjustment: Amount (Rs, negative to deduct)*; Reason* | No server call | UI | opens adjustment form |
| Detail page #/settlements/:id > dialog | Save |  | POST /admin/settlements/:id/adjustments | New | signed amount and reason; audit |
| Detail page #/settlements/:id | Export CSV |  | GET /admin/settlements/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/settlements/:id | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/settlements/:id | List |  | No server call | UI | table or list view of the same data |
| Detail page #/settlements/:id | View | ABRK1563A (IdBK-7075PNRABRK1563ACustomeridCU8CustomerKavya MenonPhone+91 9192297973TripidTR) | GET /admin/settlements/:id | New | read one record for the detail window |
| Detail page #/settlements/:id > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/settlements/:id |

### D.21 Customers (`customers`)

| Item | Value |
|---|---|
| Menu group | Customers |
| Feature / phase | Customers and profile / Phase 4 |
| API base | `/admin/customers` |
| Files | `customers_admin_manage_screen.dart`, `customers_admin_manage.ts`, `customers_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Name, phone, email \| Status [All / Active / Suspended / Deactivated] \| Sign-in method [All / Google / Whatsapp otp / Apple / Password] |
| Table columns | Customer \| Phone \| Signs in with \| Status \| Bookings \| Spent \| Joined \| Actions |
| Detail page #/customers/:id | columns: PNR, Route, Travel, Amount, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/customers/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/customers/:id | GET /admin/customers/:id | New | with bookings, tickets, SOS, devices |
| Page | View | Opens page #/customers/:id | GET /admin/customers/:id | New | with bookings, tickets, SOS, devices |
| Page | Edit | Edit Aarav Sharma: Customer*; Phone*; Signs in with*; Status [Active / Suspended / Deactivated]; Bookings*; Spent (Rs)*; Joined* | No server call | UI | opens the edit form, filled from GET /admin/customers/:id |
| Page > dialog | Save changes |  | PATCH /admin/customers/:id | New | save changes; audit before and after |
| Page | Delete | Delete Aarav Sharma? (This removes it from every list. You can undo for a few seconds.) | DELETE /admin/customers/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/customers/:id/restore |
| Page > dialog | Delete |  | DELETE /admin/customers/:id | New | confirm of a delete or revoke; audit |
| Detail page #/customers/:id | Block account | Block account: Reason* | No server call | UI | opens block form (reason, proof) |
| Detail page #/customers/:id > dialog | Block |  | POST /admin/customers/:id/block | New | revokes sessions; audit |
| Detail page #/customers/:id | Sign out all devices |  | POST /admin/customers/:id/sessions/revoke | New | sign out of all devices |
| Detail page #/customers/:id | Export CSV |  | GET /admin/customers/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/customers/:id | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/customers/:id | List |  | No server call | UI | table or list view of the same data |
| Detail page #/customers/:id | View | Opens page #/bookings/:id | GET /admin/bookings/:id | New | detail with passengers, payment, refund, messages |
| Detail page #/customers/:id | Edit | Edit ABRX7158B: PNR*; Route*; Travel*; Amount (Rs)*; Status [Confirmed / Completed / Cancelled] | No server call | UI | opens the edit form, filled from GET /admin/customers/:id |
| Detail page #/customers/:id > dialog | Save changes |  | PATCH /admin/customers/:id | New | save changes; audit before and after |

### D.22 Support tickets (`tickets`)

| Item | Value |
|---|---|
| Menu group | Customers |
| Feature / phase | Support tickets / Phase 4 |
| API base | `/admin/tickets` |
| Files | `support_admin_manage_screen.dart`, `support_admin_manage.ts`, `support_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Open \| In progress \| Past time limit \| Resolved |
| Filters | Search \| Status [All / Open / In progress / Resolved / Closed] \| Category [All / Booking / Payment / Refund / Safety / App] \| Priority [All / Urgent / High / Medium / Low] \| Assigned [All / Unassigned / Divya / Kiran] |
| Table columns | Ticket \| Customer \| Category \| Priority \| Status \| Assigned to \| Time limit \| Actions |
| Detail page #/tickets/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/tickets/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/tickets/:id | GET /admin/tickets/:id | New | thread |
| Page | View | Opens page #/tickets/:id | GET /admin/tickets/:id | New | thread |
| Page | Edit | Edit Refund not received: Customer*; Category [Refund / Booking / Payment / App / Safety]; Priority [High / Medium / Urgent / Low]; Status [Resolved / In progress / Open / Closed]; Assigned to*; Time limit* | No server call | UI | opens the edit form, filled from GET /admin/tickets/:id |
| Page > dialog | Save changes |  | PATCH /admin/tickets/:id | New | save changes; audit before and after |
| Page | Delete | Delete Refund not received? (This removes it from every list. You can undo for a few seconds.) | DELETE /admin/tickets/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/tickets/:id/restore |
| Page > dialog | Delete |  | DELETE /admin/tickets/:id | New | confirm of a delete or revoke; audit |
| Detail page #/tickets/:id | Assign | Assign ticket: Assign to [Nobody / Divya (Support) / Kiran (Support)] | No server call | UI | opens assign form |
| Detail page #/tickets/:id > dialog | Assign |  | POST /admin/tickets/:id/assign | New | notifies the assignee |
| Detail page #/tickets/:id | Mark resolved |  | POST /admin/tickets/:id/resolve | New | audit |
| Detail page #/tickets/:id | Send reply |  | POST /admin/tickets/:id/replies | New | reply with proof files; notifies the customer |

### D.23 Help content and contact (`content`)

| Item | Value |
|---|---|
| Menu group | Customers |
| Feature / phase | Information pages and FAQs / Phase 4 |
| API base | `/admin/content` |
| Files | `content_admin_manage_screen.dart`, `content_admin_manage.ts`, `content_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | FAQs \| Policy pages \| Contact and hours |
| Filters | Search \| Status [All / Published / Draft] \| Category [All / Bookings / Refunds / Payments / Safety / Trips / Offers] |
| Table columns | Question \| Category \| Status \| Views \| Updated \| Actions |
| Tab "FAQs" | filters: Search, Status [All / Published / Draft], Category [All / Bookings / Refunds / Payments / Safety / Trips / Offers]. columns: Question, Category, Status, Views, Updated, Actions |
| Tab "Policy pages" | columns: Page, Status, Version, Updated, Actions |
| Tab "Contact and hours" | filters: Support phone, WhatsApp number, Support email, Working hours, Emergency number |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/content/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add FAQ | Add FAQ: Question*; Answer*; Category [Bookings / Refunds / Payments / Safety / Trips / Offers]; Status [DRAFT / PUBLISHED] | No server call | UI | opens FAQ form |
| Page > dialog | Save |  | POST /admin/faqs or PATCH /admin/faqs/:id | New |  |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Edit | Edit FAQ: Question*; Answer*; Category [Bookings / Refunds / Payments / Safety / Trips / Offers]; Status [DRAFT / PUBLISHED] | No server call | UI | opens FAQ form |
| Page | Unpublish |  | POST /admin/faqs/:id/publish or /unpublish | New |  |
| Page | View | FAQ1 (IdFAQ1QuestionHow do I cancel a booking?CategoryBookingsStatusDraftAThis is the ) | GET /admin/content/:id | New | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /admin/content/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/content/:id/restore |
| Page | Publish |  | POST /admin/faqs/:id/publish or /unpublish | New |  |
| Tab: FAQs | Export CSV |  | GET /admin/content/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: FAQs | Add FAQ | Add FAQ: Question*; Answer*; Category [Bookings / Refunds / Payments / Safety / Trips / Offers]; Status [DRAFT / PUBLISHED] | No server call | UI | opens FAQ form |
| Tab: FAQs > dialog | Save |  | POST /admin/faqs or PATCH /admin/faqs/:id | New |  |
| Tab: FAQs | Table |  | No server call | UI | table or list view of the same data |
| Tab: FAQs | List |  | No server call | UI | table or list view of the same data |
| Tab: FAQs | Edit | Edit FAQ: Question*; Answer*; Category [Bookings / Refunds / Payments / Safety / Trips / Offers]; Status [DRAFT / PUBLISHED] | No server call | UI | opens FAQ form |
| Tab: FAQs | Unpublish |  | POST /admin/faqs/:id/publish or /unpublish | New |  |
| Tab: FAQs | View | FAQ1 (IdFAQ1QuestionHow do I cancel a booking?CategoryBookingsStatusDraftAThis is the ) | GET /admin/content/:id | New | read one record for the detail window |
| Tab: FAQs > dialog | Delete |  | DELETE /admin/content/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/content/:id/restore |
| Tab: FAQs | Publish |  | POST /admin/faqs/:id/publish or /unpublish | New |  |
| Tab: Policy pages | Export CSV |  | GET /admin/content/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Policy pages | Table |  | No server call | UI | table or list view of the same data |
| Tab: Policy pages | List |  | No server call | UI | table or list view of the same data |
| Tab: Policy pages | Edit | Edit Terms and Conditions: Title; Content | No server call | UI | opens page editor |
| Tab: Policy pages > dialog | Save draft |  | PUT /admin/pages/:slug | New | draft or publish; creates a new version |
| Tab: Policy pages > dialog | Publish |  | PUT /admin/pages/:slug | New | draft or publish; creates a new version |
| Tab: Policy pages | Versions | Versions of Terms and Conditions (Version 412 Oct 2026Version 312 Sept 2026Version 213 Aug 2026Version 114 Jul 202) | GET /admin/pages/:slug/versions | New |  |
| Tab: Policy pages | View | Terms and Conditions (IdPG1PageTerms and ConditionsStatusPublishedVersion4Updated12 Oct 2026, 05:39 pm) | GET /admin/content/:id | New | read one record for the detail window |
| Tab: Policy pages > dialog | Delete |  | DELETE /admin/content/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/content/:id/restore |
| Tab: Contact and hours | Save contact details |  | PUT /admin/contact-info | New | phone, WhatsApp, email, hours, emergency number |

### D.24 Messages sent (`messages`)

| Item | Value |
|---|---|
| Menu group | Customers |
| Feature / phase | WhatsApp and email messages / Phase 0 |
| API base | `/admin/messages` |
| Files | `messages_admin_manage_screen.dart`, `messages_admin_manage.ts`, `messages_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Sent today \| WhatsApp messages \| Emails \| Failed |
| Filters | Customer, phone, email, PNR \| Channel [All / WhatsApp / Email] \| Type [All / Booking confirmed / Booking cancelled] |
| Table columns | When ▼ \| Channel \| To \| Type \| Subject \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/messages/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Booking confirmed: ABRK5151A (ChannelEmailToAnanya Reddy - ananya.reddy@example.comTypeBooking confirmedSent12) | GET /admin/messages/:id | New |  |
| Page > dialog | Send again |  | POST /admin/messages/:id/resend | New | queues again |
| Page | View | Booking confirmed: ABRK5151A (ChannelEmailToAnanya Reddy - ananya.reddy@example.comTypeBooking confirmedSent12) | GET /admin/messages/:id | New |  |
| Page | Edit | Edit Ananya Reddy: When*; Channel [Email / Whatsapp]; To*; Type*; Subject*; Status* | No server call | UI | opens the edit form, filled from GET /admin/messages/:id |
| Page > dialog | Save changes |  | PATCH /admin/messages/:id | New | save changes; audit before and after |
| Page | Delete | Delete Ananya Reddy? (This removes it from every list. You can undo for a few seconds.) | DELETE /admin/messages/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/messages/:id/restore |
| Page > dialog | Delete |  | DELETE /admin/messages/:id | New | confirm of a delete or revoke; audit |

### D.25 Banners (`banners`)

| Item | Value |
|---|---|
| Menu group | Marketing |
| Feature / phase | Banners / Phase 1 |
| API base | `/admin/banners` |
| Files | `banners_admin_manage_screen.dart`, `banners_admin_manage.ts`, `banners_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | All banners \| Analytics |
| Filters | Search \| Status [All / Draft / Scheduled / Published / Archived] |
| Table columns | Banner \| Status \| Runs \| Shown to \| Opens \| Order ▼ \| Actions |
| Tab "Analytics" | columns: Banner, Impressions, Clicks, CTR, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/banners/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | New banner | New banner: Title*; Subtitle; Colour style [Navy to blue / Blue to sky / Green to navy]; Opens [An offer / Route search / An operator / A web link]; Offer code [None / ABRA100 / WEEKEND15 / UPIFEST / WOMEN10 / KAVERI50 ...]; Shown to [Everyone / New users / Signed-in users]; Starts; Ends; Order (higher shows first) | No server call | UI | opens banner form |
| Page > dialog | Save draft |  | POST /admin/banners or PUT /admin/banners/:id | Exists |  |
| Page > dialog | Publish |  | POST /admin/banners or PUT /admin/banners/:id | Exists |  |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | (icon) |  | PATCH /admin/banners/order | New | move up or down |
| Page | Edit | Edit banner: Title*; Subtitle; Colour style [Navy to blue / Blue to sky / Green to navy]; Opens [An offer / Route search / An operator / A web link]; Offer code [None / ABRA100 / WEEKEND15 / UPIFEST / WOMEN10 / KAVERI50 ...]; Shown to [Everyone / New users / Signed-in users]; Starts; Ends; Order (higher shows first) | No server call | UI | opens banner form |
| Page | Unpublish |  | POST /admin/banners/:id/active | Exists | (unpublish) |
| Page | Duplicate |  | POST /admin/banners/:id/duplicate | New | new |
| Page | Archive |  | POST /admin/banners/:id/archive | New | new |
| Page | View | Festive special (copy) (IdBN-90001BannerFestive special (copy)SubFlat 15% off on selected routesCodeWEEK) | GET /admin/banners/:id | Exists | read one record for the detail window |
| Page > dialog | Delete |  | DELETE /admin/banners/:id | Exists | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/banners/:id/restore |
| Page | Publish |  | POST /admin/banners/:id/active | Exists | (publish) |
| Tab: Analytics | Export CSV |  | GET /admin/banners/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Analytics | Table |  | No server call | UI | table or list view of the same data |
| Tab: Analytics | List |  | No server call | UI | table or list view of the same data |
| Tab: Analytics | View | Festive special (IdBN1BannerFestive specialSubFlat 15% off on selected routesCodeWEEKEND15StatusP) | GET /admin/banners/:id | Exists | read one record for the detail window |
| Tab: Analytics > dialog | Edit |  | No server call | UI | opens banner form |
| Tab: Analytics > dialog | Delete |  | DELETE /admin/banners/:id | Exists | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/banners/:id/restore |

### D.26 Offers and coupons (`offers`)

| Item | Value |
|---|---|
| Menu group | Marketing |
| Feature / phase | Offers and coupons / Phase 3 |
| API base | `/admin/offers` |
| Files | `offers_admin_manage_screen.dart`, `offers_admin_manage.ts`, `offers_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | All offers \| Test a coupon \| Usage report |
| Filters | Search \| Status [All / Active / Paused / Expired / Draft] \| Funded by [All / Platform / Operator] |
| Table columns | Code \| Discount \| Applies to \| Valid till \| Used \| Funded by \| Status \| Actions |
| Tab "All offers" | filters: Search, Status [All / Active / Paused / Expired / Draft], Funded by [All / Platform / Operator]. columns: Code, Discount, Applies to, Valid till, Used, Funded by, Status, Actions |
| Tab "Test a coupon" | filters: Code [ABRA100 / WEEKEND15 / UPIFEST / WOMEN10 / KAVERI50 / DIWALI20 / HYDBLR / SLEEP10], Booking amount (Rs), Customer [New customer / Existing customer], Day [Mon / Tue / Wed / Thu / Fri / Sat / Sun] |
| Tab "Usage report" | columns: Code, Times used, Discount given, Funded by, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/offers/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | New offer | New offer: Code*; Description (shown in the app)*; Type [Percentage / Flat amount]; Value (percent, or rupees); Maximum discount (Rs); Minimum booking (Rs); Valid from; Valid till; Total usage limit (0 = no limit); Uses per customer; Funded by [Abra Travels / The operator]; Who can use it [Everyone / New customers only / Women travellers]; Limit to (optional) [All / Route: Hyderabad to Bengaluru / Route: Bengaluru to Hyderabad / Route: Hyderabad to Chennai / Route: Chennai to Coimbatore / Route: Vijayawada to Visakhapatnam ...]; Terms (one per line) | No server call | UI | opens offer form |
| Page > dialog | Save offer |  | POST /admin/offers or PATCH /admin/offers/:id | New | audit |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | ABRA100 (DescriptionRs 100 off your first bookingDiscount₹100Minimum booking₹0Valid22 Sep) | GET /admin/offers/:id | New | detail with usage |
| Page | Edit | Edit ABRA100: Code*; Description (shown in the app)*; Type [Percentage / Flat amount]; Value (percent, or rupees); Maximum discount (Rs); Minimum booking (Rs); Valid from; Valid till; Total usage limit (0 = no limit); Uses per customer; Funded by [Abra Travels / The operator]; Who can use it [Everyone / New customers only / Women travellers]; Limit to (optional) [All / Route: Hyderabad to Bengaluru / Route: Bengaluru to Hyderabad / Route: Hyderabad to Chennai / Route: Chennai to Coimbatore / Route: Vijayawada to Visakhapatnam ...]; Terms (one per line) | No server call | UI | opens offer form |
| Page | Pause |  | PATCH /admin/offers/:id/active | New | pause or resume |
| Page | View | ABRA100 (DescriptionRs 100 off your first bookingDiscount₹100Minimum booking₹0Valid22 Sep) | GET /admin/offers/:id | New | detail with usage |
| Page | Delete | Delete ABRA100? (This removes it from every list. You can undo for a few seconds.) | DELETE /admin/offers/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/offers/:id/restore |
| Page > dialog | Delete |  | DELETE /admin/offers/:id | New | confirm of a delete or revoke; audit |
| Page | Resume |  | PATCH /admin/offers/:id/active | New | pause or resume |
| Tab: All offers | Export CSV |  | GET /admin/offers/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: All offers | New offer | New offer: Code*; Description (shown in the app)*; Type [Percentage / Flat amount]; Value (percent, or rupees); Maximum discount (Rs); Minimum booking (Rs); Valid from; Valid till; Total usage limit (0 = no limit); Uses per customer; Funded by [Abra Travels / The operator]; Who can use it [Everyone / New customers only / Women travellers]; Limit to (optional) [All / Route: Hyderabad to Bengaluru / Route: Bengaluru to Hyderabad / Route: Hyderabad to Chennai / Route: Chennai to Coimbatore / Route: Vijayawada to Visakhapatnam ...]; Terms (one per line) | No server call | UI | opens offer form |
| Tab: All offers > dialog | Save offer |  | POST /admin/offers or PATCH /admin/offers/:id | New | audit |
| Tab: All offers | Table |  | No server call | UI | table or list view of the same data |
| Tab: All offers | List |  | No server call | UI | table or list view of the same data |
| Tab: All offers | Row (open the record) | ABRA100 (DescriptionRs 100 off your first bookingDiscount₹100Minimum booking₹0Valid22 Sep) | GET /admin/offers/:id | New | detail with usage |
| Tab: All offers | Edit | Edit ABRA100: Code*; Description (shown in the app)*; Type [Percentage / Flat amount]; Value (percent, or rupees); Maximum discount (Rs); Minimum booking (Rs); Valid from; Valid till; Total usage limit (0 = no limit); Uses per customer; Funded by [Abra Travels / The operator]; Who can use it [Everyone / New customers only / Women travellers]; Limit to (optional) [All / Route: Hyderabad to Bengaluru / Route: Bengaluru to Hyderabad / Route: Hyderabad to Chennai / Route: Chennai to Coimbatore / Route: Vijayawada to Visakhapatnam ...]; Terms (one per line) | No server call | UI | opens offer form |
| Tab: All offers | Pause |  | PATCH /admin/offers/:id/active | New | pause or resume |
| Tab: All offers | View | ABRA100 (DescriptionRs 100 off your first bookingDiscount₹100Minimum booking₹0Valid22 Sep) | GET /admin/offers/:id | New | detail with usage |
| Tab: All offers | Delete | Delete ABRA100? (This removes it from every list. You can undo for a few seconds.) | DELETE /admin/offers/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/offers/:id/restore |
| Tab: All offers > dialog | Delete |  | DELETE /admin/offers/:id | New | confirm of a delete or revoke; audit |
| Tab: All offers | Resume |  | PATCH /admin/offers/:id/active | New | pause or resume |
| Tab: Test a coupon | Check |  | POST /admin/offers/test | New | checks a coupon for a sample trip and user |
| Tab: Usage report | Export CSV |  | GET /admin/offers/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Usage report | Table |  | No server call | UI | table or list view of the same data |
| Tab: Usage report | List |  | No server call | UI | table or list view of the same data |
| Tab: Usage report | View | ABRA100 (IdOF1CodeABRA100DescRs 100 off your first bookingTypeFlatValue10000Maxdisc₹300Mi) | GET /admin/offers/:id | New | read one record for the detail window |
| Tab: Usage report > dialog | Edit |  | No server call | UI | opens offer form |
| Tab: Usage report > dialog | Delete |  | DELETE /admin/offers/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/offers/:id/restore |

### D.27 Announcements (`announce`)

| Item | Value |
|---|---|
| Menu group | Marketing |
| Feature / phase | Announcements and popular routes / Phase 7 |
| API base | `/admin/announcements` |
| Files | `announce_admin_manage_screen.dart`, `announce_admin_manage.ts`, `announce_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Sent / Scheduled / Draft] |
| Table columns | Message \| Sent to \| Channel \| Status \| Reached \| When \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | New announcement | New announcement: Title*; Message*; Send to [All customers / Customers on a route / Customers of one trip / New users / Women travellers]; Channel [Push / Push, WhatsApp / WhatsApp]; When [Send now / Schedule]; Date and time (if scheduled) | No server call | UI | opens announcement form |
| Page > dialog | Save draft |  | POST /admin/announcements | New | draft, schedule or send now; send creates notifications and messages for the audience |
| Page > dialog | Send |  | POST /admin/announcements | New | draft, schedule or send now; send creates notifications and messages for the audience |
| Page | Export CSV |  | GET /admin/announcements/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | Heavy rain advisory on Hyderabad to Visakhapatnam (IdAN1MessageHeavy rain advisory on Hyderabad to VisakhapatnamBodyTrips may run l) | GET /admin/announcements/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/announcements/:id |
| Page > dialog | Delete |  | DELETE /admin/announcements/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/announcements/:id/restore |

### D.28 Popular routes (`popular`)

| Item | Value |
|---|---|
| Menu group | Marketing |
| Feature / phase | Announcements and popular routes / Phase 7 |
| API base | `/admin/popular-routes` |
| Files | `announce_admin_manage_screen.dart`, `announce_admin_manage.ts`, `announce_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Table columns | Order ▲ \| Route \| Searches (30 d) \| Bookings (30 d) \| Shown \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Add route | Add popular route: Route [Mumbai to Pune / Hyderabad to Tirupati / Bengaluru to Kochi / Tirupati to Chennai] | No server call | UI | opens add form |
| Page > dialog | Add |  | POST /admin/popular-routes | New |  |
| Page | Export CSV |  | GET /admin/popular-routes/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | (icon) |  | PATCH /admin/popular-routes/order | New |  |
| Page | (icon) |  | PATCH /admin/popular-routes/:id/active | New |  |
| Page | View | Hyderabad to Bengaluru (IdPO1RouteHyderabad to BengaluruOrder1ShownNoSearches (30 d)2247Bookings (30 d)4) | GET /admin/popular-routes/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/popular-routes/:id |
| Page > dialog | Delete |  | DELETE /admin/popular-routes/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/popular-routes/:id/restore |

### D.29 SOS board (`sos`)

| Item | Value |
|---|---|
| Menu group | Safety |
| Feature / phase | SOS and women safety / Phase 5 |
| API base | `/admin/sos` |
| Files | `sos_admin_manage_screen.dart`, `sos_admin_manage.ts`, `sos_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Left: a card for each SOS alert (customer name, status, "Raised by customer or driver", route, time). Right: the selected alert with map position, customer, driver, operator, bus, contacts alerted, the log of what happened, and the action buttons |
| Detail page #/sos/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Row (open the record) | Opens page #/sos/:id | GET /admin/sos/:id | New | board card and detail; new alerts arrive by Socket.IO |
| Detail page #/sos/:id | Call |  | No server call | UI | dials the number |
| Detail page #/sos/:id | Customer |  | No server call | UI | dials the number |
| Detail page #/sos/:id | Driver |  | No server call | UI | dials the number |
| Detail page #/sos/:id | Operator |  | No server call | UI | dials the number |
| Detail page #/sos/:id | Police |  | No server call | UI | dials the number |
| Detail page #/sos/:id | Acknowledge |  | POST /admin/sos/:id/acknowledge | New | tells the customer or driver and the operator |
| Detail page #/sos/:id | Add note | Add note: Note* | No server call | UI | opens note form |
| Detail page #/sos/:id > dialog | Save |  | POST /admin/sos/:id/notes | New |  |
| Detail page #/sos/:id | Escalate |  | POST /admin/sos/:id/escalate | New | police and safety lead; audit |
| Detail page #/sos/:id | Resolve | Resolve SOS: How was it resolved?* | No server call | UI | opens resolve form (note and proof required) |
| Detail page #/sos/:id > dialog | Resolve |  | POST /admin/sos/:id/resolve | New | note, proof; notifies the customer or driver |
| Detail page #/sos/:id | False alarm | Mark as false alarm: What did the customer say?* | No server call | UI | opens false alarm form (proof) |
| Detail page #/sos/:id > dialog | Mark false alarm |  | POST /admin/sos/:id/false-alarm | New | what the customer said, proof |

### D.30 Incidents and sharing (`incidents`)

| Item | Value |
|---|---|
| Menu group | Safety |
| Feature / phase | Incidents / Phase 5 |
| API base | `/admin/incidents` |
| Files | `incidents_admin_manage_screen.dart`, `incidents_admin_manage.ts`, `incidents_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Incidents \| Trip sharing audit |
| Filters | Search \| Status [All / Open / In progress / Closed] \| Severity [All / High / Medium / Low] |
| Table columns | Incident \| Reported by \| About \| Severity \| Status \| Trip \| Reported \| Actions |
| Tab "Incidents" | filters: Search, Status [All / Open / In progress / Closed], Severity [All / High / Medium / Low]. columns: Incident, Reported by, About, Severity, Status, Trip, Reported, Actions |
| Tab "Trip sharing audit" | filters: Search, Status [All / Active / Expired]. columns: Customer, Trip, Link, Times opened, Shared, Expires, Status, Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/incidents/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Log incident | Log incident: What happened*; Reported by [Aarav Sharma / Priya Nair / Rohan Mehta / Ananya Reddy / Vikram Singh / Divya Iyer ...]; About [Driver / Conductor / Co-passenger / Operator]; Severity [HIGH / MEDIUM / LOW]; Trip [TRP-3001 / TRP-3002 / TRP-3003 / TRP-3004 / TRP-3005 / TRP-3006 ...] | No server call | UI | opens incident form |
| Page > dialog | Log |  | POST /admin/incidents | New | with proof |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | INC-3001 - Rash driving reported: Change status [OPEN / IN_PROGRESS / CLOSED]; Add note | GET /admin/incidents/:id | New |  |
| Page > dialog | Save |  | PATCH /admin/incidents/:id | New | status and note; audit |
| Page | View | INC-3001 - Rash driving reported: Change status [OPEN / IN_PROGRESS / CLOSED]; Add note | GET /admin/incidents/:id | New |  |
| Page | Edit | Edit Rash driving reported: Reported by*; About*; Severity [Medium / High / Low]; Status [Closed / Open / In progress]; Trip*; Reported* | No server call | UI | opens the edit form, filled from GET /admin/incidents/:id |
| Page > dialog | Save changes |  | PATCH /admin/incidents/:id | New | save changes; audit before and after |
| Tab: Incidents | Export CSV |  | GET /admin/incidents/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Incidents | Log incident | Log incident: What happened*; Reported by [Aarav Sharma / Priya Nair / Rohan Mehta / Ananya Reddy / Vikram Singh / Divya Iyer ...]; About [Driver / Conductor / Co-passenger / Operator]; Severity [HIGH / MEDIUM / LOW]; Trip [TRP-3001 / TRP-3002 / TRP-3003 / TRP-3004 / TRP-3005 / TRP-3006 ...] | No server call | UI | opens incident form |
| Tab: Incidents > dialog | Log |  | POST /admin/incidents | New | with proof |
| Tab: Incidents | Table |  | No server call | UI | table or list view of the same data |
| Tab: Incidents | List |  | No server call | UI | table or list view of the same data |
| Tab: Incidents | Row (open the record) | INC-3001 - Rash driving reported: Change status [OPEN / IN_PROGRESS / CLOSED]; Add note | GET /admin/incidents/:id | New |  |
| Tab: Incidents > dialog | Save |  | PATCH /admin/incidents/:id | New | status and note; audit |
| Tab: Incidents | View | INC-3001 - Rash driving reported: Change status [OPEN / IN_PROGRESS / CLOSED]; Add note | GET /admin/incidents/:id | New |  |
| Tab: Incidents | Edit | Edit Rash driving reported: Reported by*; About*; Severity [Medium / High / Low]; Status [Closed / Open / In progress]; Trip*; Reported* | No server call | UI | opens the edit form, filled from GET /admin/incidents/:id |
| Tab: Incidents > dialog | Save changes |  | PATCH /admin/incidents/:id | New | save changes; audit before and after |
| Tab: Trip sharing audit | Export CSV |  | GET /admin/incidents/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Trip sharing audit | Table |  | No server call | UI | table or list view of the same data |
| Tab: Trip sharing audit | List |  | No server call | UI | table or list view of the same data |
| Tab: Trip sharing audit | Revoke link |  | DELETE /admin/trip-shares/:id | New | revokes a sharing link; audit |
| Tab: Trip sharing audit | View | SH1 (IdSH1CustomerAarav SharmaTripTRP-3004Linkabra.in/s/349787Times opened4Shared12 O) | GET /admin/incidents/:id | New | read one record for the detail window |
| Tab: Trip sharing audit > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/incidents/:id |
| Tab: Trip sharing audit > dialog | Delete |  | DELETE /admin/incidents/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /admin/incidents/:id/restore |

### D.31 Safety settings (`safety`)

| Item | Value |
|---|---|
| Menu group | Safety |
| Feature / phase | SOS and women safety / Phase 5 |
| API base | `/admin/safety` |
| Files | `sos_admin_manage_screen.dart`, `sos_admin_manage.ts`, `sos_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Safety settings \| Escalation timing (acknowledge minutes, escalate minutes, SOS hold seconds) \| Who is alerted (operator, SMS, WhatsApp switches) \| Safety team (people who receive alerts) \| Message sent to emergency contacts |
| Filters | Acknowledge within (minutes) \| Escalate to safety lead after (minutes) \| Police control room number |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Save |  | PUT /admin/safety/settings | New | acknowledge minutes, escalate minutes, police number, SOS hold seconds; audit |
| Page | (icon) |  | PUT /admin/safety/settings | New | SMS switch |
| Page | (icon) |  | PUT /admin/safety/settings | New | WhatsApp switch |
| Page | (icon) |  | PUT /admin/safety/settings | New | notify operator switch |
| Page | Add person | Add to safety team: Name and role* | No server call | UI | opens add form |
| Page > dialog | Add |  | POST /admin/safety/team | New | name and role |
| Page | Remove |  | DELETE /admin/safety/team/:id | New |  |

### D.32 Reports (`reports`)

| Item | Value |
|---|---|
| Menu group | Insights |
| Feature / phase | Dashboards and reports / Phase 7 |
| API base | `/admin/reports` |
| Files | `dashboard_admin_manage_screen.dart`, `dashboard_admin_manage.ts`, `dashboard_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | Reports (Sales, Operators, Routes) \| Gross sales by day chart \| rows that open their detail inline on the same page \| Export these rows \| Print |
| Tabs | Sales \| Operators \| Routes \| Cancellations \| Refunds \| Occupancy \| Commission |
| Filters | Search |
| Table columns | Day \| Bookings \| Gross sales \| Commission |
| Tab "Sales" | filters: Search. columns: PNR, Passenger, Route, Operator, Amount, Commission, Status. columns: Day, Bookings, Gross sales, Commission |
| Tab "Operators" | filters: Search. columns: Operator, Bookings, Sales, Cancelled, Rating |
| Tab "Routes" | filters: Search. columns: Route, Bookings, Sales, Occupancy |
| Tab "Cancellations" | filters: Search. columns: PNR, Route, Operator, Amount, Booked |
| Tab "Refunds" | filters: Search. columns: Refund, PNR, Amount, Paid by, Status, Actions |
| Tab "Occupancy" | filters: Search. columns: Trip, Route, Operator, Occupancy |
| Tab "Commission" | filters: Search. columns: Operator, Bookings, Commission earned |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Page | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Page | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Page | Print |  | No server call | UI | browser print of the report |
| Page | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Page | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Tab: Sales | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Sales | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Sales | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Sales | Print |  | No server call | UI | browser print of the report |
| Tab: Sales | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Sales | Export these rows |  | GET /admin/reports/:type/export | New | rows of the open detail |
| Tab: Sales | Close details |  | No server call | UI | closes the detail panel |
| Tab: Sales | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Sales | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Sales | Table |  | No server call | UI | table or list view of the same data |
| Tab: Sales | List |  | No server call | UI | table or list view of the same data |
| Tab: Operators | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Operators | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Operators | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Operators | Print |  | No server call | UI | browser print of the report |
| Tab: Operators | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Operators | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Operators | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Operators | Table |  | No server call | UI | table or list view of the same data |
| Tab: Operators | List |  | No server call | UI | table or list view of the same data |
| Tab: Routes | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Routes | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Routes | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Routes | Print |  | No server call | UI | browser print of the report |
| Tab: Routes | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Routes | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Routes | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Routes | Table |  | No server call | UI | table or list view of the same data |
| Tab: Routes | List |  | No server call | UI | table or list view of the same data |
| Tab: Cancellations | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Cancellations | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Cancellations | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Cancellations | Print |  | No server call | UI | browser print of the report |
| Tab: Cancellations | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Cancellations | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Cancellations | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Cancellations | Table |  | No server call | UI | table or list view of the same data |
| Tab: Cancellations | List |  | No server call | UI | table or list view of the same data |
| Tab: Refunds | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Refunds | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Refunds | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Refunds | Print |  | No server call | UI | browser print of the report |
| Tab: Refunds | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Refunds | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Refunds | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Refunds | Table |  | No server call | UI | table or list view of the same data |
| Tab: Refunds | List |  | No server call | UI | table or list view of the same data |
| Tab: Refunds | View | ABRX7013B (RefundRF-4001BookingidBK-7011PNRABRX7013BCustomerAnjali DasOperatorVindhya Trave) | GET /admin/reports/:id | New | read one record for the detail window |
| Tab: Refunds > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /admin/reports/:id |
| Tab: Occupancy | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Occupancy | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Occupancy | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Occupancy | Print |  | No server call | UI | browser print of the report |
| Tab: Occupancy | TRP-300193% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-300589% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-302289% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-300874% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-304270% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-302068% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-300264% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | TRP-300664% |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Occupancy | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Occupancy | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Occupancy | Table |  | No server call | UI | table or list view of the same data |
| Tab: Occupancy | List |  | No server call | UI | table or list view of the same data |
| Tab: Commission | 7 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Commission | 30 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Commission | 90 days |  | GET /admin/reports/:type?range= | New |  |
| Tab: Commission | Print |  | No server call | UI | browser print of the report |
| Tab: Commission | Row (open the record) |  | GET /admin/reports/:type/rows?key= | New | detail panel inline on the Reports page |
| Tab: Commission | Export CSV |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Commission | Excel (CSV) |  | GET /admin/reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Commission | Table |  | No server call | UI | table or list view of the same data |
| Tab: Commission | List |  | No server call | UI | table or list view of the same data |

### D.33 AI assistant (`ai`)

| Item | Value |
|---|---|
| Menu group | Insights |
| Feature / phase | AI assistant (Groq) / Phase 0 |
| API base | `/admin/settings/assistant` |
| Files | `assistant_admin_manage_screen.dart`, `assistant_admin_manage.ts`, `assistant_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit; Support: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | AI assistant settings \| Provider and model \| Safety rule (what the assistant may and may not do) \| What the assistant can do \| Actions done by the assistant (log) |
| Number cards (each opens the records behind it) | Questions today \| Actions done by AI \| Waiting for confirmation \| -Helpful answers |
| Filters | Provider \| Model [llama-3.3-70b-versatile / openai/gpt-oss-120b / llama-3.1-8b-instant] \| Messages per admin per day \| Saved on the server only \| Search |
| Table columns | Tool \| What it does \| Access needed \| Confirmation |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Test connection |  | POST /admin/settings/assistant/test | New | test connection |
| Page | Save |  | PUT /admin/settings/assistant | New | provider, model, key (encrypted); audit |
| Page | (icon) |  | No server call | UI | show or hide the API key field |
| Page | Export CSV |  | GET /admin/settings/assistant/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |

### D.34 Settings and integrations (`settings`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Integrations, feature flags and maintenance / Phase 0 |
| API base | `/admin/settings` |
| Files | `settings_admin_manage_screen.dart`, `settings_admin_manage.ts`, `settings_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: View; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Settings and integrations \| WhatsApp \| Email (SMTP) \| SMS \| Razorpay \| Maps \| Push (Firebase) \| Company \| Booking rules \| Security \| Message templates |
| Tabs | Integrations \| Company \| Booking rules \| Security \| Message templates |
| Tab "Company" | filters: Company name, Email, Phone, GSTIN, Address |
| Tab "Booking rules" | filters: Seat hold time (seconds), Most seats per booking, Stop sales before departure (minutes), Book up to (days ahead) |
| Tab "Security" | filters: Sign out after (minutes of no activity), Ask for a new password every (days) |
| Tab "Message templates" | columns: Message, Channels, Languages |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Set up | Set up whatsapp: Phone number id; Access token | No server call | UI | opens the integration form |
| Page > dialog | Save |  | PUT /settings/integrations/:key | Exists | email and WhatsApp Razorpay, Maps, SMS, Groq, push are new; secrets encrypted |
| Page | Test connection |  | POST /settings/integrations/:key/test-connection | Exists | for email and WhatsApp |
| Tab: Integrations | Set up | Set up whatsapp: Phone number id; Access token | No server call | UI | opens the integration form |
| Tab: Integrations > dialog | Save |  | PUT /settings/integrations/:key | Exists | email and WhatsApp Razorpay, Maps, SMS, Groq, push are new; secrets encrypted |
| Tab: Integrations | Test connection |  | POST /settings/integrations/:key/test-connection | Exists | for email and WhatsApp |
| Tab: Company | Save |  | PUT /admin/settings/company | New | audit |
| Tab: Booking rules | Save | Reason for change: Why are you changing this?* | No server call | UI | opens the reason form |
| Tab: Booking rules > dialog | Confirm |  | PUT /admin/settings/booking | New | hold minutes, seat limit and similar; a reason is required; audit |
| Tab: Security | (icon) |  | PUT /admin/settings/security/mfa | New | require MFA for roles |
| Tab: Security | Save |  | PUT /admin/settings/security | New | password and session rules; audit |
| Tab: Message templates | Table |  | No server call | UI | table or list view of the same data |
| Tab: Message templates | List |  | No server call | UI | table or list view of the same data |
| Tab: Message templates | Preview | Message preview (Booking confirmedHi Priya, your seat 12A on Hyderabad to Bengaluru is confirmed.) | GET /admin/message-templates/:id/preview | New |  |

### D.35 Staff and roles (`staff`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Staff, roles and access matrix / Phase 7 |
| API base | `/admin/staff` |
| Files | `staff_admin_manage_screen.dart`, `staff_admin_manage.ts`, `staff_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: None; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Staff \| Permission matrix \| Sessions |
| Filters | Search \| Role [All / Super Admin / Admin / Support / Accounts] \| Status [All / Active / Invited / Deactivated] |
| Table columns | Person \| Role \| Two-step \| Status \| Overrides \| Last seen \| Actions |
| Tab "Staff" | filters: Search, Role [All / Super Admin / Admin / Support / Accounts], Status [All / Active / Invited / Deactivated]. columns: Person, Role, Two-step, Status, Overrides, Last seen, Actions |
| Tab "Permission matrix" | filters: Set every area for Admin [Set all to... / None / View / Edit / Edit + Delete], Set every area for Support [Set all to... / None / View / Edit / Edit + Delete], Set every area for Accounts [Set all to... / None / View / Edit / Edit + Delete], Admin, Dashboard [None / View / Edit / Edit + Delete], Support, Dashboard [None / View / Edit / Edit + Delete], Accounts, Dashboard [None / View / Edit / Edit + Delete], Admin, Invitations [None / View / Edit / Edit + Delete], Support, Invitations [None / View / Edit / Edit + Delete], Accounts, Invitations [None / View / Edit / Edit + Delete], Admin, KYC reviews [None / View / Edit / Edit + Delete], Support, KYC reviews [None / View / Edit / Edit + Delete], Accounts, KYC reviews [None / View / Edit / Edit + Delete], Admin, Operators [None / View / Edit / Edit + Delete], Support, Operators [None / View / Edit / Edit + Delete], Accounts, Operators [None / View / Edit / Edit + Delete], Admin, Driver reports [None / View / Edit / Edit + Delete], Support, Driver reports [None / View / Edit / Edit + Delete], Accounts, Driver reports [None / View / Edit / Edit + Delete], Admin, Driver rules (defaults) [None / View / Edit / Edit + Delete], Support, Driver rules (defaults) [None / View / Edit / Edit + Delete], Accounts, Driver rules (defaults) [None / View / Edit / Edit + Delete], Admin, Commission [None / View / Edit / Edit + Delete], Support, Commission [None / View / Edit / Edit + Delete], Accounts, Commission [None / View / Edit / Edit + Delete]. columns: Area, Super Admin Always full access, AdminSet all to...NoneViewEditEdit + Delete, SupportSet all to...NoneViewEditEdit + Delete, AccountsSet all to...NoneViewEditEdit + Delete |
| Tab "Sessions" | columns: Person, Device, IP address, Signed in |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /admin/staff/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add staff | Add staff: Full name*; Email*; Role [Super Admin / Admin / Support / Accounts] | No server call | UI | opens staff form |
| Page > dialog | Send invitation |  | POST /admin/staff (invitation) or PATCH /admin/staff/:id | New |  |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Edit | Edit staff: Full name*; Email*; Role [Super Admin / Admin / Support / Accounts] | No server call | UI | opens staff form |
| Page > dialog | Save |  | POST /admin/staff (invitation) or PATCH /admin/staff/:id | New |  |
| Page | Deactivate |  | POST /admin/staff/:id/deactivate | New | audit |
| Page | View | Admin Super (IdSF1PersonAdmin SuperTitleSuper AdminRoleSuper adminStatusActiveEmailadmin.supe) | GET /admin/staff/:id | New | read one record for the detail window |
| Page | Activate |  | POST /admin/staff/:id/activate | New | audit |
| Tab: Staff | Export CSV |  | GET /admin/staff/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Staff | Add staff | Add staff: Full name*; Email*; Role [Super Admin / Admin / Support / Accounts] | No server call | UI | opens staff form |
| Tab: Staff > dialog | Send invitation |  | POST /admin/staff (invitation) or PATCH /admin/staff/:id | New |  |
| Tab: Staff | Table |  | No server call | UI | table or list view of the same data |
| Tab: Staff | List |  | No server call | UI | table or list view of the same data |
| Tab: Staff | Edit | Edit staff: Full name*; Email*; Role [Super Admin / Admin / Support / Accounts] | No server call | UI | opens staff form |
| Tab: Staff > dialog | Save |  | POST /admin/staff (invitation) or PATCH /admin/staff/:id | New |  |
| Tab: Staff | Deactivate |  | POST /admin/staff/:id/deactivate | New | audit |
| Tab: Staff | View | Admin Super (IdSF1PersonAdmin SuperTitleSuper AdminRoleSuper adminStatusActiveEmailadmin.supe) | GET /admin/staff/:id | New | read one record for the detail window |
| Tab: Permission matrix | Add role | Add role: Role name*; Start with the access of [No access (set it after) / Admin / Support / Accounts] | No server call | UI | opens add role form |
| Tab: Permission matrix > dialog | Add role |  | POST /access-matrix/roles | New | new role, optionally copying another role's access; Super Admin only; audit role.created |
| Tab: Sessions | Table |  | No server call | UI | table or list view of the same data |
| Tab: Sessions | List |  | No server call | UI | table or list view of the same data |
| Tab: Sessions | Sign out |  | DELETE /me/sessions/:sessionId | Exists |  |

### D.36 Feature flags and maintenance (`flags`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Integrations, feature flags and maintenance / Phase 0 |
| API base | `/admin/feature-flags` |
| Files | `settings_admin_manage_screen.dart`, `settings_admin_manage.ts`, `settings_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Feature flags (switch each feature on or off) \| Maintenance mode (global, customer app, operator app, partner; message and window) |
| Filters | Starts \| Ends |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | (icon) | Turn off Live tracking (Customers lose this feature straight away.) | PUT /admin/feature-flags/:key | New | confirmation first; takes effect straight away; audit |
| Page > dialog | Turn off |  | DELETE /admin/feature-flags/:id | New | confirm of a delete or revoke; audit |
| Page | (icon) | Global maintenance (Customer, operator and partner apps stop working. Admin staff still get in.) | PUT /admin/maintenance | New | on or off per scope (global, customer, operator, partner) |
| Page > dialog | Turn on |  | DELETE /admin/feature-flags/:id | New | confirm of a delete or revoke; audit |
| Page | Save message and schedule |  | PUT /admin/maintenance/message | New | message and window |

### D.37 Audit log (`audit`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Audit log / Phase 0 |
| API base | `/audit-logs` |
| Files | `audit_admin_manage_screen.dart`, `audit_admin_manage.ts`, `audit_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: View; Support: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| Person [All / Admin super / Abishek / Mynampati asha / Divya rao / Kiran kumar / Ravi teja / Sunita paul / Naveen babu] \| Type [All / Sensitive only] \| Action [All / Created coupon / Changed commission / Added staff user / Changed setting / Approved kyc submission / Suspended operator / Blocked customer / Approved settlement / Rejected document] |
| Table columns | When ▼ \| Who \| Action \| Target \| IP address \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /audit-logs/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Audit entry (When12 Oct 2026, 04:40 pmWhoMynampati AshaRoleAdminActionCreated couponTargetST-) | GET /audit-logs/:id | New | detail with before and after |
| Page | View | Audit entry (When12 Oct 2026, 04:40 pmWhoMynampati AshaRoleAdminActionCreated couponTargetST-) | GET /audit-logs/:id | New | detail with before and after |

### D.38 Notifications (`notifications`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Notifications and event router / Phase 0 |
| API base | `/notifications` |
| Files | `notifications_admin_manage_screen.dart`, `notifications_admin_manage.ts`, `notifications_admin_manage.service.ts` |
| Starting access | Super Admin: Edit+Delete; Admin: Edit+Delete; Support: Edit; Accounts: Edit |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Unread / Read] |
| Table columns | Notification \| When ▼ \| Actions |
| Detail page #/kyc/:id | detail view |
| Detail page #/settlements | cards: Still to pay, Paid this cycle, Waiting for approval, On hold. columns: Settlement, Operator, Gross, Commission, Refunds, Net payable, Mode, Status, Actions |
| Detail page #/tickets/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Mark all read |  | POST /notifications/read-all | Exists |  |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | Opens page #/kyc/:id | POST /notifications/:id/read | Exists | then opens the target |
| Page | Edit | Edit N0: Notification*; When* | No server call | UI | opens the edit form, filled from GET /notifications/:id |
| Page > dialog | Save changes |  | PATCH /notifications/:id | New | save changes; audit before and after |
| Page | Delete | Delete N0? (This removes it from every list. You can undo for a few seconds.) | DELETE /notifications/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /notifications/:id/restore |
| Page > dialog | Delete |  | DELETE /notifications/:id | New | confirm of a delete or revoke; audit |
| Page | Row (open the record) | Opens page #/settlements | POST /notifications/:id/read | Exists | then opens the target |
| Detail page #/kyc/:id | History | History (Submitted12 Oct 2026, 05:40 pm) | GET /onboarding/submissions/:id/history | New | new |
| Detail page #/kyc/:id | Reject submission |  | POST /onboarding/submissions/:id/reject | Exists | notifies the operator with the rejected documents |
| Detail page #/kyc/:id | Approve |  | POST /onboarding/submissions/:id/approve | Exists | notifies the operator |
| Detail page #/kyc/:id | View | GST certificate (GST_scan.pdfDocument preview placeholder. The real portal shows the uploaded PDF) | GET /files/:id/content | Exists |  |
| Detail page #/kyc/:id | Accept |  | POST /onboarding/submissions/:id/documents/:documentTypeId/review | Exists | accept |
| Detail page #/kyc/:id | Reject | Reject GST certificate: Reason* | No server call | UI | opens the reason form |
| Detail page #/kyc/:id > dialog | Reject document |  | POST /onboarding/submissions/:id/documents/:documentTypeId/review | Exists | reject with reason |
| Detail page #/settlements | Generate settlements | Generate settlements: Cycle [Last 7 days / Last 14 days / Custom range]; Operator [All operators / Kaveri Express / Godavari Lines / Deccan Voyager / Sahyadri Coaches / Nilgiri Travels ...] | No server call | UI | opens generate form |
| Detail page #/settlements > dialog | Generate |  | POST /admin/settlements/generate | New | cycle and operator; gross minus commission minus refunds plus adjustments |
| Detail page #/settlements | Payout file |  | GET /admin/settlements/payout-file?cycle= | New | bank file for manual mode |
| Detail page #/settlements | GST statement |  | GET /admin/settlements/gst-statement?cycle= | New | file |
| Detail page #/settlements | Export CSV |  | GET /notifications/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/settlements | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/settlements | List |  | No server call | UI | table or list view of the same data |
| Detail page #/settlements | View | Opens page #/settlements/:id | GET /admin/settlements/:id | New | with booking lines |
| Detail page #/settlements | Edit | Edit ST-6001: Operator*; Gross (Rs)*; Commission (Rs)*; Refunds (Rs)*; Net payable (Rs)*; Mode [Auto / Manual]; Status [On hold / Paid / Draft / Approved] | No server call | UI | opens the edit form, filled from GET /notifications/:id |
| Detail page #/settlements > dialog | Save changes |  | PATCH /notifications/:id | New | save changes; audit before and after |
| Detail page #/tickets/:id | Assign | Assign ticket: Assign to [Nobody / Divya (Support) / Kiran (Support)] | No server call | UI | opens assign form |
| Detail page #/tickets/:id > dialog | Assign |  | POST /admin/tickets/:id/assign | New | notifies the assignee |
| Detail page #/tickets/:id | Mark resolved |  | POST /admin/tickets/:id/resolve | New | audit |
| Detail page #/tickets/:id | Send reply |  | POST /admin/tickets/:id/replies | New | reply with proof files; notifies the customer |

### D.x Buttons that only appear in some states

These buttons are in the demo code but were not on screen in the default state (for example Approve only shows on a waiting refund). They are part of the build.

| Action | Where | Endpoint | Status | Notes |
|---|---|---|---|---|
| ai_fb | AI assistant | POST /assistant/messages/:id/feedback | New | thumbs up or down |
| ai_go | AI assistant | No server call | UI | opens the page the answer points to |
| ai_no | AI assistant | POST /assistant/actions/:id/decline | New | audit |
| ai_ok | AI assistant | POST /assistant/actions/:id/confirm | New | runs an action the assistant proposed, with the same permission check and an audit entry |
| ai_rep_csv | AI assistant | GET /admin/reports/trip-revenue/export | New | the report the assistant showed |
| ban_img | banners | POST /admin/banners/:id/image | Exists | JPG, PNG or WebP, up to 1 MB |
| bus_bulk_m | buses | POST /admin/buses/bulk-status | New | selected active buses to maintenance; audit |
| bus_bulk_x | buses | GET /catalogue/buses/export?ids= | New | export of the selected rows |
| cu_unblock | customers | POST /admin/customers/:id/unblock | New | audit |
| dr_appr | drules / dreports | No server call | UI | operator only; admin reads driver reports |
| dr_reset | drules / dreports | No server call | UI | operator only; admin edits the defaults instead |
| dr_ret | drules / dreports | No server call | UI | operator only |
| dr_ret_ok | drules / dreports | No server call | UI | operator only |
| file_view | proof files | GET /files/:id/content | Exists | viewer and download for proofs |
| gs_go | global search | No server call | UI | opens the chosen result |
| gs_run | global search | GET /admin/search?q= | New | PNR, phone, email, operator, bus, trip across collections; only what the role may see |
| gsearch | global search | No server call | UI | global search box |
| imp_dry | import dialog on places, buses, fares, schedules | POST /shell/import?dryRun=true | New | row-by-row result |
| imp_file | import dialog on places, buses, fares, schedules | No server call | UI | choose file |
| imp_go | import dialog on places, buses, fares, schedules | POST /shell/import?dryRun=false | New | saves the valid rows |
| imp_sample | import dialog on places, buses, fares, schedules | GET /shell/import-template | New | sample file |
| imp_tpl | import dialog on places, buses, fares, schedules | GET /shell/import-template | New |  |
| kpi | number cards | GET /shell?<card filter> | New | each number card opens the records behind it |
| kpi_exp | number cards | GET /shell/export?<card filter> | New | export of the records behind a card |
| mfa | account menu | No server call | UI | opens the MFA dialog (GET /me/mfa exists) |
| mfa_ok | account menu | POST /me/mfa/totp/activate | Exists |  |
| op_react | operators | POST /catalogue/operators/:id/status | Exists | body status ACTIVE; notifies operator |
| perm_all | staff | PUT /access-matrix/roles/:roleKey | New | built; one level for every page; Super Admin only; audit |
| perm_set | staff | PUT /access-matrix/roles/:roleKey/pages/:pageId | New | built; level None, View, Edit or Edit+Delete; Super Admin only; audit role.access.changed; holders get new tokens |
| pf_pick | proof files | No server call | UI | choose proof files (up to 5, 600 KB each) uploaded with POST /files \| exists |
| rec_add | every table | POST /shell | New | create from the generic form; audit |
| rf_bulk | refunds | POST /admin/refunds/bulk-approve | New | selected initiated refunds |
| rf_no | refunds | No server call | UI | opens reject form (proof required) |
| rf_no_ok | refunds | POST /admin/refunds/:id/reject | New | reason and proof; notifies the customer |
| rf_ok | refunds | POST /admin/refunds/:id/approve | New | starts the gateway refund |
| rf_retry | refunds | POST /admin/refunds/:id/retry | New | after a gateway failure |
| role | staff | No server call | UI | demo only: switching the role to preview access. Real build: the signed-in role comes from the token |
| role_del | staff | DELETE /access-matrix/roles/:roleKey | New | custom roles only; refused while any user holds it; audit role.deleted |
| role_ren | staff | No server call | UI | opens rename form |
| role_ren_ok | staff | PATCH /access-matrix/roles/:roleKey | New | custom roles only; audit role.renamed |
| rq_del | drules / dreports | DELETE /admin/driver-rules/defaults/reports/:id/questions/:qid | New |  |
| rq_mv | drules / dreports | PATCH /admin/driver-rules/defaults/reports/:id/questions/order | New |  |
| rq_req | drules / dreports | PATCH /admin/driver-rules/defaults/reports/:id/questions/:qid | New | required or not |
| st_appr | settlements | POST /admin/settlements/:id/approve | New | audit |
| st_bulk | settlements | POST /admin/settlements/bulk-approve | New | skips ones with open queries |
| st_hold | settlements | No server call | UI | opens hold form (reason and proof) |
| st_hold_ok | settlements | POST /admin/settlements/:id/hold | New | notifies the operator |
| st_pay | settlements | No server call | UI | opens pay form (reference) |
| st_pay_ok | settlements | POST /admin/settlements/:id/pay | New | manual mode marks paid with reference; automatic mode triggers the Razorpay Route transfer; notifies the operator |
| st_reply | settlements | No server call | UI | opens reply form |
| st_reply_ok | settlements | POST /admin/settlements/:id/query/reply | New | answers the operator's query; notifies the operator |
| tk_canned | tickets | GET /admin/tickets/canned-replies | New | list used by the reply box |
| tk_pick | tickets | No server call | UI | choose proof files |
| tk_reopen | tickets | POST /admin/tickets/:id/reopen | New | audit |
| trk_op | tracking | No server call | UI | filter |
| trk_replay | tracking | GET /admin/tracking/trips/:id/replay | New | stored positions |
| trk_st | tracking | No server call | UI | filter |

## Appendix E. Client (operator) portal: every page, button and endpoint

How to read each page: first its facts (feature, base path, files), then what is on the screen, then one row per button. "Where" says whether the button is on the page, on a tab, in a dialog or on a detail page. "Opens" lists the dialog and its fields (a star marks a required field). "Status" is **Exists** when the backend already has the route, **New** when it must be built, **UI** when no server call is needed. Row actions (View, Edit, Delete) exist on every table as in the demo; where changing a field would be unsafe (money, KYC status) the server refuses and says why.

> **Rule:** Build the real screen to look and behave exactly like the demo page of the same name. This appendix lists what the demo page contains; the demo file itself (`prototypes/client_demo_model.html`) is the visual reference.

### E.1 Dashboard (`dashboard`)

| Item | Value |
|---|---|
| Menu group | Overview |
| Feature / phase | Dashboards and reports / Phase 7 |
| API base | `/client/dashboard` |
| Files | `dashboard_client_manage_screen.dart`, `dashboard_client_manage.ts`, `dashboard_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | Needs your attention \| Bookings, last 14 days (chart) \| Booking status (chart) \| Your earnings per day, after commission (chart) \| Occupancy by route (chart) |
| Number cards (each opens the records behind it) | Bookings today \| Your earnings, 7 days \| Average occupancy \| Upcoming trips \| Active buses \| Buses live now \| Drivers on duty \| ustomer rating |

### E.2 KYC verification (`kyc`)

| Item | Value |
|---|---|
| Menu group | Company |
| Feature / phase | KYC review and company onboarding / Phase 1 |
| API base | `/onboarding/submissions` |
| Files | `kyc_client_manage_screen.dart`, `kyc_client_manage.ts`, `kyc_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | Step-by-step KYC wizard: questionnaire, then one upload box per required document with status (waiting, accepted, rejected with reason, replace), Send for review; bus KYC has the same steps |

### E.3 Company profile (`company`)

| Item | Value |
|---|---|
| Menu group | Company |
| Feature / phase | KYC review and company onboarding / Phase 1 |
| API base | `/client/company` |
| Files | `kyc_client_manage_screen.dart`, `kyc_client_manage.ts`, `kyc_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | Company profile (name, owner, GST, PAN, address, contact) \| Bank account for payout (with verification status set by Abra) |
| Filters | Company name * \| Owner name * \| Email * \| Support phone \| City \| GSTIN \| Account holder \| Account number \| IFSC |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Save |  | PUT /client/company | New | company profile; audit |
| Page | Save bank details |  | PUT /client/company/bank | New | bank details; admin verifies |

### E.4 Buses (`buses`)

| Item | Value |
|---|---|
| Menu group | Fleet |
| Feature / phase | Buses and seat layouts / Phase 2 |
| API base | `/catalogue/buses` |
| Files | `buses_client_manage_screen.dart`, `buses_client_manage.ts`, `buses_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Buses \| Active \| Waiting for approval \| Insurance expiring in 30 days |
| Filters | Search \| Status [All / Active / Pending approval / Maintenance / Retired] |
| Table columns | Registration \| Type \| Seats \| Layout \| Insurance \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Add bus | Add bus: Registration number*; Bus name*; Bus type [AC Sleeper / Non-AC Sleeper / AC Seater / Non-AC Seater / Volvo Multi-Axle AC / Semi-Sleeper AC]; Seats*; Seat layout [2+2 Seater / 2+1 Sleeper / 1+2 Sleeper / 2+1 Semi-sleeper]; Insurance valid till* | No server call | UI | opens bus form |
| Page > dialog | Send for approval |  | POST /catalogue/buses (sends the bus for KYC approval) or PUT /catalogue/buses/:id | Exists |  |
| Page | Import | Import buses (Upload a CSV file with these columns: registration, name, type, seats. Excel fil) | POST /catalogue/buses/import?dryRun=true then false | New | upload, row-by-row errors, then save; GET /catalogue/buses/import-template for the file |
| Page | Export CSV |  | GET /catalogue/buses/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | KA01 AB 3469 · Kaveri Prime 39 (Active Semi-sleeper ac 45 seats · 2+2 Seater Insurance valid till19 Dec 2026Amen) | GET /catalogue/buses/:id | Exists |  |
| Page > dialog | Seat layout |  | No server call | UI | opens the seat layout of the bus |
| Page > dialog | Edit |  | No server call | UI | opens bus form |
| Page > dialog | Mark maintenance |  | POST /catalogue/buses/:id/status | Exists | MAINTENANCE |
| Page | View | KA01 AB 3469 · Kaveri Prime 39 (Active Semi-sleeper ac 45 seats · 2+2 Seater Insurance valid till19 Dec 2026Amen) | GET /catalogue/buses/:id | Exists |  |

### E.5 Seat layouts (`layouts`)

| Item | Value |
|---|---|
| Menu group | Fleet |
| Feature / phase | Buses and seat layouts / Phase 2 |
| API base | `/client/seat-layouts` |
| Files | `buses_client_manage_screen.dart`, `buses_client_manage.ts`, `buses_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Seat layout designer: tools (Seat, Sleeper, Aisle, Remove), grid with Add row and Remove row, Reset, Save layout, Summary (seat counts, deck, ladies seats); choose the bus |
| Filters | Bus [KA01 AB 3469 · 2+2 Seater / KA01 AB 4945 · 2+2 Seater] |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Seat |  | No server call | UI | chooses the drawing tool (seat or sleeper) |
| Page | Sleeper |  | No server call | UI | chooses the drawing tool (seat or sleeper) |
| Page | Ladies seat |  | No server call | UI | chooses the drawing tool (seat or sleeper) |
| Page | Aisle |  | No server call | UI | chooses the drawing tool (seat or sleeper) |
| Page | Empty |  | No server call | UI | chooses the drawing tool (seat or sleeper) |
| Page | Seat |  | No server call | UI | places or removes a seat in the drawing |
| Page | Add row |  | No server call | UI | adds or removes a row in the drawing |
| Page | Remove row |  | No server call | UI | adds or removes a row in the drawing |
| Page | Reset |  | No server call | UI | clears the drawing |
| Page | Save layout |  | PUT /client/seat-layouts/:busId | New | saves a new version; trips already published keep their copy |

### E.6 Drivers and crew (`crew`)

| Item | Value |
|---|---|
| Menu group | Fleet |
| Feature / phase | Crew: drivers and conductors / Phase 2 |
| API base | `/client/crew` |
| Files | `crew_client_manage_screen.dart`, `crew_client_manage.ts`, `crew_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Drivers \| Active \| On leave \| icences expiring in 30 days |
| Filters | Search \| Role [All / Driver / Conductor / Manager] \| Status [All / Active / On leave / Inactive] |
| Table columns | Name \| Role \| Licence \| Trips in 7 days \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Add person | Add person: Full name*; Role [Driver / Conductor / Manager]; Phone*; Status [Active / On leave / Inactive]; Driving licence number; Licence valid till | No server call | UI | opens person form |
| Page > dialog | Add |  | POST /client/crew or PATCH /client/crew/:id | New | licence number and expiry; audit |
| Page | Export CSV |  | GET /client/crew/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | Ramesh K (IdST101OperatoridOP1NameRamesh KRoleDriverPhone+91 9100697329LicenceTS12 2022 00) | GET /client/crew/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form |
| Page > dialog | Delete |  | DELETE /client/crew/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /client/crew/:id/restore |

### E.7 Driver rules (`drules`)

| Item | Value |
|---|---|
| Menu group | Fleet |
| Feature / phase | Driver rules and trip checklists / Phase 9 |
| API base | `/client/driver-rules` |
| Files | `driver_rules_client_manage_screen.dart`, `driver_rules_client_manage.ts`, `driver_rules_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Before the trip \| After the trip \| Reports |
| Table columns | Item \| Rule \| Photo \| Applies to \| On |
| Tab "Before the trip" | columns: Item, Rule, Photo, Applies to, On |
| Tab "After the trip" | columns: Item, Rule, Photo, Applies to, On |
| Tab "Reports" | columns: Report, How often, Due, Questions, On |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Reset to Abra defaults | Reset to Abra defaults (Your checklist items and report questions go back to the Abra defaults. Reports ) | POST /client/driver-rules/reset | New | back to the Abra defaults |
| Page > dialog | Reset |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Page | Export CSV |  | GET /client/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add an item | Add an item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses] | No server call | UI | opens item form |
| Page > dialog | Add |  | POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | New | this operator's copy |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | (icon) |  | PATCH /client/driver-rules/items/:id/active | New | locked items cannot be switched off |
| Page | (icon) |  | PATCH /client/driver-rules/order | New |  |
| Page | Edit | Edit item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses] | No server call | UI | opens item form |
| Page > dialog | Save |  | POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | New | this operator's copy |
| Page | Remove | Remove this item (Drivers will no longer be asked: I am fit to drive and well rested. Old checklis) | DELETE /client/driver-rules/items/:id | New | locked items cannot be removed |
| Page > dialog | Remove |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Before the trip | Reset to Abra defaults | Reset to Abra defaults (Your checklist items and report questions go back to the Abra defaults. Reports ) | POST /client/driver-rules/reset | New | back to the Abra defaults |
| Tab: Before the trip > dialog | Reset |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Before the trip | Export CSV |  | GET /client/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Before the trip | Add an item | Add an item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses] | No server call | UI | opens item form |
| Tab: Before the trip > dialog | Add |  | POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | New | this operator's copy |
| Tab: Before the trip | Table |  | No server call | UI | table or list view of the same data |
| Tab: Before the trip | List |  | No server call | UI | table or list view of the same data |
| Tab: Before the trip | (icon) |  | PATCH /client/driver-rules/items/:id/active | New | locked items cannot be switched off |
| Tab: Before the trip | (icon) |  | PATCH /client/driver-rules/order | New |  |
| Tab: Before the trip | Edit | Edit item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses] | No server call | UI | opens item form |
| Tab: Before the trip > dialog | Save |  | POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | New | this operator's copy |
| Tab: Before the trip | Remove | Remove this item (Drivers will no longer be asked: I am fit to drive and well rested. Old checklis) | DELETE /client/driver-rules/items/:id | New | locked items cannot be removed |
| Tab: Before the trip > dialog | Remove |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: After the trip | Reset to Abra defaults | Reset to Abra defaults (Your checklist items and report questions go back to the Abra defaults. Reports ) | POST /client/driver-rules/reset | New | back to the Abra defaults |
| Tab: After the trip > dialog | Reset |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: After the trip | Export CSV |  | GET /client/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: After the trip | Add an item | Add an item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses] | No server call | UI | opens item form |
| Tab: After the trip > dialog | Add |  | POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | New | this operator's copy |
| Tab: After the trip | Table |  | No server call | UI | table or list view of the same data |
| Tab: After the trip | List |  | No server call | UI | table or list view of the same data |
| Tab: After the trip | (icon) |  | PATCH /client/driver-rules/items/:id/active | New | locked items cannot be switched off |
| Tab: After the trip | (icon) |  | PATCH /client/driver-rules/order | New |  |
| Tab: After the trip | Edit | Edit item: Item (what the driver reads)*; Answer type [Yes or no / Choose one / A number]; Choices (for "Choose one", separate with commas); What counts as a problem; If it is a problem [Blocks the trip / Warns only]; Photo needed [No / Yes, when there is a problem or a number]; Applies to [Every trip / Long routes (8 hours or more) / Sleeper buses / Seater buses] | No server call | UI | opens item form |
| Tab: After the trip > dialog | Save |  | POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | New | this operator's copy |
| Tab: After the trip | Remove | Remove this item (Drivers will no longer be asked: End odometer reading (km). Old checklists keep ) | DELETE /client/driver-rules/items/:id | New | locked items cannot be removed |
| Tab: After the trip > dialog | Remove |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Reports | Reset to Abra defaults | Reset to Abra defaults (Your checklist items and report questions go back to the Abra defaults. Reports ) | POST /client/driver-rules/reset | New | back to the Abra defaults |
| Tab: Reports > dialog | Reset |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |
| Tab: Reports | Export CSV |  | GET /client/driver-rules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Reports | Add a report | Add a report: Report name*; How often [Every day / Every week / When needed]; Due time (daily and weekly); Due day (weekly) [Mon / Tue / Wed / Thu / Fri / Sat ...] | No server call | UI | opens the report type form |
| Tab: Reports > dialog | Add |  | POST /client/driver-rules/reports or PATCH /client/driver-rules/reports/:id | New | this operator's report types |
| Tab: Reports | Table |  | No server call | UI | table or list view of the same data |
| Tab: Reports | List |  | No server call | UI | table or list view of the same data |
| Tab: Reports | (icon) |  | PATCH /client/driver-rules/reports/:id/active | New |  |
| Tab: Reports | Questions | Questions: Question; Answer type [Text / Number / Yes or no / Choose one / Photo / File]; Choices (for "Choose one"); Required [Optional / Required] | No server call | UI | opens question list |
| Tab: Reports > dialog | Add this question |  | POST /client/driver-rules/reports/:id/questions | New |  |
| Tab: Reports | Edit | Edit report: Report name*; How often [Every day / Every week / When needed]; Due time (daily and weekly); Due day (weekly) [Mon / Tue / Wed / Thu / Fri / Sat ...] | No server call | UI | opens the report type form |
| Tab: Reports > dialog | Save |  | POST /client/driver-rules/reports or PATCH /client/driver-rules/reports/:id | New | this operator's report types |
| Tab: Reports | Remove | Remove this report (Drivers will no longer see Daily report. Reports already sent are kept.) | DELETE /client/driver-rules/reports/:id | New |  |
| Tab: Reports > dialog | Remove |  | DELETE /client/driver-rules/:id | New | confirm of a delete or revoke; audit |

### E.8 Driver reports (`dreports`)

| Item | Value |
|---|---|
| Menu group | Fleet |
| Feature / phase | Driver reports / Phase 9 |
| API base | `/client/driver-reports` |
| Files | `driver_reports_client_manage_screen.dart`, `driver_reports_client_manage.ts`, `driver_reports_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Reports due or late6 overdue \| Waiting for review \| Sent back to drivers \| Trips started past a failed check |
| Tabs | Reports \| Missing \| Trip checklists |
| Filters | Driver or report \| Status [All / Waiting for review / Approved / Sent back] \| Report [All / Daily report / Weekly report] \| Driver [All / Ramesh k / Sunil y] |
| Table columns | Report \| Driver \| Sent ▼ \| Status \| Files |
| Tab "Reports" | cards: Reports due or late6 overdue, Waiting for review, Sent back to drivers, Trips started past a failed check. filters: Driver or report, Status [All / Waiting for review / Approved / Sent back], Report [All / Daily report / Weekly report], Driver [All / Ramesh k / Sunil y]. columns: Report, Driver, Sent ▼, Status, Files |
| Tab "Missing" | cards: Reports due or late6 overdue, Waiting for review, Sent back to drivers, Trips started past a failed check. filters: Status [All / Overdue / Due soon]. columns: Driver, Report, Due, Status |
| Tab "Trip checklists" | cards: Reports due or late6 overdue, Waiting for review, Sent back to drivers, Trips started past a failed check. filters: Search, Result [All / Passed / Warnings / Started anyway], When [All / Before the trip / After the trip]. columns: Trip, Driver, When, Time ▼, Odometer, Result |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /client/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Daily report - Ramesh K (DriverRamesh KOperatorKaveri ExpressReport11 Oct 2026Sent11 Oct 2026, 07:40 pmSt) | GET /client/driver-reports/:id | New | system numbers (frozen) and answers |
| Page > dialog | Send back |  | No server call | UI | opens the note form |
| Page > dialog | Approve |  | POST /client/driver-reports/:id/approve | New | notifies the driver |
| Tab: Reports | Export CSV |  | GET /client/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Reports | Table |  | No server call | UI | table or list view of the same data |
| Tab: Reports | List |  | No server call | UI | table or list view of the same data |
| Tab: Reports | Row (open the record) | Daily report - Ramesh K (DriverRamesh KOperatorKaveri ExpressReport11 Oct 2026Sent11 Oct 2026, 07:40 pmSt) | GET /client/driver-reports/:id | New | system numbers (frozen) and answers |
| Tab: Reports > dialog | Send back |  | No server call | UI | opens the note form |
| Tab: Reports > dialog | Approve |  | POST /client/driver-reports/:id/approve | New | notifies the driver |
| Tab: Missing | Export CSV |  | GET /client/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Missing | Table |  | No server call | UI | table or list view of the same data |
| Tab: Missing | List |  | No server call | UI | table or list view of the same data |
| Tab: Missing | Remind the driver |  | POST /client/driver-reports/remind | New | tells the driver |
| Tab: Trip checklists | Export CSV |  | GET /client/driver-reports/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Trip checklists | Table |  | No server call | UI | table or list view of the same data |
| Tab: Trip checklists | List |  | No server call | UI | table or list view of the same data |
| Tab: Trip checklists | Row (open the record) | After the trip: TRP-3018 (DriverRamesh KTripTRP-3018 Vijayawada to VisakhapatnamWhen11 Oct 2026, 07:40 amO) | GET /client/trip-checks/:id | New | checklist result |

### E.9 Routes and stops (`routes`)

| Item | Value |
|---|---|
| Menu group | Network |
| Feature / phase | Routes, stops and boarding points / Phase 2 |
| API base | `/catalogue/routes` |
| Files | `routes_client_manage_screen.dart`, `routes_client_manage.ts`, `routes_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search |
| Table columns | Route \| Distance \| Duration \| Stops \| Your trips \| Status \| Actions |
| Detail page #/routes/:id | detail view |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | New route | Add a report: Report name*; How often [Every day / Every week / When needed]; Due time (daily and weekly); Due day (weekly) [Mon / Tue / Wed / Thu / Fri / Sat ...] | No server call | UI | opens route form |
| Page > dialog | Add |  | POST /catalogue/routes or PUT /catalogue/routes/:id | Exists | stops with times, boarding and dropping points |
| Page | Export CSV |  | GET /catalogue/routes/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/routes/:id | GET /catalogue/routes/:id | Exists |  |
| Page | View | Opens page #/routes/:id | GET /catalogue/routes/:id | Exists |  |
| Page | Edit | Edit report: Report name*; How often [Every day / Every week / When needed]; Due time (daily and weekly); Due day (weekly) [Mon / Tue / Wed / Thu / Fri / Sat ...] | No server call | UI | opens route form |
| Page > dialog | Save |  | POST /catalogue/routes or PUT /catalogue/routes/:id | Exists | stops with times, boarding and dropping points |
| Detail page #/routes/:id | Copy as my route |  | POST /client/routes/copy-from/:id | New | copies a public route as this operator's own |

### E.10 Places (`places`)

| Item | Value |
|---|---|
| Menu group | Network |
| Feature / phase | Cities and places / Phase 1 |
| API base | `/client/place-requests` |
| Files | `places_client_manage_screen.dart`, `places_client_manage.ts`, `places_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search \| City [All / Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore / Kochi / Mumbai / Pune] |
| Table columns 1 | Place \| City \| Requested \| Status \| Actions |
| Table columns 2 | Place \| City \| Used for \| Landmark |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Request a place | Request a place: City [Hyderabad / Bengaluru / Chennai / Vijayawada / Visakhapatnam / Coimbatore ...]; Place name*; Address*; Landmark | No server call | UI | opens place request form |
| Page > dialog | Send request |  | POST /client/place-requests | New | admin approves or rejects; the operator is notified |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | Hosur Bus Stand Gate 2 (IdPR-100OperatorKaveri ExpressCityHosurPlaceHosur Bus Stand Gate 2AddressHosur M) | GET /client/place-requests/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /client/place-requests/:id |
| Page | Export CSV |  | GET /client/place-requests/export?format=csv\|xlsx | New | same filters, search and permissions as the list |

### E.11 Fares (`fares`)

| Item | Value |
|---|---|
| Menu group | Sales setup |
| Feature / phase | Fares and schedules / Phase 2 |
| API base | `/client/fares` |
| Files | `fares_client_manage_screen.dart`, `fares_client_manage.ts`, `fares_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: View |

| On the screen | Contents |
|---|---|
| Filters | Search \| Status [All / Active / Inactive] |
| Table columns | Route \| Seat type \| Weekday \| Weekend \| Festival \| Customer pays (weekday) \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | New fare | New fare: Route [Hyderabad to Bengaluru / Bengaluru to Hyderabad / Vijayawada to Visakhapatnam]; Seat type [AC Sleeper / Non-AC Sleeper / AC Seater / Non-AC Seater / Volvo Multi-Axle AC / Semi-Sleeper AC]; Weekday fare (Rs)*; Weekend fare (Rs)*; Festival fare (Rs)*; Effective from*; Status [ACTIVE / INACTIVE] | No server call | UI | opens fare form |
| Page > dialog | Save fare |  | POST /client/fares or PATCH /client/fares/:id | New | weekday, weekend, festival fare per seat type; effective from |
| Page | Export CSV |  | GET /client/fares/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | Vijayawada to Visakhapatnam (IdFR17OperatoridOP1RouteidRT5RouteVijayawada to VisakhapatnamSeat typeNon-AC Sle) | GET /client/fares/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens fare form |
| Page > dialog | Delete |  | DELETE /client/fares/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /client/fares/:id/restore |

### E.12 Schedules (`schedules`)

| Item | Value |
|---|---|
| Menu group | Sales setup |
| Feature / phase | Fares and schedules / Phase 2 |
| API base | `/client/schedules` |
| Files | `fares_client_manage_screen.dart`, `fares_client_manage.ts`, `fares_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | List of recurring schedules (route, bus, time, days, from, till, status) and the form to create them; Generate trips |
| Filters | Search |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | New schedule | New schedule: Route [Hyderabad to Bengaluru / Bengaluru to Hyderabad / Vijayawada to Visakhapatnam]; Bus [KA01 AB 3469 · Semi-Sleeper AC / KA01 AB 4945 · Non-AC Sleeper]; Departure time*; Status [ACTIVE / INACTIVE]; From*; Till* | No server call | UI | opens schedule form |
| Page > dialog | Save |  | POST /client/schedules or PATCH /client/schedules/:id | New | recurring trip |
| Page | Export CSV |  | GET /client/schedules/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |

### E.13 Trips (`trips`)

| Item | Value |
|---|---|
| Menu group | Sales setup |
| Feature / phase | Trips and seat inventory / Phase 2 |
| API base | `/catalogue/trips` |
| Files | `trips_client_manage_screen.dart`, `trips_client_manage.ts`, `trips_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: Edit; Accounts: None |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | On sale \| Drafts \| Running now \| Without a driver |
| Filters | Search \| Status [All / Draft / Scheduled / Boarding / In transit / Delayed / Arrived / Cancelled] \| When [All / Upcoming / Today / Past] |
| Table columns | Trip \| Departs ▲ \| Bus \| Driver \| Booked \| Fare \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | New trip | New trip: Route [Hyderabad to Bengaluru / Bengaluru to Hyderabad / Vijayawada to Visakhapatnam]; Bus [KA01 AB 3469 · Semi-Sleeper AC · 45 seats / KA01 AB 4945 · Non-AC Sleeper · 38 seats]; Date*; Departure time*; Driver [Assign later / Ramesh K / Sunil Y / Anwar S]; Window / corner seat (Rs per seat)*; Normal seat (Rs per seat)* | No server call | UI | opens trip form |
| Page > dialog | Create trip |  | POST /catalogue/trips | Exists | draft with fares by seat type |
| Page | Export CSV |  | GET /catalogue/trips/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | TRP-4001 · Hyderabad to Bengaluru (Arrived 8 Oct 2026, 08:30 pm · KA01 AB 3469 · Semi-Sleeper AC · ₹1,100 per seat ) | GET /catalogue/trips/:id | Exists | plus seat map GET /client/trips/:id/seats |
| Page > dialog | Download manifest |  | GET /client/trips/:id/manifest.pdf | New | passenger list with seats and boarding points |
| Page | View | TRP-4001 · Hyderabad to Bengaluru (Arrived 8 Oct 2026, 08:30 pm · KA01 AB 3469 · Semi-Sleeper AC · ₹1,100 per seat ) | GET /catalogue/trips/:id | Exists | plus seat map GET /client/trips/:id/seats |
| Page | Edit | Edit Hyderabad to Bengaluru: Departs*; Bus*; Driver*; Booked*; Fare (Rs)*; Status [Arrived / Scheduled / Delayed / In transit / Draft / Cancelled] | No server call | UI | opens the edit form, filled from GET /catalogue/trips/:id |
| Page > dialog | Save changes |  | PATCH /catalogue/trips/:id | New | save changes; audit before and after |

### E.14 Bookings (`bookings`)

| Item | Value |
|---|---|
| Menu group | Sales |
| Feature / phase | Booking, passengers and bookings lists / Phase 3 |
| API base | `/client/bookings` |
| Files | `booking_client_manage_screen.dart`, `booking_client_manage.ts`, `booking_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: Edit; Accounts: View |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Bookings \| onfirmed \| ancelled \| Your share |
| Filters | Search \| Status [All / Confirmed / Completed / Cancelled] \| Route [All / Vijayawada to visakhapatnam / Hyderabad to bengaluru / Bengaluru to hyderabad] |
| Table columns | PNR \| Passenger \| Route \| Travel ▼ \| Seats \| Fare \| You get \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /client/bookings/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | ABRK5152A (PassengerRahul VermaPhone+91 9777868637TripTRP-4022 · Bengaluru to HyderabadTrav) | GET /client/bookings/:id | New | detail |
| Page > dialog | Call passenger |  | No server call | UI | dials the passenger |
| Page > dialog | Cancel booking |  | No server call | UI | opens cancel form (proof) |
| Page | View | ABRK5152A (PassengerRahul VermaPhone+91 9777868637TripTRP-4022 · Bengaluru to HyderabadTrav) | GET /client/bookings/:id | New | detail |
| Page | Edit | Edit ABRK5152A: PNR*; Passenger*; Route*; Travel*; Seats*; Fare (Rs)*; Status [Confirmed / Completed / Cancelled] | No server call | UI | opens the edit form, filled from GET /client/bookings/:id |
| Page > dialog | Save changes |  | PATCH /client/bookings/:id | New | save changes; audit before and after |

### E.15 Offers (`offers`)

| Item | Value |
|---|---|
| Menu group | Sales |
| Feature / phase | Offers and coupons / Phase 3 |
| API base | `/client/offer-requests` |
| Files | `offers_client_manage_screen.dart`, `offers_client_manage.ts`, `offers_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Filters | Search |
| Table columns | Code \| Discount \| Valid till \| Used \| Cost to you \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Request an offer | Request an offer: Code*; Type [Flat amount / Percentage]; Value (Rs, or percent)*; Maximum discount (Rs); Valid till*; Total uses (0 = no limit); Description (customers see it)* | No server call | UI | opens offer request form |
| Page > dialog | Send to Abra |  | POST /client/offer-requests | New | arrives in admin as an offer request to approve |
| Page | Export CSV |  | GET /client/offer-requests/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | KAVERI50 (IdOF5CodeKAVERI50DescRs 50 off Kaveri Express busesTypeFlatDiscount5000Maxdisc₹5) | GET /client/offer-requests/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /client/offer-requests/:id |
| Page > dialog | Delete |  | DELETE /client/offer-requests/:id | New | soft delete, refused if the record is in use; audit; "Undo" calls POST /client/offer-requests/:id/restore |

### E.16 Earnings and settlements (`earnings`)

| Item | Value |
|---|---|
| Menu group | Money |
| Feature / phase | Settlements and earnings / Phase 6 |
| API base | `/client/settlements` |
| Files | `settlements_client_manage_screen.dart`, `settlements_client_manage.ts`, `settlements_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: Edit |

| On the screen | Contents |
|---|---|
| Number cards (each opens the records behind it) | Gross sales, 30 days \| Abra commission \| Refunds you bore \| Your net, 30 days |
| Filters | Search |
| Table columns | Settlement \| Gross \| Commission \| Refunds \| Net payable \| Status \| Actions |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /client/settlements/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | ST-6001 · 1 Oct to 7 Oct 2026 (Gross₹34,453.35Abra commission- ₹3,445.34Refunds- ₹2,742.97Adjustments₹0Net paya) | GET /client/settlements/:id | New | detail with lines |
| Page > dialog | Download statement |  | GET /client/settlements/:id/statement.pdf | New |  |
| Page > dialog | Raise a query |  | No server call | UI | opens query form (proof allowed) |
| Page | View | ST-6001 · 1 Oct to 7 Oct 2026 (Gross₹34,453.35Abra commission- ₹3,445.34Refunds- ₹2,742.97Adjustments₹0Net paya) | GET /client/settlements/:id | New | detail with lines |
| Page | Edit | Edit ST-6001: Gross (Rs)*; Commission (Rs)*; Refunds (Rs)*; Net payable (Rs)*; Status [On hold / Paid / Draft / Approved] | No server call | UI | opens the edit form, filled from GET /client/settlements/:id |
| Page > dialog | Save changes |  | PATCH /client/settlements/:id | New | save changes; audit before and after |

### E.17 Commission (`commission`)

| Item | Value |
|---|---|
| Menu group | Money |
| Feature / phase | Commission rules / Phase 2 |
| API base | `/client/commission` |
| Files | `commission_client_manage_screen.dart`, `commission_client_manage.ts`, `commission_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: None; Accounts: View |

| On the screen | Contents |
|---|---|
| Sections of the page | Rules that apply to you (read-only, set by Abra) \| Price calculator: fare in, customer price and your payable out |
| Filters | Your fare per seat (Rs) \| Route [Hyderabad to Bengaluru / Bengaluru to Hyderabad / Vijayawada to Visakhapatnam] \| Seat type [Semi-Sleeper AC / Non-AC Sleeper] |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Calculate |  | POST /client/commission/calculate | New | shows how a fare becomes the customer price and the operator payable |

### E.18 Live buses and safety (`live`)

| Item | Value |
|---|---|
| Menu group | Operations |
| Feature / phase | Live tracking / Phase 5 |
| API base | `/client/live` |
| Files | `tracking_client_manage_screen.dart`, `tracking_client_manage.ts`, `tracking_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: View; Accounts: None |

| On the screen | Contents |
|---|---|
| Sections of the page | Live buses and safety \| Running now (list with map, position, ETA, passengers, checked in) \| SOS history on this operator's buses (customer, driver, status) |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Call |  | No server call | UI | dials the passenger |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |

### E.19 Notifications (`notifications`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Notifications and event router / Phase 0 |
| API base | `/notifications` |
| Files | `notifications_client_manage_screen.dart`, `notifications_client_manage.ts`, `notifications_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: Edit+Delete; Booking staff: Edit; Accounts: Edit |

| On the screen | Contents |
|---|---|
| Filters | Search |
| Table columns | Notification \| When ▼ |
| Detail page #/buses | cards: Buses, Active, Waiting for approval, Insurance expiring in 30 days. columns: Registration, Type, Seats, Layout, Insurance, Status, Actions |
| Detail page #/settlements | cards: Bookings today, Your earnings, 7 days, Average occupancy, Upcoming trips, Active buses, Buses live now, Drivers on duty, ustomer rating |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Mark all read |  | POST /notifications/read-all | Exists |  |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | Row (open the record) | Opens page #/buses | POST /notifications/:id/read | Exists | then opens the target |
| Detail page #/buses | Add bus | Add bus: Registration number*; Bus name*; Bus type [AC Sleeper / Non-AC Sleeper / AC Seater / Non-AC Seater / Volvo Multi-Axle AC / Semi-Sleeper AC]; Seats*; Seat layout [2+2 Seater / 2+1 Sleeper / 1+2 Sleeper / 2+1 Semi-sleeper]; Insurance valid till* | No server call | UI | opens bus form |
| Detail page #/buses > dialog | Send for approval |  | POST /catalogue/buses (sends the bus for KYC approval) or PUT /catalogue/buses/:id | Exists |  |
| Detail page #/buses | Import | Import buses (Upload a CSV file with these columns: registration, name, type, seats. Excel fil) | POST /notifications/import?dryRun=true then false | New | upload, row-by-row errors, then save; GET /notifications/import-template for the file |
| Detail page #/buses | Export CSV |  | GET /notifications/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Detail page #/buses | Table |  | No server call | UI | table or list view of the same data |
| Detail page #/buses | List |  | No server call | UI | table or list view of the same data |
| Detail page #/buses | View | KA01 AB 3469 · Kaveri Prime 39 (Active Semi-sleeper ac 45 seats · 2+2 Seater Insurance valid till19 Dec 2026Amen) | GET /catalogue/buses/:id | Exists |  |
| Detail page #/buses > dialog | Seat layout |  | No server call | UI | opens the seat layout of the bus |
| Detail page #/buses > dialog | Edit |  | No server call | UI | opens bus form |
| Detail page #/buses > dialog | Mark maintenance |  | POST /catalogue/buses/:id/status | Exists | MAINTENANCE |

### E.20 Staff and roles (`staff`)

| Item | Value |
|---|---|
| Menu group | System |
| Feature / phase | Staff, roles and access matrix / Phase 7 |
| API base | `/client/users` |
| Files | `staff_client_manage_screen.dart`, `staff_client_manage.ts`, `staff_client_manage.service.ts` |
| Starting access | Owner: Edit+Delete; Manager: None; Booking staff: None; Accounts: None |

| On the screen | Contents |
|---|---|
| Tabs | Portal users \| Permission matrix |
| Filters | Search |
| Table columns | Person \| Role \| Status \| Last seen \| Actions |
| Tab "Portal users" | filters: Search. columns: Person, Role, Status, Last seen, Actions |
| Tab "Permission matrix" | filters: Set every area for Manager [Set all to... / None / View / Edit / Edit + Delete], Set every area for Booking staff [Set all to... / None / View / Edit / Edit + Delete], Set every area for Accounts [Set all to... / None / View / Edit / Edit + Delete], Manager, Dashboard [None / View / Edit / Edit + Delete], Booking staff, Dashboard [None / View / Edit / Edit + Delete], Accounts, Dashboard [None / View / Edit / Edit + Delete], Manager, KYC verification [None / View / Edit / Edit + Delete], Booking staff, KYC verification [None / View / Edit / Edit + Delete], Accounts, KYC verification [None / View / Edit / Edit + Delete], Manager, Company profile [None / View / Edit / Edit + Delete], Booking staff, Company profile [None / View / Edit / Edit + Delete], Accounts, Company profile [None / View / Edit / Edit + Delete], Manager, Buses [None / View / Edit / Edit + Delete], Booking staff, Buses [None / View / Edit / Edit + Delete], Accounts, Buses [None / View / Edit / Edit + Delete], Manager, Seat layouts [None / View / Edit / Edit + Delete], Booking staff, Seat layouts [None / View / Edit / Edit + Delete], Accounts, Seat layouts [None / View / Edit / Edit + Delete], Manager, Drivers and crew [None / View / Edit / Edit + Delete], Booking staff, Drivers and crew [None / View / Edit / Edit + Delete], Accounts, Drivers and crew [None / View / Edit / Edit + Delete], Manager, Driver reports [None / View / Edit / Edit + Delete], Booking staff, Driver reports [None / View / Edit / Edit + Delete], Accounts, Driver reports [None / View / Edit / Edit + Delete]. columns: Area, Owner Always full access, ManagerSet all to...NoneViewEditEdit + Delete, Booking staffSet all to...NoneViewEditEdit + Delete, AccountsSet all to...NoneViewEditEdit + Delete |

| Where | Button | Opens | Endpoint | Status | Notes |
|---|---|---|---|---|---|
| Page | Export CSV |  | GET /client/users/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Page | Add user | Add user: Full name*; Email*; Role [Manager / Booking staff / Accounts] | No server call | UI | opens user form |
| Page > dialog | Send invitation |  | POST /client/users (invitation) or PATCH /client/users/:id | New |  |
| Page | Table |  | No server call | UI | table or list view of the same data |
| Page | List |  | No server call | UI | table or list view of the same data |
| Page | View | Ramesh Naidu (IdOU1OperatoridOP1PersonRamesh NaiduEmailramesh.naidu@example.comRoleSuper admin) | GET /client/users/:id | New | read one record for the detail window |
| Page > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /client/users/:id |
| Tab: Portal users | Export CSV |  | GET /client/users/export?format=csv\|xlsx | New | same filters, search and permissions as the list |
| Tab: Portal users | Add user | Add user: Full name*; Email*; Role [Manager / Booking staff / Accounts] | No server call | UI | opens user form |
| Tab: Portal users > dialog | Send invitation |  | POST /client/users (invitation) or PATCH /client/users/:id | New |  |
| Tab: Portal users | Table |  | No server call | UI | table or list view of the same data |
| Tab: Portal users | List |  | No server call | UI | table or list view of the same data |
| Tab: Portal users | View | Ramesh Naidu (IdOU1OperatoridOP1PersonRamesh NaiduEmailramesh.naidu@example.comRoleSuper admin) | GET /client/users/:id | New | read one record for the detail window |
| Tab: Portal users > dialog | Edit |  | No server call | UI | opens the edit form, filled from GET /client/users/:id |
| Tab: Permission matrix | Add role | Add role: Role name*; Start with the access of [No access (set it after) / Manager / Booking staff / Accounts] | No server call | UI | opens role form |
| Tab: Permission matrix > dialog | Add role |  | POST /access-matrix/roles | New | audience OPERATOR; phase 8 lets the owner manage own roles (operatorId on the role) |

### E.x Buttons that only appear in some states

These buttons are in the demo code but were not on screen in the default state (for example Approve only shows on a waiting refund). They are part of the build.

| Action | Where | Endpoint | Status | Notes |
|---|---|---|---|---|
| au_acc | sign-in and KYC wizard | POST /onboarding/invitations/accept | Exists |  |
| au_back | sign-in and KYC wizard | No server call | UI | back |
| au_in | sign-in and KYC wizard | POST /auth/login | Exists | (password) or POST /auth/social/google |
| au_inv | sign-in and KYC wizard | POST /onboarding/invitations/inspect | Exists | shows the invited company |
| bd_fix | sign-in and KYC wizard | PUT /onboarding/submissions/:id/documents/:documentTypeId | Exists |  |
| bd_resend | sign-in and KYC wizard | POST /onboarding/submissions/:id/submit | Exists |  |
| bdoc | sign-in and KYC wizard | No server call | UI | choose the bus document |
| cai_go | AI assistant | No server call | UI | opens the page the answer points to |
| cai_no | AI assistant | POST /assistant/actions/:id/decline | New |  |
| cai_ok | AI assistant | POST /assistant/actions/:id/confirm | New | same permission check and audit |
| cb_cancel_ok | bookings | POST /client/bookings/:id/cancel | New | operator-side cancellation; refund by the operator's slab; audit |
| cs_q_ok | earnings | POST /client/settlements/:id/query | New | notifies admin |
| d_reset | drules / dreports | No server call | UI | confirm reset |
| dop | drules / dreports | No server call | UI | opens an option list |
| dr_push | drules / dreports | No server call | UI | admin only |
| dr_ret_ok | drules / dreports | POST /client/driver-reports/:id/return | New | note required; notifies the driver |
| file_view | proof files | GET /files/:id/content | Exists |  |
| gs_go | global search | No server call | UI | opens the result |
| gs_run | global search | GET /client/search?q= | New | only this company's data |
| gsearch | global search | No server call | UI | search box |
| imp_dry | import dialog on places, buses, fares, schedules | POST /shell/import?dryRun=true | New | row-by-row result |
| imp_file | import dialog on places, buses, fares, schedules | No server call | UI | choose file |
| imp_go | import dialog on places, buses, fares, schedules | POST /shell/import?dryRun=false | New |  |
| imp_sample | import dialog on places, buses, fares, schedules | GET /shell/import-template | New | sample file |
| imp_tpl | import dialog on places, buses, fares, schedules | GET /shell/import-template | New |  |
| kd_fix | sign-in and KYC wizard | PUT /onboarding/submissions/:id/documents/:documentTypeId | Exists | replaces a rejected file |
| kd_resend | sign-in and KYC wizard | POST /onboarding/submissions/:id/submit | Exists | sends corrections |
| kd_submit | sign-in and KYC wizard | POST /onboarding/submissions/:id/submit | Exists |  |
| kd_up | sign-in and KYC wizard | PUT /onboarding/submissions/:id/documents/:documentTypeId | Exists |  |
| kpi | number cards | GET /shell?<card filter> | New | every number card opens the records behind it |
| kpi_exp | number cards | GET /shell/export?<card filter> | New |  |
| kq | sign-in and KYC wizard | PUT /onboarding/submissions/:id/answers | New | saves a questionnaire answer |
| kq_in | sign-in and KYC wizard | PUT /onboarding/submissions/:id/answers | New |  |
| kstep | sign-in and KYC wizard | No server call | UI | wizard step |
| lay_bus | layouts | GET /client/seat-layouts?busId= | New | layout of the chosen bus |
| mfa | account menu | No server call | UI | MFA dialog |
| mfa_ok | account menu | POST /me/mfa/totp/activate | Exists |  |
| perm_all | staff | PUT /access-matrix/roles/:roleKey | New | one level for every page |
| perm_set | staff | PUT /access-matrix/roles/:roleKey/pages/:pageId | New | the owner only (phase 8) |
| pf_pick | proof files | No server call | UI | choose files; POST /files \| exists |
| rec_add | every table | POST /shell | New | create from the generic form; audit |
| role | staff | No server call | UI | demo only: preview as another role |
| role_del | staff | DELETE /access-matrix/roles/:roleKey | New |  |
| role_ren | staff | No server call | UI | rename |
| role_ren_ok | staff | PATCH /access-matrix/roles/:roleKey | New |  |
| rq_del | drules / dreports | DELETE /client/driver-rules/reports/:id/questions/:qid | New |  |
| rq_mv | drules / dreports | PATCH /client/driver-rules/reports/:id/questions/order | New |  |
| rq_req | drules / dreports | PATCH /client/driver-rules/reports/:id/questions/:qid | New |  |
| rt_add | drules / dreports | No server call | UI | adds a stop row |
| rt_mv | drules / dreports | No server call | UI | moves a stop |
| rt_off | drules / dreports | No server call | UI | sets the minutes from start |
| rt_pl | drules / dreports | GET /catalogue/locations?cityId= | Exists | places for a stop |
| rt_rm | drules / dreports | No server call | UI | removes a stop row |
| rt_ty | drules / dreports | No server call | UI | sets the stop type (boarding, dropping, both) |
| sc_day | schedules | No server call | UI | picks days of the week |
| sc_gen | schedules | POST /client/schedules/:id/generate | New | creates the trips for the date range |
| sch_edit | schedules | No server call | UI | opens schedule form |
| tr_bulk_pub | trips | POST /client/trips/bulk-publish | New | selected drafts |
| tr_cancel_ok | trips | POST /catalogue/trips/:id/cancel | Exists | refunds all bookings; notifies customers, driver, admin |
| tr_delay_ok | trips | POST /client/trips/:id/delay | New | minutes, reason, proof; notifies customers and admin |
| tr_drv_ok | trips | PUT /client/trips/:id/driver | New | notifies the driver |
| tr_pub | trips | POST /catalogue/trips/:id/publish | Exists | only if company and bus KYC are approved |
| tr_refares | trips | POST /client/trips/:id/refares | New | reapplies the fare rule to unsold trips (does not change published trips unless republished) |
| up_ex | sign-in and KYC wizard | No server call | UI | choose file |
| up_go | sign-in and KYC wizard | POST /files | Exists |  |

## Appendix F. Customer app: every screen and endpoint

The customer app is mostly built; this lists every screen so the remaining ones and the real connections are finished against the demo. Endpoints under `/customer` need a signed-in customer; the others are public.

> **Rule:** Build the real screens to look and behave exactly like the demo (`prototypes/customer_demo_model.html`): same layout, wording, order, colours, dialogs and states.

### F.1 Welcome, onboarding and language

| Item | Value |
|---|---|
| Feature / phase | Customers and profile / Phase 4 |
| Files | `customers_customer_screen.dart`, `customers_customer.ts`, `customers_customer.service.ts` |
| On the screen | Three intro cards (Get started, Skip, Back, Continue); language chooser with the 8 languages (names in English next to the native script). |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Get started / Skip / Continue | Stores the chosen language and marks onboarding as done on the device | none (device only) | UI | Language is saved to the profile after sign-in with PATCH /customer/profile |
| Language chooser | Sets app language | GET /translations/:lang (bundle, cached) | New | translations |

### F.2 Home

| Item | Value |
|---|---|
| Feature / phase | Search and trip details / Phase 3 |
| Files | `discovery_customer_screen.dart`, `discovery_customer.ts`, `discovery_customer.service.ts` |
| On the screen | Search card (From, To, Date, Swap, Today/Tomorrow chips), recent searches, banner carousel, offers strip, popular routes, running-trip banner with SOS and Track buttons, bell with unread count. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| City picker (From / To) | Searches cities as the user types | GET /cities?q= | Exists | cities (exists) |
| Swap | Swaps From and To | none | UI |  |
| Recent searches | Last 4 searches kept on the device | none (device only) | UI |  |
| Banner tap | Opens the linked offer or route | GET /banners?placement=home (exists) and POST /banners/:id/click | Exists | banners |
| Popular routes | Fills the search card | GET /popular-routes | New | popular |
| Search | Opens results | GET /trips/search?from&to&date (exists) | Exists | trips |
| Running-trip banner: Track / SOS | Opens tracking or the safety screen of the trip in transit | GET /customer/bookings?status=RUNNING | New | bookings, trips |
| Bell | Opens notifications | GET /notifications/unread-count (exists) | Exists | inbox |

### F.3 Search results

| Item | Value |
|---|---|
| Feature / phase | Search and trip details / Phase 3 |
| Files | `discovery_customer_screen.dart`, `discovery_customer.ts`, `discovery_customer.service.ts` |
| On the screen | Day chips, sort sheet, filter sheet (time of day, bus type, AC, operator, amenities, maximum fare), list of trips with operator, times, seats left, price from. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Day chips | Changes the date | GET /trips/search (exists) | Exists |  |
| Sort / Filters / Apply | Re-runs the search with filters | GET /trips/search/filters (exists), GET /trips/search | Exists |  |
| Trip card | Opens trip details | GET /trips/:tripId (exists) | Exists |  |

### F.4 Trip details

| Item | Value |
|---|---|
| Feature / phase | Search and trip details / Phase 3 |
| Files | `discovery_customer_screen.dart`, `discovery_customer.ts`, `discovery_customer.service.ts` |
| On the screen | Operator, bus type, amenities, route timeline with stops, boarding and dropping points, per-seat-type prices, cancellation policy, rating, Select seats. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Select seats | Opens the seat map | GET /trips/:tripId/seats | New | inventory |
| Bus no longer available | Shown when the trip was cancelled, sold out or unpublished | GET /trips/:tripId returns 410 | New |  |

### F.5 Select seats

| Item | Value |
|---|---|
| Feature / phase | Seat selection and hold / Phase 3 |
| Files | `seats_customer_screen.dart`, `seats_customer.ts`, `seats_customer.service.ts` |
| On the screen | Seat map (seater and sleeper, ladies seats, blocked, held, sold), price on each seat by seat type, running total, limit of 6. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Tap a seat | Selects or unselects locally; the limit of 6 is shown | none until Hold | UI |  |
| Continue (hold) | Holds the seats for 10 minutes atomically; asks to sign in if needed | POST /trips/:tripId/seat-locks | New | Redis lock + inventory; returns holdId and expiry |
| Back / timer end | Releases the hold | DELETE /trips/:tripId/seat-locks/:holdId | New |  |
| Live seat changes | Other people's holds and sales appear without reload | Socket.IO room trip:{id} | New |  |

### F.6 Sign in sheet (opens at Continue)

| Item | Value |
|---|---|
| Feature / phase | Sign-in and access control / Phase 0 |
| Files | `auth_access_customer_screen.dart`, `auth_access_customer.ts`, `auth_access_customer.service.ts` |
| On the screen | Mobile number, Continue, code boxes, Verify, Change number, Resend, Continue with Google, Continue with Apple. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Continue | Sends the WhatsApp code | POST /auth/otp/send (exists) | Exists | sessions |
| Verify | Checks the code and signs in | POST /auth/otp/verify (exists) | Exists |  |
| Resend / Change number | Resend after a countdown; change goes back | POST /auth/otp/send (exists) | Exists |  |
| Google / Apple | Signs in with the provider token | POST /auth/social/google, POST /auth/social/apple | Exists | Google exists for admin and client; Apple is new |

### F.7 Boarding and dropping

| Item | Value |
|---|---|
| Feature / phase | Booking, passengers and bookings lists / Phase 3 |
| Files | `booking_customer_screen.dart`, `booking_customer.ts`, `booking_customer.service.ts` |
| On the screen | Two tabs (Boarding, Dropping), points with time and address, map link, Continue. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Boarding / Dropping tabs | Switches the list | GET /trips/:tripId/points (new, also returned inside trip details) | New | places |
| Open in maps | Opens the map app for the point | none (deep link) | UI |  |
| Continue | Stores the chosen points in the draft booking | PATCH /customer/booking-drafts/:holdId | New | bookings (draft) |

### F.8 Passenger details

| Item | Value |
|---|---|
| Feature / phase | Booking, passengers and bookings lists / Phase 3 |
| Files | `booking_customer_screen.dart`, `booking_customer.ts`, `booking_customer.service.ts` |
| On the screen | One block per seat (Full name, Age, Gender; ladies-only seat rule), Use my profile, Contact (Mobile *, Email *), GST details (GSTIN, Company name). |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Use my profile | Fills passenger 1 and the contact | GET /customer/profile | New | customers |
| Continue | Validates and saves passengers and contact; 10-digit mobile, valid email, GSTIN pattern, age 1 to 99, female-only seats | PATCH /customer/booking-drafts/:holdId | New |  |

### F.9 Review booking

| Item | Value |
|---|---|
| Feature / phase | Booking, passengers and bookings lists / Phase 3 |
| Files | `booking_customer_screen.dart`, `booking_customer.ts`, `booking_customer.service.ts` |
| On the screen | Passengers, coupon box (Apply, Remove), fare breakup (fare, convenience fee, GST, discount, total), cancellation policy, agree checkbox, Proceed to pay. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Apply coupon | Validates the code for this trip and user | POST /customer/coupons/validate | New | offers |
| Remove coupon | Removes it | DELETE /customer/booking-drafts/:holdId/coupon | New |  |
| Fare breakup | Price computed on the server: fare + commission + fee + GST - discount | GET /customer/booking-drafts/:holdId/price | New | commissions, payoutCfg |
| Proceed to pay | Creates the booking in PENDING and the Razorpay order (idempotent) | POST /customer/bookings (Idempotency-Key header) | New | bookings, payments |

### F.10 Payment

| Item | Value |
|---|---|
| Feature / phase | Payments / Phase 3 |
| Files | `payments_customer_screen.dart`, `payments_customer.ts`, `payments_customer.service.ts` |
| On the screen | Payment methods (UPI apps, card, netbanking, wallet), processing screen, failure screen (Retry payment, Change payment method, Back to review). |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Pay now | Opens Razorpay checkout with the server order | POST /customer/bookings/:id/pay (returns Razorpay order) | New | payments |
| Payment result | App sends the Razorpay result; the server verifies the signature and also trusts its own webhook | POST /customer/bookings/:id/verify-payment and POST /webhooks/razorpay | New | payments, bookings |
| Retry / Change method | New attempt on the same booking while the hold lasts | POST /customer/bookings/:id/pay | New |  |

### F.11 Booking confirmed

| Item | Value |
|---|---|
| Feature / phase | Ticket, PNR and QR / Phase 3 |
| Files | `tickets_pdf_customer_screen.dart`, `tickets_pdf_customer.ts`, `tickets_pdf_customer.service.ts` |
| On the screen | PNR (copy), ticket, share trip, add to calendar, View the messages, My trips. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Copy PNR | Copies | none | UI |  |
| View ticket | Opens e-ticket | GET /customer/bookings/:id | New | bookings |
| Add to calendar | Downloads an .ics file | GET /customer/bookings/:id/calendar.ics | New |  |
| View the messages | Opens the messages page | GET /customer/messages | New | messages |

### F.12 E-ticket

| Item | Value |
|---|---|
| Feature / phase | Ticket, PNR and QR / Phase 3 |
| Files | `tickets_pdf_customer_screen.dart`, `tickets_pdf_customer.ts`, `tickets_pdf_customer.service.ts` |
| On the screen | QR to show the conductor, passengers and seats, boarding and dropping, operator contact, PDF, share. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Call operator | Dials the operator contact | none (tel link) | UI |  |
| Download PDF | Ticket PDF | GET /customer/bookings/:id/ticket.pdf | New |  |
| Share trip | Opens the sharing screen | see Trip sharing | New |  |

### F.13 My trips (tab)

| Item | Value |
|---|---|
| Feature / phase | My Trips / Phase 4 |
| Files | `my_trips_customer_screen.dart`, `my_trips_customer.ts`, `my_trips_customer.service.ts` |
| On the screen | Tabs Upcoming, Completed, Cancelled; booking cards. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Tabs | Filter by status | GET /customer/bookings?status= | New | bookings |
| Card tap | Opens booking details | GET /customer/bookings/:id | New |  |

### F.14 Booking details

| Item | Value |
|---|---|
| Feature / phase | My Trips / Phase 4 |
| Files | `my_trips_customer_screen.dart`, `my_trips_customer.ts`, `my_trips_customer.service.ts` |
| On the screen | Status, PNR, route, seats, amount, boarding point, buttons Track, Ticket, Share, Cancel, Refund status, Support. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Track | Opens live tracking when the trip is running | GET /customer/bookings/:id/tracking | New | live |
| Cancel booking | Opens cancel screen | GET /customer/bookings/:id/cancel-quote | New | cancelSlabs |
| Refund status | Opens refund screen | GET /customer/refunds/:bookingId | New | refunds |

### F.15 Cancel booking

| Item | Value |
|---|---|
| Feature / phase | Cancellation and refunds / Phase 4 |
| Files | `refunds_customer_screen.dart`, `refunds_customer.ts`, `refunds_customer.service.ts` |
| On the screen | Select seats to cancel, refund estimate from the slab, reason, Cancel booking. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Refund estimate | Slab by hours before departure | GET /customer/bookings/:id/cancel-quote?seats= | New |  |
| Cancel | Cancels the chosen seats, frees them, starts the refund, sends messages | POST /customer/bookings/:id/cancel | New | bookings, refunds, inventory, messages |

### F.16 Refund status

| Item | Value |
|---|---|
| Feature / phase | Cancellation and refunds / Phase 4 |
| Files | `refunds_customer_screen.dart`, `refunds_customer.ts`, `refunds_customer.service.ts` |
| On the screen | Amount, status steps (initiated, processing, completed), reference. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Open | Shows the refund | GET /customer/refunds/:bookingId | New | refunds |

### F.17 Live tracking

| Item | Value |
|---|---|
| Feature / phase | Live tracking / Phase 5 |
| Files | `tracking_customer_screen.dart`, `tracking_customer.ts`, `tracking_customer.service.ts` |
| On the screen | Map with the bus, ETA, driver and bus details, Call, SOS and safety button, share. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Live position | Receives GPS every few seconds | Socket.IO room tracking:{tripId} and GET /customer/bookings/:id/tracking | New | live |
| SOS and safety | Opens the safety screen | see Women safety | New |  |
| Call driver or operator | Dial | none (tel link) | UI |  |

### F.18 Women safety and SOS

| Item | Value |
|---|---|
| Feature / phase | SOS and women safety / Phase 5 |
| Files | `sos_customer_screen.dart`, `sos_customer.ts`, `sos_customer.service.ts` |
| On the screen | Press-and-hold SOS ring, I am safe (cancel), emergency contacts (add, remove), helplines, share trip. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Hold SOS | Sends the alert with live location; nothing is sent until the ring is full | POST /customer/sos | New | sos |
| I am safe | Cancels a fresh alert | POST /customer/sos/:id/cancel | New | sos |
| Add / remove contact | Emergency contacts of the customer | POST /customer/emergency-contacts, DELETE /customer/emergency-contacts/:id | New | customers |
| Status updates | Acknowledged, resolved, false alarm arrive as notifications | Socket.IO + notification | New |  |

### F.19 Trip sharing

| Item | Value |
|---|---|
| Feature / phase | Trip sharing / Phase 5 |
| Files | `sharing_customer_screen.dart`, `sharing_customer.ts`, `sharing_customer.service.ts` |
| On the screen | Share link (WhatsApp, SMS, Copy), people with access, Stop sharing. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Start sharing | Creates the link, expires after the trip | POST /customer/trip-shares | New | sharing |
| WhatsApp / SMS / Copy | Sends the link | POST /customer/trip-shares/:id/send | New |  |
| Stop sharing | Revokes | DELETE /customer/trip-shares/:id | New |  |
| Family view (public link) | Read-only live page | GET /public/share/:token | New |  |

### F.20 Notifications

| Item | Value |
|---|---|
| Feature / phase | Notifications and event router / Phase 0 |
| Files | `notifications_customer_screen.dart`, `notifications_customer.ts`, `notifications_customer.service.ts` |
| On the screen | List of notifications with read and unread, Mark all read. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| List / open | Marks one read | GET /notifications, POST /notifications/:id/read (exist) | Exists | inbox |
| Mark all read |  | POST /notifications/read-all (exists) | Exists |  |

### F.21 Offers and promotions

| Item | Value |
|---|---|
| Feature / phase | Offers and coupons / Phase 3 |
| Files | `offers_customer_screen.dart`, `offers_customer.ts`, `offers_customer.service.ts` |
| On the screen | Offer cards with code, Copy, Terms apply. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| List | Active offers | GET /offers | New | offers |
| Terms | Shows terms | GET /offers/:id | New |  |

### F.22 Messages sent to me

| Item | Value |
|---|---|
| Feature / phase | WhatsApp and email messages / Phase 0 |
| Files | `messages_customer_screen.dart`, `messages_customer.ts`, `messages_customer.service.ts` |
| On the screen | Copies of the WhatsApp messages and emails Abra sent, open one to read. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| List / open |  | GET /customer/messages, GET /customer/messages/:id | New | messages |

### F.23 Support (tab) and ticket

| Item | Value |
|---|---|
| Feature / phase | Support tickets / Phase 4 |
| Files | `support_customer_screen.dart`, `support_customer.ts`, `support_customer.service.ts` |
| On the screen | Help centre (FAQs), Contact support (call), My tickets, New ticket with category, subject, message and proof file; ticket thread with replies. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| FAQs | Help centre | GET /faqs | New | faqs |
| New ticket | Creates a ticket with proof files | POST /customer/tickets | New | tickets |
| My tickets | List and thread | GET /customer/tickets, GET /customer/tickets/:id | New |  |
| Reply | Adds a message with proof | POST /customer/tickets/:id/replies | New |  |
| Contact support | Dial the support number | GET /contact-info | New | contact |

### F.24 Profile (tab), edit, notification settings

| Item | Value |
|---|---|
| Feature / phase | Customers and profile / Phase 4 |
| Files | `customers_customer_screen.dart`, `customers_customer.ts`, `customers_customer.service.ts` |
| On the screen | Signed-in details, Edit profile (Full name, Email *, mobile read-only), Notification settings, Language, Help centre, Messages, Delete account, Sign out. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Save profile | Name and email | PATCH /customer/profile | New | customers |
| Notification settings | Toggles per channel and topic | PUT /customer/notification-settings | New | customers |
| Language | Saves the language | PATCH /customer/profile | New |  |
| Sign out | Revokes this session | POST /auth/logout (exists) | Exists | sessions |
| Delete account | Deletes personal data after confirmation; past financial records stay | DELETE /customer/account | New | customers |

### F.25 Information pages

| Item | Value |
|---|---|
| Feature / phase | Information pages and FAQs / Phase 4 |
| Files | `content_customer_screen.dart`, `content_customer.ts`, `content_customer.service.ts` |
| On the screen | About, Terms, Privacy, Refund policy, Contact. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Open page |  | GET /pages/:slug | New | pages |

### F.26 AI assistant

| Item | Value |
|---|---|
| Feature / phase | AI assistant (Groq) / Phase 0 |
| Files | `assistant_customer_screen.dart`, `assistant_customer.ts`, `assistant_customer.service.ts` |
| On the screen | Chat sheet with suggestions (my trips, track, refund, safety), voice input, answers in the user's language. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Send / voice | Asks the assistant | POST /assistant/chat (streams) | New | Groq via backend; sees only this customer's data |

## Appendix G. Driver app (new app, Android): every screen and endpoint

The driver app does not exist yet. Phase 5 builds sign-in, trips, check-in, start and end, delay, GPS and SOS; Phase 9 adds reports and checklists.

> **Rule:** Build the real screens to look and behave exactly like the demo (`prototypes/driver_demo_model.html`): same layout, wording, order, colours, dialogs and states.

### G.1 Sign in

| Item | Value |
|---|---|
| Feature / phase | Driver app: trips and check-in / Phase 5 |
| Files | `driver_core_driver_screen.dart`, `driver_core_driver.ts`, `driver_core_driver.service.ts` |
| On the screen | Phone and code (demo picks a driver). |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Sign in | Driver sign-in with the WhatsApp code | POST /auth/otp/send, POST /auth/otp/verify (exist) | Exists | opStaff, sessions |

### G.2 Home (tab)

| Item | Value |
|---|---|
| Feature / phase | Driver app: trips and check-in / Phase 5 |
| Files | `driver_core_driver_screen.dart`, `driver_core_driver.ts`, `driver_core_driver.service.ts` |
| On the screen | Greeting, next trip card, running trip, reports-to-send banner, SOS button always visible. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Trip cards | Trips assigned to this driver | GET /driver/trips?status= | New | trips |
| Reports to send banner | Count of due and overdue reports | GET /driver/reports/due | New | driverReports |
| SOS | Raises a driver SOS | POST /driver/sos | New | sos |

### G.3 Your trip (tab)

| Item | Value |
|---|---|
| Feature / phase | Driver app: trips and check-in / Phase 5 |
| Files | `driver_core_driver_screen.dart`, `driver_core_driver.ts`, `driver_core_driver.service.ts` |
| On the screen | Trip details, passenger list with check-in, buttons Board, Start, Resume, End, Delay. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Passenger list | Booked passengers and seats | GET /driver/trips/:id/manifest | New | bookings |
| Check in | Marks a passenger checked in (QR or manual) | POST /driver/trips/:id/check-in | New | trips.checkedIn |
| Board | Status BOARDING; notifies customers | POST /driver/trips/:id/board | New |  |
| Start (opens pre-trip checklist) | Runs the checklist first, then starts | POST /driver/trips/:id/start (with checklist) | New | tripChecks, trips |
| Delay | Sets minutes and reason with proof; notifies customers, operator, admin | POST /driver/trips/:id/delay | New |  |
| End (opens end checklist) | Runs the end checklist, then ends | POST /driver/trips/:id/end (with checklist) | New |  |
| GPS | Sends position while the trip runs | POST /driver/trips/:id/location (batched) or Socket.IO | New | live |

### G.4 Reports (tab)

| Item | Value |
|---|---|
| Feature / phase | Driver reports / Phase 9 |
| Files | `driver_reports_driver_screen.dart`, `driver_reports_driver.ts`, `driver_reports_driver.service.ts` |
| On the screen | To send (Daily, Weekly, each with state Due, Overdue, Sent back), Report something now (Incident, Bus problem, Expense claim), Sent by you. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| To send list | Reports due for this driver | GET /driver/reports/due | New | driverReports |
| Open a report | Shows system numbers (trips, distance, passengers, no-shows, delays, on-time, SOS, checklists) and the questions the operator set | GET /driver/reports/preview?type&period | New | computed on the server from trips, bookings, tripChecks, sos |
| Save draft / Send report | Stores answers and files; on send, freezes the system numbers | POST /driver/reports, PATCH /driver/reports/:id, POST /driver/reports/:id/send | New | driverReports |
| Report something now | Incident, bus problem or expense claim | POST /driver/reports (type event) | New |  |
| Sent by you | List and view | GET /driver/reports | New |  |

### G.5 Before you start

| Item | Value |
|---|---|
| Feature / phase | Driver rules and trip checklists / Phase 9 |
| Files | `driver_rules_driver_screen.dart`, `driver_rules_driver.ts`, `driver_rules_driver.service.ts` |
| On the screen | The checklist the operator set: automatic checks (licence, bus papers, location, rest hours, passengers checked in), yes/no, choice and number items with photo where required; summary (all clear, warnings, blocked); override with reason and proof for non-locked failures. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Automatic checks | Server evaluates licence, papers, location, rest, manifest | GET /driver/trips/:id/checklist | New | driverRules, opStaff, buses |
| Answer items | Stored on the device until Start | none | UI |  |
| Start trip | Server re-checks; blocks if a blocking item failed; with override reason and proof it starts and notifies operator and admin | POST /driver/trips/:id/start | New | tripChecks |

### G.6 End of trip

| Item | Value |
|---|---|
| Feature / phase | Driver rules and trip checklists / Phase 9 |
| Files | `driver_rules_driver_screen.dart`, `driver_rules_driver.ts`, `driver_rules_driver.service.ts` |
| On the screen | End odometer with photo, new damage, lost items, fuel filled, cash collected, bus parked and locked. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| End trip | Saves the end check and closes the trip | POST /driver/trips/:id/end | New | tripChecks, trips |

### G.7 Notifications

| Item | Value |
|---|---|
| Feature / phase | Notifications and event router / Phase 0 |
| Files | `notifications_driver_screen.dart`, `notifications_driver.ts`, `notifications_driver.service.ts` |
| On the screen | List, Mark all read. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| List / read all |  | GET /notifications, POST /notifications/read-all (exist) | Exists | inbox |

### G.8 Profile

| Item | Value |
|---|---|
| Feature / phase | Driver app: trips and check-in / Phase 5 |
| Files | `driver_core_driver_screen.dart`, `driver_core_driver.ts`, `driver_core_driver.service.ts` |
| On the screen | Name, company, licence expiry, Sign out. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Sign out |  | POST /auth/logout (exists) | Exists |  |

### G.9 AI assistant

| Item | Value |
|---|---|
| Feature / phase | AI assistant (Groq) / Phase 0 |
| Files | `assistant_driver_screen.dart`, `assistant_driver.ts`, `assistant_driver.service.ts` |
| On the screen | Chat and voice: start trip, end trip, report delay, my trips. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Send / voice | Start and end now open the checklists | POST /assistant/chat | New |  |

## Appendix H. Public website (Next.js): every screen and endpoint

Server-rendered pages for search engines; booking hands over to the customer app.

> **Rule:** Build the real screens to look and behave exactly like the demo (`prototypes/website_demo_model.html`): same layout, wording, order, colours, dialogs and states.

### H.1 Home

| Item | Value |
|---|---|
| Feature / phase | Public website / Phase 10 |
| Files | `website_public_page.tsx`, `website_public.ts`, `website_public.service.ts` |
| On the screen | Header (logo, language, menu), search box with Swap and Search, banners, offers, popular routes, footer. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Search | Opens results and hands over to the customer app to book | GET /trips/search (exists), GET /cities (exists) | Exists | trips, cities |
| Banners / offers / popular routes | Public lists | GET /banners, GET /offers, GET /popular-routes | New |  |

### H.2 Search results

| Item | Value |
|---|---|
| Feature / phase | Public website / Phase 10 |
| Files | `website_public_page.tsx`, `website_public.ts`, `website_public.service.ts` |
| On the screen | Trips for the route with price from, Book in app. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Book in app | Deep link to the customer app | none | UI |  |

### H.3 Popular routes

| Item | Value |
|---|---|
| Feature / phase | Public website / Phase 10 |
| Files | `website_public_page.tsx`, `website_public.ts`, `website_public.service.ts` |
| On the screen | Route pages for search engines. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Route page | Server-rendered page with structured data | GET /public/routes/:slug | New | routes |

### H.4 Offers

| Item | Value |
|---|---|
| Feature / phase | Public website / Phase 10 |
| Files | `website_public_page.tsx`, `website_public.ts`, `website_public.service.ts` |
| On the screen | Offer cards with Copy code. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| List |  | GET /offers | New | offers |

### H.5 Track my bus

| Item | Value |
|---|---|
| Feature / phase | Live tracking / Phase 5 |
| Files | `tracking_public_page.tsx`, `tracking_public.ts`, `tracking_public.service.ts` |
| On the screen | PNR and phone, Track. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Track | Shows the bus position for a booking | POST /public/track (PNR + phone) | New | bookings, live |

### H.6 Help and FAQs

| Item | Value |
|---|---|
| Feature / phase | Information pages and FAQs / Phase 4 |
| Files | `content_public_page.tsx`, `content_public.ts`, `content_public.service.ts` |
| On the screen | FAQs, Contact us. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| FAQs |  | GET /faqs | New | faqs |

### H.7 Contact us

| Item | Value |
|---|---|
| Feature / phase | Information pages and FAQs / Phase 4 |
| Files | `content_public_page.tsx`, `content_public.ts`, `content_public.service.ts` |
| On the screen | Contact form. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Send | Creates an enquiry for admin | POST /public/enquiries (type contact) | New | contact |

### H.8 Partner with us

| Item | Value |
|---|---|
| Feature / phase | Public website / Phase 10 |
| Files | `website_public_page.tsx`, `website_public.ts`, `website_public.service.ts` |
| On the screen | Form (company, city, phone, email). |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Send | Creates a partner enquiry for admin | POST /public/enquiries (type partner) | New | contact |

### H.9 About, Terms, Privacy

| Item | Value |
|---|---|
| Feature / phase | Information pages and FAQs / Phase 4 |
| Files | `content_public_page.tsx`, `content_public.ts`, `content_public.service.ts` |
| On the screen | Static pages from the CMS. |

| Button / element | What it does | Endpoint | Status | Data |
|---|---|---|---|---|
| Open |  | GET /pages/:slug | New | pages |

## Appendix I. The backend today

Read from the controllers in `backend/src`: 26 controllers, 113 routes. Everything above marked "Exists" is in this list. Everything marked "New" is not.

| Module | Routes |
|---|---|
| admin-banners | GET /admin/banners<br>GET /admin/banners/:id<br>POST /admin/banners<br>PUT /admin/banners/:id<br>POST /admin/banners/:id/active<br>POST /admin/banners/:id/image<br>DELETE /admin/banners/:id/image<br>DELETE /admin/banners/:id<br>GET /admin/banners<br>GET /admin/banners/:id/image |
| audit-logs | GET /audit-logs |
| authentication | POST /auth/otp/send<br>POST /auth/otp/verify<br>POST /auth/register<br>POST /auth/login<br>POST /auth/mfa/verify<br>POST /auth/refresh<br>POST /auth/logout<br>POST /auth/password/reset<br>GET /me<br>POST /me/password<br>POST /auth/logout-all<br>GET /me/mfa<br>POST /me/mfa/totp/enroll<br>POST /me/mfa/totp/activate<br>POST /me/mfa/totp/disable |
| bus-types | GET /catalogue/bus-types<br>POST /catalogue/bus-types<br>PUT /catalogue/bus-types/:id<br>POST /catalogue/bus-types/:id/active |
| buses | GET /catalogue/buses<br>GET /catalogue/buses/:id<br>POST /catalogue/buses<br>PUT /catalogue/buses/:id<br>POST /catalogue/buses/:id/status |
| cities | GET /catalogue/cities<br>GET /catalogue/cities/:id<br>POST /catalogue/cities<br>PUT /catalogue/cities/:id<br>POST /catalogue/cities/:id/active<br>GET /cities |
| document-types | GET /catalogue/document-types<br>POST /catalogue/document-types<br>PUT /catalogue/document-types/:id<br>POST /catalogue/document-types/:id/active |
| files | POST /files<br>GET /files/:id<br>GET /files/:id/content |
| health | GET /health/live<br>GET /health/ready |
| locations | GET /catalogue/locations<br>GET /catalogue/locations/:id<br>POST /catalogue/locations<br>PUT /catalogue/locations/:id<br>POST /catalogue/locations/:id/active |
| notifications | GET /notifications<br>GET /notifications/unread-count<br>POST /notifications/read-all<br>POST /notifications/devices<br>POST /notifications/devices/remove<br>POST /notifications/:id/read |
| onboarding | POST /onboarding/invitations<br>GET /onboarding/invitations<br>POST /onboarding/invitations/:id/resend<br>POST /onboarding/invitations/:id/revoke<br>POST /onboarding/invitations/inspect<br>POST /onboarding/invitations/accept<br>GET /onboarding/submissions<br>GET /onboarding/submissions/:id<br>POST /onboarding/submissions<br>PUT /onboarding/submissions/:id/documents/:documentTypeId<br>DELETE /onboarding/submissions/:id/documents/:documentTypeId<br>POST /onboarding/submissions/:id/submit<br>POST /onboarding/submissions/:id/documents/:documentTypeId/review<br>POST /onboarding/submissions/:id/approve<br>POST /onboarding/submissions/:id/reject |
| operators | GET /catalogue/operators<br>GET /catalogue/operators/:id<br>POST /catalogue/operators<br>PUT /catalogue/operators/:id<br>POST /catalogue/operators/:id/status |
| rbac | GET /permissions<br>GET /roles<br>GET /me/permissions<br>GET /users/:userId/permissions<br>PUT /users/:userId/roles<br>PUT /users/:userId/permissions/:permissionKey<br>DELETE /users/:userId/permissions/:permissionKey<br>PUT /users/:userId/data-scope |
| routes | GET /catalogue/routes<br>GET /catalogue/routes/:id<br>POST /catalogue/routes<br>PUT /catalogue/routes/:id<br>POST /catalogue/routes/:id/status |
| sessions | GET /me/sessions<br>DELETE /me/sessions/:sessionId |
| system-settings | GET /settings/integrations/email<br>PUT /settings/integrations/email<br>POST /settings/integrations/email/test-connection<br>POST /settings/integrations/email/test-email<br>GET /settings/integrations/whatsapp<br>POST /settings/integrations/whatsapp/test-connection<br>PUT /settings/integrations/whatsapp |
| trips | GET /trips/search<br>GET /trips/search/filters<br>GET /trips/:tripId<br>GET /catalogue/trips<br>GET /catalogue/trips/:id<br>POST /catalogue/trips<br>PUT /catalogue/trips/:id<br>POST /catalogue/trips/:id/publish<br>POST /catalogue/trips/:id/cancel |
| users | GET /users |

### I.1 Controllers in `<feature>_manage` style files (not in the table above)

Checked 12 October 2026 against `backend/src`. These routes exist and count as "Exists".

| File | Routes |
|---|---|
| rbac/access_matrix_admin_manage.ts | GET /access-matrix<br>PUT /access-matrix/roles/:roleKey/pages/:pageId<br>PUT /access-matrix/roles/:roleKey<br>POST /access-matrix/roles<br>PATCH /access-matrix/roles/:roleKey<br>DELETE /access-matrix/roles/:roleKey |
| authentication/google_sign_in.ts | POST /auth/google<br>POST /auth/apple<br>POST /auth/client/otp/verify<br>GET /client/kyc/login-methods<br>POST /client/kyc/login-methods/phone<br>POST /client/kyc/login-methods/social |
| onboarding/client_kyc.ts | GET /client/kyc<br>PUT /client/kyc |
| system-settings/admin_kyc_configuration.ts | GET /settings/kyc-configuration<br>PUT /settings/kyc-configuration<br>POST /settings/kyc-configuration/validate-import<br>POST /settings/kyc-configuration/preview |

Corrections found on the same check: Apple sign-in already has a route; the KYC questionnaire is one configuration document at `/settings/kyc-configuration`, not the `/admin/kyc/...` routes named in D.12 (to be rewritten in Phase 1 step 10).

### I.4 Routes added in Phase 1 (13 October 2026)

All need a bearer token and the permission shown. They live on the branch `phase1-catalogue-kyc`.

| Area | Routes | Permission |
|---|---|---|
| Delete and Undo | `DELETE` and `POST .../restore` on `/catalogue/cities/:id`, `/catalogue/locations/:id`, `/catalogue/bus-types/:id`, `/catalogue/document-types/:id`, `/catalogue/operators/:id`, `/onboarding/invitations/:id`, `/admin/banners/:id` | `catalogue.delete`, `documents.delete`, `operators.delete`, `banners.delete` |
| Read one | `GET /catalogue/bus-types/:id`, `GET /catalogue/document-types/:id`, `GET /onboarding/invitations/:id` | `catalogue.read`, `documents.read`, `operators.create` |
| Invitations | `PATCH /onboarding/invitations/:id`; the list takes `status=EXPIRED` or `PENDING` (still valid) and `search` | `operators.create` |
| Banners | `POST /admin/banners/:id/duplicate`, `/archive`, `/unarchive`; `PATCH /admin/banners/order`; `GET /banners?viewer=` (public) | `banners.manage`; the two reads need `banners.read` |
| Export | `GET .../export?format=csv\|xlsx` on `/catalogue/cities`, `/catalogue/locations`, `/catalogue/bus-types`, `/catalogue/document-types`, `/catalogue/operators`, `/onboarding/invitations`, `/onboarding/submissions`, `/admin/banners` (same filters as the list) | `catalogue.export`, `documents.export`, `operators.export`, `banners.export` |
| Import | `GET /catalogue/cities/import-template`, `POST /catalogue/cities/import?dryRun=true\|false`; the same two on `/catalogue/locations` | `catalogue.manage` |
| Amenities | `GET`, `POST /admin/amenities`; `PATCH /admin/amenities/:id/active`; `GET /catalogue/amenities` (the ones switched on, for bus forms) | `catalogue.read`, `catalogue.manage`, `buses.read` |

The KYC questionnaire routes stay as in I.1 (`/settings/kyc-configuration`); its export is part of step 10.

### I.2 Modules with no controller yet

`analytics`, `api-clients`, `bookings`, `boarding-points`, `chatbot`, `check-in`, `commissions`, `content`, `coupons`, `customers`, `drivers`, `fares`, `feature-flags`, `inventory`, `live-tracking`, `maintenance`, `notification-templates`, `offers`, `operator-staff`, `partner-webhooks`, `partners`, `passengers`, `payments`, `popular-routes`, `reconciliation`, `refunds`, `reports`, `schedules`, `seat-layouts`, `settlements`, `support`, `tickets`, `translations`, `trip-operations`, `whatsapp`, `women-safety`. These folders exist as empty placeholders; they get their three-file packages in the phases above.

### I.3 Coverage of the demo buttons

| App | Buttons mapped to an existing endpoint | Buttons that need a new endpoint | UI-only buttons | Not mapped |
|---|---|---|---|---|
| Admin portal | 35 | 221 | 123 | 0 |
| Client portal | 12 | 57 | 53 | 0 |

Customer app: 26 screens, 78 mapped elements. Driver app: 9 screens, 23. Website: 9 pages, 10.

## Appendix J. Feature file index (the three files of every feature)

One row per feature and audience. Paths are relative to the repository root. Flutter files live in the app's `lib/features/<feature>/` folder; backend files in `backend/src/modules/<first module>/`. A "(backend only)" feature has no screen. Update the Status column as work finishes.

| Phase | Feature | Screen file (all widgets inside) | Backend file (schema, DTOs, controller, module) | Service file | Status |
|---|---|---|---|---|---|
| Phase 0 | Sign-in and access control | apps/customer_app/lib/features/auth_access/auth_access_customer_screen.dart | backend/src/modules/authentication/auth_access_customer.ts | backend/src/modules/authentication/auth_access_customer.service.ts | Not started |
| Phase 0 | Sign-in and access control | apps/driver_app/lib/features/auth_access/auth_access_driver_screen.dart | backend/src/modules/authentication/auth_access_driver.ts | backend/src/modules/authentication/auth_access_driver.service.ts | Not started |
| Phase 0 | Audit log | apps/admin_app/lib/features/audit/audit_admin_manage_screen.dart | backend/src/modules/audit-logs/audit_admin_manage.ts | backend/src/modules/audit-logs/audit_admin_manage.service.ts | Not started |
| Phase 0 | Notifications and event router | apps/admin_app/lib/features/notifications/notifications_admin_manage_screen.dart | backend/src/modules/notifications/notifications_admin_manage.ts | backend/src/modules/notifications/notifications_admin_manage.service.ts | Not started |
| Phase 0 | Notifications and event router | apps/client_portal/lib/features/notifications/notifications_client_manage_screen.dart | backend/src/modules/notifications/notifications_client_manage.ts | backend/src/modules/notifications/notifications_client_manage.service.ts | Not started |
| Phase 0 | Notifications and event router | apps/customer_app/lib/features/notifications/notifications_customer_screen.dart | backend/src/modules/notifications/notifications_customer.ts | backend/src/modules/notifications/notifications_customer.service.ts | Not started |
| Phase 0 | Notifications and event router | apps/driver_app/lib/features/notifications/notifications_driver_screen.dart | backend/src/modules/notifications/notifications_driver.ts | backend/src/modules/notifications/notifications_driver.service.ts | Not started |
| Phase 0 | File storage and proof attachments | (backend only) | backend/src/modules/files/files_core.ts | backend/src/modules/files/files_core.service.ts | Not started |
| Phase 0 | WhatsApp and email messages | apps/admin_app/lib/features/messages/messages_admin_manage_screen.dart | backend/src/modules/whatsapp/messages_admin_manage.ts | backend/src/modules/whatsapp/messages_admin_manage.service.ts | Not started |
| Phase 0 | WhatsApp and email messages | apps/customer_app/lib/features/messages/messages_customer_screen.dart | backend/src/modules/whatsapp/messages_customer.ts | backend/src/modules/whatsapp/messages_customer.service.ts | Not started |
| Phase 0 | Integrations, feature flags and maintenance | apps/admin_app/lib/features/settings/settings_admin_manage_screen.dart | backend/src/modules/system-settings/settings_admin_manage.ts | backend/src/modules/system-settings/settings_admin_manage.service.ts | Not started |
| Phase 0 | AI assistant (Groq) | apps/admin_app/lib/features/assistant/assistant_admin_manage_screen.dart | backend/src/modules/chatbot/assistant_admin_manage.ts | backend/src/modules/chatbot/assistant_admin_manage.service.ts | Not started |
| Phase 0 | AI assistant (Groq) | apps/customer_app/lib/features/assistant/assistant_customer_screen.dart | backend/src/modules/chatbot/assistant_customer.ts | backend/src/modules/chatbot/assistant_customer.service.ts | Not started |
| Phase 0 | AI assistant (Groq) | apps/driver_app/lib/features/assistant/assistant_driver_screen.dart | backend/src/modules/chatbot/assistant_driver.ts | backend/src/modules/chatbot/assistant_driver.service.ts | Not started |
| Phase 0 | Seed data and live updates | (backend only) | backend/src/modules/database/seed_core.ts | backend/src/modules/database/seed_core.service.ts | Not started |
| Phase 1 | Cities and places | apps/admin_app/lib/features/places/places_admin_manage_screen.dart | backend/src/modules/cities/places_admin_manage.ts | backend/src/modules/cities/places_admin_manage.service.ts | In progress (13 Oct 2026): view, delete and Undo, export, import done; tabs, filters and operator requests not yet. Files in use: `modules/cities/cities_admin_manage*`, `modules/locations/places_admin_manage*`, screens in `features/catalogue/pages/` |
| Phase 1 | Cities and places | apps/client_portal/lib/features/places/places_client_manage_screen.dart | backend/src/modules/cities/places_client_manage.ts | backend/src/modules/cities/places_client_manage.service.ts | Not started (step 5) |
| Phase 1 | Cities and places | apps/customer_app/lib/features/places/places_customer_screen.dart | backend/src/modules/cities/places_customer.ts | backend/src/modules/cities/places_customer.service.ts | Not started |
| Phase 1 | Bus types and amenities | apps/admin_app/lib/features/bus_types/bus_types_admin_manage_screen.dart | backend/src/modules/bus-types/bus_types_admin_manage.ts | backend/src/modules/bus-types/bus_types_admin_manage.service.ts | Done 13 Oct 2026: view, delete and Undo, export, amenities. Files in use: `modules/bus-types/bus_types_admin_manage*`, `modules/amenities/amenities_admin_manage*`, screen widget `amenities_card.dart` |
| Phase 1 | Required documents and KYC questionnaire | apps/admin_app/lib/features/kyc_config/kyc_config_admin_manage_screen.dart | backend/src/modules/document-types/kyc_config_admin_manage.ts | backend/src/modules/document-types/kyc_config_admin_manage.service.ts | In progress (13 Oct 2026): view, delete and Undo, export of documents done; the questionnaire waits for step 10 |
| Phase 1 | Operator invitations | apps/admin_app/lib/features/invitations/invitations_admin_manage_screen.dart | backend/src/modules/onboarding/invitations_admin_manage.ts | backend/src/modules/onboarding/invitations_admin_manage.service.ts | Done 13 Oct 2026: view, edit, Expired, search, delete and Undo, export. Files in use: `modules/onboarding/invitations_admin_manage*`, screen `features/invitations/invitations_page.dart` |
| Phase 1 | KYC review and company onboarding | apps/admin_app/lib/features/kyc/kyc_admin_manage_screen.dart | backend/src/modules/onboarding/kyc_admin_manage.ts | backend/src/modules/onboarding/kyc_admin_manage.service.ts | In progress (13 Oct 2026): export done; history in step 9. File in use: `modules/onboarding/kyc_admin_manage.ts` |
| Phase 1 | KYC review and company onboarding | apps/client_portal/lib/features/kyc/kyc_client_manage_screen.dart | backend/src/modules/onboarding/kyc_client_manage.ts | backend/src/modules/onboarding/kyc_client_manage.service.ts | Not started (steps 8 and 9) |
| Phase 1 | Operators | apps/admin_app/lib/features/operators/operators_admin_manage_screen.dart | backend/src/modules/operators/operators_admin_manage.ts | backend/src/modules/operators/operators_admin_manage.service.ts | In progress (13 Oct 2026): view, delete and Undo, export done; detail page, suspend with proof and payout in steps 6 and 7. File in use: `modules/operators/operators_admin_manage.ts` |
| Phase 1 | Banners | apps/admin_app/lib/features/banners/banners_admin_manage_screen.dart | backend/src/modules/admin-banners/banners_admin_manage.ts | backend/src/modules/admin-banners/banners_admin_manage.service.ts | Done 13 Oct 2026 except the Analytics tab: demo columns and form, Save draft and Publish, duplicate, archive, order, delete and Undo, export. Files in use: `modules/admin-banners/banners_admin_manage*`, screen `features/banners/admin_banners_manage.dart` |
| Phase 1 | Banners | apps/customer_app/lib/features/banners/banners_customer_screen.dart | backend/src/modules/admin-banners/banners_customer.ts | backend/src/modules/admin-banners/banners_customer.service.ts | Not started |
| Phase 1 | Banners | apps/public_website/app/banners/banners_public_page.tsx | backend/src/modules/admin-banners/banners_public.ts | backend/src/modules/admin-banners/banners_public.service.ts | Not started |
| Phase 2 | Buses and seat layouts | apps/admin_app/lib/features/buses/buses_admin_manage_screen.dart | backend/src/modules/buses/buses_admin_manage.ts | backend/src/modules/buses/buses_admin_manage.service.ts | Not started |
| Phase 2 | Buses and seat layouts | apps/client_portal/lib/features/buses/buses_client_manage_screen.dart | backend/src/modules/buses/buses_client_manage.ts | backend/src/modules/buses/buses_client_manage.service.ts | Not started |
| Phase 2 | Crew: drivers and conductors | apps/client_portal/lib/features/crew/crew_client_manage_screen.dart | backend/src/modules/operator-staff/crew_client_manage.ts | backend/src/modules/operator-staff/crew_client_manage.service.ts | Not started |
| Phase 2 | Routes, stops and boarding points | apps/client_portal/lib/features/routes/routes_client_manage_screen.dart | backend/src/modules/routes/routes_client_manage.ts | backend/src/modules/routes/routes_client_manage.service.ts | Not started |
| Phase 2 | Fares and schedules | apps/client_portal/lib/features/fares/fares_client_manage_screen.dart | backend/src/modules/fares/fares_client_manage.ts | backend/src/modules/fares/fares_client_manage.service.ts | Not started |
| Phase 2 | Trips and seat inventory | apps/admin_app/lib/features/trips/trips_admin_manage_screen.dart | backend/src/modules/trips/trips_admin_manage.ts | backend/src/modules/trips/trips_admin_manage.service.ts | Not started |
| Phase 2 | Trips and seat inventory | apps/client_portal/lib/features/trips/trips_client_manage_screen.dart | backend/src/modules/trips/trips_client_manage.ts | backend/src/modules/trips/trips_client_manage.service.ts | Not started |
| Phase 2 | Commission rules | apps/admin_app/lib/features/commission/commission_admin_manage_screen.dart | backend/src/modules/commissions/commission_admin_manage.ts | backend/src/modules/commissions/commission_admin_manage.service.ts | Not started |
| Phase 2 | Commission rules | apps/client_portal/lib/features/commission/commission_client_manage_screen.dart | backend/src/modules/commissions/commission_client_manage.ts | backend/src/modules/commissions/commission_client_manage.service.ts | Not started |
| Phase 2 | Payout and fee settings | apps/admin_app/lib/features/payout_cfg/payout_cfg_admin_manage_screen.dart | backend/src/modules/settlements/payout_cfg_admin_manage.ts | backend/src/modules/settlements/payout_cfg_admin_manage.service.ts | Not started |
| Phase 3 | Search and trip details | apps/customer_app/lib/features/discovery/discovery_customer_screen.dart | backend/src/modules/trips/discovery_customer.ts | backend/src/modules/trips/discovery_customer.service.ts | Not started |
| Phase 3 | Search and trip details | apps/public_website/app/discovery/discovery_public_page.tsx | backend/src/modules/trips/discovery_public.ts | backend/src/modules/trips/discovery_public.service.ts | Not started |
| Phase 3 | Seat selection and hold | apps/customer_app/lib/features/seats/seats_customer_screen.dart | backend/src/modules/inventory/seats_customer.ts | backend/src/modules/inventory/seats_customer.service.ts | Not started |
| Phase 3 | Booking, passengers and bookings lists | apps/admin_app/lib/features/booking/booking_admin_manage_screen.dart | backend/src/modules/bookings/booking_admin_manage.ts | backend/src/modules/bookings/booking_admin_manage.service.ts | Not started |
| Phase 3 | Booking, passengers and bookings lists | apps/client_portal/lib/features/booking/booking_client_manage_screen.dart | backend/src/modules/bookings/booking_client_manage.ts | backend/src/modules/bookings/booking_client_manage.service.ts | Not started |
| Phase 3 | Booking, passengers and bookings lists | apps/customer_app/lib/features/booking/booking_customer_screen.dart | backend/src/modules/bookings/booking_customer.ts | backend/src/modules/bookings/booking_customer.service.ts | Not started |
| Phase 3 | Offers and coupons | apps/admin_app/lib/features/offers/offers_admin_manage_screen.dart | backend/src/modules/coupons/offers_admin_manage.ts | backend/src/modules/coupons/offers_admin_manage.service.ts | Not started |
| Phase 3 | Offers and coupons | apps/client_portal/lib/features/offers/offers_client_manage_screen.dart | backend/src/modules/coupons/offers_client_manage.ts | backend/src/modules/coupons/offers_client_manage.service.ts | Not started |
| Phase 3 | Offers and coupons | apps/customer_app/lib/features/offers/offers_customer_screen.dart | backend/src/modules/coupons/offers_customer.ts | backend/src/modules/coupons/offers_customer.service.ts | Not started |
| Phase 3 | Offers and coupons | apps/public_website/app/offers/offers_public_page.tsx | backend/src/modules/coupons/offers_public.ts | backend/src/modules/coupons/offers_public.service.ts | Not started |
| Phase 3 | Payments | apps/admin_app/lib/features/payments/payments_admin_manage_screen.dart | backend/src/modules/payments/payments_admin_manage.ts | backend/src/modules/payments/payments_admin_manage.service.ts | Not started |
| Phase 3 | Payments | apps/customer_app/lib/features/payments/payments_customer_screen.dart | backend/src/modules/payments/payments_customer.ts | backend/src/modules/payments/payments_customer.service.ts | Not started |
| Phase 3 | Ticket, PNR and QR | apps/customer_app/lib/features/tickets_pdf/tickets_pdf_customer_screen.dart | backend/src/modules/tickets/tickets_pdf_customer.ts | backend/src/modules/tickets/tickets_pdf_customer.service.ts | Not started |
| Phase 4 | My Trips | apps/customer_app/lib/features/my_trips/my_trips_customer_screen.dart | backend/src/modules/bookings/my_trips_customer.ts | backend/src/modules/bookings/my_trips_customer.service.ts | Not started |
| Phase 4 | Cancellation and refunds | apps/admin_app/lib/features/refunds/refunds_admin_manage_screen.dart | backend/src/modules/refunds/refunds_admin_manage.ts | backend/src/modules/refunds/refunds_admin_manage.service.ts | Not started |
| Phase 4 | Cancellation and refunds | apps/customer_app/lib/features/refunds/refunds_customer_screen.dart | backend/src/modules/refunds/refunds_customer.ts | backend/src/modules/refunds/refunds_customer.service.ts | Not started |
| Phase 4 | Support tickets | apps/admin_app/lib/features/support/support_admin_manage_screen.dart | backend/src/modules/support/support_admin_manage.ts | backend/src/modules/support/support_admin_manage.service.ts | Not started |
| Phase 4 | Support tickets | apps/customer_app/lib/features/support/support_customer_screen.dart | backend/src/modules/support/support_customer.ts | backend/src/modules/support/support_customer.service.ts | Not started |
| Phase 4 | Support tickets | apps/public_website/app/support/support_public_page.tsx | backend/src/modules/support/support_public.ts | backend/src/modules/support/support_public.service.ts | Not started |
| Phase 4 | Customers and profile | apps/admin_app/lib/features/customers/customers_admin_manage_screen.dart | backend/src/modules/customers/customers_admin_manage.ts | backend/src/modules/customers/customers_admin_manage.service.ts | Not started |
| Phase 4 | Customers and profile | apps/customer_app/lib/features/customers/customers_customer_screen.dart | backend/src/modules/customers/customers_customer.ts | backend/src/modules/customers/customers_customer.service.ts | Not started |
| Phase 4 | Information pages and FAQs | apps/admin_app/lib/features/content/content_admin_manage_screen.dart | backend/src/modules/content/content_admin_manage.ts | backend/src/modules/content/content_admin_manage.service.ts | Not started |
| Phase 4 | Information pages and FAQs | apps/customer_app/lib/features/content/content_customer_screen.dart | backend/src/modules/content/content_customer.ts | backend/src/modules/content/content_customer.service.ts | Not started |
| Phase 4 | Information pages and FAQs | apps/public_website/app/content/content_public_page.tsx | backend/src/modules/content/content_public.ts | backend/src/modules/content/content_public.service.ts | Not started |
| Phase 5 | Driver app: trips and check-in | apps/driver_app/lib/features/driver_core/driver_core_driver_screen.dart | backend/src/modules/drivers/driver_core_driver.ts | backend/src/modules/drivers/driver_core_driver.service.ts | Not started |
| Phase 5 | Live tracking | apps/admin_app/lib/features/tracking/tracking_admin_manage_screen.dart | backend/src/modules/live-tracking/tracking_admin_manage.ts | backend/src/modules/live-tracking/tracking_admin_manage.service.ts | Not started |
| Phase 5 | Live tracking | apps/client_portal/lib/features/tracking/tracking_client_manage_screen.dart | backend/src/modules/live-tracking/tracking_client_manage.ts | backend/src/modules/live-tracking/tracking_client_manage.service.ts | Not started |
| Phase 5 | Live tracking | apps/customer_app/lib/features/tracking/tracking_customer_screen.dart | backend/src/modules/live-tracking/tracking_customer.ts | backend/src/modules/live-tracking/tracking_customer.service.ts | Not started |
| Phase 5 | Live tracking | apps/driver_app/lib/features/tracking/tracking_driver_screen.dart | backend/src/modules/live-tracking/tracking_driver.ts | backend/src/modules/live-tracking/tracking_driver.service.ts | Not started |
| Phase 5 | Live tracking | apps/public_website/app/tracking/tracking_public_page.tsx | backend/src/modules/live-tracking/tracking_public.ts | backend/src/modules/live-tracking/tracking_public.service.ts | Not started |
| Phase 5 | SOS and women safety | apps/admin_app/lib/features/sos/sos_admin_manage_screen.dart | backend/src/modules/women-safety/sos_admin_manage.ts | backend/src/modules/women-safety/sos_admin_manage.service.ts | Not started |
| Phase 5 | SOS and women safety | apps/customer_app/lib/features/sos/sos_customer_screen.dart | backend/src/modules/women-safety/sos_customer.ts | backend/src/modules/women-safety/sos_customer.service.ts | Not started |
| Phase 5 | SOS and women safety | apps/driver_app/lib/features/sos/sos_driver_screen.dart | backend/src/modules/women-safety/sos_driver.ts | backend/src/modules/women-safety/sos_driver.service.ts | Not started |
| Phase 5 | Trip sharing | apps/customer_app/lib/features/sharing/sharing_customer_screen.dart | backend/src/modules/women-safety/sharing_customer.ts | backend/src/modules/women-safety/sharing_customer.service.ts | Not started |
| Phase 5 | Incidents | apps/admin_app/lib/features/incidents/incidents_admin_manage_screen.dart | backend/src/modules/women-safety/incidents_admin_manage.ts | backend/src/modules/women-safety/incidents_admin_manage.service.ts | Not started |
| Phase 6 | Settlements and earnings | apps/admin_app/lib/features/settlements/settlements_admin_manage_screen.dart | backend/src/modules/settlements/settlements_admin_manage.ts | backend/src/modules/settlements/settlements_admin_manage.service.ts | Not started |
| Phase 6 | Settlements and earnings | apps/client_portal/lib/features/settlements/settlements_client_manage_screen.dart | backend/src/modules/settlements/settlements_client_manage.ts | backend/src/modules/settlements/settlements_client_manage.service.ts | Not started |
| Phase 7 | Dashboards and reports | apps/admin_app/lib/features/dashboard/dashboard_admin_manage_screen.dart | backend/src/modules/reports/dashboard_admin_manage.ts | backend/src/modules/reports/dashboard_admin_manage.service.ts | Not started |
| Phase 7 | Dashboards and reports | apps/client_portal/lib/features/dashboard/dashboard_client_manage_screen.dart | backend/src/modules/reports/dashboard_client_manage.ts | backend/src/modules/reports/dashboard_client_manage.service.ts | Not started |
| Phase 7 | Announcements and popular routes | apps/admin_app/lib/features/announce/announce_admin_manage_screen.dart | backend/src/modules/content/announce_admin_manage.ts | backend/src/modules/content/announce_admin_manage.service.ts | Not started |
| Phase 7 | Announcements and popular routes | apps/public_website/app/announce/announce_public_page.tsx | backend/src/modules/content/announce_public.ts | backend/src/modules/content/announce_public.service.ts | Not started |
| Phase 7 | Staff, roles and access matrix | apps/admin_app/lib/features/staff/staff_admin_manage_screen.dart | backend/src/modules/rbac/staff_admin_manage.ts | backend/src/modules/rbac/staff_admin_manage.service.ts | Not started |
| Phase 7 | Staff, roles and access matrix | apps/client_portal/lib/features/staff/staff_client_manage_screen.dart | backend/src/modules/rbac/staff_client_manage.ts | backend/src/modules/rbac/staff_client_manage.service.ts | Not started |
| Phase 9 | Driver rules and trip checklists | apps/admin_app/lib/features/driver_rules/driver_rules_admin_manage_screen.dart | backend/src/modules/drivers/driver_rules_admin_manage.ts | backend/src/modules/drivers/driver_rules_admin_manage.service.ts | Not started |
| Phase 9 | Driver rules and trip checklists | apps/client_portal/lib/features/driver_rules/driver_rules_client_manage_screen.dart | backend/src/modules/drivers/driver_rules_client_manage.ts | backend/src/modules/drivers/driver_rules_client_manage.service.ts | Not started |
| Phase 9 | Driver rules and trip checklists | apps/driver_app/lib/features/driver_rules/driver_rules_driver_screen.dart | backend/src/modules/drivers/driver_rules_driver.ts | backend/src/modules/drivers/driver_rules_driver.service.ts | Not started |
| Phase 9 | Driver reports | apps/admin_app/lib/features/driver_reports/driver_reports_admin_manage_screen.dart | backend/src/modules/drivers/driver_reports_admin_manage.ts | backend/src/modules/drivers/driver_reports_admin_manage.service.ts | Not started |
| Phase 9 | Driver reports | apps/client_portal/lib/features/driver_reports/driver_reports_client_manage_screen.dart | backend/src/modules/drivers/driver_reports_client_manage.ts | backend/src/modules/drivers/driver_reports_client_manage.service.ts | Not started |
| Phase 9 | Driver reports | apps/driver_app/lib/features/driver_reports/driver_reports_driver_screen.dart | backend/src/modules/drivers/driver_reports_driver.ts | backend/src/modules/drivers/driver_reports_driver.service.ts | Not started |
| Phase 10 | Public website | apps/public_website/app/website/website_public_page.tsx | backend/src/modules/public/website_public.ts | backend/src/modules/public/website_public.service.ts | Not started |
| Phase 10 | Partner app and partner API | (backend only) | backend/src/modules/partners/partner_core.ts | backend/src/modules/partners/partner_core.service.ts | Not started |

## Appendix K. Glossary and languages

| Term | Meaning |
|---|---|
| Operator / client / bus owner | The bus company. The client portal is the operator app. |
| KYC | Know your customer: company and bus documents checked by Abra. |
| PNR | The booking reference printed on the ticket. |
| Hold | Seats reserved for 10 minutes while a customer pays. |
| Manifest | The passenger list of a trip. |
| Settlement | What Abra pays an operator for a cycle: gross sales minus commission minus refunds plus adjustments. |
| Razorpay Route | Razorpay's automatic split of one payment between Abra and the operator. |
| Proof | A picture, PDF or text file attached to a sensitive action. |
| Locked item | A driver checklist item Abra requires; an operator cannot remove or switch it off. |
| Snapshot | The system numbers of a driver report, frozen when the driver sends it. |
| Access matrix | None, View, Edit, Edit+Delete per role per page. |
| Seed | The script that loads the sample data into MongoDB. |

| Language | Code | Shown in the picker as |
|---|---|---|
| English | en | English |
| Telugu | te | Telugu (తెలుగు) |
| Hindi | hi | Hindi (हिन्दी) |
| Kannada | kn | Kannada (ಕನ್ನಡ) |
| Tamil | ta | Tamil (தமிழ்) |
| Malayalam | ml | Malayalam (മലയാളം) |
| Marathi | mr | Marathi (मराठी) |
| Bengali | bn | Bengali (বাংলা) |
