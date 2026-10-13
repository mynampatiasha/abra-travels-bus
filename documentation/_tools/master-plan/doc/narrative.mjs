import { PHASES } from './features.mjs';

export function cover(d, today) {
  d.raw(`# Abra Travels: Master Build Plan\n\n_One document for the whole project. Written ${today}._\n`,
    `<div class="cover"><h1>Abra Travels: Master Build Plan</h1><div class="sub">One document for the whole project, from the basics to the last endpoint.<br>Written ${today}. Read Part 0 first.</div></div>`);
}

export function part0(d, ctx) {
  d.h(2, 'Part 0. Start here (for anyone new, including another session)');
  d.p('Abra Travels is a bus booking platform: travellers book seats, bus owners (operators) sell them, Abra (admin) runs the marketplace, drivers run the trips. This document explains **what exists, how everything connects, the order to build it in, and the exact screens, buttons and endpoints to build**, so that nobody has to guess.');
  d.h(3, '0.1 Facts you need in the first five minutes');
  d.table(['Item', 'Value'], [
    ['Repository', '`D:\\New_project\\abra-travels` (monorepo)'],
    ['Functional source of truth', '`Abra Travels.pdf` (122 sections) in the repo root; the older design notes are in `documentation/`'],
    ['The demos (the specification)', '`prototypes/index.html` opens five working HTML demos: admin, client (operator), customer, driver, website. They share one data store and sync live. Everything in this document was read from them.'],
    ['Backend', 'NestJS + TypeScript in `backend/`. 26 controllers and 113 routes exist today (Appendix I).'],
    ['Database', 'MongoDB Atlas, database `abra_travels`. The connection string is in `backend/.env.development` (git-ignored). **Never put it in a document, a chat or git.** Connection tested: working.'],
    ['Redis', 'Needed for seat holds, queues and live updates. Runs in Docker from `infrastructure/docker-compose.development.yml` (container `abra-redis`); start Docker Desktop first.'],
    ['Flutter apps today', '`apps/customer_app` (built on mock data, some screens missing), `apps/admin_app` and `apps/client_portal` (partly built: sign-in, KYC, banners, catalogue, settings). Shared code is in `packages/shared_*`.'],
    ['Apps not started', 'Driver app, public website (Next.js), partner app'],
    ['UI rule (mandatory)', '**The real screens must look and behave exactly like the demo**: same layout, same labels and wording, same order of buttons, same colours and gradient, same dialogs and fields, same empty, error and loading states, same table and list views, same horizontal and vertical layouts. The demo is the design, not a sketch.'],
    ['Design rule', 'Navy and blue palette with the brand gradient, from `documentation/design-system.md`. UI and functionality ship together. Every new screen gets a visual check.'],
    ['Current phase', "**Phase 0 committed on `main`; Phase 1 steps 0 to 4 merged into `main`; Phase 1 continues on its branch from step 5** (updated 13 October 2026). Phase 0: access matrix, messages log, integration settings, assistant, live updates, feature flags with maintenance and the demo seed are built and tested; the 27-step checklist passes on a local database and still has to be run on Atlas. Phase 1: delete and Undo, export and import, banners as in the demo, invitation edit, amenities (see Part 4, Phase 1). Phase 0 gaps still to build: audit log page, proof files, event router. Full detail and what is not proven: Part 9."],
  ]);
  d.h(3, '0.2 How the demos map to the real build');
  d.table(['In the demo', 'In the real application'], [
    ['`AbraStore`: one shared data store in the browser', 'MongoDB collections behind one NestJS API (Appendix A lists every collection and field)'],
    ['`route()`: turns an event into notifications', 'An event service in the backend that creates notifications, push, WhatsApp and email (Appendix B)'],
    ['`msgSend` / message log', 'A message queue worker plus the `messages` collection and the WhatsApp and email providers'],
    ['Saving to the browser and syncing between tabs', 'The API plus Socket.IO live updates'],
    ['`PERM`: role access matrix (None, View, Edit, Edit+Delete)', 'RBAC on the server, editable by Super Admin only (Appendix C)'],
    ['Proof attachments stored in the browser', 'The files service (Phase 0), with the same limits and the same viewer'],
    ['Scripted assistant', 'One backend endpoint that calls Groq and answers only from the caller\'s own data'],
    ['`_ver` reseed', 'A seed script that loads the same sample data (Phase 0)'],
    ['Demo buttons such as "simulate a payment"', 'Do not exist in production; they are replaced by Razorpay and the driver app'],
  ]);
  d.h(3, '0.3 How to read this document');
  d.ul([
    '**Part 1** the product and the flow. **Part 2** architecture and decisions. **Part 3** the file rule (three files per feature). **Part 4** the phases. **Part 5** the rules that apply to every feature. **Part 6** testing. **Part 7** open items and who owns them. **Part 8** how we work. **Part 9** the progress log: what is built, how it was checked, what is not done and the known problems.',
    '**Appendices D to H** list every page, tab, filter, table column, button, dialog field and the endpoint behind each button, exactly as the demos show them. **Appendix J** lists the three files of every feature.',
    'If a number or label here and the demo ever disagree, the demo wins and this document is fixed.',
  ]);
  d.h(3, '0.4 What happens next');
  d.p('The current list is in Part 9.5. In short: you run the Phase 0 checklist (Part 4), you say "Phase 0 is good", the two branches are merged and Phase 1 continues. No sample data is loaded into the real database: the first data is created by testing through the apps.');
}

export function part1(d) {
  d.h(2, 'Part 1. The product and the flow');
  d.h(3, '1.1 Who uses what');
  d.table(['Who', 'App', 'What they do'], [
    ['Traveller (customer)', 'Customer app (Flutter: Android, iOS, web)', 'Search, pick seats, pay, get the ticket, track the bus, cancel and refund, raise SOS, get support'],
    ['Abra admin, support, accounts, Super Admin', 'Admin app (Flutter web)', 'Run the marketplace: onboard operators, set commission, watch trips and money, handle safety and support'],
    ['Bus owner and their staff (the operator)', 'Client portal (Flutter web). This **is** the operator app; there is no separate one', 'Company KYC, buses, seat layouts, routes, fares, trips, bookings, earnings, driver rules and reports'],
    ['Driver and conductor', 'Driver app (Flutter, Android)', 'Check passengers in, start and end the trip, send GPS, raise SOS, send reports, pass the pre-trip checklist'],
    ['Anyone on Google', 'Public website (Next.js)', 'Route and city pages, offers, help, track-my-bus, contact, partner enquiry; booking hands over to the customer app'],
    ['External agents', 'Partner app and partner API (last)', 'Book through the API'],
  ]);
  d.h(3, '1.2 The flow from start to payout');
  d.ol([
    '**Admin sets up the catalogue:** cities and places, bus types and amenities, required documents, KYC questions, banners, settings.',
    '**An operator joins:** admin invites, or the owner signs in with Google. The owner fills the KYC questions and uploads documents. Admin reviews each document and approves it, or rejects it with a reason. The owner fixes only the rejected items. Approval makes the company active. Each bus gets its own KYC, and only after the company.',
    '**Commercial terms:** admin sets the commission rule (agreed privately with the operator) and the payout mode (automatic split with Razorpay Route, or manual settlement).',
    '**Supply:** the operator adds buses with a seat layout, routes with timed stops and boarding and dropping points, fares (one price per trip, or per seat type and stop pair), and single or recurring trips, then publishes. No per-trip approval: company KYC and bus KYC are the only gates.',
    '**Booking:** the customer searches without logging in, picks seats (10 minute hold, at most 6 seats), logs in at Continue, chooses boarding and dropping points, enters passengers (email is required together with the mobile number), applies a coupon, and pays with Razorpay.',
    '**After payment:** the server confirms, issues the ticket (PNR, QR, PDF), sends WhatsApp and email messages, notifies the operator.',
    '**Travel day:** the driver passes the pre-trip checklist, checks passengers in by QR, starts the trip and sends GPS. The customer sees live tracking and has SOS and sharing. Admin and operator see the same bus on their maps.',
    '**After the trip:** cancellation and refund (slabs set by admin), settlement to the operator (commission deducted), reports and exports.',
  ]);
  d.h(3, '1.3 Who sees whose data');
  d.ul([
    'An operator and their staff see **only their own company\'s** data. This is enforced on the server.',
    'Admin roles see what the access matrix allows: None, View, Edit, Edit+Delete per page. Only the Super Admin edits the matrix.',
    'Customers see only their own bookings, support tickets and messages.',
    'Drivers see only the trips assigned to them and the rules their own operator set.',
  ]);
}

export function part2(d) {
  d.h(2, 'Part 2. Architecture and decisions');
  d.h(3, '2.1 The system in one picture');
  d.code(
`   Customer app   Admin app    Client portal   Driver app   Public website   Partner app
        \\            |              |             |              |              /
         \\___________|______________|_____________|______________|_____________/
                                      |  HTTPS (REST)  +  Socket.IO (live)
                              +------------------+
                              |  NestJS backend  |  one API for every app
                              +------------------+
                  |            |            |             |             |
              MongoDB        Redis        BullMQ        Files        Providers
          (all records)   (seat holds,   (workers:     (proofs,     (Razorpay, WhatsApp,
                           live data)    messages,      tickets)     email, SMS, Maps,
                                         refunds,                    Groq, Firebase push)
                                         expiry)`);
  d.h(3, '2.2 Technology');
  d.table(['Layer', 'Choice'], [
    ['Mobile and web apps', 'Flutter (Android, iOS, web), shared packages in `packages/shared_*`'],
    ['Public website', 'Next.js'],
    ['Backend', 'NestJS + TypeScript, one API'],
    ['Database', 'MongoDB (Atlas). Money is stored in paise (integers).'],
    ['Cache, locks, queues', 'Redis with BullMQ'],
    ['Live data', 'Socket.IO (GPS, SOS, notifications, seat changes)'],
    ['Payments', 'Razorpay: orders, webhooks, Route (automatic split)'],
    ['Messages', 'WhatsApp provider, email provider, SMS (DLT), Firebase push (project ids are in the project memory notes)'],
    ['Assistant', 'Groq, called only from the backend; admin picks the model and key'],
    ['Maps', 'Placeholder until the provider and key are chosen (Part 7)'],
  ]);
  d.h(3, '2.3 Decisions already taken');
  d.table(['Topic', 'Decision'], [
    ['Commission', 'Agreed privately between admin and operator. A rule per operator, per route or per bus type; a percentage or a flat amount; versioned. Only admin edits; the operator sees it read-only. Each booking stores the rule that applied at booking time.'],
    ['Fares', 'The operator chooses: one price per trip, or a price per seat type and per stop pair. Both are supported.'],
    ['Trip approval', 'None. Company KYC and bus KYC are the only gates.'],
    ['Payouts', 'Both modes supported; admin picks the mode per operator.'],
    ['Bus location', 'From the driver app.'],
    ['Seat hold', '10 minutes on the server. At most 6 seats per booking, enforced on the server.'],
    ['Guests', 'Search without login; login only at Continue to book and on personal screens.'],
    ['Customer contact', 'Mobile and email are both required. Google and Apple sign-in are offered next to the WhatsApp code.'],
    ['Languages', 'All 8 in the first release: English, Telugu, Hindi, Kannada, Tamil, Malayalam, Marathi, Bengali. Language names are always shown in English next to the native script.'],
    ['Proofs', 'Every sensitive admin action asks for a proof file (picture, PDF or text, up to 5 files, 600 KB each) that Abra and the person concerned can view and download.'],
    ['Number cards', 'Every number card opens the records behind it. A card that says 1 must show that one record.'],
    ['UI', 'The real UI is the same as the demo in every app. Nothing is redesigned, reworded or rearranged while connecting the backend. Any change to a screen is agreed with the user first and the demo is updated at the same time.'],
    ['Operator app', 'The client portal is the operator app. One app, not two.'],
    ['Driver rules', 'The operator maintains pre-trip and end-of-trip checklists and the report types. Abra provides default templates and a locked minimum that operators cannot remove.'],
    ['Driver reports', 'Daily and weekly numbers come from the system and are frozen when the driver sends the report. The driver only adds what the system cannot know.'],
    ['Database separation', 'This project uses its own database (`abra_travels`) on the Atlas cluster the user shared. Keep it separate from the databases of other Abra projects.'],
  ]);
}

export function part3(d) {
  d.h(2, 'Part 3. The file rule: three files per feature');
  d.note('Every feature is built as a small, complete package: **one screen file**, **one backend file**, **one service file**. Nothing is split into many small files. A feature is finished from the screen to the database before the next feature starts.', 'rule');
  d.h(3, '3.1 The three files');
  d.table(['#', 'File', 'Where', 'What is inside it'], [
    ['1', '`<feature>_<app>_screen.dart`', '`apps/<app>/lib/features/<feature>/`', 'Everything the user sees for this feature, in this order inside the one file: (1) data models, (2) state and controller, (3) API calls through the shared client, (4) every widget the screen needs (cards, tables, dialogs, forms, charts), (5) the screen itself. **No widgets in other files.**'],
    ['2', '`<feature>_<app>.ts`', '`backend/src/modules/<module>/`', 'Everything the API needs for this feature, in this order: (1) Mongoose schema, (2) request and response types with validation, (3) the controller with every endpoint, (4) the Nest module wiring. **No other backend files for the feature.** If the service needs the schema, the schema sits at the top of the service file instead, so the two files never import each other in a circle.'],
    ['3', '`<feature>_<app>.service.ts`', '`backend/src/modules/<module>/`', 'All business logic: rules, calculations, permission checks, events, notifications, queries. The controller only calls the service.'],
  ]);
  d.p('`<app>` is the audience: `admin_manage` for the admin portal, `client_manage` for the operator portal, `customer` for the customer app, `driver` for the driver app, `public` for the website. The SOS feature therefore has, for the admin: `sos_admin_manage_screen.dart`, `sos_admin_manage.ts`, `sos_admin_manage.service.ts`; for the customer: `sos_customer_screen.dart`, `sos_customer.ts`, `sos_customer.service.ts`; for the driver: the same with `driver`.');
  d.h(3, '3.2 What is allowed to be shared');
  d.ul([
    '**Flutter:** the shared packages already in `packages/` (network client, authentication, permissions, theme, UI kit, localization, validation, storage, notifications). A feature never copies them.',
    '**Backend:** authentication guards, the permission decorator, the audit service, the notification service, the files service, the Mongoose connection, and shared helper functions (money, dates, pagination). Written once, imported by every feature.',
    '**Collections:** the schema of a collection lives in the file of the feature that owns it (the `*_admin_manage.ts` file). Other audiences import it.',
    '**Tests** live in `test/` folders and are not counted as feature files.',
  ]);
  d.h(3, '3.3 Rules for the files');
  d.ul([
    'Section banners inside each file (`// ===== 1. MODELS =====`) keep a long file easy to read. A file can be long; it must stay in order.',
    'The existing backend modules (cities, buses, trips, onboarding and so on) keep their present structure. The three-file rule applies to everything new. When an existing module needs new endpoints, they go into the new `<feature>_<app>.ts`.',
    'Every endpoint in the `.ts` file carries the permission it needs, the audit event it writes, and the notification it sends, written in a comment line above it so a reader sees the whole behaviour in one place.',
    'Every screen file shows loading, empty, error, no-permission and offline states. These are part of the screen, not extras.',
    'Money is shown in rupees, stored in paise. Dates are shown in India time.',
    '**The screen file reproduces the demo screen exactly:** the same sections in the same order, the same labels, buttons, filters, table columns, dialogs and form fields that Appendices D to H list, the same table / list toggle, the same horizontal / vertical layout option, the same number-card behaviour, the same 8-language switching and the same proof attachment box. If the demo and the screen file differ, the screen file is wrong.',
    'Naming: feature names are lower snake case and are the same in all three files and in Appendix J.',
  ]);
  d.h(3, '3.4 Example: the SOS feature for the admin');
  d.code(
`apps/admin_app/lib/features/sos/sos_admin_manage_screen.dart     <- models, controller, API calls, every widget, the screen
backend/src/modules/women-safety/sos_admin_manage.ts             <- schema, DTOs, controller (list, detail, acknowledge,
                                                                    escalate, resolve, false alarm, note), module
backend/src/modules/women-safety/sos_admin_manage.service.ts     <- rules: status changes, contact alerts, escalation timers,
                                                                    audit, notifications to customer, driver, operator`);
}

export function part5(d) {
  d.h(2, 'Part 5. Rules that apply to every feature');
  d.table(['Area', 'Rule'], [
    ['UI matches the demo', 'Every screen is built to look and behave like its demo page: layout, wording, colours, spacing, icons, dialogs, states and responsive behaviour at phone, tablet and desktop widths. The demo files in `prototypes/` are opened side by side with the real screen during the check. Only real data replaces the sample data.'],
    ['Access', 'Server-side permission check on every endpoint using the matrix (None, View, Edit, Edit+Delete). A view-only user can open and copy but not change; the buttons are hidden **and** the server refuses.'],
    ['Audit', 'Every create, edit, delete, status change, block, refund, payout and permission change writes an audit entry: who, what, when, from where, before and after.'],
    ['Proofs', 'SOS resolve, false alarm, refund reject, trip cancel, booking cancel, customer block, settlement hold, incident, ticket replies, delay and driver override need a proof (file or note) as the demos show. Stored with the record.'],
    ['Money', 'Integers in paise. One rounding function used everywhere. Customer price = fare + commission + convenience fee + GST, always calculated on the server, never taken from the app. Commission changes never alter bookings already made.'],
    ['Time', 'India time everywhere; trips across midnight; cut-off before departure; travel date versus departure date.'],
    ['Idempotency', 'Every create that costs money or changes stock takes an idempotency key. A double tap returns the same booking.'],
    ['Seat stock', 'Held, sold and blocked seats are separate; 10 minute hold; expiry worker; the booked count always equals the real bookings.'],
    ['Lists', 'Server-side paging, stable sorting, the filters shown in the demo, search, export (CSV, Excel, PDF where the demo has it) limited by the same filters and permissions. Table and list view are two views of the same data.'],
    ['Import', 'Excel import with a template download, a dry run, row-by-row errors, then save (places, buses, schedules, fares).'],
    ['Delete', 'Soft delete wherever a record is referenced. Deleting a place used by trips is refused.'],
    ['Notifications', 'Created by the event service, never by the app. A provider failure never fails the business action. No duplicates for one event. See Appendix B for every event, recipient and message.'],
    ['Messages', 'WhatsApp and email after booking, cancellation, refund, payment failure, delay and boarding; logged; resendable by admin.'],
    ['Languages', 'All text through one translation system; 8 languages; names shown in English; the assistant answers in the language the user used.'],
    ['Number cards', 'Each card links to the filtered list behind it; the count and the list always agree.'],
    ['Maintenance and switches', 'Enforced by one global guard on every request. Every app sends the header `X-Abra-App: customer | operator | driver | partner | admin | website` so a request without a token can be placed; signed-in people are placed by their account. `GET /maintenance/status` and `GET /features` are public and always work, so an app can show the message and hide what is off. Staff with `maintenance.bypass` (and the Super Admin) are never locked out of the admin portal. A feature that can be switched off carries `@RequireFeature(\'key\')`.'],
    ['Realtime', 'GPS, SOS, notifications, seat changes and report status arrive by Socket.IO; the screen updates without a reload.'],
    ['Privacy', 'Phone numbers and emails are masked in lists for roles that only need to see the record. Account deletion keeps past financial records but removes personal data.'],
    ['Errors', 'One error format with a code and a human sentence; the app shows the sentence, not the code.'],
    ['Security', 'Secrets only in git-ignored environment files; rate limits on OTP and login; webhooks verified by signature; files served by short-lived signed links; no trust of amounts from the app.'],
  ]);
}

export function part6(d) {
  d.h(2, 'Part 6. Testing plan');
  d.table(['Layer', 'What', 'Who'], [
    ['Unit', 'Pricing, commission, cancellation and refund maths, settlement totals, driver report numbers, rule evaluation', 'Claude, automatic'],
    ['Endpoint', 'Every endpoint in Appendices D to H: allowed role works, forbidden role is refused, bad input gives a clear error, an audit entry is written', 'Claude, automatic (Jest end-to-end)'],
    ['Concurrency', '500 parallel requests for one seat give exactly one winner; hold expiry frees seats', 'Claude, automatic'],
    ['Payments', 'Duplicate webhook, failed, pending, expired-then-paid, amount mismatch', 'Claude, automatic'],
    ['Apps', '`flutter analyze` clean and existing tests green', 'Claude, automatic'],
    ['Screen walk', 'The same click-through that passes on the demo (every page, every button) must pass on the real app. The demo test scripts are the acceptance spec.', 'Claude runs a minimum; **you test with the checklist**'],
    ['Visual', 'Every new screen is compared side by side with its demo page (layout, wording, colours, dialogs, states) and checked against the design system at phone, tablet and desktop widths. A screen that differs from the demo is not done.', 'Claude, then you'],
    ['User test', 'At the end of each phase you receive a short checklist in plain language: what to open, what to press, what you should see', 'You'],
  ]);
  d.note('To keep effort and cost sensible, Claude runs only the minimum self-tests and hands you the checklist; you do the full manual test of each phase. Nothing moves to the next phase until you say so.', 'rule');
  d.h(3, 'Definition of done for one feature');
  d.ol([
    'The three files exist and nothing else was needed.',
    'Every button in the demo page has a working endpoint (Appendices D to H show them).',
    'Permissions, audit, notifications and messages work as described.',
    'Loading, empty, error, no-permission and offline states show.',
    'The screen matches the demo page side by side: same layout, wording, buttons, colours, dialogs and fields.',
    'Automatic tests pass; analyzer clean.',
    'You tested the checklist and said it is good.',
    'Appendix J is updated (status, date).',
  ]);
}

export function part7(d) {
  d.h(2, 'Part 7. Open items and who owns them');
  d.table(['Needed', 'Phase', 'From'], [
    ['Redis running (Docker is installed)', '0', 'Claude to set up; you confirm Docker Desktop is running'],
    ['New MongoDB Atlas password (the current one was shown in a screenshot and in chat) and your IP allowed in Atlas', '0', 'You'],
    ['Razorpay account: test and live keys, webhook secret, Route enabled for splits', '3, 6', 'You'],
    ['Google Maps (or Mappls) provider decision and key, from the Google Cloud project with billing and a budget alert', '5', 'You'],
    ['Groq API key for the assistant', '0 or 7', 'You'],
    ['WhatsApp provider credentials, SMS provider (DLT registration), email provider', '3 onward', 'You'],
    ['Cancellation slabs and refund percentages (defaults are in the demo; operators may override)', '4', 'You and operators'],
    ['Who funds coupon discounts: platform or operator', '3, 6', 'You'],
    ['Hosting provider and a real storage bucket for documents', '11 (staging earlier)', 'You'],
    ['Safety escalation contacts and legal review', '5', 'You'],
    ['Inter font files and official logos (Google, Apple, WhatsApp, UPI, banks) and the Abra logo as transparent PNG or SVG', 'any', 'You'],
    ['Native-speaker review of Kannada, Tamil, Malayalam, Marathi and Bengali (machine-written so far); Telugu and Hindi also reviewed', '11', 'You'],
    ['Decision: where proof files live (MongoDB GridFS or a cloud bucket such as S3)', '0', 'You'],
    ['Report reminders on a timer (the demo only reminds on a button press)', '9', 'You to confirm'],
  ]);
}

export function part8(d) {
  d.h(2, 'Part 8. How we work');
  d.ul([
    'One phase at a time. At the end of each phase you get the checklist; the next phase starts when you say so. This document is updated after each phase with the status and the date.',
    'You prefer short, simple English. When you say "just tell me", Claude explains and does not code. When you give a clear build instruction, Claude builds.',
    'You test; Claude keeps self-testing to the minimum and gives you the checklist.',
    'The login files of the customer app are not edited without asking.',
    'Secrets live in git-ignored files, never in code, documents or chat.',
    'No fake or sample data ships to production; development seed data stays behind a development switch.',
    'The demos in `prototypes/` stay as the specification and are not deleted. `prototypes/_build/build_client.py` is stale and must not be run.',
    'Keep the three-file rule (Part 3) in every new feature.',
  ]);
}
