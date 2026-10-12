import fs from 'fs';
import { Doc } from './lib.mjs';
import { PHASES, FEATURES, STATUS } from './features.mjs';
import * as N from './narrative.mjs';
import { COLL } from './collections.mjs';
import { ADMIN_BASE, CLIENT_BASE, GENERIC, ADMIN, CLIENT, PAGE_UI } from './endpoints.mjs';
import { CUSTOMER, DRIVER, WEBSITE } from './mobile.mjs';

const SP = 'C:/Users/user/AppData/Local/Temp/claude/C--Users-user-Downloads/efdc9bca-7893-4dd5-8808-e375b1102896/scratchpad/';
const OUT = 'D:/New_project/abra-travels/documentation/';
const today = '12 October 2026';
const AA = JSON.parse(fs.readFileSync(SP + 'all_admin.json', 'utf8'));
const CC = JSON.parse(fs.readFileSync(SP + 'all_client.json', 'utf8'));
const BR = JSON.parse(fs.readFileSync(SP + 'backend_routes.json', 'utf8'));
const CO = JSON.parse(fs.readFileSync(SP + 'collections.json', 'utf8'));

// ---------- helpers
const norm = p => String(p).replace(/:[A-Za-z]+/g, ':p').replace(/\?.*$/, '').replace(/\/$/, '');
const EXIST = new Set(BR.map(r => r.method + ' ' + norm(r.path)));
const PERM_L = { NONE: 'None', VIEW: 'View', EDIT: 'Edit', FULL: 'Edit+Delete' };
const sentence = s => s;
const rolesOf = (app, page) => Object.keys((app.perm || {})).map(r => ({ r, l: ((app.perm[r] || {})[page]) || 'NONE' }));

function resolve(app, page, handler, label) {
  const MAP = app === 'admin' ? ADMIN : CLIENT, BASE = app === 'admin' ? ADMIN_BASE : CLIENT_BASE;
  const base = BASE[page] || '/' + page;
  let s = null;
  const OVR = {
    'client:drules:rt_new': 'UI | opens the report type form', 'client:drules:rt_edit': 'UI | opens the report type form',
    'client:drules:rt_save': 'POST /client/driver-rules/reports or PATCH /client/driver-rules/reports/:id | this operator\'s report types', 'client:drules:rt_del': 'DELETE /client/driver-rules/reports/:id',
    'client:drules:rt_tog': 'PATCH /client/driver-rules/reports/:id/active', 'admin:inventory:rec_save': 'PATCH /admin/trips/:id/inventory | held and blocked seats (generic row edit)',
    'admin:inventory:rec_del': 'UI | not allowed: inventory is derived from bookings; the server refuses', 'admin:payments:rec_save': 'UI | not allowed to edit money fields; the server refuses with an explanation',
    'admin:bookings:rec_save': 'PATCH /admin/bookings/:id | only notes and contact fields are editable; amounts and seats are refused', 'admin:refunds:rec_save': 'UI | not allowed to edit amounts; use approve, reject or mark paid',
    'admin:settlements:rec_save': 'UI | not allowed to edit totals; use adjustments', 'admin:kyc:rec_save': 'UI | not allowed to edit KYC status; use review, approve or reject',
  };
  s = OVR[app + ':' + page + ':' + handler] || MAP[handler] || GENERIC[handler] || null;
  if (!s) return { ep: '(not mapped yet)', st: '?', note: handler };
  s = s.replace(/\{B\}/g, base);
  const [a, ...rest] = s.split(' | ');
  const note = rest.join(' | ');
  if (a === 'UI') return { ep: 'No server call', st: 'UI', note };
  let st = 'New';
  const opts = a.split(' or ').map(x => x.trim());
  const first = opts.map(o => { const m = o.match(/^([A-Z]+)\s+(\S+)/); return m ? m[1] + ' ' + norm(m[2]) : ''; });
  if (/\bexist/i.test(note) || first.some(f => EXIST.has(f))) st = 'Exists';
  return { ep: a, st, note: note.replace(/\bexists?\b[;,.]?\s*/gi, '').trim() };
}

function cleanLabel(handler, label, kind) {
  let l = (label || '').trim();
  const camel = /[a-z][A-Z]/.test(l) && l.length > 18;
  if ((/_open$|_sel$/.test(handler) && !/^c?ai_open$|^n_open$/.test(handler) && (l.length > 14 || camel)) || (handler === 'rec_view' && l.length > 16) || (kind === 'row' && l.length > 26) || camel) l = 'Row (open the record)';
  if (l.length > 26 && /\d/.test(l)) l = l.replace(/\d.*$/, '').trim() || 'Row';
  if (!l) l = '(icon)';
  return l;
}

function pageRows(app, page) {
  const rows = [], seen = new Set();
  const take = (where, node) => {
    for (const a of node.actions || []) {
      if (a.kind === 'gone') continue;
      if (/^(tab|nav|go|t_pg|menu|theme|lang|lang_sel|bell|acct|signout|role|sim|sim_ok)$/.test(a.a) || /^c?ai_(open|new|x|mic|q|send|go|fb|ok|no)$/.test(a.a)) continue;
      const lab = cleanLabel(a.a, a.label, a.row ? 'row' : '');
      if (where.startsWith('Detail') && /_open$|_sel$|^rec_view$/.test(a.a) && lab === 'Row (open the record)') continue;
      const key = where + '|' + a.a + '|' + lab;
      if (seen.has(key)) continue; seen.add(key);
      const r = resolve(app, page.id, a.a, lab);
      let opens = '';
      if (a.kind === 'dialog') opens = a.title + (a.fields && a.fields.length ? ': ' + a.fields.map(f => f.label.replace(/\s*\*$/, '*') + (f.type === 'select' && f.opts ? ' [' + f.opts.slice(0, 6).join(' / ') + (f.opts.length > 6 ? ' ...' : '') + ']' : '')).join('; ') : (a.body ? ' (' + a.body.slice(0, 80) + ')' : ''));
      else if (a.kind === 'navigates') opens = 'Opens page ' + a.to.replace(/[A-Z]{2,4}-?\d+[A-Z0-9-]*/g, ':id').replace(/\/(OP|CU)\d+/g, '/:id');
      rows.push([where, lab, opens, r.ep, r.st, r.note, a.a]);
      // footer buttons of a dialog are real actions too
      for (const f of a.foot || []) {
        if (f.a === 'mdl_x') continue;
        const fk = where + '|' + f.a + '|' + f.label; if (seen.has(fk)) continue; seen.add(fk);
        const fr = resolve(app, page.id, f.a, f.label);
        rows.push([where + ' > dialog', f.label || '(button)', '', fr.ep, fr.st, fr.note, f.a]);
      }
    }
  };
  take('Page', page);
  for (const t of page.tabPages || []) take('Tab: ' + t.tab.replace(/\s+\d+$/, ''), t);
  for (const d of page.details || []) {
    take('Detail page ' + d.route, d);
    for (const t of d.tabPages || []) take('Detail page ' + d.route + ' / tab ' + t.tab.replace(/\s+\d+$/, ''), t);
  }
  return rows;
}

function screenFacts(node) {
  const k = [...new Set((node.kpis || []).map(x => x.replace(/^[\d.,₹%LKCr\s]+/, '').replace(/[+-]\d.*$/, '').trim()))].filter(Boolean);
  return { kpis: k, tabs: (node.tabs || []).map(t => t.replace(/\s+\d+$/, '')), tables: node.tables || [], filters: (node.filters || []).filter(f => !/^Language\b/.test(f)) };
}

// ---------- document
const d = new Doc();
N.cover(d, today);
N.part0(d, {});
N.part1(d);
N.part2(d);
N.part3(d);

// ---- Part 4: phases
function endpointsOfFeature(f) {
  const set = new Map();
  const add = (app, ids) => { const A = app === 'admin' ? AA : CC; for (const id of ids) { const pg = A.pages.find(p => p.id === id); if (!pg) continue; for (const r of pageRows(app, pg)) if (r[4] !== 'UI' && r[4] !== '?') set.set(r[3], r[4]); } };
  add('admin', f.admin); add('client', f.client);
  for (const [list, src] of [[f.customer, CUSTOMER], [f.driver, DRIVER], [f.web, WEBSITE]]) for (const id of list) { const sc = src.find(s => s.id === id); if (!sc) continue; for (const r of sc.rows) if (!/^none|^UI/i.test(r[2])) set.set(r[2], /exist/i.test(r[2] + r[3]) ? 'Exists' : 'New'); }
  const all = [...set.values()];
  return { total: all.length, exists: all.filter(x => x === 'Exists').length };
}

d.h(2, 'Part 4. The phases');
d.p('Each phase builds backend and screens together for the features inside it, so every phase can be tested end to end. The customer app is finished inside Phases 3 to 5; the admin portal and the client portal are built page by page in the phase of their feature and completed in Phases 7 and 8; the driver app starts in Phase 5 and is completed in Phase 9; the public website is Phase 10.');
d.table(['Phase', 'Name', 'Apps', 'Features'], PHASES.map(p => [String(p.n), p.name, p.apps, String(FEATURES.filter(f => f.phase === p.n).length)]));
d.note('Why this order and not "all backend first": a mistake in an early endpoint stays hidden until a screen uses it. Building each feature with its screen finds mistakes the same day. The order still follows your plan: foundation and backend first, customer app, then admin, client, driver, website.', 'note');
d.h(3, '4.1 Customer app: what to check before building (found by comparing the Flutter code with the demo)');
d.table(['Item in the demo', 'In the Flutter app today', 'Phase'], [
  ['Search, trip details, seats, boarding, passengers, review, payment, ticket, My Trips, cancel, refund, tracking, trip sharing, women safety, notifications and offers', 'Screens exist; their data comes from `Mock...Repository` classes with `Api...` stubs waiting', '3, 4, 5'],
  ['Home banners, city lookup, trip search', 'Real (call the backend today)', 'done'],
  ['Messages page (copies of WhatsApp and email)', 'Not found in `features/`; check', '3'],
  ['Google and Apple sign-in buttons; email required together with mobile', 'Check the login and passenger screens (login files must not be edited without asking)', '3'],
  ['Per-seat-type prices on the seat map and in the fare breakup', 'Check', '3'],
  ['Running-trip banner on Home with Track and SOS', 'Check', '5'],
  ['SOS button on the tracking screen', 'Check', '5'],
  ['Support tickets with proof files and a reply thread', '`support_screen.dart` looks static; check', '4'],
  ['Notification settings, delete account, 8 languages, AI assistant', 'Check each', '4, 11'],
], {});
for (const p of PHASES) {
  d.h(3, `Phase ${p.n}. ${p.name}`);
  d.table(['', ''], [['Goal', p.goal], ['Apps touched', p.apps], ['Done when', p.done]]);
  const fs_ = FEATURES.filter(f => f.phase === p.n);
  d.table(['Feature', 'Screens in the demo', 'Backend today', 'Collections', 'Endpoints (new / existing)', 'What to build'],
    fs_.map(f => {
      const e = endpointsOfFeature(f);
      const surf = [f.admin.length ? 'Admin: ' + f.admin.join(', ') : '', f.client.length ? 'Client: ' + f.client.join(', ') : '', f.customer.length ? 'Customer: ' + f.customer.join(', ') : '', f.driver.length ? 'Driver: ' + f.driver.join(', ') : '', f.web.length ? 'Website: ' + f.web.join(', ') : ''].filter(Boolean).join('\n') || 'backend only';
      return [`**${f.name}** (\`${f.id}\`)`, surf, STATUS[f.st] + ' (' + f.mod + ')', f.coll.join(', ') || '-', `${e.total - e.exists} new / ${e.exists} existing`, f.note];
    }));
  // test checklist
  const items = [];
  for (const f of fs_) {
    for (const id of f.admin) { const pg = AA.pages.find(x => x.id === id); if (pg) items.push(checkLine('Admin', pg, 'admin')); }
    for (const id of f.client) { const pg = CC.pages.find(x => x.id === id); if (pg) items.push(checkLine('Client portal', pg, 'client')); }
    for (const id of f.customer) { const sc = CUSTOMER.find(x => x.id === id); if (sc) items.push(`Customer app, **${sc.title}**: ${sc.rows.slice(0, 5).map(r => r[0]).join('; ')}. Everything shown comes from the real backend; nothing is mock, and it looks the same as the demo.`); }
    for (const id of f.driver) { const sc = DRIVER.find(x => x.id === id); if (sc) items.push(`Driver app, **${sc.title}**: ${sc.rows.slice(0, 5).map(r => r[0]).join('; ')}.`); }
    for (const id of f.web) { const sc = WEBSITE.find(x => x.id === id); if (sc) items.push(`Website, **${sc.title}**: ${sc.rows.slice(0, 4).map(r => r[0]).join('; ')}.`); }
  }
  d.h(4, `Phase ${p.n}: your test checklist`);
  d.ul(items.length ? items : ['Backend only: Claude shows you the results of the automatic tests; there is nothing to press.']);
}
function checkLine(label, pg, app) {
  const facts = screenFacts(pg);
  const rows = pageRows(app, pg).filter(r => r[4] !== 'UI' && r[4] !== '?').map(r => r[1]).filter((x, i, a) => x && a.indexOf(x) === i && !/^Row|icon/.test(x)).slice(0, 7);
  return `${label}, **${pg.title}**: the list loads${facts.filters.length ? '; try the filters (' + facts.filters.slice(0, 4).map(x => x.replace(/\s*\[.*$/, '')).join(', ') + ')' : ''}${facts.kpis.length ? '; each number card opens its records' : ''}; press ${rows.length ? rows.join(', ') : 'each button'}; export downloads; as a view-only role the buttons are hidden and the server refuses; the screen looks the same as the demo page.`;
}

N.part5(d);
N.part6(d);
N.part7(d);
N.part8(d);

// ---------- Appendices
d.pagebreak();
d.h(2, 'Appendix A. Collections (the database)');
d.p('The demo store has 62 keys. This table maps each to a real MongoDB collection. Collection names are plural snake case. Every collection also gets `_id`, `createdAt`, `updatedAt`, `createdBy`, and `deletedAt` where soft delete applies. Operator-owned collections carry `operatorId` and every query for an operator user is filtered by it on the server. Money fields are integers in paise. "Demo fields" are the fields of the first record in the demo store, with their types.');
d.table(['Demo key', 'Collection', 'Backend today', 'Phase', 'Owner module', 'Purpose', 'Relations', 'Indexes'],
  COLL.map(c => [c.key, '`' + c.real + '`', c.exists ? 'exists' : 'new', String(c.phase), c.mod, c.purpose, c.rel || '-', c.idx || '-']));
d.h(3, 'A.2 Demo fields per collection');
d.table(['Demo key', 'Fields (name:type)'], CO.filter(c => !/^_|busList|replies|reviews|series$/.test(c.key)).map(c => [c.key + ' (' + c.count + ' in the demo)', c.fields.join(', ')]));

d.h(2, 'Appendix B. Events, notifications and messages');
d.p('These are the rules the demo\'s event router applies. In the real build the backend event service does exactly this, once per event, and never from the app. "Go to" is the page or screen the notification opens.');
d.table(['Event', 'Who is told', 'Title', 'Message', 'Go to'], [
  ['Operator sends KYC documents (company or bus)', 'Admin', 'New KYC submission', '<operator> sent company documents / documents for bus <reg>', 'KYC detail'],
  ['Admin approves KYC', 'Operator', 'Company approved / Bus approved', 'Verified; buses, trips and staff are open / you can schedule trips on the bus', 'Dashboard / Buses'],
  ['Admin rejects KYC', 'Operator', 'Documents need fixing', 'Each rejected document with its reason', 'KYC'],
  ['Operator resends corrected documents', 'Admin', 'KYC corrections sent', '<operator> replaced the rejected documents', 'KYC detail'],
  ['Operator requests a place', 'Admin', 'Place request', '<operator> wants to add <place>, <city>', 'Places'],
  ['Admin approves or rejects a place request', 'Operator', 'Place request approved / rejected', 'Can be used in routes / reason', 'Routes'],
  ['Settlement status changes', 'Operator', 'Settlement <status>', '<id> for <cycle>', 'Earnings'],
  ['Operator raises a settlement query', 'Admin', 'Settlement query', '<operator>: <query>', 'Settlement detail'],
  ['Admin answers the query', 'Operator', 'Query answered', 'Abra replied to your query on <id>', 'Earnings'],
  ['Operator accepts the invitation', 'Admin', 'New operator signed up', '<company> accepted the invitation', 'Operator detail'],
  ['Operator suspended or status changes', 'Operator', 'Account suspended / status changed', 'Trips hidden from customers; contact Abra support', 'Dashboard'],
  ['Bus marked for maintenance', 'Operator', 'Bus marked for maintenance', '<reg> cannot be used for trips until it returns to service', 'Buses'],
  ['Driver assigned or changed on a trip', 'Driver, Operator', 'New trip assigned / Driver changed', '<trip> and time / <driver> now drives <trip>', 'Trip'],
  ['Trip cancelled', 'Customers (booked and cancelled), Driver, Operator', 'Trip cancelled', 'Route and date; full refund has started', 'My trips / Home / Trips'],
  ['Trip delayed', 'Customers, Admin, Operator', 'Bus running late / Trip delayed', 'Route, minutes, reason', 'My trips / Tracking / Trip'],
  ['Trip boarding', 'Customers', 'Boarding started', 'Your bus <reg> is boarding now', 'My trips'],
  ['Trip starts', 'Customers', 'Your trip has started', 'Track your bus live', 'My trips'],
  ['Trip arrives', 'Customers', 'You have arrived', 'Thanks for travelling; rate your trip', 'My trips'],
  ['Booking created', 'Operator', 'New booking', '<PNR> - seats on <route>', 'Bookings'],
  ['Booking cancelled', 'Operator, Customer', 'Booking cancelled', '<PNR> on <route>; your refund has started', 'Bookings / My trips'],
  ['Refund status changes', 'Customer', 'Refund <status>', 'Refund of Rs <amount> is <status>', 'My trips'],
  ['SOS raised by a customer', 'Admin, Operator, Driver', 'SOS from <name> / SOS on your bus', 'Note and route; "stop safely and check, Abra safety team is calling"', 'SOS board / Live / Trip'],
  ['SOS raised by a driver', 'Admin, Operator', 'SOS from Driver <name>', 'Note and route', 'SOS board / Live'],
  ['SOS status changes (acknowledged, resolved, false alarm)', 'Customer or Driver who raised it', 'SOS <status>', 'Our safety team has your alert and is calling you / your SOS is now <status>', 'SOS'],
  ['New support ticket', 'Admin', 'New support ticket', '<id> - <subject>', 'Ticket detail'],
  ['Agent replies / customer replies', 'Customer / Admin', 'Support replied / Customer replied', '<subject>', 'Support / Ticket detail'],
  ['Operator asks for an offer', 'Admin', 'Offer request', '<code> from an operator needs approval', 'Offers'],
  ['Driver sends a report', 'Operator', 'Driver report received', '<driver> sent the <type> for <period> (late if late)', 'Driver reports'],
  ['Driver sends a returned report again', 'Operator', 'Driver report sent again', '<driver> fixed the <type>', 'Driver reports'],
  ['Operator approves or returns a report', 'Driver', 'Report approved / Report sent back', 'Type and period / the review note', 'Reports'],
  ['Trip started past a failed check', 'Operator, Admin', 'Trip started with a failed check', '<driver> started <trip> after overriding: <checks>', 'Driver reports'],
  ['Trip started with warnings', 'Operator', 'Trip checklist has warnings', '<driver> started <trip> with: <warnings>', 'Driver reports'],
  ['Missing report reminder (button)', 'Operator or Driver', 'Driver report missing / Please send your report', 'Which report and period', 'Driver reports / Reports'],
], {});
d.h(3, 'B.2 WhatsApp and email messages to the customer');
d.table(['Event', 'Channels', 'Subject', 'Body (in the customer\'s language)'], [
  ['Booking confirmed', 'WhatsApp and email, to the booking\'s contact (not only the account)', 'Booking confirmed: <PNR>', 'Route, date and time, seats, boarding point, amount, how to track, link to the ticket'],
  ['Booking cancelled', 'WhatsApp and email', 'Booking cancelled: <PNR>', 'Cancelled; the refund starts and arrives in 5 to 7 working days'],
  ['Refund paid', 'WhatsApp and email', 'Refund processed: <PNR>', 'Amount and reference number'],
  ['Payment failed', 'WhatsApp and email', 'Payment failed', 'Amount and reason; seats are held for a short time; try again'],
  ['Bus delayed', 'WhatsApp and email', 'Bus delayed: <PNR>', 'Minutes and reason; track live in the app'],
  ['Boarding started', 'WhatsApp and email', 'Boarding now: <PNR>', 'Bus number, reach your boarding point'],
], {});
d.note('The demo stores English text only. The real build uses templates per language (Appendix K lists the 8 languages) and logs every message in the `messages` collection.', 'note');

// Appendix C: access matrix
d.h(2, 'Appendix C. Access matrix (starting values)');
d.p('Levels: None, View, Edit, Edit+Delete. These are the demo\'s starting values. The Super Admin can change them in Staff and roles. Operators have their own matrix for their staff.');
function matrix(title, A, labelOf) {
  const pages = A.pages.map(p => p.id);
  const roles = Object.keys(A.perm);
  d.h(3, title);
  d.table(['Page', ...roles.map(r => (A.roles && A.roles[r]) || r)], pages.map(pid => [labelOf(pid), ...roles.map(r => PERM_L[(A.perm[r] || {})[pid]] || 'None')]));
}
matrix('C.1 Admin portal', AA, id => (AA.pages.find(p => p.id === id) || {}).title + ' (`' + id + '`)');
matrix('C.2 Client (operator) portal', CC, id => (CC.pages.find(p => p.id === id) || {}).title + ' (`' + id + '`)');

// Appendices D and E: page by page
function pageAppendix(letter, title, app, A, BASE) {
  d.pagebreak();
  d.h(2, `Appendix ${letter}. ${title}: every page, button and endpoint`);
  d.p('How to read each page: first its facts (feature, base path, files), then what is on the screen, then one row per button. "Where" says whether the button is on the page, on a tab, in a dialog or on a detail page. "Opens" lists the dialog and its fields (a star marks a required field). "Status" is **Exists** when the backend already has the route, **New** when it must be built, **UI** when no server call is needed. Row actions (View, Edit, Delete) exist on every table as in the demo; where changing a field would be unsafe (money, KYC status) the server refuses and says why.');
  d.note('Build the real screen to look and behave exactly like the demo page of the same name. This appendix lists what the demo page contains; the demo file itself (`prototypes/' + (app === 'admin' ? 'admin' : 'client') + '_demo_model.html`) is the visual reference.', 'rule');
  let n = 0;
  const groups = {};
  A.pages.forEach(p => (groups[p.group || 'Other'] = groups[p.group || 'Other'] || []).push(p));
  for (const [g, pages] of Object.entries(groups)) {
    for (const pg of pages) {
      n++;
      const f = FEATURES.find(x => (app === 'admin' ? x.admin : x.client).includes(pg.id));
      d.h(3, `${letter}.${n} ${pg.title} (\`${pg.id}\`)`);
      const fa = screenFacts(pg);
      const aud = app === 'admin' ? 'admin_manage' : 'client_manage';
      const feat = f ? f.id : pg.id;
      const ro = rolesOf(A, pg.id).map(x => `${(A.roles && A.roles[x.r]) || x.r}: ${PERM_L[x.l]}`).join('; ');
      d.table(['Item', 'Value'], [
        ['Menu group', g || '-'], ['Feature / phase', f ? `${f.name} / Phase ${f.phase}` : '(see feature list)'], ['API base', '`' + (BASE[pg.id] || '/' + pg.id) + '`'],
        ['Files', `\`${feat}_${aud}_screen.dart\`, \`${feat}_${aud}.ts\`, \`${feat}_${aud}.service.ts\``], ['Starting access', ro],
      ]);
      const screen = [];
      if (fa.kpis.length) screen.push(['Number cards (each opens the records behind it)', fa.kpis.join(' | ')]);
      if (fa.tabs.length) screen.push(['Tabs', fa.tabs.join(' | ')]);
      if (fa.filters.length) screen.push(['Filters', fa.filters.join(' | ')]);
      fa.tables.forEach((t, i) => t.length && screen.push(['Table columns' + (fa.tables.length > 1 ? ' ' + (i + 1) : ''), t.join(' | ')]));
      for (const t of pg.tabPages || []) {
        const ft = screenFacts(t);
        if (ft.tables.length || ft.kpis.length || ft.filters.length) screen.push(['Tab "' + t.tab.replace(/\s+\d+$/, '') + '"', [ft.kpis.length ? 'cards: ' + ft.kpis.join(', ') : '', ft.filters.length ? 'filters: ' + ft.filters.join(', ') : '', ...ft.tables.map(x => 'columns: ' + x.join(', '))].filter(Boolean).join('. ')]);
      }
      for (const dt of pg.details || []) {
        const fd = screenFacts(dt);
        screen.push(['Detail page ' + dt.route, [fd.tabs.length ? 'tabs: ' + fd.tabs.join(', ') : '', fd.kpis.length ? 'cards: ' + fd.kpis.join(', ') : '', ...fd.tables.map(x => 'columns: ' + x.join(', '))].filter(Boolean).join('. ') || 'detail view']);
      }
      if (PAGE_UI[app + ':' + pg.id]) screen.unshift(['Sections of the page', PAGE_UI[app + ':' + pg.id]]);
      if (screen.length) d.table(['On the screen', 'Contents'], screen);
      const rows = pageRows(app, pg);
      d.table(['Where', 'Button', 'Opens', 'Endpoint', 'Status', 'Notes'], rows.map(r => [r[0], r[1], r[2], r[3], r[4], r[5]]));
    }
  }
}
function stateRows(app, A) {
  const txt = fs.readFileSync(SP + 'handlers_' + app + '.txt', 'utf8').split(/\r?\n/).filter(l => /NOT ON ANY CAPTURED PAGE/.test(l)).map(l => l.split(' ')[0]);
  const hint = h => {
    const m = [[/^rf_/, 'refunds'], [/^st_|^cs_/, app === 'admin' ? 'settlements' : 'earnings'], [/^role|^perm_/, 'staff'], [/^tk_/, 'tickets'], [/^op_/, 'operators'], [/^cu_/, 'customers'], [/^trk_/, 'tracking'], [/^bus_/, 'buses'], [/^rq_|^rt_|^dr_|^d_reset|^dop/, app === 'admin' ? 'drules / dreports' : 'drules / dreports'], [/^ban_/, 'banners'], [/^imp_/, 'import dialog on places, buses, fares, schedules'], [/^ai_|^cai_/, 'AI assistant'], [/^gs_|^gsearch/, 'global search'], [/^kpi/, 'number cards'], [/^mfa/, 'account menu'], [/^au_|^kd_|^bd|^kq|^kstep|^up_/, 'sign-in and KYC wizard'], [/^sc_|^sch_/, 'schedules'], [/^tr_/, 'trips'], [/^lay_/, 'layouts'], [/^cb_/, 'bookings'], [/^pf_|^file_/, 'proof files'], [/^rec_/, 'every table'], [/^rep_/, 'reports']];
    for (const [re, p] of m) if (re.test(h)) return p; return 'shell (header, menu, theme, demo controls)';
  };
  const out = [];
  for (const h of txt) {
    if (/^(acct|bell|menu|nav|theme|lang|lang_sel|signout|sim|sim_ok|demo_toggle|ev|offline_off|open_app|orient|relogin|mdl_bg|tab|t_pg|t_clr|t_clr_sel|chart_pt|undo|run|snd|replay|x_exp|x_go)$/.test(h)) continue;
    const r = resolve(app, 'shell', h, '');
    out.push([h, hint(h), r.ep, r.st, r.note]);
  }
  return out;
}
function stateAppendix(letter, app, A) {
  const rows = stateRows(app, A);
  d.h(3, `${letter}.x Buttons that only appear in some states`);
  d.p('These buttons are in the demo code but were not on screen in the default state (for example Approve only shows on a waiting refund). They are part of the build.');
  d.table(['Action', 'Where', 'Endpoint', 'Status', 'Notes'], rows);
}
pageAppendix('D', 'Admin portal', 'admin', AA, ADMIN_BASE);
stateAppendix('D', 'admin', AA);
pageAppendix('E', 'Client (operator) portal', 'client', CC, CLIENT_BASE);
stateAppendix('E', 'client', CC);

function mobileAppendix(letter, title, list, aud, note) {
  d.pagebreak();
  d.h(2, `Appendix ${letter}. ${title}: every screen and endpoint`);
  d.p(note);
  d.note('Build the real screens to look and behave exactly like the demo (`prototypes/' + (aud === 'public' ? 'website' : aud) + '_demo_model.html`): same layout, wording, order, colours, dialogs and states.', 'rule');
  let n = 0;
  for (const s of list) {
    n++;
    const f = FEATURES.find(x => x.id === s.feature);
    d.h(3, `${letter}.${n} ${s.title}`);
    d.table(['Item', 'Value'], [['Feature / phase', f ? `${f.name} / Phase ${f.phase}` : s.feature], ['Files', `\`${s.feature}_${aud}_${aud === 'public' ? 'page.tsx' : 'screen.dart'}\`, \`${s.feature}_${aud}.ts\`, \`${s.feature}_${aud}.service.ts\``], ['On the screen', s.ui]]);
    d.table(['Button / element', 'What it does', 'Endpoint', 'Status', 'Data'], s.rows.map(r => [r[0], r[1], r[2], /^none|^UI/i.test(r[2]) ? 'UI' : (/exist/i.test(r[2] + r[3]) ? 'Exists' : 'New'), r[3]]));
  }
}
mobileAppendix('F', 'Customer app', CUSTOMER, 'customer', 'The customer app is mostly built; this lists every screen so the remaining ones and the real connections are finished against the demo. Endpoints under `/customer` need a signed-in customer; the others are public.');
mobileAppendix('G', 'Driver app (new app, Android)', DRIVER, 'driver', 'The driver app does not exist yet. Phase 5 builds sign-in, trips, check-in, start and end, delay, GPS and SOS; Phase 9 adds reports and checklists.');
mobileAppendix('H', 'Public website (Next.js)', WEBSITE, 'public', 'Server-rendered pages for search engines; booking hands over to the customer app.');

// Appendix I: backend today
d.pagebreak();
d.h(2, 'Appendix I. The backend today');
d.p('Read from the controllers in `backend/src`: 26 controllers, 113 routes. Everything above marked "Exists" is in this list. Everything marked "New" is not.');
const byMod = {};
BR.forEach(r => (byMod[r.module] = byMod[r.module] || []).push(r.method + ' ' + r.path));
d.table(['Module', 'Routes'], Object.entries(byMod).map(([m, l]) => [m, l.join('\n')]));
d.h(3, 'I.2 Modules with no controller yet');
const have = new Set(Object.keys(byMod));
const placeholders = ['analytics', 'api-clients', 'bookings', 'boarding-points', 'chatbot', 'check-in', 'commissions', 'content', 'coupons', 'customers', 'drivers', 'fares', 'feature-flags', 'inventory', 'live-tracking', 'maintenance', 'notification-templates', 'offers', 'operator-staff', 'partner-webhooks', 'partners', 'passengers', 'payments', 'popular-routes', 'reconciliation', 'refunds', 'reports', 'schedules', 'seat-layouts', 'settlements', 'support', 'tickets', 'translations', 'trip-operations', 'users', 'whatsapp', 'women-safety'];
d.p(placeholders.filter(m => !have.has(m)).map(m => '`' + m + '`').join(', ') + '. These folders exist as empty placeholders; they get their three-file packages in the phases above.');
// coverage stats
function stat(app, A) {
  let ex = 0, nw = 0, ui = 0, un = 0; const seen = new Set();
  for (const pg of A.pages) for (const r of pageRows(app, pg)) { const k = pg.id + '|' + r[6]; if (seen.has(k)) continue; seen.add(k); if (r[4] === 'Exists') ex++; else if (r[4] === 'New') nw++; else if (r[4] === 'UI') ui++; else un++; }
  return [ex, nw, ui, un];
}
const sa = stat('admin', AA), sc = stat('client', CC);
d.h(3, 'I.3 Coverage of the demo buttons');
d.table(['App', 'Buttons mapped to an existing endpoint', 'Buttons that need a new endpoint', 'UI-only buttons', 'Not mapped'], [
  ['Admin portal', String(sa[0]), String(sa[1]), String(sa[2]), String(sa[3])], ['Client portal', String(sc[0]), String(sc[1]), String(sc[2]), String(sc[3])],
]);
const cnt = l => l.reduce((a, s) => a + s.rows.length, 0);
d.p(`Customer app: ${CUSTOMER.length} screens, ${cnt(CUSTOMER)} mapped elements. Driver app: ${DRIVER.length} screens, ${cnt(DRIVER)}. Website: ${WEBSITE.length} pages, ${cnt(WEBSITE)}.`);

// Appendix J: file index
d.pagebreak();
d.h(2, 'Appendix J. Feature file index (the three files of every feature)');
d.p('One row per feature and audience. Paths are relative to the repository root. Flutter files live in the app\'s `lib/features/<feature>/` folder; backend files in `backend/src/modules/<first module>/`. A "(backend only)" feature has no screen. Update the Status column as work finishes.');
const rowsJ = [];
const appDir = { admin: 'apps/admin_app', client: 'apps/client_portal', customer: 'apps/customer_app', driver: 'apps/driver_app', public: 'apps/public_website' };
for (const f of FEATURES) {
  const mod = f.mod.split(',')[0].trim().split(' ')[0];
  const auds = [];
  if (f.admin.length) auds.push('admin_manage'); if (f.client.length) auds.push('client_manage'); if (f.customer.length) auds.push('customer'); if (f.driver.length) auds.push('driver'); if (f.web.length) auds.push('public');
  if (!auds.length) auds.push('core');
  for (const a of auds) {
    const key = a.startsWith('admin') ? 'admin' : a.startsWith('client') ? 'client' : a;
    const screen = a === 'core' ? '(backend only)' : `${appDir[key]}/lib/features/${f.id}/${f.id}_${a}_${a === 'public' ? 'page.tsx' : 'screen.dart'}`.replace('apps/public_website/lib/features', 'apps/public_website/app');
    rowsJ.push([`Phase ${f.phase}`, f.name, screen, `backend/src/modules/${mod}/${f.id}_${a}.ts`, `backend/src/modules/${mod}/${f.id}_${a}.service.ts`, 'Not started']);
  }
}
d.table(['Phase', 'Feature', 'Screen file (all widgets inside)', 'Backend file (schema, DTOs, controller, module)', 'Service file', 'Status'], rowsJ);

// Appendix K: glossary and languages
d.h(2, 'Appendix K. Glossary and languages');
d.table(['Term', 'Meaning'], [
  ['Operator / client / bus owner', 'The bus company. The client portal is the operator app.'], ['KYC', 'Know your customer: company and bus documents checked by Abra.'], ['PNR', 'The booking reference printed on the ticket.'],
  ['Hold', 'Seats reserved for 10 minutes while a customer pays.'], ['Manifest', 'The passenger list of a trip.'], ['Settlement', 'What Abra pays an operator for a cycle: gross sales minus commission minus refunds plus adjustments.'],
  ['Razorpay Route', 'Razorpay\'s automatic split of one payment between Abra and the operator.'], ['Proof', 'A picture, PDF or text file attached to a sensitive action.'], ['Locked item', 'A driver checklist item Abra requires; an operator cannot remove or switch it off.'],
  ['Snapshot', 'The system numbers of a driver report, frozen when the driver sends it.'], ['Access matrix', 'None, View, Edit, Edit+Delete per role per page.'], ['Seed', 'The script that loads the sample data into MongoDB.'],
]);
d.table(['Language', 'Code', 'Shown in the picker as'], [['English', 'en', 'English'], ['Telugu', 'te', 'Telugu (తెలుగు)'], ['Hindi', 'hi', 'Hindi (हिन्दी)'], ['Kannada', 'kn', 'Kannada (ಕನ್ನಡ)'], ['Tamil', 'ta', 'Tamil (தமிழ்)'], ['Malayalam', 'ml', 'Malayalam (മലയാളം)'], ['Marathi', 'mr', 'Marathi (मराठी)'], ['Bengali', 'bn', 'Bengali (বাংলা)']]);

// ---------- write
fs.mkdirSync(OUT, { recursive: true });
const md = d.md();
fs.writeFileSync(OUT + 'abra-master-plan.md', md);
fs.writeFileSync(SP + 'abra-master-plan.html', d.html('Abra Travels: Master Build Plan'));
const unm = [];
for (const [app, A] of [['admin', AA], ['client', CC]]) for (const pg of A.pages) for (const r of pageRows(app, pg)) if (r[4] === '?') unm.push(app + ':' + pg.id + ':' + r[6]);
console.log('written', (md.length / 1024).toFixed(0) + ' KB markdown; blocks', d.b.length, '; unmapped:', [...new Set(unm)].join(' ') || 'none');
console.log('admin stats [exists,new,ui,unmapped]', sa, 'client', sc);
