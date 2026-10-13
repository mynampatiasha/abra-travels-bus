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
];

export const PHASE1_REMAINING = [
  'Step 5: place requests (operator asks, admin approves or rejects) and the three-tab Places page',
  'Step 6: operator detail page with tabs; suspend with reason and proof; reactivate; message the owner',
  'Step 7: payout mode and bank details with verification',
  'Step 8: company profile and bank page in the client portal',
  'Step 9: bus KYC from the client portal, KYC history',
  'Step 10: compare the KYC questionnaire with the demo; export of the questionnaire',
  'Import with a dry run for bus types, document types and banners (they still use the old on-device CSV import)',
  'Merge the Phase 1 branch (worktree abra-wt-p1) with the Phase 0 work in the main folder',
];

export const GAPS = [
  ['Real outside services', 'Razorpay, Google Maps, Groq, SMS, Firebase push and WhatsApp were only tested against a fake network. Keys are needed (Part 7).'],
  ['Atlas for the newer features', 'Messages, integration settings, assistant, feature flags, maintenance and live updates were tested on a local database. The checklist script can run them against Atlas with your password.'],
  ['Event router and notification demo', 'The plan\'s Phase 0 goal "a notification travels from the backend to a phone and to the admin bell" is not shown yet: the notification and socket machinery exists and is tested, but no business event feeds it until bookings, trips and refunds exist.'],
  ['Audit log page', 'The read endpoint exists. Filters, the detail view and export from the demo are still to build (Phase 7).'],
  ['Proof files', 'The storage decision (existing files service, local in development, a bucket before staging) is recommended but not yet built into the proof boxes.'],
  ['Apple sign-in', 'Not built.'],
  ['Flutter apps', 'No app calls any of the Phase 0 endpoints yet. The admin app is being wired to Phase 1 on its own branch.'],
  ['Assistant details', 'Answers arrive whole, not word by word. Feature tools (bookings, trips) are added with those features. Behaviour with the real Groq model, including attempts to break its rules, is untested.'],
];

export const ISSUES = [
  ['Docker Desktop is unreliable on this PC', 'It stopped twice and once crashed during the Redis-restart test. Database tests need it. Start it first and wait for "running".'],
  ['Two tests are timing-sensitive', 'A Super Admin bootstrap test that starts several runs at once (passes about 2 of 3 times alone) and a queue test (passes about 3 of 4). Neither is in code changed in Phase 0.'],
  ['Redis-restart test', 'It stops and starts the Redis container itself and can bring Docker down. Run it alone, or leave it out of a full run.'],
  ['Branch merge', 'Both branches changed the same shared files (permission list, audit action list, module list, eslint config). Keep both sides; the cross-session notes list each line. The Dart permission parity test needs messages.read, messages.resend and maintenance.bypass.'],
  ['customer_app analyze', 'Shows 3 informational lines on the untouched main branch.'],
  ['Atlas password', 'The database password was shown in a screenshot and in chat. It still needs resetting; then update backend/.env.development.'],
];

export const TOTALS = 'Unit tests: 730 (729 pass; one queue test fails now and then). End-to-end tests: every new suite passes; the 15 older failures are fixed. Phase 0 checklist: 27 of 27.';

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
  d.h(3, '9.1 Phase 0 (main folder, not committed yet)');
  d.table(['Phase', 'What', 'Status', 'How it was checked', 'Where'], BUILT);
  d.h(3, '9.2 Phase 1 (other session, branch `phase1-catalogue-kyc`, worktree `D:/New_project/abra-wt-p1`, not merged)');
  d.table(['Phase', 'What', 'Status', 'How it was checked', 'Where'], PHASE1);
  d.p('Still to do in Phase 1:');
  d.ul(PHASE1_REMAINING);
  d.h(3, '9.3 What is not done or not proven');
  d.table(['Item', 'Detail'], GAPS);
  d.h(3, '9.4 Known problems');
  d.table(['Problem', 'Detail'], ISSUES);
  d.h(3, '9.5 What happens next');
  d.ol([
    'You run the Phase 0 checklist (Part 4) or tell Claude to run it against Atlas with your password.',
    'No sample data is loaded into Atlas (your decision): the first real data is created through the apps while you test.',
    'You say "Phase 0 is good". Then the two branches are merged and Phase 1 continues with step 5.',
    'You reset the Atlas password and supply the keys listed in Part 7 when each phase needs them.',
  ]);
}
