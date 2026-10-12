# Management app (Admin and Operator)

Flutter app for platform staff and operator staff, in `apps/admin_app`. Web, desktop-first. One app serves both groups: what a user sees follows from their permissions and data scope, not from a separate build. Implemented 2026-10-06: foundation and the catalogue pages.

It is separate from the customer app and shares only the `packages/shared_*` code with it.

## 1. What exists

| Area | Status |
|---|---|
| Staff sign-in (email and password) | Done |
| Two-step verification at sign-in (authenticator code or recovery code) | Done |
| Setting up two-step verification in the app | **Not built** — an account that must set it up is told so and gets no further |
| Session restore, token refresh, sign-out, session ended by the server | Done (shared session manager) |
| Permission loading and permission-driven navigation | Done |
| Catalogue pages: cities, bus types, operators, locations, buses, routes, trips | Done |
| Trip publishing and cancelling | Done |
| Users and roles, bookings, payments, reports, settings (including the WhatsApp settings API) | Not built |

Verified by widget tests against a stand-in backend, by a web build, and by a run in a browser against the real backend (2026-10-06: sign-in, session restore, every catalogue section, trip publishing and cancelling, and the customer search showing only the published trip). Its look follows [design-system.md](design-system.md).

## 2. First administrator

A new installation has no accounts. The first Super Admin is created from the command line, never through the API:

```bash
BOOTSTRAP_SUPER_ADMIN_EMAIL=admin@example.com \
BOOTSTRAP_SUPER_ADMIN_NAME="Platform Admin" \
BOOTSTRAP_SUPER_ADMIN_PASSWORD='<at least 10 characters>' \
npm run bootstrap:super-admin          # in a deployed image: node dist/bootstrap-super-admin.js
```

- The three variables are read by this command only, not by the API or the worker. Supply them for the one run (shell, or the secret manager of the deployment) and remove them afterwards. Do not put them in a committed file.
- The password must satisfy the password policy (length, not a repeated pattern, not containing the e-mail address). It is stored as an Argon2id hash.
- The command creates a `STAFF` account with the `SUPER_ADMIN` role and data scope `ALL`, and writes an audit entry (`user.super-admin.bootstrapped`) in the same transaction.
- **It does nothing when any account already holds the Super Admin role**, whatever its status, so it cannot add a second administrator or take over an installation. Other roles (for example `ADMIN`) do not block it.
- Runs at the same moment create exactly one account.
- Missing or unacceptable variables stop it before it connects to anything; the message names the variable and never repeats the password.
- Exit code 0: created, or an administrator already existed. Exit code 1: failed.

Further staff and operator staff accounts need user management, which is not built yet (§8).

## 3. Structure

```
apps/admin_app/
├── l10n/admin_<locale>.arb            Messages (English complete; other languages fall back to English)
├── lib/
│   ├── bootstrap/                     Environment, services, error handlers
│   ├── app/providers.dart             Session mirror, access state (permissions), start-up
│   ├── routing/                       Locations, route guard, router
│   ├── shell/admin_shell.dart         Top bar and permission-driven side navigation
│   ├── core/                          Loading/failure/data view, failure messages
│   └── features/
│       ├── auth/                      Sign-in, two-step verification, access gate
│       └── catalogue/
│           ├── catalogue_repository.dart   The /catalogue API
│           ├── widgets/resource_page.dart  The standard list: filters, table, pagination, actions
│           ├── widgets/resource_form.dart  The standard create/edit form
│           └── pages/                      One page per resource
└── test/
```

State management is Riverpod, as in the customer app. The seven catalogue pages are descriptions (columns, filters, form fields, actions) handed to two shared widgets, so lists and forms behave the same everywhere. The environment, error-handling and loading/failure view files were taken over from the customer app; moving them into a shared package is open (§8).

Configuration is the same as the customer app's (`ABRA_ENV`, `ABRA_API_BASE_URL`; HTTPS required in staging, production and every release build). In a browser the app is a `WEB` client of the backend: the refresh token is an HttpOnly cookie the app never sees and the access token is kept in memory only. The development default is `http://localhost:4000`; the backend must list the app's origin in `CORS_ALLOWED_ORIGINS`.

## 4. Sign-in and access

1. E-mail and password (`POST /auth/login`).
2. If the account uses two-step verification, the code from the authenticator app or a recovery code (`POST /auth/mfa/verify`). An expired step returns to the password.
3. The permissions are loaded (`GET /me/permissions`).

What happens next depends on the account:

| Account | Result |
|---|---|
| Platform staff or operator staff, permissions loaded | The management area, at the first section they may open |
| Customer, driver or partner account | "This account cannot use the management app". No management screen, no catalogue request, not even the permissions are requested |
| Must still set up two-step verification | Told so; nothing else is reachable (the backend refuses everything else for that session anyway) |
| Permissions could not be loaded | Nothing is shown; retry or sign out |
| Staff without any catalogue permission | "Nothing to manage" |

Passwords and codes leave their input fields when submitted and are never stored or logged.

## 5. Navigation and permissions

The side navigation, the route guard and every button read the permission set from `GET /me/permissions`. Nothing checks a role name. Keys come from the shared registry (`shared_permissions`), which is tested against the backend catalogue.

| Section | Shown with | Create / edit shown with |
|---|---|---|
| Trips | `trips.read` | `trips.create`, `trips.update` (drafts), `trips.publish`, `trips.cancel` |
| Buses | `buses.read` | `buses.create`, `buses.update` |
| Routes | `routes.read` | `routes.create`, `routes.update` |
| Locations | `routes.read` | `routes.create`, `routes.update` |
| Operators | `operators.read` | `operators.create`, `operators.update`, `operators.approve` |
| Cities | `catalogue.read` | `catalogue.manage` |
| Bus types | `buses.read` | `catalogue.manage` |

Resulting navigation for the system roles: Super Admin and Admin see all seven sections; Operator Admin sees all but Cities; Operator Manager sees Trips, Buses, Routes, Locations and Bus types; Support sees Trips, Buses, Operators and Bus types, read-only.

The open section is part of the address and survives a page reload: while the session is checked the section travels as `?from=`, and the user lands on it again if their permissions still allow it. A section opened by address without its permission shows "No access" and makes no request. **This is presentation only.** The backend checks permission and data scope on every request, and the app shows its refusal when it happens.

## 6. Operator data isolation

- The app never filters by operator itself. Operator staff receive only their operator's records because the backend returns nothing else.
- The operator selector (as a list filter and as a form field) exists only for users whose data scope is `ALL`. Operator staff are never offered it and the app never sends an `operatorId` for them; the backend assigns their own.
- Locations show their owner: "Shared (platform)" or "Operator-owned". Shared locations have no edit or disable action for operator staff.
- The top bar states the scope: "All operators" or "Your operator".

## 7. Catalogue pages

Each page is one data surface: filters applied by the backend, a table, pagination (20 per page), an "Add" button and row actions, each shown only with its permission. Row actions are pinned at the trailing edge, so they stay on screen when the columns need to scroll sideways; on a phone each record is a block with its actions. While the first page loads the table shows its shape; an empty list says what to do next. Create and edit happen in a form dialog: required fields and number formats are checked in the form; everything else is checked by the backend, whose message is shown in the form, which stays open with what was typed. Enabling, disabling and status changes ask for confirmation. A saved change is confirmed and the list reloads.

| Page | Filters | Actions |
|---|---|---|
| Cities | name, status | add, edit, enable/disable |
| Bus types | status | add, edit, enable/disable |
| Operators | status | register, edit, change status (only the transitions the state machine allows are offered; a reason is required) |
| Locations | city, status | add, edit, enable/disable |
| Buses | operator (platform staff), status | add, edit, change status |
| Routes | operator (platform staff), status | add with stops, edit, enable/disable |
| Trips | operator (platform staff), status, travel date | create draft, view, edit draft, publish, cancel |

### Trips

The list shows the lifecycle status (`Draft`, `Scheduled`, `Cancelled`, `Arrived`, and the running states when trip operations exist). Only a draft can be edited. Fares are entered in rupees and sent in paise.

Opening a trip shows its details. A draft has no seats on sale, so its seats read "Not on sale yet" instead of a count. For a draft it also shows the **publishing requirements**:

| Requirement | Shown as |
|---|---|
| Operator is active; bus is active; bus has a seat capacity; route is active; boarding and dropping locations are active; departure is in the future | Met / Not met, read from the current records |
| Bus type is active; origin and destination cities are active; bus is free at this time | "Checked by the server on publishing" |

The list is an aid to see problems early. It is not a second implementation of the rules: the backend checks every requirement again on publishing and its answer is final. When it refuses, its reason is shown as given and the trip stays a draft. Publishing asks for confirmation; cancelling asks for a reason.

## 8. Not included, and known gaps

- **Two-step verification cannot be set up in the app.** With `MFA_REQUIRED_FOR_STAFF=true`, a new staff account cannot get past sign-in until this exists.
- **No user management.** Further administrators and all operator staff accounts cannot be created through the app (or any API) yet.
- **Operator staff cannot create routes or locations in the app.** Both need a city chooser, and the city list is platform catalogue (`catalogue.read`). The backend allows them to; the app needs a city search built on the public `GET /cities` first. They can create buses and trips.
- **Selectors list the first 100 records** (operators, buses, routes, locations, cities). Larger catalogues need a search-as-you-type selector.
- Travel date and time are typed as text (`YYYY-MM-DD`, `HH:mm`); the backend validates them.
- No detail pages for records other than trips; no audit trail viewer; no bulk actions or export.
- Three foundation files are duplicated from the customer app instead of shared.
- English only; the other seven languages fall back to English.
