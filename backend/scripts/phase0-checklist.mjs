// Phase 0 checklist, run over HTTP against a running backend (documentation/abra-master-plan.md, Part 4).
//
//   CHECKLIST_EMAIL=you@example.com CHECKLIST_PASSWORD='...' node scripts/phase0-checklist.mjs
//   optional: BASE=http://localhost:4000   (the backend; default http://localhost:4000)
//
// It signs in as a Super Admin and walks the checklist step by step, printing PASS or FAIL for each.
// It leaves nothing behind except audit entries: it creates and deletes a test role, switches one
// feature and one maintenance scope off again, and sets and clears one test secret. Step J (the
// sample data) runs only when CHECKLIST_EXPECT_SEED=yes, for a throw-away local database where
// `npm run seed:demo` was run. Do not load the sample data into Atlas: the real data is created
// by using the applications.
const EMAIL = process.env.CHECKLIST_EMAIL;
const PASSWORD = process.env.CHECKLIST_PASSWORD;
if (!EMAIL || !PASSWORD) {
  console.error('Set CHECKLIST_EMAIL and CHECKLIST_PASSWORD.');
  process.exit(2);
}
const ORIGIN = process.env.BASE || 'http://localhost:4000';
const BASE = ORIGIN + '/api/v1';
let token = '';
let refreshToken = '';
const call = async (method, path, body, opts = {}) => {
  const url = path.startsWith('/health') ? ORIGIN + path : BASE + path;
  const r = await fetch(url, {
    method,
    headers: { 'content-type': 'application/json', ...(opts.auth === false ? {} : token ? { authorization: 'Bearer ' + token } : {}), ...(opts.headers || {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const j = await r.json().catch(() => ({}));
  return { status: r.status, data: j.data, meta: j.meta, error: j.error, body: j };
};
const results = [];
const step = (id, text, cond, extra = '') => { results.push([id, cond]); console.log(`${cond ? 'PASS' : 'FAIL'}  ${id}  ${text}${extra ? '  [' + extra + ']' : ''}`); };

// ---- A
let r = await call('GET', '/health/ready', undefined, { auth: false });
step('A', 'health: ready true, MongoDB up, Redis up', r.data?.ready === true && r.data.checks.mongodb.status === 'up' && r.data.checks.redis.status === 'up');

// ---- B
r = await call('POST', '/auth/login', { identifier: EMAIL, password: PASSWORD, device: { clientType: 'MOBILE' } }, { auth: false });
token = r.data?.accessToken || '';
refreshToken = r.data?.refreshToken || '';
step('B1', 'sign in gives an access token', !!token, `status ${r.status}${r.data?.mfaEnrollmentRequired ? ', MFA enrolment required!' : ''}`);
r = await call('GET', '/me');
step('B2', 'GET /me shows the name and account type STAFF (under "user")', r.status === 200 && r.data?.user?.userType === 'STAFF' && !!r.data?.user?.name, JSON.stringify({ name: r.data?.user?.name, type: r.data?.user?.userType }));

// ---- C
r = await call('GET', '/access-matrix?audience=ADMIN');
const sa = r.data?.roles?.find((x) => x.key === 'SUPER_ADMIN');
step('C1', '38 pages, Super Admin row locked and FULL everywhere', r.status === 200 && r.data.pages.length === 38 && sa?.locked === true && Object.values(sa.levels).every((l) => l === 'FULL'), `roles: ${r.data?.roles?.map((x) => x.key).join(',')}`);
r = await call('POST', '/access-matrix/roles', { audience: 'ADMIN', name: 'My test role', copyFromRoleKey: 'SUPPORT' });
const key = r.data?.key;
step('C2', 'new role created from SUPPORT', (r.status === 201 || r.status === 200) && !!key, key);
r = await call('PUT', `/access-matrix/roles/${key}/pages/trips`, { level: 'VIEW', reason: 'testing' });
step('C3', "that role's Trips level becomes View", r.status === 200 && r.data?.levels?.trips === 'VIEW');
r = await call('PUT', '/access-matrix/roles/SUPER_ADMIN/pages/trips', { level: 'NONE' });
step('C4', 'changing the Super Admin row is refused (403)', r.status === 403, `status ${r.status}`);
r = await call('DELETE', `/access-matrix/roles/${key}`, { reason: 'cleanup' });
step('C5', 'the test role is deleted', r.status === 200 && r.data?.deleted === true);

// ---- D
r = await call('GET', '/audit-logs?pageSize=50');
const actions = (r.data || []).map((a) => a.action);
step('D', 'audit log shows created, access changed, deleted with who and why', ['role.created', 'role.access.changed', 'role.deleted'].every((a) => actions.includes(a)) && r.data.every((a) => a.actor && a.at), [...new Set(actions)].join(', '));

// ---- E
r = await call('GET', '/admin/messages');
step('E', 'messages: empty list is correct', r.status === 200 && Array.isArray(r.data) && r.data.length === 0 && r.meta?.total === 0);

// ---- F
r = await call('GET', '/settings/integrations');
step('F1', '7 cards: WhatsApp, Email, Razorpay, Maps, SMS, Push, Assistant', r.status === 200 && r.data.map((x) => x.key).join() === 'whatsapp,email,razorpay,maps,sms,push,assistant', r.data?.map((x) => x.key + ':' + x.status).join(' '));
r = await call('PUT', '/settings/integrations/maps', { values: { provider: 'osm' }, reason: 'testing' });
step('F2', 'Maps with OpenStreetMap becomes READY', r.status === 200 && r.data?.status === 'READY', `status ${r.status} ${r.data?.status}`);
r = await call('POST', '/settings/integrations/maps/test-connection');
step('F3', 'maps test: OpenStreetMap needs no key', r.status === 200 && r.data?.ok === true, r.data?.message);
r = await call('PUT', '/settings/integrations/sms', { secrets: { apiKey: 'test-key-12345678' }, reason: 'testing' });
step('F4', 'a secret never comes back: only "set" and the last four characters', r.status === 200 && r.data?.secrets?.apiKey?.configured === true && r.data.secrets.apiKey.lastFour === '5678' && !JSON.stringify(r.body).includes('test-key-12345678'), JSON.stringify(r.data?.secrets?.apiKey));
r = await call('PUT', '/settings/integrations/sms', { secrets: { apiKey: null }, reason: 'cleanup' });
step('F5', 'the secret is cleared', r.status === 200 && r.data?.secrets?.apiKey?.configured === false);
await call('PUT', '/settings/integrations/maps', { values: { provider: null }, reason: 'cleanup' });

// ---- G
r = await call('POST', '/assistant/chat', { messages: [{ role: 'user', content: 'who am i?' }], language: 'en' });
step('G', 'assistant answers with the role (development assistant)', r.status === 200 && /STAFF/.test(r.data?.reply || ''), r.data?.reply);

// ---- H
r = await call('GET', '/features', undefined, { auth: false });
const on = Object.values(r.data || {}).filter(Boolean).length;
step('H1', 'public /features: 9 switches, 4 on, 5 off', r.status === 200 && Object.keys(r.data).length === 9 && on === 4, `${Object.keys(r.data || {}).length} switches, ${on} on`);
r = await call('PUT', '/admin/feature-flags/live_tracking', { on: false, reason: 'testing' });
const off = await call('GET', '/features', undefined, { auth: false });
step('H2', 'live_tracking off shows false in the public map', r.status === 200 && off.data?.live_tracking === false);
await call('PUT', '/admin/feature-flags/live_tracking', { on: true, reason: 'restore' });
const back = await call('GET', '/features', undefined, { auth: false });
step('H3', 'live_tracking back on', back.data?.live_tracking === true);

// ---- I
r = await call('GET', '/maintenance/status?app=customer', undefined, { auth: false });
step('I1', 'maintenance status starts inactive', r.data?.active === false);
r = await call('PUT', '/admin/maintenance', { scopes: { customer: true }, message: 'Back at 6 pm.', reason: 'testing' });
step('I2', 'maintenance saved', r.status === 200 && r.data?.scopes?.customer === true);
r = await call('GET', '/maintenance/status?app=customer', undefined, { auth: false });
step('I3', 'status now active with the message', r.data?.active === true && r.data?.message === 'Back at 6 pm.', JSON.stringify(r.data));
const blocked = await call('GET', '/banners', undefined, { auth: false, headers: { 'X-Abra-App': 'customer' } });
step('I3b', 'a customer-app request is stopped with 503 and the message', blocked.status === 503 && blocked.error?.message === 'Back at 6 pm.', `status ${blocked.status}`);
r = await call('GET', '/admin/maintenance');
step('I4', 'the admin portal still works during maintenance', r.status === 200);
r = await call('PUT', '/admin/maintenance', { scopes: { customer: false }, reason: 'done' });
const after = await call('GET', '/banners', undefined, { auth: false, headers: { 'X-Abra-App': 'customer' } });
step('I5', 'switched off again: customer-app requests work', r.status === 200 && after.status === 200, `status ${after.status}`);

// ---- J (seed ran on the same temporary database before this script)
if (process.env.CHECKLIST_EXPECT_SEED === 'yes') {
  r = await call('GET', '/catalogue/cities?pageSize=100');
  step('J', 'sample data: 20 cities after the seed', r.status === 200 && r.data?.length === 20 && r.meta?.total === 20, `total ${r.meta?.total}`);
} else {
  console.log('SKIP  J  sample data is not loaded on purpose (data is created through the apps)');
}

// ---- K
r = await call('POST', '/auth/logout', { refreshToken });
const refused = await call('GET', '/me');
step('K', 'sign out works and the token stops working', (r.status === 200 || r.status === 204) && refused.status === 401, `logout ${r.status}, then /me ${refused.status}`);

const failed = results.filter(([, ok]) => !ok).length;
console.log(`\n${results.length - failed} of ${results.length} steps pass${failed ? `, ${failed} FAIL` : ''}`);
process.exit(failed ? 1 : 0);
