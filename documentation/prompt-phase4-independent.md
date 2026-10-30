# Hand-off prompt: Phase 4, the parts that do not depend on the booking journey

Give this whole file to a new Claude Code session. It is written so the session needs nothing else.

---

## 0. Who you work for and how to talk

The owner of this project writes short, informal English and often with typing mistakes. Read for meaning.
- "just tell me" means explain only, change nothing.
- A request to "commit" or "start" is a go-ahead. **Never commit, push, merge or send a real message without a clear yes.**
- Show what you did with real numbers (tests run, passed, failed). Never say "done" for something you did not run.
- When you test in the browser, the owner signs in. Never enter the owner's own account password.

## 1. The project

Abra Travels is a bus booking platform: a NestJS backend (`backend/`, MongoDB, Redis) and four Flutter apps in `apps/`:
`admin_app` (Abra staff), `client_portal` (bus operators), `customer_app` (travellers), `driver_app`. Shared Flutter packages are in `packages/`.
Plan of record: `documentation/abra-master-plan.md` (read the Phase 4 section and the "Phase 4: your test checklist"). Other useful files: `documentation/architecture.md`, `api-architecture.md`, `authorization.md`, `testing.md`, `notification-architecture.md`.

## 2. Your task: the independent parts of Phase 4

Another session is finishing Phase 3 (seat hold, booking, coupons, payments, ticket). **Do not touch** these folders: `backend/src/modules/{bookings,payments,tickets,coupons,inventory}`, the customer app `features/booking`, the admin `features/marketing` offers page. Do not touch `backend/src/modules/rbac/permissions/permission-catalog.ts` except to **append** a new permission group at the end of the object (that file is shared; only append).

Build, in this order. For each: backend endpoints with tests, then the Flutter screen connected to it, then widget tests. Every screen must show real data from the backend: no sample or mock data.

### A. Information pages and FAQs (`content`)
- Backend module `backend/src/modules/content/` (today only an empty module file). Collections: `pages` (terms, privacy, about; a title, a body, a status, who changed it and when), `faqs` (question, answer, order, status, category), `contact` (support phone, email, address, hours).
- Admin writes, everyone reads. Public read endpoints (no sign-in) for the customer app and the website: `GET /content/pages/:key`, `GET /content/faqs`, `GET /content/contact`. Admin endpoints under `/admin/content/...` with permissions `content.read` / `content.manage`. Every change is audited (use `AuditedChangeRunner`, see how `operator-staff` or `commissions` do it).
- Admin screen: `apps/admin_app/lib/features/support/admin_content_page.dart` (a shell today). Customer screen: `apps/customer_app/lib/features/info/info_page.dart`.

### B. Customers and profile (`customers`)
- Backend: `backend/src/modules/customers/` has schemas, repositories and services already; check what exists first. Add: customer profile read and edit (name, email is required, language), admin customer list with search and filters and detail, **block and unblock with a reason and optional proof file**, **sign out of all devices** (the `sessions` module exists), **account deletion** (soft delete; if the customer has upcoming bookings, refuse with a clear message; for now check the `bookings` collection by `customerId` and `status` only, read-only, do not import the bookings module).
- Admin screen: `apps/admin_app/lib/features/customers/admin_customers.dart`. Customer screens: `apps/customer_app/lib/features/profile/` (profile, edit, delete account, sign out of all devices).

### C. Notification settings and languages
- Customer notification settings (`profile/notification_settings_screen.dart`): which kinds of message the customer wants on WhatsApp, email and push. Store per customer; the existing notification/event router (`backend/src/modules/notifications/event_router_core*`) must respect it (read how rules choose recipients and channels before changing anything; add the check, do not rewrite the router).
- Languages: `backend/src/modules/translations/` and `customer_app/lib/features/language/`. Keep the existing language step; add what the plan asks for if missing, and make the choice persist on the customer.

### D. Support tickets (`support`)
- Backend `backend/src/modules/support/`. Collections `tickets`, `replies`. A customer raises a ticket with category, message and an optional proof file (use the existing file upload service, see `ProofFiles` and `FILE_STORAGE`); an optional `bookingId` is stored as text only. Admin: list with filters, assign, canned replies, send reply, mark resolved, reopen, a time limit after which a ticket is flagged. Customer sees status and replies.
- Admin screen `admin_tickets_page.dart`; customer screens in `customer_app/lib/features/support/`.

## 3. Where to work

Create your own git worktree from the branch `screens-group-a` (it holds all the shared work), for example:
`git worktree add ../abra-wt-phase4 -b phase4-independent screens-group-a`
Work only there. Do not change `main`. Do not push.

## 4. How the code is organised (follow it, do not invent a new style)

- Backend module files are named by feature and audience: for example `crew_client_manage.ts` (controller), `crew_client_manage.service.ts`, `tests/*.e2e-spec.ts`. Look at `backend/src/modules/commissions/` and `operator-staff/` as models.
- Permissions: `@RequirePermission('x.read')` on admin routes; `@AuthenticatedOnly()` for customer routes; `@PublicEndpoint()` for guests. New permission group: append to `PERMISSION_CATALOG` in `rbac/permissions/permission-catalog.ts`, and add the page row in `access-pages.ts` only if the page is not already listed. Then run the rbac tests.
- Errors: `new ApiException('CODE', 'message in words')`; codes are in `common/errors/api-error-codes.ts`.
- Transactions: `TransactionRunner`. Customer id from the actor: `new Types.ObjectId(actor.userId)`.
- Money is always in paise (integers).
- Flutter: every app talks to the backend through `ApiClient` from `shared_network`; screens depend on repository interfaces. Look at `customer_app/lib/features/booking/repositories/` and `client_portal/lib/features/crew/` for the pattern. No hard-coded sample data. Text for users must be plain, short and actionable.
- File encoding: write files as UTF-8. The file tool converts `\u` and `\n` escapes in some content into real characters; when you need a special character in Dart or TypeScript source, build it with a code (for example `String.fromCharCode`) or test the result. Some old files are not UTF-8: if an edit is refused for that reason, delete the file and write it again.
- In shell scripts, avoid heredocs that contain quotes and dollar signs; write a script file with the file tool and run it.

## 5. Data and environment rules (important)

- **Use only the local Docker MongoDB (`abra-mongodb`) and Redis (`abra-redis`).** Never use MongoDB Atlas. Never print, store or paste any password or connection string. **Do not edit `backend/.env.development` or `backend/.env.bootstrap.local`**; override settings with environment variables on the command line instead.
- Backend e2e tests use throw-away databases named `*_test` (for example `abra_supply_test`). Run with:
  `MONGODB_URI='mongodb://localhost:27017/abra_supply_test?directConnection=true' npm run test:e2e -- src/modules/<your module>`
  Unit tests: `npm test -- <path>`. Type check: `npx tsc --noEmit -p tsconfig.json`.
- If the Mongo container shows "unhealthy", `docker restart abra-mongodb` fixes it. The machine is slow; give long commands a long timeout and run them in the background.
- Flutter checks: in each app folder `flutter analyze` and `flutter test`. Port 3000 may be held by an unrelated Docker container (`run-app-1`): do not stop it. For the browser, serve a `flutter build web --profile --dart-define=ABRA_API_BASE_URL=http://localhost:4001` build with `python -m http.server <port>` and start the backend with `CORS_ALLOWED_ORIGINS` including that port. Release builds refuse an http API address.
- The browser pane is flaky: hover before clicking, the first click after typing may be swallowed, and screenshots can lag. Prefer reading the page over screenshots where you can.

## 6. Definition of done

For each of A to D: endpoints built and listed with their routes and permissions; backend tests written and run (give the numbers); the Flutter screens connected and their widget tests run (give the numbers); `flutter analyze` clean; then a browser test with a screenshot at each step (the owner signs in). Finish with a short report: what is done, what is not, anything you changed outside your folders, and the branch name. Ask before committing.

## 7. Report format

Short plain sentences, no jargon, in this order: what works now, what you tested (with numbers), what is not done, what needs the owner's decision.
