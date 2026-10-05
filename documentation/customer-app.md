# Customer App

Flutter app for customers (Android and iOS), in `apps/customer_app`. This document describes what exists. Status of each milestone is in the table at the end; nothing is described as working unless it is.

## 1. Status

| Milestone | Scope | Status |
|---|---|---|
| 10A | Foundation: bootstrap, configuration, router, authentication gate, shell, theme, localization, error handling | Done (2026-10-05) |
| 10B | Sign-in, OTP, session handling screens | Not started |
| 10C–10K | Home, search, seats, booking, payment, trips, tracking, Women Safety, notifications, profile, hardening | Not started |

After 10A the app starts, checks a stored session, guards every route and switches language. **It has no customer feature yet.** Every screen except the splash, language and "not found" screens is a stand-in that states "Not available yet" and has no controls. Sign-in is one of those stand-ins, so nobody can sign in through the UI until 10B.

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
   - signed out → `/login` (remembering the requested location);
   - server not reachable → the splash screen shows the failure with a retry. The stored session is kept.

`RouteGuard` runs on every navigation and whenever the authentication state changes:

- only `/splash`, `/onboarding`, `/login`, `/otp` and `/language` are public; **every other location, including ones added later, requires a signed-in user**;
- a signed-out user is sent to `/login?from=<location>`; after sign-in the router opens `<location>`. Only in-app paths are accepted in `from`;
- when the server ends the session (expired, revoked, refresh failed), the session manager clears the tokens and the user is taken to `/login` from wherever they are;
- a signed-in user is not shown the sign-in screens.

The guard decides what is *shown*. It is not a security control: the backend authorizes every request.

Tokens are stored only by `shared_authentication` in the Keystore/Keychain (`shared_storage`), never in preferences, URLs or logs. Android backup is disabled for the app so session data does not leave the device.

## 6. Route map

| Location | Access | Screen in 10A | Delivered in |
|---|---|---|---|
| `/splash` | public | Splash (real) | 10A |
| `/language` | public | Language selection (real) | 10A |
| `/onboarding`, `/login`, `/otp` | signed-out only | stand-in | 10B |
| `/home` | signed in, shell tab | stand-in | 10C |
| `/search`, `/search/results`, `/bus/:id`, `/trip/:id` | signed in | stand-in | 10D |
| `/seats` | signed in | stand-in | 10E |
| `/passenger-details`, `/booking-review` | signed in | stand-in | 10F |
| `/payment`, `/booking-success`, `/ticket/:id` | signed in | stand-in | 10G |
| `/my-trips` (shell tab), `/my-trips/:id`, `/cancel-booking` | signed in | stand-in | 10H |
| `/live-tracking`, `/women-safety` | signed in | stand-in | 10I |
| `/support` (shell tab), `/profile` (shell tab), `/settings`, `/account-delete` | signed in | stand-in | 10J |
| anything else | — | "Not found" with a link to home | 10A |

Rules for the booking and payment flow (to be applied when those screens are built): a step that creates or changes server state is entered with `go`, not `push`, so that Back cannot return to it and repeat it; the flow's state comes from the backend booking, never from navigation arguments alone.

### Guest browsing (product decision, 2026-10-05)

Customers will be able to use the app without an account up to the point of booking:

1. the app opens; a guest can search buses, view trips, bus details and seat availability;
2. sign-in is required when the guest starts a booking action (selecting seats to hold, passenger details, payment, and everything about their own trips and profile).

This is **not implemented**. It is delivered with the screens it concerns (10C–10E), which need backend search and inventory endpoints that do not exist yet. Until then every location except the public ones above requires sign-in. When those screens are built, their locations (`/home`, `/search`, `/search/results`, `/bus/:id`, `/trip/:id`, seat viewing) are added to `AppRoutes.public`, the start-up redirect for a signed-out user changes from `/login` to `/home`, and the matching backend endpoints must be public as well. Seat locking and everything after it stays behind sign-in.

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

Existing and needed for 10B: the authentication endpoints of [authentication.md](authentication.md) (OTP send/verify, password sign-in, registration, MFA, logout, sessions).

**Not existing yet — these block the later milestones.** The backend currently contains authentication, users, sessions and RBAC only.

| Milestone | Missing backend capability |
|---|---|
| 10C Home | Cities/stops lookup, offers and banners (public, for guests), the customer's upcoming trip. **10C cannot start until these exist.** |
| 10D Search | Trip search with filters and sorting, bus/trip details, boarding and dropping points |
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
