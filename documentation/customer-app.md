# Customer App

Flutter app for customers (Android and iOS), in `apps/customer_app`. This document describes what exists. Status of each milestone is in the table at the end; nothing is described as working unless it is.

## 1. Status

| Milestone | Scope | Status |
|---|---|---|
| 10A | Foundation: bootstrap, configuration, router, authentication gate, shell, theme, localization, error handling | Done (2026-10-05) |
| 10B | Sign-in with mobile number and one-time code, session handling, sign-out | Done (2026-10-05). Google and Apple sign-in: not built, blocked on backend |
| 10C | Discovery: home search form, city picker, travel date, search results with day switching, filters and sorting, trip details with boarding and dropping points; guest browsing ([discovery.md](discovery.md)) | Done (2026-10-06). No catalogue data can be entered yet |
| 10E–10K | Seats, booking, payment, trips, tracking, Women Safety, notifications, profile, hardening | Not started |

After 10C anyone can open the app, search buses between two cities on a date, filter and sort the results and open a trip, without signing in; a customer can sign in with a mobile number and a one-time code, stay signed in across restarts, and sign out. **Searching returns nothing on a real database yet, because the APIs that enter cities, buses and trips do not exist** (see [discovery.md](discovery.md)). Booking does not exist: trip details say so. My trips and Support, and every screen of the later milestones, are stand-ins that state "Not available yet" and have no controls. The Profile section shows who is signed in, the language setting and sign-out only.

## 2. Structure

```
apps/customer_app/
├── l10n/customer_<locale>.arb        App messages (English complete; 7 languages empty → English)
├── lib/
│   ├── main.dart
│   ├── bootstrap/
│   │   ├── bootstrap.dart            Start-up order: error handlers → configuration → services → runApp
│   │   ├── customer_environment.dart --dart-define values → validated AppConfig
│   │   ├── app_dependencies.dart     The long-lived services (one place; tests swap storage and HTTP)
│   │   └── error_handling.dart       Global error handlers, fallback for a widget that fails to build
│   ├── app/
│   │   ├── customer_app.dart         MaterialApp.router + Abra theme + localization
│   │   ├── providers.dart            Riverpod: dependencies, auth state mirror, start-up controller
│   │   └── startup_failure_app.dart  Shown when the app cannot start at all
│   ├── routing/
│   │   ├── app_routes.dart           All locations; which are public
│   │   ├── route_guard.dart          Pure redirect rules
│   │   └── customer_router.dart      go_router configuration
│   ├── shell/app_shell.dart          Signed-in frame: bottom bar (phone) / side rail (tablet+)
│   ├── core/async_value_view.dart    Loading / failure / data for anything loaded from the backend
│   ├── l10n/customer_strings.dart    Message keys
│   └── features/
│       ├── startup/                  Splash screen
│       ├── language/                 Language selection
│       └── unavailable/              "Not available yet" stand-in, "not found" screen
└── test/
```

Features are added under `features/<name>/` with `screens/`, `widgets/`, `controllers/` (Riverpod notifiers), `repositories/` (call the API through `shared_network`) and `models/`, as in [project-structure.md](project-structure.md). Widgets do not call the API and controllers do not build widgets.

**State management:** Riverpod. The shared packages own the long-lived state (`AuthSessionManager`, `LocaleController`); providers expose it and feature controllers are `Notifier`s. There is no second copy of the authentication state: `authStateProvider` mirrors the session manager.

**Dependencies added by the app:** `flutter_riverpod`, `go_router`. Everything else comes from the shared packages.

## 3. Application identifiers

| Platform | Identifier |
|---|---|
| Android application ID (and namespace) | `com.abratravels.customer` |
| iOS bundle ID | `com.abratravels.customer` (tests: `com.abratravels.customer.RunnerTests`) |

These are the production identifiers and must not change once the app is published. The Dart package and folder remain `customer_app`.

## 4. Configuration

Passed at build time with `--dart-define`. Only public values; no secret is compiled into the app.

| Name | Values | Notes |
|---|---|---|
| `ABRA_ENV` | `development` (default), `test`, `staging`, `production` | |
| `ABRA_API_BASE_URL` | Origin of the backend, e.g. `https://api.example.com` | Required outside development |

Rules enforced at start-up (an invalid build shows the start-up failure screen and logs the reason):

- staging and production require HTTPS;
- a release build requires HTTPS in every environment;
- development without a URL uses the backend on the developer machine: `http://10.0.2.2:4000` on the Android emulator, `http://localhost:4000` on the iOS simulator.

Plain HTTP is allowed by the platforms only for that case: Android debug builds (`src/debug/AndroidManifest.xml`) and local-network addresses on iOS (`NSAllowsLocalNetworking`).

## 5. Start-up and authentication gate

1. `bootstrap` installs the error handlers, validates the configuration, opens storage and creates the services.
2. The app shows the splash screen and asks the shared session manager to restore the session (`GET /api/v1/me` when tokens are stored; no request otherwise).
3. The router leaves the splash screen when the result is known:
   - signed in → the location that was requested, or `/home`;
   - signed out → the public location that was requested, otherwise `/home` as a guest; a personal location leads to `/login` (remembering it);
   - server not reachable → the splash screen shows the failure with a retry. The stored session is kept.

`RouteGuard` runs on every navigation and whenever the authentication state changes:

- public for everyone, signed in or not: `/splash`, `/language`, `/home`, `/search`, `/search/city`, `/search/results`, `/trip/:id` and the sign-in screens. **Every other location, including ones added later and anything below `/trip/:id/`, requires a signed-in user**;
- a signed-out user is sent to `/login?from=<location>`; after sign-in the router opens `<location>`. Only in-app paths are accepted in `from`;
- when the server ends the session (expired, revoked, refresh failed), the session manager clears the tokens and the user is taken to `/login` from wherever they are;
- a signed-in user is not shown the sign-in screens.

The guard decides what is *shown*. It is not a security control: the backend authorizes every request.

Tokens are stored only by `shared_authentication` in the Keystore/Keychain (`shared_storage`), never in preferences, URLs or logs. Android backup is disabled for the app so session data does not leave the device.

### Sign-in (10B)

1. **Mobile number** (`/login`). India (+91) is the only country offered; a country is one entry in `SignInCountry.supported` plus the backend's phone rules. The number is checked on the device, then `POST /auth/otp/send`. The button shows progress and ignores further taps; when the backend asks to wait, the button stays disabled for that time and shows the countdown.
2. **Verification code** (`/otp`). The screen says where the code went (WhatsApp, or SMS when the backend fell back) and shows the number masked. The code is verified by `POST /auth/otp/verify`; a new account is created by the backend on first sign-in. Resend is offered only after `resendAfterSeconds`; expiry follows `expiresInSeconds`. Both countdowns are computed from the clock and the server's values, so they stay correct after the app was in the background.
3. On success the shared session manager stores the tokens in secure storage and the router opens the screen the customer was heading to (the `from` location survives both steps and "Change number").

The app never generates, stores or logs the code: it exists in the input field until it is submitted. The sign-in state is kept in memory only, so after the app is closed the customer starts again from the number.

Messages shown for failures: incorrect code, expired code, too many attempts (rate limit or lockout, with the wait), account cannot use this app, account disabled, code could not be sent, no connection, timeout, service problem. Server text is never shown.

Not supported yet: accounts with two-step verification (customers cannot enable it today; the app says so instead of failing silently), password sign-in, the profile step of registration (name, e-mail, terms and marketing consent — the backend creates the account from the phone alone), and links to the terms and privacy policy (those pages do not exist yet and are required before store submission).

The requested `authenticating / refreshing / error` states exist as: `AuthUnknown`, `AuthSignedOut`, `AuthSignedIn` in the shared session manager (the only owner of the session), plus `isSending` / `isVerifying` / `problem` in the sign-in controller. Token refresh is invisible to the UI and handled inside the shared API client.

**Sign-out** (Profile → Sign out, with confirmation) calls `POST /auth/logout` and always clears the session on the device, also when the server cannot be reached or already ended the session.

## 6. Route map

| Location | Access | Screen in 10A | Delivered in |
|---|---|---|---|
| `/splash` | public | Splash (real) | 10A |
| `/language` | public | Language selection (real) | 10A |
| `/login`, `/otp` | signed-out only | Mobile number, verification code (real) | 10B |
| `/onboarding` | signed-out only | stand-in (no content defined yet) | — |
| `/home` (shell tab), `/search` | public | Search form (real) | 10C |
| `/search/city`, `/search/results`, `/trip/:id` | public | City picker, results, trip details (real) | 10C |
| `/bus/:id` | signed in | stand-in (not used; trips are opened at `/trip/:id`) | — |
| `/seats` | signed in | stand-in | 10E |
| `/passenger-details`, `/booking-review` | signed in | stand-in | 10F |
| `/payment`, `/booking-success`, `/ticket/:id` | signed in | stand-in | 10G |
| `/my-trips` (shell tab), `/my-trips/:id`, `/cancel-booking` | signed in | stand-in | 10H |
| `/live-tracking`, `/women-safety` | signed in | stand-in | 10I |
| `/profile` (shell tab) | signed in | Who is signed in, language, sign-out (real); the rest in 10J | 10B / 10J |
| `/support` (shell tab), `/settings`, `/account-delete` | signed in | stand-in | 10J |
| anything else | — | "Not found" with a link to home | 10A |

Rules for the booking and payment flow (to be applied when those screens are built): a step that creates or changes server state is entered with `go`, not `push`, so that Back cannot return to it and repeat it; the flow's state comes from the backend booking, never from navigation arguments alone.

### Guest browsing (implemented in 10C)

Customers use the app without an account up to the point of booking:

1. the app opens on Home; a guest can search buses, see the results and open a trip;
2. sign-in is required for personal sections (My trips, Support, Profile) and for every booking step. The location the guest was heading to is kept through sign-in.

A session that ends on the server while the customer is on a public screen leaves them there as a guest; the notice appears when they next reach sign-in. Seat viewing, seat locking and everything after them are not built; when they are, seat viewing joins the public locations and seat locking stays behind sign-in.

## 7. Errors and offline behaviour

- **Uncaught errors** (framework, platform, async) are logged with their type and stack trace only. Messages are not logged because they can contain user input or server data. A widget that fails to build is replaced by a neutral box in release builds.
- **Backend data** is shown through `AsyncValueView`, which renders exactly one of: loading, the failure state for the kind of failure (no connection, timeout, server problem, no access, not found, too many attempts, session ended), or the data. Retry appears only when retrying can help. Server error text is never shown; the request reference is.
- **No connectivity plugin** is used. Whether the network works is learned from the request that fails, which is also the only reliable signal.
- No crash-reporting service is connected yet. When one is chosen it plugs into `reportError`.

## 8. Localization, theme, accessibility

- Messages: `AbraStrings` (shared) and `CustomerStrings` (app), from ARB files merged at start-up. No screen contains literal text. English is complete; Hindi, Telugu, Kannada, Tamil, Malayalam, Marathi and Bengali have no reviewed translations yet and show English.
- The language follows the device until the user chooses one on `/language`; the choice is stored on the device and sent to the backend as `Accept-Language`. Layout direction follows the language.
- Theme: `AbraTheme.light()` from `shared_theme`; the app defines no colours of its own.
- Layout: `AbraPageContainer` and `AbraBreakpoint` (bottom bar below 600 px, side rail from 600 px).
- Accessibility checks in the tests: Android and iOS tap-target size, labelled tap targets, text contrast, 2× text on a 320 px wide screen, rotation.

## 9. Permissions

| Permission | Platform | Why | When requested |
|---|---|---|---|
| `INTERNET` | Android | Talk to the backend | Install time (not a runtime permission) |

Nothing else is declared in 10A and nothing is requested at start-up. Location, camera and notification permissions are added with the feature that needs them, requested in context with an explanation, and listed here.

## 10. Backend dependencies

Existing and used in 10A: `GET /api/v1/me`, `POST /api/v1/auth/refresh` (through the shared session manager).

Existing and used in 10B: `POST /auth/otp/send`, `POST /auth/otp/verify`, `POST /auth/logout`.

Missing for sign-in: `POST /auth/google` and `POST /auth/apple` (see [authentication.md](authentication.md) §7). Until they exist the app offers the mobile number only.

**Not existing yet — these block the later milestones.** The backend currently contains authentication, users, sessions and RBAC only.

| Milestone | Missing backend capability |
|---|---|
| Catalogue data | Admin APIs for cities, locations and bus types; operator APIs for buses, routes and trips; trip publishing. **Until these exist, search has nothing to return.** |
| Home extras | Offers and banners, the customer's upcoming trip |
| 10E Seats | Seat layout and availability, seat locks with server expiry, real-time seat updates |
| 10F Booking | Passenger rules, fare quote, coupons, booking creation |
| 10G Payment | Payment order, verification/webhook result, booking confirmation, ticket and QR payload |
| 10H Trips | Booking list and details, cancellation policy and quote, cancellation, refund status |
| 10I Tracking and safety | Live-tracking socket, SOS, emergency contacts, trip sharing |
| 10J Notifications and profile | Device registration and push delivery, notification preferences, profile update, account deletion, support |

Each of those milestones stops at this boundary until its endpoints exist; the app will not ship invented contracts or fixture data.

## 11. Not verified yet

- Running on a device or emulator: none is available on the development machine. The Android debug build succeeds and the widget tests start the real app.
- The iOS build: not run, macOS is required; development is on Windows.
- Release signing is not configured and nothing has been uploaded to a store.
- App icon and launch screen are the Flutter defaults.
