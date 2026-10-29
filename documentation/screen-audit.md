# Screen audit: real admin app against the demo (14 October 2026)

Method: the real admin app (web build, local database with the demo sample data) and `prototypes/admin_demo_model.html`, both at 1440 x 900, opened side by side. Pictures are in `documentation/screen-audit/` (`app_d_<page>.png` is the real app, `demo_d_<page>.png` is the demo). Phone width was not checked yet.

**Result: no screen matches its demo.** The pages work, but they are built from one generic list page, so every page has the same look and the same gaps.

## A. The shared frame (affects every screen, fix first)

| Part | Demo | Real app |
|---|---|---|
| Side menu | Product name "Abra Travels, Admin portal"; 11 titled groups (Overview, Operators, Commercial, Catalogue, Operations, Sales, Customers, Marketing, Safety, Insights, System); red count badges (KYC reviews, Driver reports, Cities and places, Payments, Tickets, SOS) | One flat list under two titles (Catalogue, Content); no counts; wrong order; names differ ("Bus types", "KYC configuration" against "Bus types and amenities", "KYC questionnaire"); has pages the demo does not have as menu items (Routes, Reviews) |
| Top bar | Page title; global search "Search PNR, operator, bus..." with Ctrl K; role badge (Super Admin); language list (8 languages); AI assistant button; dark mode button; bell with a count; account menu | Page title with a small grey line; "All operators" chip; inbox icon; bell; name and sign-out button. No search, no role badge, no language, no AI, no dark mode |
| Page header | Breadcrumb ("Catalogue / Cities and places"), large title, one-line explanation, the main button at the right of the title (for example "Invite operator") | Title and line sit in the top bar; no breadcrumb; the main button sits in the toolbar |
| Toolbar | Labelled fields (Search, Status ...), then Clear, Export CSV, the main button, and the Table / List switch | Search with an icon, drop-downs, a refresh icon, Import, Export, the main button. No Clear while filters are empty, no Table / List switch |
| Table | Light grey header with plain words; first column bold with a grey second line; coloured pills for status; row buttons with words ("Edit"), an eye and a red bin | Dark navy header; plain first column; small icon-only buttons (eye, pencil, disable circle, bin); different pill colours |
| Number cards | None on most pages | Coloured cards (Active, Pending, Suspended) above the table on Operators, Cities, Banners |
| Footer | "14 results", Previous, "Page 1 of 2", Next | "1-14 of 14" and two arrows |
| Empty state | Specific message per page | "Nothing here yet / Add the first one" |
| Colours and type | Inter-style font, soft blue and white, small pills | Navy blocks, heavier look |

## B. Page by page

| Page | Main differences found |
|---|---|
| Cities and places (Places tab) | Demo columns Place (with address), City, Used for, Added by, Trips using it, Status, Actions (Edit, eye, bin): real has them but with the generic look; demo fields are labelled Search, City, Used for, Status with Clear, Export CSV, Add place, Import, Table / List; real "Used for" shows Both for every seeded place (the seed has no value); tab counts in demo are plain grey pills. |
| Cities (tab) | Demo columns: City with Telugu and Hindi names, State, Places, Popular, Status; filters Search, State, Status; form with Telugu and Hindi names and "Show as popular". Real: Name, State, Country code, URL key, Popular city, Status, no Places count, no State filter, two number cards the demo does not have. |
| Operator requests (tab) | Not compared yet (needs a request in the database). Known: Approve and Reject must be a green button and a red button with words. |
| Operators | Demo: filters Search, Status, Payout mode; columns Operator (name and "owner - city"), Status, KYC, Buses, Trips, Payout, Rating, Joined, Actions; Invite operator at the top right. Real: filters Search company or name and Status only; no KYC column values (shows a dash), no Payout, no Rating; Buses and Trips numbers right-aligned; Joined in numbers (14/10/2026) instead of "13 Sept 2025"; extra approve circle button and number cards. |
| Banners | Demo: tabs All banners and Analytics; columns Banner (title and subtitle), Status, Runs (dates), Shown to, Opens, Order with arrows, Actions with words (Edit, Unpublish / Publish, Duplicate, Archive), eye, bin. Real: no tabs, number cards, Export and New banner, nothing in the table (no data to compare). |
| KYC questionnaire (real name "KYC configuration") | Demo: tabs Questions (6), Document rules (5), Preview checklist; table with Question (with key and choices), Answer type pill, Required, Active switch, Edit, eye, bin; Export CSV, Add question, Export config; Table / List. Real: a big heading again inside the page, four number cards, an explanation paragraph, Add question, Preview, Export, Import, link to Manage documents, two tabs only, four filters. Different structure. |
| Bus types, Required documents | Same generic look; demo pages are titled "Bus types and amenities" (amenities card) and "Required documents"; see pictures `app_d_bus_types`, `demo_d_bustypes`, `app_d_document_types`, `demo_d_documents`. Detailed field list still to write. |
| Invitations, Reviews (KYC reviews), Customers, Settings, Audit log, Trips, Buses, Routes, Locations | Pictures taken for both sides; detailed lists still to write. Routes and Locations have no demo page (they are inside Trips and Buses forms in the demo), so they should stop being menu items of their own. |
| Audit log | The one page that was compared during its build. It matches the demo's columns, filters and entry window; it still sits inside the generic frame (section A). |

## C. What to do, in order

1. **Rebuild the frame once** (section A): grouped side menu with counts, top bar, page header with breadcrumb, toolbar, table, list view, pills, footer and empty states in the demo's style. Every page then improves together.
2. **Rebuild the shared table and toolbar** so a page only describes its columns, filters and row buttons, and the result looks like the demo.
3. **Fix each page** in this order: Cities and places (three tabs), Operators, Banners, KYC questionnaire, Bus types, Required documents, Invitations, KYC reviews, Customers, Settings, Audit log.
4. **Check each page against its demo again** at laptop and phone width, then give you a short look-and-click checklist.
5. The client portal gets the same audit and the same fix (not audited yet).
