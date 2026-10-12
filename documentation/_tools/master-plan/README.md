# How abra-master-plan.md was generated

The master plan is generated from the HTML demos so nothing depends on memory.

1. `ext_desktop.mjs admin|client <out.json> [from to]` opens every page of the admin or client demo in headless Chrome (uses `grab.js`) and records tables, filters, tabs, number cards, buttons, dialogs and fields.
2. `merge.mjs` joins the chunk files into `all_admin.json` and `all_client.json`; `handlers.mjs` lists every action handler and where it was seen.
3. `routes.mjs` reads the backend controllers; `ext_cols.mjs` reads the store collections.
4. `doc/build.mjs` (with `features.mjs`, `endpoints.mjs`, `mobile.mjs`, `collections.mjs`, `narrative.mjs`) writes `abra-master-plan.md` and an HTML file that Chrome prints to PDF.

The scripts have hard-coded scratch paths (`SP`, `OUT`); change them before re-running. Hand-written parts: `endpoints.mjs` (handler to endpoint), `mobile.mjs` (customer, driver, website), `features.mjs`, `collections.mjs`, `narrative.mjs`.
