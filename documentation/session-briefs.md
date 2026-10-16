# Session briefs

Sessions share one working folder, so each brief tells its session to create its own folder (a git worktree) and branch. The main folder stays on main and belongs to the coordinator.

How to use: open a new session, paste the whole block of one brief (it already contains the common rules), and let it work. The coordinator (the first brief) is the session that already has the full picture. Start with briefs 1 to 3; start briefs 4 and 5 when the coordinator says Phase 0 is stable.

Written 12 October 2026. Repository: `D:\New_project\abra-travels`.

**USER'S ORDER FOR EVERY SESSION (14 October 2026, overrides anything below): every screen you build or change must look and behave exactly like its demo screen in `prototypes/` (same columns, filters, tabs, buttons, colours, dialogs, empty states, side menu, table/list toggle, phone and laptop layouts). Do not ship a "normal" generic admin table in its place. Before coding, list every element of the demo page (plan Appendix D to H). After coding, open the real screen next to the demo at laptop and phone widths and fix every difference. A screen is not done, and must not be shown to the user for testing, until that side-by-side check passes. If a shared piece (table, toolbar, tabs, dialog) does not match the demo, fix the shared piece.**

---

# Brief 1. Coordinator (this session)

```text
## Rules for every session (read first)

You are the **coordinator** session of the Abra Travels build. Several sessions work in the same repository at the same time. A coordinator session owns the shared files and merges everyone's work. Follow these rules exactly.

**Read, in this order**
1. `documentation/abra-master-plan.md`: Part 0, Part 3 (the file rule), Part 5 (rules), then your own phase in Part 4 and the appendices named in your brief. The PDF copy is `documentation/abra-master-plan.pdf`.
2. The demo files in `prototypes/` for every screen you build. **The real UI must look and behave exactly like the demo** (same layout, wording, buttons, dialogs, fields, states).

**Working rules**
- You work in the main folder `D:/New_project/abra-travels` on `main` and never create a worktree. Every other session works in its own worktree and branch; you merge their branches into main one at a time, only after the checks pass, and you never switch branches inside the main folder.
- **Three files per feature and audience**: `<feature>_<app>_screen.dart` (models, state, API calls and ALL widgets inside), `<feature>_<app>.ts` (schema, DTOs, controller, module), `<feature>_<app>.service.ts` (logic). New code only; do not rewrite working files. Tests go in `test/` or `tests/` folders.
- **Shared files belong to the coordinator**: `rbac/permissions/permission-catalog.ts`, `rbac/permissions/access-pages.ts`, `audit-logs/schemas/audit-log.schema.ts` (audit action list), `modules/domain-modules.ts`, `app.module.ts`, `config/environment.schema.ts`, everything in `packages/shared_*`, and `documentation/abra-master-plan.*`. If you need a change there, write it in your report under "Shared changes I need" with the exact lines; do not edit the file. (The only exception: adding new entries at the end of a list is allowed in your own branch, never reorder or remove, and list each one in your report.)
- Do not run Prettier or ESLint `--fix` over folders you do not own.
- Every endpoint needs its permission key, and mutating endpoints write an audit entry through the shared audit approach already used by the access matrix (`rbac/access_matrix_admin_manage*` is the reference example). Operators see only their own data. Money is integer paise. Times are India time.
- Secrets: never print, paste or commit any secret or the MongoDB connection string. Read them from the git-ignored env files only.

**Your own test environment (so sessions do not break each other)**
- Database: copy `MONGODB_URI` from `backend/.env.development` and change only the database name at the end to `abra_travels`. Pass it to the backend as a process environment variable (it overrides the file). Never use the main database `abra_travels` for tests.
- Run your backend on port `4000` (`PORT=4000`). Use `REDIS_KEY_PREFIX=abra` and `QUEUE_PREFIX=abra`.
- Docker and Redis are already running (container `abra-redis`).

**Definition of done for each feature**
1. The three files exist and nothing else was needed.
2. Every button of the demo page has a working endpoint (see the appendix of the master plan).
3. Permissions, audit and notifications work; the matrix level None / View / Edit / Edit+Delete is enforced by the server.
4. Loading, empty, error, no-permission and offline states show.
5. The screen matches the demo side by side.
6. `npx tsc --noEmit`, lint and the unit tests are clean; database tests pass on your own test database; Flutter: `flutter analyze` clean.
7. A plain-language test checklist for the user is written (what to open, what to press, what should happen).

**Report format (send to the coordinator after each feature)**
- Done and tested: what, with the commands you ran and the result.
- Done but untested: what and why.
- Not done / blocked: what and what you need.
- Shared changes I need: exact lines.
- Files created or changed (paths).
- Do not say "done" for anything you did not run.

## Your job
You are responsible for the whole result. You own Phase 0 and every shared file, merge the other sessions' branches in order, and re-run all checks after each merge.

## Phase 0 scope (from the master plan, Part 4)
Done and tested: MongoDB (Atlas) and Redis connected, backend starts with both up, Super Admin created, access matrix (`rbac/access_matrix_admin_manage*`) tested end to end.
Still to build, each with the three-file rule:
1. Messages log: `messages` collection, WhatsApp and email copies per event, resend, admin list and detail (admin page "Messages sent", customer "Messages").
2. Integration settings for Razorpay, Maps, Groq, SMS and push (extend `system-settings`; secrets encrypted; test-connection endpoints).
3. Assistant endpoint (Groq, add `groq` to the AI provider setting; answers only from the caller's own data; confirm-before-action with audit).
4. Socket.IO updates for GPS, SOS, notifications, seat changes and report status.
5. Seed script that loads the foundation data and, as each collection gets its schema, the demo sample data.
6. Proof-file storage decision applied (existing files service, local in development, S3-style bucket before staging).

## Standing duties
- Merge order: Phase 0 first, then Phase 1, then Phase 2; each merge is followed by typecheck, lint, all unit tests, database tests and a sign-in check.
- Apply the "Shared changes I need" requests from the other sessions and tell them when done.
- Keep `documentation/abra-master-plan.md` and the PDF updated (status and date) after each merge; copy to Downloads.
- Give the user a plain-language test checklist at the end of each phase and wait for the user's yes before the next phase.
- Report honestly: what was run, what passed, what was not tested.
```

---

# Brief 2. Phase 1 session: catalogue, operators and KYC

```text
## Rules for every session (read first)

You are the **Phase 1** session of the Abra Travels build. Several sessions work in the same repository at the same time. A coordinator session owns the shared files and merges everyone's work. Follow these rules exactly.

**Read, in this order**
1. `documentation/abra-master-plan.md`: Part 0, Part 3 (the file rule), Part 5 (rules), then your own phase in Part 4 and the appendices named in your brief. The PDF copy is `documentation/abra-master-plan.pdf`.
2. The demo files in `prototypes/` for every screen you build. **The real UI must look and behave exactly like the demo** (same layout, wording, buttons, dialogs, fields, states).

**Working rules**
- **Work only in your own folder (a git worktree) on your own branch `phase1-catalogue-kyc`.** All sessions share the folder `D:/New_project/abra-travels`, so never switch branches inside it; that would move every other session's files. The checkpoint commit already exists on main. Create your folder once, from a terminal:
  `git -C D:/New_project/abra-travels worktree add D:/New_project/abra-wt-p1 -b phase1-catalogue-kyc main`
  Then work only inside `D:/New_project/abra-wt-p1`. Git does not copy ignored files, so copy `backend/.env.development` and the folder `backend/secrets` from the main folder into the same paths in yours (copy the files with the operating system; never open, print or paste their contents), then run `npm ci` in `backend` and `flutter pub get` in each Flutter app you touch.
- Commit only on your branch, in small commits. Do not commit to main, do not push, do not reset or rebase anything you did not create. The coordinator merges your branch.
- (The coordinator session is the exception: it works in the main folder on main and never creates a worktree.)
- **Three files per feature and audience**: `<feature>_<app>_screen.dart` (models, state, API calls and ALL widgets inside), `<feature>_<app>.ts` (schema, DTOs, controller, module), `<feature>_<app>.service.ts` (logic). New code only; do not rewrite working files. Tests go in `test/` or `tests/` folders.
- **Shared files belong to the coordinator**: `rbac/permissions/permission-catalog.ts`, `rbac/permissions/access-pages.ts`, `audit-logs/schemas/audit-log.schema.ts` (audit action list), `modules/domain-modules.ts`, `app.module.ts`, `config/environment.schema.ts`, everything in `packages/shared_*`, and `documentation/abra-master-plan.*`. If you need a change there, write it in your report under "Shared changes I need" with the exact lines; do not edit the file. (The only exception: adding new entries at the end of a list is allowed in your own branch, never reorder or remove, and list each one in your report.)
- Do not run Prettier or ESLint `--fix` over folders you do not own.
- Every endpoint needs its permission key, and mutating endpoints write an audit entry through the shared audit approach already used by the access matrix (`rbac/access_matrix_admin_manage*` is the reference example). Operators see only their own data. Money is integer paise. Times are India time.
- Secrets: never print, paste or commit any secret or the MongoDB connection string. Read them from the git-ignored env files only.

**Your own test environment (so sessions do not break each other)**
- Database: copy `MONGODB_URI` from `backend/.env.development` and change only the database name at the end to `abra_travels_p1`. Pass it to the backend as a process environment variable (it overrides the file). Never use the main database `abra_travels` for tests.
- Run your backend on port `4001` (`PORT=4001`). Use `REDIS_KEY_PREFIX=p1` and `QUEUE_PREFIX=p1`.
- Docker and Redis are already running (container `abra-redis`).

**Definition of done for each feature**
1. The three files exist and nothing else was needed.
2. Every button of the demo page has a working endpoint (see the appendix of the master plan).
3. Permissions, audit and notifications work; the matrix level None / View / Edit / Edit+Delete is enforced by the server.
4. Loading, empty, error, no-permission and offline states show.
5. The screen matches the demo side by side.
6. `npx tsc --noEmit`, lint and the unit tests are clean; database tests pass on your own test database; Flutter: `flutter analyze` clean.
7. A plain-language test checklist for the user is written (what to open, what to press, what should happen).

**Report format (send to the coordinator after each feature)**
- Done and tested: what, with the commands you ran and the result.
- Done but untested: what and why.
- Not done / blocked: what and what you need.
- Shared changes I need: exact lines.
- Files created or changed (paths).
- Do not say "done" for anything you did not run.

## Your scope
Phase 1 of the master plan: the things admin sets up before a bus owner can join.
Features: cities and places (with the three tabs Places / Cities / Operator requests), bus types and amenities, required documents, KYC questionnaire, invitations, KYC review (company and bus), operators (detail page with tabs), banners, company profile and bus KYC in the client portal.
Screens: admin pages `places`, `bustypes`, `documents`, `questions`, `invitations`, `kyc`, `operators`, `banners`; client pages `kyc`, `company`, `places`. See master plan Appendix D and E for every button, field and endpoint, and Appendix A for collections.

## Build order (already agreed; follow it)
0. Checkpoint commit (ask the user's yes first) and update the plan's "what exists today" and KYC route names (`/settings/kyc-configuration`).
1. Shared mechanism, written once in `catalogue_shared_manage` files: soft delete (`deletedAt`, `deletedBy`), delete and restore routes, refusal when "in use" with a clear sentence, audit hook, shared list query (filter, search, sort, paging). First add per-module delete (and export) permission keys so the access matrix can tell Edit from Edit+Delete (send the lines to the coordinator).
2. Small items: banners duplicate / archive / reorder and Scheduled and Archived statuses; read-one routes for bus types, document types, invitations; invitation edit (PATCH) and the EXPIRED status.
3. Server-side export (`GET .../export?format=csv|xlsx`, same filters and permissions as the list, audited) and import (template, dry run with row-by-row errors, then save), places and cities first.
4. Amenities collection and toggle.
5. Place requests (backend, admin tab, client page).
6. Operator detail with tabs (Overview, Buses, Commission and payout, Bookings, Activity); suspend with reason and proof, reactivate, message owner.
7. Payout mode and bank details with verification.
8. Company profile page and bank details (client portal).
9. Bus KYC in the client portal.
10. KYC questionnaire comparison against the demo's three tabs (can run early in parallel).

## Decisions already taken
- Soft delete and audit: one shared mechanism. Export and import: server-side. Proof files: existing files service. Three-file rule: new code only. KYC questionnaire: keep the existing one-config design and add only what is missing.

## Stay out of
Phase 0 folders being built by the coordinator: `whatsapp`, `notifications`, `system-settings`, `chatbot`. For "message owner" use the current notification service until the coordinator's messages log exists.
```

---

# Brief 3. Phase 2 session: supply and commercial terms

```text
## Rules for every session (read first)

You are the **Phase 2** session of the Abra Travels build. Several sessions work in the same repository at the same time. A coordinator session owns the shared files and merges everyone's work. Follow these rules exactly.

**Read, in this order**
1. `documentation/abra-master-plan.md`: Part 0, Part 3 (the file rule), Part 5 (rules), then your own phase in Part 4 and the appendices named in your brief. The PDF copy is `documentation/abra-master-plan.pdf`.
2. The demo files in `prototypes/` for every screen you build. **The real UI must look and behave exactly like the demo** (same layout, wording, buttons, dialogs, fields, states).

**Working rules**
- **Work only in your own folder (a git worktree) on your own branch `phase2-supply`.** All sessions share the folder `D:/New_project/abra-travels`, so never switch branches inside it; that would move every other session's files. The checkpoint commit already exists on main. Create your folder once, from a terminal:
  `git -C D:/New_project/abra-travels worktree add D:/New_project/abra-wt-p2 -b phase2-supply main`
  Then work only inside `D:/New_project/abra-wt-p2`. Git does not copy ignored files, so copy `backend/.env.development` and the folder `backend/secrets` from the main folder into the same paths in yours (copy the files with the operating system; never open, print or paste their contents), then run `npm ci` in `backend` and `flutter pub get` in each Flutter app you touch.
- Commit only on your branch, in small commits. Do not commit to main, do not push, do not reset or rebase anything you did not create. The coordinator merges your branch.
- (The coordinator session is the exception: it works in the main folder on main and never creates a worktree.)
- **Three files per feature and audience**: `<feature>_<app>_screen.dart` (models, state, API calls and ALL widgets inside), `<feature>_<app>.ts` (schema, DTOs, controller, module), `<feature>_<app>.service.ts` (logic). New code only; do not rewrite working files. Tests go in `test/` or `tests/` folders.
- **Shared files belong to the coordinator**: `rbac/permissions/permission-catalog.ts`, `rbac/permissions/access-pages.ts`, `audit-logs/schemas/audit-log.schema.ts` (audit action list), `modules/domain-modules.ts`, `app.module.ts`, `config/environment.schema.ts`, everything in `packages/shared_*`, and `documentation/abra-master-plan.*`. If you need a change there, write it in your report under "Shared changes I need" with the exact lines; do not edit the file. (The only exception: adding new entries at the end of a list is allowed in your own branch, never reorder or remove, and list each one in your report.)
- Do not run Prettier or ESLint `--fix` over folders you do not own.
- Every endpoint needs its permission key, and mutating endpoints write an audit entry through the shared audit approach already used by the access matrix (`rbac/access_matrix_admin_manage*` is the reference example). Operators see only their own data. Money is integer paise. Times are India time.
- Secrets: never print, paste or commit any secret or the MongoDB connection string. Read them from the git-ignored env files only.

**Your own test environment (so sessions do not break each other)**
- Database: copy `MONGODB_URI` from `backend/.env.development` and change only the database name at the end to `abra_travels_p2`. Pass it to the backend as a process environment variable (it overrides the file). Never use the main database `abra_travels` for tests.
- Run your backend on port `4002` (`PORT=4002`). Use `REDIS_KEY_PREFIX=p2` and `QUEUE_PREFIX=p2`.
- Docker and Redis are already running (container `abra-redis`).

**Definition of done for each feature**
1. The three files exist and nothing else was needed.
2. Every button of the demo page has a working endpoint (see the appendix of the master plan).
3. Permissions, audit and notifications work; the matrix level None / View / Edit / Edit+Delete is enforced by the server.
4. Loading, empty, error, no-permission and offline states show.
5. The screen matches the demo side by side.
6. `npx tsc --noEmit`, lint and the unit tests are clean; database tests pass on your own test database; Flutter: `flutter analyze` clean.
7. A plain-language test checklist for the user is written (what to open, what to press, what should happen).

**Report format (send to the coordinator after each feature)**
- Done and tested: what, with the commands you ran and the result.
- Done but untested: what and why.
- Not done / blocked: what and what you need.
- Shared changes I need: exact lines.
- Files created or changed (paths).
- Do not say "done" for anything you did not run.

## Your scope
Phase 2 of the master plan: everything an operator needs to publish trips, and the commercial terms admin sets.
Features: buses and seat layouts, crew (drivers and conductors), routes with timed stops and boarding and dropping points, fares and schedules, trips and seat inventory, commission rules and the price calculator, payout and fee settings (refund slabs, convenience fee, GST).
Screens: admin pages `buses`, `trips`, `inventory`, `commission`, `payout`; client pages `buses`, `layouts`, `crew`, `routes`, `fares`, `schedules`, `trips`, `commission`. See Appendix D and E for every button, field and endpoint, and Appendix A for collections (`seat_layouts`, `operator_crew`, `fares`, `schedules`, `seat_inventory`, `commission_rules`, `commission_history`, `payout_settings`, `cancellation_slabs`).

## Rules specific to this phase
- Commission: rule per operator, route or bus type; percent or flat; versioned; only admin edits; the operator sees it read-only; every booking will store the rule that applied. The price function (fare + commission + convenience fee + GST) is one pure function used by search, the seat screen and booking. Money in paise, one rounding function.
- Fares: the operator chooses one price per trip or a price per seat type and stop pair. Trips already published keep their fares unless the operator republishes.
- Trip publish is gated only by company KYC and bus KYC. Seat layouts are versioned; published trips keep their copy.
- Seat inventory: held, sold and blocked are separate; the 10 minute hold and the Redis lock belong to Phase 3, but the inventory records and block and unblock by admin belong here.
- Delete protection: a route or bus used by trips cannot be deleted.

## Dependencies
- Operators, buses and KYC come from Phase 1 (another session). Until it is merged, create your own test operators and approved buses in your test database with a small test seed. Do not edit Phase 1 files.
- The soft-delete, audit and export helpers come from Phase 1's shared mechanism; until it is merged, write against the same names and tell the coordinator what you assumed.
```

---

# Brief 4. Driver app and public website session (start after Phase 0 is stable)

```text
## Rules for every session (read first)

You are the **Driver app and website** session of the Abra Travels build. Several sessions work in the same repository at the same time. A coordinator session owns the shared files and merges everyone's work. Follow these rules exactly.

**Read, in this order**
1. `documentation/abra-master-plan.md`: Part 0, Part 3 (the file rule), Part 5 (rules), then your own phase in Part 4 and the appendices named in your brief. The PDF copy is `documentation/abra-master-plan.pdf`.
2. The demo files in `prototypes/` for every screen you build. **The real UI must look and behave exactly like the demo** (same layout, wording, buttons, dialogs, fields, states).

**Working rules**
- **Work only in your own folder (a git worktree) on your own branch `driver-and-website`.** All sessions share the folder `D:/New_project/abra-travels`, so never switch branches inside it; that would move every other session's files. The checkpoint commit already exists on main. Create your folder once, from a terminal:
  `git -C D:/New_project/abra-travels worktree add D:/New_project/abra-wt-dw -b driver-and-website main`
  Then work only inside `D:/New_project/abra-wt-dw`. Git does not copy ignored files, so copy `backend/.env.development` and the folder `backend/secrets` from the main folder into the same paths in yours (copy the files with the operating system; never open, print or paste their contents), then run `npm ci` in `backend` and `flutter pub get` in each Flutter app you touch.
- Commit only on your branch, in small commits. Do not commit to main, do not push, do not reset or rebase anything you did not create. The coordinator merges your branch.
- (The coordinator session is the exception: it works in the main folder on main and never creates a worktree.)
- **Three files per feature and audience**: `<feature>_<app>_screen.dart` (models, state, API calls and ALL widgets inside), `<feature>_<app>.ts` (schema, DTOs, controller, module), `<feature>_<app>.service.ts` (logic). New code only; do not rewrite working files. Tests go in `test/` or `tests/` folders.
- **Shared files belong to the coordinator**: `rbac/permissions/permission-catalog.ts`, `rbac/permissions/access-pages.ts`, `audit-logs/schemas/audit-log.schema.ts` (audit action list), `modules/domain-modules.ts`, `app.module.ts`, `config/environment.schema.ts`, everything in `packages/shared_*`, and `documentation/abra-master-plan.*`. If you need a change there, write it in your report under "Shared changes I need" with the exact lines; do not edit the file. (The only exception: adding new entries at the end of a list is allowed in your own branch, never reorder or remove, and list each one in your report.)
- Do not run Prettier or ESLint `--fix` over folders you do not own.
- Every endpoint needs its permission key, and mutating endpoints write an audit entry through the shared audit approach already used by the access matrix (`rbac/access_matrix_admin_manage*` is the reference example). Operators see only their own data. Money is integer paise. Times are India time.
- Secrets: never print, paste or commit any secret or the MongoDB connection string. Read them from the git-ignored env files only.

**Your own test environment (so sessions do not break each other)**
- Database: copy `MONGODB_URI` from `backend/.env.development` and change only the database name at the end to `abra_travels_dw`. Pass it to the backend as a process environment variable (it overrides the file). Never use the main database `abra_travels` for tests.
- Run your backend on port `4003` (`PORT=4003`). Use `REDIS_KEY_PREFIX=dw` and `QUEUE_PREFIX=dw`.
- Docker and Redis are already running (container `abra-redis`).

**Definition of done for each feature**
1. The three files exist and nothing else was needed.
2. Every button of the demo page has a working endpoint (see the appendix of the master plan).
3. Permissions, audit and notifications work; the matrix level None / View / Edit / Edit+Delete is enforced by the server.
4. Loading, empty, error, no-permission and offline states show.
5. The screen matches the demo side by side.
6. `npx tsc --noEmit`, lint and the unit tests are clean; database tests pass on your own test database; Flutter: `flutter analyze` clean.
7. A plain-language test checklist for the user is written (what to open, what to press, what should happen).

**Report format (send to the coordinator after each feature)**
- Done and tested: what, with the commands you ran and the result.
- Done but untested: what and why.
- Not done / blocked: what and what you need.
- Shared changes I need: exact lines.
- Files created or changed (paths).
- Do not say "done" for anything you did not run.

## Your scope
Two new apps that nothing else depends on yet.
1. **Driver app** (`apps/driver_app`, Flutter, Android). Screens and every button and endpoint are in master plan Appendix G; the design is `prototypes/driver_demo_model.html`. Phase 5 part: sign-in, trips, passenger list and QR check-in, board, start, end, delay, GPS sending, SOS. Phase 9 part later: reports tab, pre-trip and end-of-trip checklists. Use the shared packages in `packages/`. Mirror the structure of `apps/customer_app`.
2. **Public website** (`apps/public_website`, Next.js). Pages and endpoints are in Appendix H; the design is `prototypes/website_demo_model.html`. Server-rendered route and city pages with SEO and structured data, search hand-off to the customer app, offers, help, track my bus, contact and partner enquiry.

## How to work before the backend exists
- Build against the endpoint list in the master plan. Put each API call behind a repository with a mock version and a real version (as the customer app does), so switching to the real backend is one line.
- Do not build backend endpoints. Write what you need in "Shared changes I need" or "Endpoints I need" in your report; the coordinator or the backend sessions build them.
- Driver app login uses the existing WhatsApp-code sign-in (`POST /auth/otp/send`, `/auth/otp/verify`).

## Special rules
- Design system: navy and blue palette with the brand gradient (`documentation/design-system.md`). UI and functionality ship together; do a visual check at phone, tablet and desktop widths.
- The driver app needs the Maps provider key (undecided): keep the map behind a provider switch with a placeholder.
```

---

# Brief 5. Customer app session (start after Phase 0 is stable)

```text
## Rules for every session (read first)

You are the **Customer app** session of the Abra Travels build. Several sessions work in the same repository at the same time. A coordinator session owns the shared files and merges everyone's work. Follow these rules exactly.

**Read, in this order**
1. `documentation/abra-master-plan.md`: Part 0, Part 3 (the file rule), Part 5 (rules), then your own phase in Part 4 and the appendices named in your brief. The PDF copy is `documentation/abra-master-plan.pdf`.
2. The demo files in `prototypes/` for every screen you build. **The real UI must look and behave exactly like the demo** (same layout, wording, buttons, dialogs, fields, states).

**Working rules**
- **Work only in your own folder (a git worktree) on your own branch `customer-app`.** All sessions share the folder `D:/New_project/abra-travels`, so never switch branches inside it; that would move every other session's files. The checkpoint commit already exists on main. Create your folder once, from a terminal:
  `git -C D:/New_project/abra-travels worktree add D:/New_project/abra-wt-ca -b customer-app main`
  Then work only inside `D:/New_project/abra-wt-ca`. Git does not copy ignored files, so copy `backend/.env.development` and the folder `backend/secrets` from the main folder into the same paths in yours (copy the files with the operating system; never open, print or paste their contents), then run `npm ci` in `backend` and `flutter pub get` in each Flutter app you touch.
- Commit only on your branch, in small commits. Do not commit to main, do not push, do not reset or rebase anything you did not create. The coordinator merges your branch.
- (The coordinator session is the exception: it works in the main folder on main and never creates a worktree.)
- **Three files per feature and audience**: `<feature>_<app>_screen.dart` (models, state, API calls and ALL widgets inside), `<feature>_<app>.ts` (schema, DTOs, controller, module), `<feature>_<app>.service.ts` (logic). New code only; do not rewrite working files. Tests go in `test/` or `tests/` folders.
- **Shared files belong to the coordinator**: `rbac/permissions/permission-catalog.ts`, `rbac/permissions/access-pages.ts`, `audit-logs/schemas/audit-log.schema.ts` (audit action list), `modules/domain-modules.ts`, `app.module.ts`, `config/environment.schema.ts`, everything in `packages/shared_*`, and `documentation/abra-master-plan.*`. If you need a change there, write it in your report under "Shared changes I need" with the exact lines; do not edit the file. (The only exception: adding new entries at the end of a list is allowed in your own branch, never reorder or remove, and list each one in your report.)
- Do not run Prettier or ESLint `--fix` over folders you do not own.
- Every endpoint needs its permission key, and mutating endpoints write an audit entry through the shared audit approach already used by the access matrix (`rbac/access_matrix_admin_manage*` is the reference example). Operators see only their own data. Money is integer paise. Times are India time.
- Secrets: never print, paste or commit any secret or the MongoDB connection string. Read them from the git-ignored env files only.

**Your own test environment (so sessions do not break each other)**
- Database: copy `MONGODB_URI` from `backend/.env.development` and change only the database name at the end to `abra_travels_ca`. Pass it to the backend as a process environment variable (it overrides the file). Never use the main database `abra_travels` for tests.
- Run your backend on port `4004` (`PORT=4004`). Use `REDIS_KEY_PREFIX=ca` and `QUEUE_PREFIX=ca`.
- Docker and Redis are already running (container `abra-redis`).

**Definition of done for each feature**
1. The three files exist and nothing else was needed.
2. Every button of the demo page has a working endpoint (see the appendix of the master plan).
3. Permissions, audit and notifications work; the matrix level None / View / Edit / Edit+Delete is enforced by the server.
4. Loading, empty, error, no-permission and offline states show.
5. The screen matches the demo side by side.
6. `npx tsc --noEmit`, lint and the unit tests are clean; database tests pass on your own test database; Flutter: `flutter analyze` clean.
7. A plain-language test checklist for the user is written (what to open, what to press, what should happen).

**Report format (send to the coordinator after each feature)**
- Done and tested: what, with the commands you ran and the result.
- Done but untested: what and why.
- Not done / blocked: what and what you need.
- Shared changes I need: exact lines.
- Files created or changed (paths).
- Do not say "done" for anything you did not run.

## Your scope
Finish the customer app (`apps/customer_app`) so it equals the demo (`prototypes/customer_demo_model.html`) and is ready to connect to the real backend one feature at a time. Screens and every button and endpoint: master plan Appendix F.

## What to do
1. Compare the Flutter app with the demo screen by screen and list the gaps (the master plan lists likely ones: Messages page, Google and Apple sign-in buttons, email required together with mobile, per-seat-type prices, running-trip banner, SOS on tracking, support tickets with proof files, notification settings, delete account, 8 languages, assistant). Verify each in the code; do not assume.
2. Build the missing screens, each as the three-file pattern for the customer audience, with mock repositories first.
3. As the backend endpoints appear (the coordinator tells you), swap the `Mock...Repository` for the `Api...Repository` one feature at a time and test on your own database, in this order: seats, passengers and review, payment, ticket and messages, My Trips, cancel and refund, tracking, SOS and sharing, notifications, support, profile.

## Special rules
- **The login files of the customer app are not edited without asking the user.**
- Languages: English, Telugu, Hindi, Kannada, Tamil, Malayalam, Marathi, Bengali; names shown in English next to the native script.
- Design system: navy and blue palette with the brand gradient; check each screen at phone widths against the demo.
- Do not build backend endpoints; send "Endpoints I need" to the coordinator.
```
