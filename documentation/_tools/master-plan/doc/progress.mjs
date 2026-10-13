// Part 9: where the work stands. Update this file whenever something is built, tested or found.
export const LAST_UPDATED = '13 October 2026';

export const BUILT = [
  // [phase, what, status, how it was checked, where]
  ['0', 'MongoDB Atlas connected; the database accepts only the two PC addresses', 'Done', 'Connection tested from the backend; the open "anywhere" entry was removed', 'backend/.env.development (git-ignored)'],
  ['0', 'Redis in Docker, backend starts with MongoDB, Redis, queues and outbox up', 'Done', '/health/ready answers ready', 'infrastructure/docker-compose.development.yml'],
  ['0', 'Super Admin account created', 'Done', 'Signed in over HTTP; the bootstrap lines were then deleted from the env file', 'npm run bootstrap:super-admin'],
  ['0', 'Access matrix (None, View, Edit, Edit and delete per role per page), Super Admin only, audited', 'Built and tested', '19 unit tests; tested against Atlas: create, change and delete a role, the Super Admin row refuses changes', 'rbac/access_matrix_admin_manage*.ts, rbac/permissions/access-pages.ts'],
  ['0', 'Messages log: admin list, filters, read, resend; customer "Messages sent to me"; the sender other features call', 'Built and tested', '10 unit and 11 end-to-end tests', 'messages/messages_admin_manage*.ts, messages_customer*.ts'],
  ['0', 'Integration settings: Razorpay, Maps, SMS, Push, AI assistant (secrets encrypted, never returned), connection tests', 'Built and tested', '16 unit and 9 end-to-end tests; real provider calls tested only against a fake network', 'system-settings/integrations_admin_manage*.ts'],
  ['0', 'Assistant endpoint (Groq through the backend, tools by role, proposed changes need confirmation, development mode without a key)', 'Built and tested', '23 unit and 16 end-to-end tests; real Groq not tested (no key)', 'chatbot/assistant_chat*.ts'],
  ['0', 'Live-update channel (sockets): token check, rooms, followable topics, publisher for API and worker, re-check every minute', 'Built and tested', '29 unit and 13 end-to-end tests with real socket connections', 'realtime/live_updates_channel*.ts'],
  ['0', 'Feature flags (9 switches) and maintenance (5 scopes, message, window) enforced by one global guard', 'Built and tested', '31 unit and 15 end-to-end tests', 'feature-flags/flags_admin_manage*.ts'],
  ['0', 'Demo seed: 20 cities, 52 places, 6 bus types, 14 companies, 31 buses', 'Built, tested locally; NOT loaded into Atlas by decision', '18 unit tests; run for real on a local database and twice (adds nothing the second time). Decision of 13 October 2026: no sample data goes into Atlas; real data is created by testing through the apps. The seed stays a tool for throw-away local databases only', 'npm run seed:demo, backend/src/seed, backend/seed/demo-data.json'],
  ['0', '15 end-to-end tests that were failing before any of this work', 'Fixed', 'Cause: test operators had no active company record, which the login guard now requires. Test helper fixed; one test now checks the real data-scope protection', 'rbac/tests/rbac-e2e.harness.ts, authorization-isolation.e2e-spec.ts'],
  ['0', 'Phase 0 checklist (27 steps) run end to end over HTTP', 'All 27 pass', 'On a temporary local database with a throw-away admin, then deleted (step J, the sample data, is skipped on Atlas). Rerun on Atlas with your password', 'backend/scripts/phase0-checklist.mjs'],
];

export const PHASE1 = [
  ['1', 'Step 0 and 1: permission keys for delete and export, shared soft delete and restore, audit of delete and restore, "in use" refusals', 'Built and tested (branch)', 'catalogue-shared end-to-end suite passes (33)', 'modules/catalogue-shared/catalogue_shared_manage*.ts'],
  ['1', 'Step 2: banner duplicate, archive and reorder; banners shown higher-order first with audience and colour style as in the demo; read-one routes; invitation edit and expiry', 'Built and tested (branch)', 'banners end-to-end 28 pass; invitations suite passes; admin app 144 tests pass', 'banners_admin_manage*, invitations_admin_manage*'],
  ['1', 'Step 3: server-side export (CSV and Excel) for 8 lists; import with template and dry run for cities and places', 'Built and tested (branch)', 'export 15 and import 10 end-to-end tests pass', 'catalogue-shared; exceljs added to package.json'],
  ['1', 'Step 4: amenities (add, switch on and off, bus forms use the active ones)', 'Built and tested (branch)', 'amenities 8 end-to-end tests pass; admin app 150 tests pass', 'modules/amenities/amenities_admin_manage*.ts'],
  ['1', 'Step 5: place requests (operator asks, admin approves or rejects with a reason; approve creates a shared place; audited; notifications); places gain "Used for" and "Trips using it"; admin "Cities and places" page with three tabs; client Places page', 'Built and tested; merged into main', 'locations, catalogue-shared, amenities, trips, routes end-to-end pass; admin app 154 and client portal 20 tests pass; checked in a browser on a local database except the client "Request a place" window', 'modules/locations/places_admin_manage*.ts, places_client_manage*.ts'],
];

export const PHASE1_REMAINING = [
  'Step 6: operator detail page with tabs; suspend with reason and proof; reactivate; message the owner',
  'Step 7: payout mode and bank details with verification',
  'Step 8: company profile and bank page in the client portal',
  'Step 9: bus KYC from the client portal, KYC history',
  'Step 10: compare the KYC questionnaire with the demo; export of the questionnaire',
  'Import with a dry run for bus types, document types and banners (they still use the old on-device CSV import)',
];

export const GAPS = [
  ['Real outside services', 'Razorpay, Google Maps, Groq, SMS, Firebase push and WhatsApp were only tested against a fake network. Keys are needed (Part 7).'],
  ['Atlas for the newer features', 'Messages, integration settings, assistant, feature flags, maintenance and live updates were tested on a local database. The checklist script can run them against Atlas with your password.'],
  ['Event router and notification demo', 'The plan\'s Phase 0 goal "a notification travels from the backend to a phone and to the admin bell" is not shown yet: the notification and socket machinery exists and is tested, but no business event feeds it until bookings, trips and refunds exist.'],
  ['Audit log page', 'The read endpoint exists. Filters, the detail view and export from the demo are still to build (Phase 7).'],
  ['Proof files', 'The storage decision (existing files service, local in development, a bucket before staging) is recommended but not yet built into the proof boxes.'],
  ['Apple sign-in', 'The route exists (`POST /auth/apple`); not tried with a real Apple account.'],
  ['Flutter apps', 'No app calls any of the Phase 0 endpoints yet. The admin app is being wired to Phase 1 on its own branch.'],
  ['Assistant details', 'Answers arrive whole, not word by word. Feature tools (bookings, trips) are added with those features. Behaviour with the real Groq model, including attempts to break its rules, is untested.'],
];

export const ISSUES = [
  ['Docker Desktop is unreliable on this PC', 'It stopped twice and once crashed during the Redis-restart test. Database tests need it. Start it first and wait for "running".'],
  ['Two tests are timing-sensitive', 'A Super Admin bootstrap test that starts several runs at once (passes about 2 of 3 times alone) and a queue test (passes about 3 of 4). Neither is in code changed in Phase 0.'],
  ['Redis-restart test', 'It stops and starts the Redis container itself and can bring Docker down. Run it alone, or leave it out of a full run.'],
  ['Branch merge', 'Phase 1 steps 0 to 4 were merged into main on 13 October 2026; the shared files kept both sides. Later Phase 1 steps are merged the same way. The Dart permission parity test needs messages.read, messages.resend and maintenance.bypass.'],
  ['customer_app analyze', 'Shows 3 informational lines on the untouched main branch.'],
  ['Atlas password', 'The database password was shown in a screenshot and in chat. It still needs resetting; then update backend/.env.development.'],
];

export const TOTALS = 'After merging Phase 1 steps 0 to 4 into main (13 October 2026): unit tests 751 (750 pass; one queue test fails now and then); end-to-end 295 of 295 in 27 files (rbac, document types, catalogue-shared, banners, onboarding, amenities, system settings, messages, assistant, live updates, feature flags, password sign-in; the Redis-restart test left out); Dart permission parity passes. Phase 0 checklist: 27 of 27 on a local database; not yet run on Atlas.';

export const PHASE0_CHECKLIST = [
  'Start Docker Desktop and wait for "running", then start the backend (`npm run start` in the backend folder) and open `http://localhost:4000/api/docs`.',
  '**A. Health:** `GET /health/ready` shows ready, MongoDB up, Redis up.',
  '**B. Sign in:** `POST /api/v1/auth/login` with `{ "identifier": "<Super Admin email>", "password": "...", "device": { "clientType": "MOBILE" } }` (use MOBILE so the refresh token is in the answer). Copy `accessToken` into Authorize. `GET /me` shows your name and `userType` STAFF inside `user`.',
  '**C. Access matrix:** `GET /access-matrix?audience=ADMIN` shows 38 pages, the Super Admin row locked and FULL. Create a role with `POST /access-matrix/roles`, set Trips to VIEW, try to change SUPER_ADMIN (must be refused with 403), then delete the test role.',
  '**D. Audit:** `GET /audit-logs` shows created, access changed and deleted, each with who and why.',
  '**E. Messages:** `GET /admin/messages` is an empty list (correct until bookings exist).',
  '**F. Integrations:** `GET /settings/integrations` lists 7 cards. Set Maps to `osm`, test it. Save a test SMS secret: only "set" and the last four characters come back. Clear it.',
  '**G. Assistant:** `POST /assistant/chat` with "who am i?" answers with your role.',
  '**H. Feature flags:** `GET /features` (no sign-in) shows 9 switches, 4 on. Switch `live_tracking` off, see it false, switch it back on.',
  '**I. Maintenance:** switch the customer scope on with a message, see `/maintenance/status?app=customer` active, see a customer-app request answered 503 with the message, see the admin portal still works, then **switch it off**.',
  '**J. Sample data: skipped on purpose.** No sample data is loaded into Atlas; you create the real data through the apps. (On a throw-away local database only: `npm run seed:demo`, then 20 cities show.)',
  '**K. Sign out:** `POST /auth/logout` with `{ "refreshToken": "..." }` from the sign-in answer; the old token then answers 401.',
  'All of this can be run by script: `CHECKLIST_EMAIL=... CHECKLIST_PASSWORD=... node scripts/phase0-checklist.mjs` (26 steps on Atlas; step J is skipped).',
];

export function progress(d) {
  d.h(2, 'Part 9. Progress log');
  d.p(`Kept up to date as work is done. Last updated ${LAST_UPDATED}. ${TOTALS}`);
  d.h(3, '9.1 Phase 0 (committed on main, eea85ec)');
  d.table(['Phase', 'What', 'Status', 'How it was checked', 'Where'], BUILT);
  d.h(3, '9.2 Phase 1 (other session, branch `phase1-catalogue-kyc`, worktree `D:/New_project/abra-wt-p1`; steps 0 to 4 merged into main)');
  d.table(['Phase', 'What', 'Status', 'How it was checked', 'Where'], PHASE1);
  d.p('Still to do in Phase 1:');
  d.ul(PHASE1_REMAINING);
  d.h(3, '9.3 What is not done or not proven');
  d.table(['Item', 'Detail'], GAPS);
  d.h(3, '9.4 Known problems');
  d.table(['Problem', 'Detail'], ISSUES);
  d.h(3, '9.5 What happens next');
  d.ol([
    'You run the Phase 0 checklist (Part 4) against Atlas, or tell Claude to run it with your password.',
    'No sample data is loaded into Atlas (your decision): the first real data is created through the apps while you test.',
    'You say "Phase 0 is good" and give the Phase 1 session the go for step 5.',
    'The Phase 0 gaps are built one at a time after your yes: audit log page (filters, detail, export), proof files, the event router.',
    'You reset the Atlas password and supply the keys listed in Part 7 when each phase needs them.',
  ]);
}

// Part 4, Phase 1: build order and status (written by the Phase 1 session, merged 13 October 2026).
export function phase1Status(d) {
  d.h(4, 'Phase 1: build order (approved 12 October 2026)');
  d.p('0. Checkpoint commit (done) and this document corrected. 1. Per-module delete and export permission keys, then the shared mechanism (soft delete, restore, audit hook, shared list query, "in use" check). 2. Small items: banner duplicate, archive and reorder; read-one routes; invitation edit and expiry. 3. Server-side export for every list, then import with template and dry run. 4. Amenities. 5. Place requests (backend, admin tabs, client Places page). 6. Operator detail page with tabs, suspend with proof, message owner. 7. Payout mode and bank verification. 8. Company profile and bank details (client portal). 9. Bus KYC (client portal) and KYC history. 10. KYC questionnaire compared with the demo\'s three tabs (can run early, in parallel). One step at a time; you test after each.');
  d.p('**Status on 13 October 2026.** Phase 1 is built on the branch `phase1-catalogue-kyc` (its own working folder, `D:/New_project/abra-wt-p1`). Steps 0 to 4 are merged into `main`; later steps are merged by the coordinator the same way.');
  d.table(['Step', 'What', 'Status', 'Commits'], [
    ['0', 'Checkpoint commit and this document corrected', 'Done 12 Oct', 'on `main`'],
    ['1', 'Delete and export permission keys; one shared soft delete with restore, audit and "in use" refusal', 'Done 12 Oct', '276be54, 501667f'],
    ['2', 'Banner duplicate, archive and reorder; read-one routes; invitation edit and the Expired status', 'Done 13 Oct', 'b982a60'],
    ['2b', 'Admin screens for step 2; banner fields as in the demo (colour style, shown to, operator link, higher order first)', 'Done 13 Oct', '2001676, edbd087'],
    ['3', 'Server-side export of eight lists (CSV and Excel); import with template and dry run for cities and places', 'Done 13 Oct', '39e7ee4, fe15857'],
    ['4', 'Amenities as a managed list; Amenities card on the Bus types page', 'Done 13 Oct', '6f75cb4, 222913e'],
    ['5', 'Place requests (backend, admin tab, client page); admin page "Cities and places" with tabs Places, Cities, Operator requests; client Places page', 'Done 13 Oct', 'b15e122'],
    ['6', 'Operator detail with tabs; suspend with reason and proof; message owner', 'Not started', ''],
    ['7', 'Payout mode and bank details with verification', 'Not started', ''],
    ['8', 'Company profile and bank details (client portal)', 'Not started', ''],
    ['9', 'Bus KYC (client portal) and KYC history', 'Not started', ''],
    ['10', 'KYC questionnaire compared with the demo\'s three tabs, and its export', 'Not started', ''],
  ]);
  d.p('**What works now**');
  d.ul([
    '**Delete and Undo** on cities, places, bus types, required documents, operators, invitations and banners. A record that other records use is refused with a sentence that names what uses it ("This city is used by 3 routes and 5 trips, so it cannot be deleted. Disable it instead."). Undo is the restore route. Needs the module\'s delete key (Edit+Delete level). Audited.',
    '**View** (read-only window) on cities, places, bus types, required documents, operators and invitations.',
    '**Banners** as in the demo: columns Banner, Status (Draft, Scheduled, Published, Expired, Archived), Runs, Shown to, Opens, Order with arrows; the form with colour style, Opens (offer, route search, operator, web link), offer code, shown to (everyone, new users, signed-in users), dates, order, pictures and a home-screen preview; Save draft and Publish; Unpublish, Duplicate, Archive (with Undo and a way back), Delete (with Undo).',
    '**Invitations**: open one, edit a pending one (a new email makes the old link stop working; the closing date can be moved up to 30 days ahead), Expired filter and card, search, delete a withdrawn one.',
    '**Export** (CSV or Excel, the list\'s own filters, at most 20,000 rows, audited) for cities, places, bus types, required documents, operators, invitations, KYC reviews and banners.',
    '**Import** for cities and places: template download (the headings match the export), a check of the whole file that lists the problem of every row, then a save of the rows that are right (at most 500 rows and 1 MB). The old on-device CSV import remains for bus types, required documents and banners until they get the same.',
    '**Amenities** are a list staff manage (add, switch on or off; never deleted). A bus can be given only amenities that are switched on; a bus keeps an amenity that was switched off later. The 13 amenities that were fixed before are the starting list.',
  ]);
  d.p('**Decisions taken while building (13 October 2026)**');
  d.ul([
    'Soft delete is one mechanism for all catalogue records (`deletedAt`, `deletedBy`; `backend/src/database/soft-delete.plugin.ts`). A deleted record is hidden from every query. Known limit: the unique key or slug of a deleted city, bus type or document type stays taken; restore it instead of adding it again.',
    'Delete and restore both need the module\'s delete key. Export is a View-level action in the access matrix (the demo shows Export to everyone who can open the page); delete is Edit+Delete only.',
    'Only a withdrawn invitation can be deleted. A pending or accepted one is refused.',
    'Banner order: a higher number shows first (as in the demo; this reversed the old lower-first rule). Banner pictures: desktop 1920 x 600, phone 800 x 600, at most 1 MB. The customer app asks for `GET /banners?viewer=GUEST|NEW_USER|RETURNING` so audiences reach the right people; it must also draw `colourStyle`.',
    'An import saves the rows that are right and leaves out the others, saying why for each row; a file is never refused as a whole because of one bad row (only for missing columns, size or row count).',
    'Export and import controllers are registered before a module\'s other controllers, because those have `GET <list>/:id` routes.',
    'Tests that need the database run on the local Docker MongoDB in a throw-away database whose name ends in `_test`, not on Atlas.',
    'Step 5: on the Operator requests tab, View uses `GET /admin/place-requests/:id`, not `/catalogue/locations/:id` as Appendix D.9 shows. Place requests are never deleted; they are kept for the record.',
  ]);
  d.p('**Where the real screens still differ from the demo**');
  d.ul([
    'Banners: no Analytics tab yet (impressions and clicks are not counted); the offer code is a text field until the offers module exists (Phase 3); the route, operator and web-link inputs are extra, because the demo form has no place to enter them; Expired and "Put back as draft" are extra statuses and buttons.',
    'Cities and places: the lists lack the demo\'s Search, City, Used-for and Status filters, the Operator requests tab and the "Trips using it" column (step 5 and later).',
    'Operators: no detail page with tabs, and no Buses, Trips or Rating columns (step 6).',
    'Required documents and KYC questionnaire: export of the questionnaire, delete of questions and the three-tab comparison wait for step 10.',
    'Screens were checked with automated tests and the analyzer, not yet looked at in a browser against the demo.',
  ]);
  d.p('**Shared files changed by Phase 1** (appended only; kept when merging): the permission catalogue (`catalogue.delete`, `catalogue.export`, `documents.delete`, `documents.export`, `operators.delete`, `operators.export`, `banners.read`, `banners.export`), the access pages (`export` counts as a View action), the audit actions (`catalogue.deleted`, `catalogue.restored`, `catalogue.exported`, `catalogue.imported`, `onboarding.invitation-updated`), the error codes (`RESOURCE_IN_USE`), the domain module list (`CatalogueSharedModule`, `AmenitiesModule`), the Dart permission keys and error codes, `ApiClient.patch`, and the backend package list (`exceljs`).');
  d.p('Boundaries for the Phase 1 session: do not run prettier or eslint --fix across `rbac` or `users`; the audit action list is shared, so only add actions; stay out of `whatsapp`, `notifications`, `system-settings` and `chatbot` (the Phase 0 session works there).');
}

// Appendix I: routes not in the generated table (feature-style files and Phase 0 and 1 additions).
export function routesAddedSince(d) {
  d.h(3, 'I.1 Controllers in `<feature>_manage` style files (not in the table above)');
  d.p('Checked 12 October 2026 against `backend/src`. These routes exist and count as "Exists".');
  d.table(['File', 'Routes'], [
    ['rbac/access_matrix_admin_manage.ts', 'GET /access-matrix\nPUT /access-matrix/roles/:roleKey/pages/:pageId\nPUT /access-matrix/roles/:roleKey\nPOST /access-matrix/roles\nPATCH /access-matrix/roles/:roleKey\nDELETE /access-matrix/roles/:roleKey'],
    ['authentication/google_sign_in.ts', 'POST /auth/google\nPOST /auth/apple\nPOST /auth/client/otp/verify\nGET /client/kyc/login-methods\nPOST /client/kyc/login-methods/phone\nPOST /client/kyc/login-methods/social'],
    ['onboarding/client_kyc.ts', 'GET /client/kyc\nPUT /client/kyc'],
    ['system-settings/admin_kyc_configuration.ts', 'GET /settings/kyc-configuration\nPUT /settings/kyc-configuration\nPOST /settings/kyc-configuration/validate-import\nPOST /settings/kyc-configuration/preview'],
  ]);
  d.p('Corrections found on the same check: Apple sign-in already has a route; the KYC questionnaire is one configuration document at `/settings/kyc-configuration`, not the `/admin/kyc/...` routes named in D.12 (to be rewritten in Phase 1 step 10).');
  d.h(3, 'I.4 Routes added in Phase 1 (13 October 2026)');
  d.p('All need a bearer token and the permission shown. Merged into `main` on 13 October 2026.');
  d.table(['Area', 'Routes', 'Permission'], [
    ['Delete and Undo', '`DELETE` and `POST .../restore` on `/catalogue/cities/:id`, `/catalogue/locations/:id`, `/catalogue/bus-types/:id`, `/catalogue/document-types/:id`, `/catalogue/operators/:id`, `/onboarding/invitations/:id`, `/admin/banners/:id`', '`catalogue.delete`, `documents.delete`, `operators.delete`, `banners.delete`'],
    ['Read one', '`GET /catalogue/bus-types/:id`, `GET /catalogue/document-types/:id`, `GET /onboarding/invitations/:id`', '`catalogue.read`, `documents.read`, `operators.create`'],
    ['Invitations', '`PATCH /onboarding/invitations/:id`; the list takes `status=EXPIRED` or `PENDING` (still valid) and `search`', '`operators.create`'],
    ['Banners', '`POST /admin/banners/:id/duplicate`, `/archive`, `/unarchive`; `PATCH /admin/banners/order`; `GET /banners?viewer=` (public)', '`banners.manage`; the two reads need `banners.read`'],
    ['Export', '`GET .../export?format=csv|xlsx` on `/catalogue/cities`, `/catalogue/locations`, `/catalogue/bus-types`, `/catalogue/document-types`, `/catalogue/operators`, `/onboarding/invitations`, `/onboarding/submissions`, `/admin/banners` (same filters as the list)', '`catalogue.export`, `documents.export`, `operators.export`, `banners.export`'],
    ['Import', '`GET /catalogue/cities/import-template`, `POST /catalogue/cities/import?dryRun=true|false`; the same two on `/catalogue/locations`', '`catalogue.manage`'],
    ['Amenities', '`GET`, `POST /admin/amenities`; `PATCH /admin/amenities/:id/active`; `GET /catalogue/amenities` (the ones switched on, for bus forms)', '`catalogue.read`, `catalogue.manage`, `buses.read`'],
  ]);
  d.p('The KYC questionnaire routes stay as in I.1 (`/settings/kyc-configuration`); its export is part of step 10. Phase 0 routes (access matrix, `/admin/messages`, `/settings/integrations`, `/assistant/chat`, `/features`, `/admin/feature-flags`, `/maintenance/status`, `/admin/maintenance`) are listed in Part 9 and in the Phase 0 checklist.');
}
