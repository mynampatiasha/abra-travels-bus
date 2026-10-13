// handler -> "METHOD /path | note"   or   "UI | note" (no server call).  Paths follow the existing backend where a route already exists.
// {B} is replaced by the page's base path (PAGE_BASE). Notes starting with "audit" say what is written to the audit log.

export const ADMIN_BASE = {
  dashboard: '/admin/dashboard', invitations: '/onboarding/invitations', kyc: '/onboarding/submissions', operators: '/catalogue/operators',
  commission: '/admin/commission/rules', payout: '/admin/payout/refund-slabs', places: '/catalogue/locations', bustypes: '/catalogue/bus-types',
  documents: '/catalogue/document-types', questions: '/admin/kyc/questions', buses: '/catalogue/buses', trips: '/catalogue/trips',
  inventory: '/admin/inventory', tracking: '/admin/tracking', bookings: '/admin/bookings', payments: '/admin/payments', refunds: '/admin/refunds',
  settlements: '/admin/settlements', customers: '/admin/customers', tickets: '/admin/tickets', content: '/admin/content', banners: '/admin/banners',
  offers: '/admin/offers', announce: '/admin/announcements', popular: '/admin/popular-routes', sos: '/admin/sos', incidents: '/admin/incidents',
  safety: '/admin/safety', reports: '/admin/reports', settings: '/admin/settings', staff: '/admin/staff', flags: '/admin/feature-flags',
  audit: '/audit-logs', notifications: '/notifications', ai: '/admin/settings/assistant', messages: '/admin/messages', drules: '/admin/driver-rules', dreports: '/admin/driver-reports',
};
export const CLIENT_BASE = {
  dashboard: '/client/dashboard', kyc: '/onboarding/submissions', company: '/client/company', buses: '/catalogue/buses', layouts: '/client/seat-layouts',
  crew: '/client/crew', dreports: '/client/driver-reports', drules: '/client/driver-rules', routes: '/catalogue/routes', places: '/client/place-requests',
  fares: '/client/fares', schedules: '/client/schedules', trips: '/catalogue/trips', bookings: '/client/bookings', offers: '/client/offer-requests',
  earnings: '/client/settlements', commission: '/client/commission', live: '/client/live', notifications: '/notifications', staff: '/client/users',
};

// Rules that depend on the page the button is on
export const GENERIC = {
  rec_view: 'GET {B}/:id | read one record for the detail window',
  rec_edit: 'UI | opens the edit form, filled from GET {B}/:id',
  rec_save: 'PATCH {B}/:id | save changes; audit before and after',
  rec_add: 'POST {B} | create from the generic form; audit',
  rec_del: 'DELETE {B}/:id | soft delete, refused if the record is in use; audit; "Undo" calls POST {B}/:id/restore',
  cb_ok: 'DELETE {B}/:id | confirm of a delete or revoke; audit',
  t_exp: 'GET {B}/export?format=csv|xlsx | same filters, search and permissions as the list',
  imp: 'POST {B}/import?dryRun=true then false | upload, row-by-row errors, then save; GET {B}/import-template for the file',
  vw: 'UI | table or list view of the same data',
  rec_edit_ops: 'UI | opens the edit form',
};

export const ADMIN = {
  // ---- shell and generic UI
  acct: 'UI | account menu', bell: 'UI | opens notifications (count from GET /notifications/unread-count)', chart_pt: 'UI | chart point opens the records behind it: GET {B} with the matching filter',
  copy: 'UI | copies text to the clipboard', demo_toggle: 'UI | demo only, not built', ev: 'UI | demo only, not built', lang: 'UI | opens language list', lang_sel: 'PATCH /me/preferences | saves language (8 languages)',
  mdl_bg: 'UI | closes the dialog', mdl_x: 'UI | closes the dialog', menu: 'UI | opens the menu', mfa: 'UI | opens the MFA dialog (GET /me/mfa exists)', mfa_ok: 'POST /me/mfa/totp/activate | exists',
  nav: 'UI | route change', offline_off: 'UI | dismisses the offline bar', open_app: 'UI | demo launcher only', orient: 'UI | horizontal or vertical layout, saved in /me/preferences', print: 'UI | browser print of the report',
  relogin: 'POST /auth/login | exists (session expired)', signout: 'POST /auth/logout | exists', sim: 'UI | demo only, not built', sim_ok: 'UI | demo only, not built', snd: 'UI | demo only, not built',
  t_clr: 'UI | clears filters', t_clr_sel: 'UI | clears the selection', t_pg: 'UI | page change: GET {B}?page=', tab: 'UI | tab change', theme: 'UI | light or dark, saved in /me/preferences', undo: 'POST {B}/:id/restore | undo a delete within a few seconds',
  role: 'UI | demo only: switching the role to preview access. Real build: the signed-in role comes from the token', x_go: 'UI | opens the page behind a chart detail', x_exp: 'GET /admin/reports/chart-detail/export | chart rows as CSV',
  kpi: 'GET {B}?<card filter> | each number card opens the records behind it', kpi_exp: 'GET {B}/export?<card filter> | export of the records behind a card',
  file_view: 'GET /files/:id/content | exists; viewer and download for proofs', pf_pick: 'UI | choose proof files (up to 5, 600 KB each) uploaded with POST /files | exists',
  gsearch: 'UI | global search box', gs_run: 'GET /admin/search?q= | PNR, phone, email, operator, bus, trip across collections; only what the role may see', gs_go: 'UI | opens the chosen result',
  // ---- assistant
  ai_open: 'UI | opens the assistant', ai_new: 'UI | new chat', ai_x: 'UI | closes', ai_mic: 'UI | browser speech to text', ai_mask: 'UI | show or hide the API key field',
  ai_send: 'POST /assistant/chat | question to Groq through the backend; answers only from data this role may read', ai_q: 'POST /assistant/chat | suggested question',
  ai_go: 'UI | opens the page the answer points to', ai_fb: 'POST /assistant/messages/:id/feedback | thumbs up or down', ai_rep_csv: 'GET /admin/reports/trip-revenue/export | the report the assistant showed',
  ai_ok: 'POST /assistant/actions/:id/confirm | runs an action the assistant proposed, with the same permission check and an audit entry', ai_no: 'POST /assistant/actions/:id/decline | audit',
  ai_cfg: 'PUT /admin/settings/assistant | provider, model, key (encrypted); audit', ai_test: 'POST /admin/settings/assistant/test | test connection',
  // ---- invitations, kyc, operators
  inv_new: 'UI | opens the invite form', inv_save: 'POST /onboarding/invitations | exists; sends the email and WhatsApp link', inv_open: 'GET /onboarding/invitations/:id | detail',
  inv_resend: 'POST /onboarding/invitations/:id/resend | exists', inv_revoke: 'UI | opens the revoke confirmation', kyc_open: 'GET /onboarding/submissions/:id | exists',
  kyc_hist: 'GET /onboarding/submissions/:id/history | new', doc_view: 'GET /files/:id/content | exists', doc_acc: 'POST /onboarding/submissions/:id/documents/:documentTypeId/review | exists, accept',
  doc_rej: 'UI | opens the reason form', doc_rej_ok: 'POST /onboarding/submissions/:id/documents/:documentTypeId/review | exists, reject with reason', kyc_approve: 'POST /onboarding/submissions/:id/approve | exists; notifies the operator',
  kyc_reject: 'POST /onboarding/submissions/:id/reject | exists; notifies the operator with the rejected documents',
  op_open: 'GET /catalogue/operators/:id | exists, plus tabs Overview, Buses, Bookings, Commission and payout', op_msg: 'UI | opens message form', op_msg_ok: 'POST /admin/operators/:id/messages | in-app and WhatsApp to the owner',
  op_suspend: 'UI | opens reason form (proof allowed)', op_susp_ok: 'POST /catalogue/operators/:id/status | exists; body status SUSPENDED + reason + proof; stops new sales, keeps existing bookings; notifies operator',
  op_react: 'POST /catalogue/operators/:id/status | exists; body status ACTIVE; notifies operator', op_payout: 'UI | opens payout mode form', op_payout_ok: 'PUT /admin/operators/:id/payout-mode | AUTO_SPLIT or MANUAL; audit', bank_ver: 'POST /admin/operators/:id/bank/verify | penny-drop or manual check; audit',
  // ---- commission, payout
  com_new: 'UI | opens the rule form', com_edit: 'UI | opens the rule form', com_save: 'POST /admin/commission/rules | new rule, or POST /admin/commission/rules/:id/versions for "Save as new version"; history row written; never changes past bookings',
  com_tog: 'PATCH /admin/commission/rules/:id/active | activate or deactivate; audit', com_def: 'UI | opens default form', com_def_ok: 'PUT /admin/commission/default | audit', com_calc: 'POST /admin/commission/calculate | price calculator: fare in, customer price and operator payable out (same function the booking uses)',
  pay_save: 'PUT /admin/payout/settings | cycle days, minimum payout, hold days, convenience fee, GST percent, coupon funding; audit', pay_route: 'PUT /admin/payout/settings/default-mode | automatic (Razorpay Route) or manual',
  slab_add: 'UI | opens slab form', slab_ok: 'POST /admin/payout/refund-slabs | audit', slab_del: 'DELETE /admin/payout/refund-slabs/:id | audit',
  // ---- catalogue
  place_new: 'UI | opens place form', place_edit: 'UI | opens place form', place_save: 'POST /catalogue/locations or PUT /catalogue/locations/:id | exists', city_new: 'UI | opens city form', city_edit: 'UI | opens city form', city_save: 'POST /catalogue/cities or PUT /catalogue/cities/:id | exists',
  preq_ok: 'POST /admin/place-requests/:id/approve | creates the place for every operator; notifies the operator', preq_no: 'UI | opens reason form', preq_no_ok: 'POST /admin/place-requests/:id/reject | reason; notifies the operator',
  bt_new: 'UI | opens bus type form', bt_edit: 'UI | opens bus type form', bt_save: 'POST /catalogue/bus-types or PUT /catalogue/bus-types/:id | exists', am_new: 'UI | opens amenity form', am_ok: 'POST /admin/amenities | new', am_tog: 'PATCH /admin/amenities/:id/active | new',
  dt_new: 'UI | opens document type form', dt_edit: 'UI | opens document type form', dt_save: 'POST /catalogue/document-types or PUT /catalogue/document-types/:id | exists', dt_tog: 'POST /catalogue/document-types/:id/active | exists',
  q_new: 'UI | opens question form', q_edit: 'UI | opens question form', q_save: 'POST /admin/kyc/questions or PATCH /admin/kyc/questions/:id | new', q_tog: 'PATCH /admin/kyc/questions/:id/active | new', q_exp: 'GET /admin/kyc/config/export | questions and document rules as a file',
  r_new: 'UI | opens rule form', r_save: 'POST /admin/kyc/document-rules or PATCH /admin/kyc/document-rules/:id | new', r_tog: 'PATCH /admin/kyc/document-rules/:id/active | new', pre_run: 'POST /admin/kyc/preview | evaluates which documents a sample answer set would require',
  // ---- buses, trips, inventory, tracking
  bus_open: 'GET /catalogue/buses/:id | exists', bus_m: 'POST /catalogue/buses/:id/status | exists; MAINTENANCE or back to ACTIVE; notifies operator', bus_ret: 'POST /catalogue/buses/:id/status | exists; RETIRED',
  bus_bulk_m: 'POST /admin/buses/bulk-status | selected active buses to maintenance; audit', bus_bulk_x: 'GET /catalogue/buses/export?ids= | export of the selected rows',
  trip_new: 'UI | opens the trip form', trip_save: 'POST /catalogue/trips | exists; creates a draft for an operator', trip_open: 'GET /catalogue/trips/:id | exists; plus seat map GET /admin/trips/:id/seats',
  seat_click: 'POST /admin/trips/:id/seats/:seat/block (or /unblock) for a free seat; GET /admin/bookings/:id for a booked seat | audit; a held seat only explains who holds it',
  trip_cancel: 'UI | opens reason form (proof)', trip_cancel_ok: 'POST /catalogue/trips/:id/cancel | exists; refunds all bookings, notifies customers, operator and driver; audit', trip_delay: 'UI | opens delay form',
  trip_delay_ok: 'POST /admin/trips/:id/delay | minutes, reason, proof; notifies customers, operator, admin', trip_driver: 'UI | opens driver form', trip_driver_ok: 'PUT /admin/trips/:id/driver | notifies the new driver and the operator',
  go: 'UI | opens the booking from the trip', inv_rel: 'POST /admin/inventory/release-expired-holds | frees holds past 10 minutes (also runs by itself every minute)',
  trk_sel: 'GET /admin/tracking/trips/:id | live card; position by Socket.IO tracking:{tripId}', trk_op: 'UI | filter', trk_st: 'UI | filter', trk_replay: 'GET /admin/tracking/trips/:id/replay | stored positions',
  // ---- bookings, payments, refunds
  bk_open: 'GET /admin/bookings/:id | detail with passengers, payment, refund, messages', bk_cancel: 'UI | opens cancel form (refund percent override, reason, proof)', bk_cancel_ok: 'POST /admin/bookings/:id/cancel | frees the seats, starts the refund, messages the customer; audit',
  bk_note: 'UI | opens note form', bk_note_ok: 'POST /admin/bookings/:id/notes | staff-only note', bk_resend: 'POST /admin/bookings/:id/resend-ticket | WhatsApp and email again',
  pay_open: 'GET /admin/payments/:id | detail with gateway ids', pay_ver: 'POST /admin/payments/:id/verify | asks Razorpay for the real status and updates', rec_fix: 'POST /admin/payments/reconciliation/:id/resolve | marks reconciled; audit',
  rf_done: 'POST /admin/refunds/:id/mark-paid | for manual refunds; reference required; messages the customer', rf_ok: 'POST /admin/refunds/:id/approve | starts the gateway refund', rf_no: 'UI | opens reject form (proof required)', rf_no_ok: 'POST /admin/refunds/:id/reject | reason and proof; notifies the customer',
  rf_retry: 'POST /admin/refunds/:id/retry | after a gateway failure', rf_bulk: 'POST /admin/refunds/bulk-approve | selected initiated refunds',
  // ---- settlements
  st_open: 'GET /admin/settlements/:id | with booking lines', st_gen: 'UI | opens generate form', st_gen_ok: 'POST /admin/settlements/generate | cycle and operator; gross minus commission minus refunds plus adjustments', st_gst: 'GET /admin/settlements/gst-statement?cycle= | file', st_payfile: 'GET /admin/settlements/payout-file?cycle= | bank file for manual mode',
  st_adj: 'UI | opens adjustment form', st_adj_ok: 'POST /admin/settlements/:id/adjustments | signed amount and reason; audit', st_rel: 'POST /admin/settlements/:id/release-hold | audit', st_stmt: 'GET /admin/settlements/:id/statement.pdf',
  st_appr: 'POST /admin/settlements/:id/approve | audit', st_bulk: 'POST /admin/settlements/bulk-approve | skips ones with open queries', st_hold: 'UI | opens hold form (reason and proof)', st_hold_ok: 'POST /admin/settlements/:id/hold | notifies the operator',
  st_pay: 'UI | opens pay form (reference)', st_pay_ok: 'POST /admin/settlements/:id/pay | manual mode marks paid with reference; automatic mode triggers the Razorpay Route transfer; notifies the operator', st_reply: 'UI | opens reply form', st_reply_ok: 'POST /admin/settlements/:id/query/reply | answers the operator\'s query; notifies the operator',
  // ---- customers, tickets, content
  cu_open: 'GET /admin/customers/:id | with bookings, tickets, SOS, devices', cu_block: 'UI | opens block form (reason, proof)', cu_block_ok: 'POST /admin/customers/:id/block | revokes sessions; audit', cu_unblock: 'POST /admin/customers/:id/unblock | audit', cu_out: 'POST /admin/customers/:id/sessions/revoke | sign out of all devices',
  tk_open: 'GET /admin/tickets/:id | thread', tk_assign: 'UI | opens assign form', tk_assign_ok: 'POST /admin/tickets/:id/assign | notifies the assignee', tk_send: 'POST /admin/tickets/:id/replies | reply with proof files; notifies the customer', tk_canned: 'GET /admin/tickets/canned-replies | list used by the reply box',
  tk_resolve: 'POST /admin/tickets/:id/resolve | audit', tk_reopen: 'POST /admin/tickets/:id/reopen | audit', tk_pick: 'UI | choose proof files',
  faq_new: 'UI | opens FAQ form', faq_edit: 'UI | opens FAQ form', faq_save: 'POST /admin/faqs or PATCH /admin/faqs/:id', faq_pub: 'POST /admin/faqs/:id/publish or /unpublish', pg_edit: 'UI | opens page editor', pg_save: 'PUT /admin/pages/:slug | draft or publish; creates a new version', pg_hist: 'GET /admin/pages/:slug/versions', con_save: 'PUT /admin/contact-info | phone, WhatsApp, email, hours, emergency number',
  // ---- marketing
  bn_new: 'UI | opens banner form', bn_edit: 'UI | opens banner form', ban_save: 'POST /admin/banners or PUT /admin/banners/:id | exists', ban_img: 'POST /admin/banners/:id/image | exists; JPG, PNG or WebP, up to 1 MB', bn_pub: 'POST /admin/banners/:id/active | exists (publish)', bn_unpub: 'POST /admin/banners/:id/active | exists (unpublish)',
  bn_arc: 'POST /admin/banners/:id/archive | new', bn_dup: 'POST /admin/banners/:id/duplicate | new', bn_up: 'PATCH /admin/banners/order | move up or down', of_new: 'UI | opens offer form', of_edit: 'UI | opens offer form', of_save: 'POST /admin/offers or PATCH /admin/offers/:id | audit',
  of_tog: 'PATCH /admin/offers/:id/active | pause or resume', of_view: 'GET /admin/offers/:id | detail with usage', of_test: 'POST /admin/offers/test | checks a coupon for a sample trip and user', an_new: 'UI | opens announcement form', an_save: 'POST /admin/announcements | draft, schedule or send now; send creates notifications and messages for the audience',
  po_new: 'UI | opens add form', po_ok: 'POST /admin/popular-routes', po_mv: 'PATCH /admin/popular-routes/order', po_tog: 'PATCH /admin/popular-routes/:id/active',
  // ---- safety
  sos_sel: 'GET /admin/sos/:id | board card and detail; new alerts arrive by Socket.IO', sos_ack: 'POST /admin/sos/:id/acknowledge | tells the customer or driver and the operator', sos_esc: 'POST /admin/sos/:id/escalate | police and safety lead; audit', sos_res: 'UI | opens resolve form (note and proof required)', sos_res_ok: 'POST /admin/sos/:id/resolve | note, proof; notifies the customer or driver',
  sos_fa: 'UI | opens false alarm form (proof)', sos_fa_ok: 'POST /admin/sos/:id/false-alarm | what the customer said, proof', sos_note: 'UI | opens note form', sos_note_ok: 'POST /admin/sos/:id/notes', tel: 'UI | dials the number',
  inc_new: 'UI | opens incident form', inc_new_ok: 'POST /admin/incidents | with proof', inc_open: 'GET /admin/incidents/:id', inc_save: 'PATCH /admin/incidents/:id | status and note; audit', shr_rev: 'DELETE /admin/trip-shares/:id | revokes a sharing link; audit',
  sf_add: 'UI | opens add form', sf_add_ok: 'POST /admin/safety/team | name and role', sf_del: 'DELETE /admin/safety/team/:id', sf_save: 'PUT /admin/safety/settings | acknowledge minutes, escalate minutes, police number, SOS hold seconds; audit', sf_op: 'PUT /admin/safety/settings | notify operator switch', sf_sms: 'PUT /admin/safety/settings | SMS switch', sf_wa: 'PUT /admin/safety/settings | WhatsApp switch',
  // ---- reports, settings, staff, flags
  range: 'GET /admin/dashboard?range=today|7d|30d', rrange: 'GET /admin/reports/:type?range=', rep_sel: 'GET /admin/reports/:type/rows?key= | detail panel inline on the Reports page', rep_clr: 'UI | closes the detail panel', rep_exp: 'GET /admin/reports/:type/export | rows of the open detail', dash_exp: 'GET /admin/dashboard/export',
  set_gen: 'PUT /admin/settings/company | audit', set_bk: 'UI | opens the reason form', set_bk_ok: 'PUT /admin/settings/booking | hold minutes, seat limit and similar; a reason is required; audit', set_sec: 'PUT /admin/settings/security | password and session rules; audit', set_mfa: 'PUT /admin/settings/security/mfa | require MFA for roles',
  int_edit: 'UI | opens the integration form', int_save: 'PUT /settings/integrations/:key | email and WhatsApp exist; Razorpay, Maps, SMS, Groq, push are new; secrets encrypted', int_test: 'POST /settings/integrations/:key/test-connection | exists for email and WhatsApp', tpl_view: 'GET /admin/message-templates/:id/preview',
  sf_new: 'UI | opens staff form', sf_edit: 'UI | opens staff form', sf_save_ok: 'POST /admin/staff (invitation) or PATCH /admin/staff/:id', sf_off: 'POST /admin/staff/:id/deactivate | audit', sf_on: 'POST /admin/staff/:id/activate | audit',
  role_new: 'UI | opens add role form', role_save: 'POST /admin/roles | new role, optionally copying another role\'s access; audit', role_ren: 'UI | opens rename form', role_ren_ok: 'PATCH /admin/roles/:id | audit', role_del: 'DELETE /admin/roles/:id | refused if staff use it',
  perm_set: 'PUT /admin/permissions/:role/:page | level None, View, Edit or Edit+Delete; Super Admin only; audit', perm_all: 'PUT /admin/permissions/:role | one level for every page; Super Admin only; audit', ses_out: 'DELETE /me/sessions/:sessionId | exists',
  flag_tog: 'PUT /admin/feature-flags/:key | confirmation first; takes effect straight away; audit', maint_tog: 'PUT /admin/maintenance | on or off per scope (global, customer, operator, partner)', maint_save: 'PUT /admin/maintenance/message | message and window',
  au_open: 'GET /audit-logs/:id | detail with before and after', n_all: 'POST /notifications/read-all | exists', n_open: 'POST /notifications/:id/read | exists, then opens the target', msg_open: 'GET /admin/messages/:id', msg_resend: 'POST /admin/messages/:id/resend | queues again',
  // ---- driver rules and reports (admin)
  dr_new: 'UI | opens item form', dr_edit: 'UI | opens item form', dr_save: 'POST /admin/driver-rules/defaults/items or PATCH .../items/:id | defaults every new operator starts from', dr_del: 'DELETE /admin/driver-rules/defaults/items/:id | locked items cannot be removed', dr_tog: 'PATCH /admin/driver-rules/defaults/items/:id/active | locked items cannot be switched off', dr_mv: 'PATCH /admin/driver-rules/defaults/order',
  dr_push: 'POST /admin/driver-rules/push-minimum | adds the locked items to every operator\'s copy; audit', rt_new: 'UI | opens report type form', rt_edit: 'UI | opens report type form', rt_save: 'POST /admin/driver-rules/defaults/reports or PATCH .../reports/:id', rt_del: 'DELETE /admin/driver-rules/defaults/reports/:id', rt_tog: 'PATCH /admin/driver-rules/defaults/reports/:id/active',
  rt_q: 'UI | opens the question list of a report type', rq_add: 'POST /admin/driver-rules/defaults/reports/:id/questions', rq_del: 'DELETE /admin/driver-rules/defaults/reports/:id/questions/:qid', rq_mv: 'PATCH /admin/driver-rules/defaults/reports/:id/questions/order', rq_req: 'PATCH /admin/driver-rules/defaults/reports/:id/questions/:qid | required or not',
  dr_open: 'GET /admin/driver-reports/:id | read-only: system numbers (frozen at send) and the driver\'s answers', dc_open: 'GET /admin/trip-checks/:id | read-only checklist result', dr_remind: 'POST /admin/driver-reports/remind | tells the operator which report is missing',
  run: 'UI | demo only, not built',
  dr_appr: 'UI | operator only; admin reads driver reports', dr_ret: 'UI | operator only', dr_ret_ok: 'UI | operator only', dr_reset: 'UI | operator only; admin edits the defaults instead',
  imp_dry: 'POST {B}/import?dryRun=true | row-by-row result', imp_file: 'UI | choose file', imp_go: 'POST {B}/import?dryRun=false | saves the valid rows', imp_sample: 'GET {B}/import-template | sample file', imp_tpl: 'GET {B}/import-template',
};

export const CLIENT = {
  // shell and generic UI: same meaning as in the admin app
  acct: 'UI | account menu', bell: 'UI | opens notifications', chart_pt: 'UI | chart point opens the records behind it', demo_toggle: 'UI | demo only', ev: 'UI | demo only', lang: 'UI | language list', lang_sel: 'PATCH /me/preferences | language',
  mdl_bg: 'UI | closes the dialog', mdl_x: 'UI | closes the dialog', menu: 'UI | menu', mfa: 'UI | MFA dialog', mfa_ok: 'POST /me/mfa/totp/activate | exists', nav: 'UI | route change', offline_off: 'UI | offline bar', open_app: 'UI | demo launcher only', orient: 'UI | layout preference',
  relogin: 'POST /auth/login | exists', signout: 'POST /auth/logout | exists', sim: 'UI | demo only', sim_ok: 'UI | demo only', t_clr: 'UI | clears filters', t_clr_sel: 'UI | clears selection', t_pg: 'UI | page change', tab: 'UI | tab change', theme: 'UI | light or dark', undo: 'POST {B}/:id/restore',
  x_go: 'UI | opens the page behind a chart', x_exp: 'GET /client/reports/chart-detail/export', kpi: 'GET {B}?<card filter> | every number card opens the records behind it', kpi_exp: 'GET {B}/export?<card filter>', file_view: 'GET /files/:id/content | exists', pf_pick: 'UI | choose files; POST /files | exists',
  gsearch: 'UI | search box', gs_run: 'GET /client/search?q= | only this company\'s data', gs_go: 'UI | opens the result',
  imp_dry: 'POST {B}/import?dryRun=true | row-by-row result', imp_file: 'UI | choose file', imp_go: 'POST {B}/import?dryRun=false', imp_sample: 'GET {B}/import-template | sample file', imp_tpl: 'GET {B}/import-template',
  cai_open: 'UI | opens the assistant', cai_new: 'UI | new chat', cai_x: 'UI | closes', cai_mic: 'UI | browser speech to text', cai_send: 'POST /assistant/chat | answers only from this company\'s data', cai_q: 'POST /assistant/chat | suggested question', cai_go: 'UI | opens the page the answer points to', cai_ok: 'POST /assistant/actions/:id/confirm | same permission check and audit', cai_no: 'POST /assistant/actions/:id/decline',
  // sign-in and onboarding wizard
  au_in: 'POST /auth/login | exists (password) or POST /auth/social/google', au_acc: 'POST /onboarding/invitations/accept | exists', au_back: 'UI | back', au_inv: 'POST /onboarding/invitations/inspect | exists; shows the invited company',
  kstep: 'UI | wizard step', kq: 'PUT /onboarding/submissions/:id/answers | saves a questionnaire answer', kq_in: 'PUT /onboarding/submissions/:id/answers', kd_up: 'PUT /onboarding/submissions/:id/documents/:documentTypeId | exists', kd_fix: 'PUT /onboarding/submissions/:id/documents/:documentTypeId | exists; replaces a rejected file',
  kd_resend: 'POST /onboarding/submissions/:id/submit | exists; sends corrections', kd_submit: 'POST /onboarding/submissions/:id/submit | exists', bdoc: 'UI | choose the bus document', bd_fix: 'PUT /onboarding/submissions/:id/documents/:documentTypeId | exists', bd_resend: 'POST /onboarding/submissions/:id/submit | exists',
  // company
  co_save: 'PUT /client/company | company profile; audit', bk_save: 'PUT /client/company/bank | bank details; admin verifies', up_ex: 'UI | choose file', up_go: 'POST /files | exists',
  // buses and layouts
  bus_new: 'UI | opens bus form', bus_edit: 'UI | opens bus form', bus_save: 'POST /catalogue/buses (sends the bus for KYC approval) or PUT /catalogue/buses/:id | exists', bus_open: 'GET /catalogue/buses/:id | exists', bus_mt: 'POST /catalogue/buses/:id/status | exists; MAINTENANCE', go: 'UI | opens the seat layout of the bus', lay_bus: 'GET /client/seat-layouts?busId= | layout of the chosen bus',
  ltool: 'UI | chooses the drawing tool (seat or sleeper)', lcell: 'UI | places or removes a seat in the drawing', lrow: 'UI | adds or removes a row in the drawing', lreset: 'UI | clears the drawing', lsave: 'PUT /client/seat-layouts/:busId | saves a new version; trips already published keep their copy',
  // crew
  cr_new: 'UI | opens person form', cr_save: 'POST /client/crew or PATCH /client/crew/:id | licence number and expiry; audit',
  // routes, places, fares, schedules, trips
  rt_new: 'UI | opens route form', rt_edit: 'UI | opens route form', rt_save: 'POST /catalogue/routes or PUT /catalogue/routes/:id | exists; stops with times, boarding and dropping points', rt_open: 'GET /catalogue/routes/:id | exists', rt_copy: 'POST /client/routes/copy-from/:id | copies a public route as this operator\'s own',
  rt_add: 'UI | adds a stop row', rt_rm: 'UI | removes a stop row', rt_mv: 'UI | moves a stop', rt_ty: 'UI | sets the stop type (boarding, dropping, both)', rt_pl: 'GET /catalogue/locations?cityId= | exists; places for a stop', rt_off: 'UI | sets the minutes from start',
  rt_del: 'DELETE /catalogue/routes/:id | refused if trips use it', rt_tog: 'POST /catalogue/routes/:id/status | exists',
  pr_new: 'UI | opens place request form', pr_save: 'POST /client/place-requests | admin approves or rejects; the operator is notified',
  fr_new: 'UI | opens fare form', fare_edit: 'UI | opens fare form', fr_save: 'POST /client/fares or PATCH /client/fares/:id | weekday, weekend, festival fare per seat type; effective from', tr_refares: 'POST /client/trips/:id/refares | reapplies the fare rule to unsold trips (does not change published trips unless republished)',
  sc_new: 'UI | opens schedule form', sch_edit: 'UI | opens schedule form', sc_save: 'POST /client/schedules or PATCH /client/schedules/:id | recurring trip', sc_day: 'UI | picks days of the week', sc_gen: 'POST /client/schedules/:id/generate | creates the trips for the date range',
  tr_new: 'UI | opens trip form', tr_save: 'POST /catalogue/trips | exists; draft with fares by seat type', tr_open: 'GET /catalogue/trips/:id | exists; plus seat map GET /client/trips/:id/seats', tr_pub: 'POST /catalogue/trips/:id/publish | exists; only if company and bus KYC are approved', tr_bulk_pub: 'POST /client/trips/bulk-publish | selected drafts',
  tr_cancel: 'UI | opens reason form (proof)', tr_cancel_ok: 'POST /catalogue/trips/:id/cancel | exists; refunds all bookings; notifies customers, driver, admin', tr_delay: 'UI | opens delay form', tr_delay_ok: 'POST /client/trips/:id/delay | minutes, reason, proof; notifies customers and admin', tr_drv: 'UI | opens driver form', tr_drv_ok: 'PUT /client/trips/:id/driver | notifies the driver', tr_man: 'GET /client/trips/:id/manifest.pdf | passenger list with seats and boarding points',
  // bookings
  cb_open: 'GET /client/bookings/:id | detail', cb_cancel: 'UI | opens cancel form (proof)', cb_cancel_ok: 'POST /client/bookings/:id/cancel | operator-side cancellation; refund by the operator\'s slab; audit', tel: 'UI | dials the passenger',
  // offers, earnings, commission
  of_req: 'UI | opens offer request form', of_req_ok: 'POST /client/offer-requests | arrives in admin as an offer request to approve', cs_open: 'GET /client/settlements/:id | detail with lines', cs_q: 'UI | opens query form (proof allowed)', cs_q_ok: 'POST /client/settlements/:id/query | notifies admin', cs_stmt: 'GET /client/settlements/:id/statement.pdf', cm_calc: 'POST /client/commission/calculate | shows how a fare becomes the customer price and the operator payable',
  // live, notifications
  n_all: 'POST /notifications/read-all | exists', n_open: 'POST /notifications/:id/read | exists, then opens the target',
  // staff
  ou_new: 'UI | opens user form', ou_save: 'POST /client/users (invitation) or PATCH /client/users/:id', role_new: 'UI | opens role form', role_save: 'POST /client/roles | audit', role_ren: 'UI | rename', role_ren_ok: 'PATCH /client/roles/:id', role_del: 'DELETE /client/roles/:id', role: 'UI | demo only: preview as another role',
  perm_all: 'PUT /client/permissions/:role | one level for every page', perm_set: 'PUT /client/permissions/:role/:page | None, View, Edit, Edit+Delete; the owner only',
  // driver rules and reports
  dr_new: 'UI | opens item form', dr_edit: 'UI | opens item form', dr_save: 'POST /client/driver-rules/items or PATCH /client/driver-rules/items/:id | this operator\'s copy', dr_del: 'DELETE /client/driver-rules/items/:id | locked items cannot be removed', dr_tog: 'PATCH /client/driver-rules/items/:id/active | locked items cannot be switched off', dr_mv: 'PATCH /client/driver-rules/order',
  dr_reset: 'POST /client/driver-rules/reset | back to the Abra defaults', dr_push: 'UI | admin only', rt_q: 'UI | opens question list', rq_add: 'POST /client/driver-rules/reports/:id/questions', rq_del: 'DELETE /client/driver-rules/reports/:id/questions/:qid', rq_mv: 'PATCH /client/driver-rules/reports/:id/questions/order', rq_req: 'PATCH /client/driver-rules/reports/:id/questions/:qid',
  d_reset: 'UI | confirm reset', dop: 'UI | opens an option list', dr_open: 'GET /client/driver-reports/:id | system numbers (frozen) and answers', dc_open: 'GET /client/trip-checks/:id | checklist result', dr_appr: 'POST /client/driver-reports/:id/approve | notifies the driver', dr_ret: 'UI | opens the note form', dr_ret_ok: 'POST /client/driver-reports/:id/return | note required; notifies the driver', dr_remind: 'POST /client/driver-reports/remind | tells the driver',
};

// Where each page's records come from, one line used in the page header table
export const PAGE_NOTES = {
  admin: {
    dashboard: 'Cards and charts computed on the server from bookings, payments, trips and operators; cached for a minute.',
    inventory: 'Seat counts per trip: sold, held, blocked, free; low-occupancy list.',
    reports: 'Sales, operators and routes reports; each row opens its detail inline on the same page; export and print.',
    tracking: 'Live bus list and map; positions arrive by Socket.IO.',
  },
  client: {},
};

// Sections that the click-through cannot list (charts, cards, forms). Read from the demo pages.
export const PAGE_UI = {
  'admin:dashboard': 'Needs your attention | Bookings over time (chart, today / 7 days / 30 days) | Booking status (chart) | Revenue and commission (chart) | Top routes by bookings | Top operators by sales | Latest activity',
  'admin:sos': 'Left: a card for each SOS alert (customer name, status, "Raised by customer or driver", route, time). Right: the selected alert with map position, customer, driver, operator, bus, contacts alerted, the log of what happened, and the action buttons',
  'admin:tracking': 'Map with every running bus, list of buses with state, speed, progress and ETA, filter by operator and state, route replay',
  'admin:safety': 'Safety settings | Escalation timing (acknowledge minutes, escalate minutes, SOS hold seconds) | Who is alerted (operator, SMS, WhatsApp switches) | Safety team (people who receive alerts) | Message sent to emergency contacts',
  'admin:reports': 'Reports (Sales, Operators, Routes) | Gross sales by day chart | rows that open their detail inline on the same page | Export these rows | Print',
  'admin:flags': 'Feature flags (switch each feature on or off) | Maintenance mode (global, customer app, operator app, partner; message and window)',
  'admin:settings': 'Settings and integrations | WhatsApp | Email (SMTP) | SMS | Razorpay | Maps | Push (Firebase) | Company | Booking rules | Security | Message templates',
  'admin:ai': 'AI assistant settings | Provider and model | Safety rule (what the assistant may and may not do) | What the assistant can do | Actions done by the assistant (log)',
  'admin:inventory': 'Cards: trips on sale, seats sold, seats held right now, low-occupancy trips; table of trips with seat counts',
  'client:dashboard': 'Needs your attention | Bookings, last 14 days (chart) | Booking status (chart) | Your earnings per day, after commission (chart) | Occupancy by route (chart)',
  'client:kyc': 'Step-by-step KYC wizard: questionnaire, then one upload box per required document with status (waiting, accepted, rejected with reason, replace), Send for review; bus KYC has the same steps',
  'client:live': 'Live buses and safety | Running now (list with map, position, ETA, passengers, checked in) | SOS history on this operator\'s buses (customer, driver, status)',
  'client:layouts': 'Seat layout designer: tools (Seat, Sleeper, Aisle, Remove), grid with Add row and Remove row, Reset, Save layout, Summary (seat counts, deck, ladies seats); choose the bus',
  'client:schedules': 'List of recurring schedules (route, bus, time, days, from, till, status) and the form to create them; Generate trips',
  'client:company': 'Company profile (name, owner, GST, PAN, address, contact) | Bank account for payout (with verification status set by Abra)',
  'client:commission': 'Rules that apply to you (read-only, set by Abra) | Price calculator: fare in, customer price and your payable out',
};

// Access matrix: built 2026-10-12 (backend/src/modules/rbac/access_matrix_admin_manage*). These replace the first guesses above.
Object.assign(ADMIN, {
  role_save: 'POST /access-matrix/roles | new role, optionally copying another role\'s access; Super Admin only; audit role.created',
  role_ren_ok: 'PATCH /access-matrix/roles/:roleKey | custom roles only; audit role.renamed',
  role_del: 'DELETE /access-matrix/roles/:roleKey | custom roles only; refused while any user holds it; audit role.deleted',
  perm_set: 'PUT /access-matrix/roles/:roleKey/pages/:pageId | built; level None, View, Edit or Edit+Delete; Super Admin only; audit role.access.changed; holders get new tokens',
  perm_all: 'PUT /access-matrix/roles/:roleKey | built; one level for every page; Super Admin only; audit',
});
Object.assign(CLIENT, {
  role_save: 'POST /access-matrix/roles | audience OPERATOR; phase 8 lets the owner manage own roles (operatorId on the role)',
  role_ren_ok: 'PATCH /access-matrix/roles/:roleKey', role_del: 'DELETE /access-matrix/roles/:roleKey',
  perm_set: 'PUT /access-matrix/roles/:roleKey/pages/:pageId | the owner only (phase 8)', perm_all: 'PUT /access-matrix/roles/:roleKey | one level for every page',
});

// Integration settings: built 2026-10-12 (backend/src/modules/system-settings/integrations_admin_manage*).
Object.assign(ADMIN, {
  int_edit: 'UI | opens the integration form (values and write-only secrets)',
  int_save: 'PUT /settings/integrations/:key | built; key = razorpay, maps, sms, push or assistant (WhatsApp and email keep their own PUT routes, which exist); secrets stored encrypted, never returned; reason required; audit settings.integration.changed',
  int_test: 'POST /settings/integrations/:key/test-connection | built; asks the provider a harmless question; nothing is sent to a customer; WhatsApp and email have their own test routes (exist)',
  ai_cfg: 'PUT /settings/integrations/assistant | built; provider, Groq key (secret), model, "may propose actions"; audit',
  ai_test: 'POST /settings/integrations/assistant/test-connection | built; checks the Groq key and the model name',
});

// Assistant: built 2026-10-12 (backend/src/modules/chatbot/assistant_chat*). One endpoint serves every app.
Object.assign(ADMIN, {
  ai_send: 'POST /assistant/chat | built; the conversation so far + app language; answers only from tools the person\'s role allows; 20 a minute; returns reply, proposals, turn id (streaming is not built yet)',
  ai_q: 'POST /assistant/chat | built; a suggested question is sent like any other',
  ai_fb: 'POST /assistant/messages/:turnId/feedback | built; thumbs up or down on one answer',
  ai_ok: 'POST /assistant/actions/:id/confirm | built; checks the permission again, makes the change once, audit assistant.action.confirmed',
  ai_no: 'POST /assistant/actions/:id/decline | built; audit assistant.action.declined',
});
Object.assign(CLIENT, {
  cai_send: 'POST /assistant/chat | built; same endpoint as the admin portal; the operator assistant sees only that operator\'s tools',
  cai_q: 'POST /assistant/chat | built',
  cai_ok: 'POST /assistant/actions/:id/confirm | built',
  cai_no: 'POST /assistant/actions/:id/decline | built',
});

// Feature flags and maintenance: built 2026-10-12 (backend/src/modules/feature-flags/flags_admin_manage*).
Object.assign(ADMIN, {
  flag_tog: 'PUT /admin/feature-flags/:key | built; body on and a reason; audit feature-flag.changed; reaches every server within seconds; the public map GET /features follows',
  maint_tog: 'PUT /admin/maintenance | built; body scopes (global, customer, operator, partner, admin) and a reason; audit maintenance.changed; the guard enforces it on every request',
  maint_save: 'PUT /admin/maintenance | built; body message, from, to (end must be after start) and a reason; same endpoint as the switches',
});
