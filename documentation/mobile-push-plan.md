# Mobile push notifications (plan)

Status: CODE DONE for the customer app on 2026-10-10 (Android + iOS wiring). NOT live until the Firebase files below are added and delivery is tested on real devices.
Do not mark live push complete until Android and iOS delivery are tested on real devices.

## Already built (reuse, do not duplicate)
- Backend: `push_tokens` store (platforms WEB/ANDROID/IOS), `POST /notifications/devices` and `/devices/remove`, `FcmPushProvider` (Firebase Admin SDK, server only), dead-token cleanup, per-channel retry, `NotificationDispatcher`.
- Flutter: `packages/shared_notifications` (`DevicePush`, `FirebaseDevicePush`, `NotificationCenter`, bell).
- Customer app Android package name: `com.abratravels.customer`.

## Work
1. Firebase config for Android (`google-services.json`) and iOS (`GoogleService-Info.plist`); native options in `shared_notifications` (today it only holds the web config + VAPID key).
2. Background/terminated delivery: background message handler, Android notification channel (FCM already sends title + body).
3. Wire `shared_notifications` into the customer app (and later operator/driver apps): permission prompt, denial handling with "turn on in settings", register token after sign-in, token refresh, remove token on sign-out.
4. Events: onboarding approval/rejection (done), booking updates, trip reminders (needs a scheduled job), important service alerts.
5. Delivery logging per channel (sent / failed / invalid token).
6. Tests: Flutter with a fake `DevicePush`; backend for new events and token cleanup.
7. Docs for iOS: `GoogleService-Info.plist`, APNs key uploaded to Firebase, Apple Developer account dependency.

## External requirements
- Firebase: register Android app `com.abratravels.customer`; download `google-services.json`.
- iOS: Apple Developer account, bundle ID, `GoogleService-Info.plist`, APNs key uploaded in Firebase (Project settings > Cloud Messaging).
- Server: Firebase service-account JSON at `backend/secrets/firebase-service-account.json` (git-ignored). Secrets (service account, APNs key) stay server-side/Firebase console, never in the Flutter apps or Git.


## What was built (2026-10-10)
- `shared_notifications`: `FirebaseDevicePush` now works on Android/iOS (reads the native Firebase file; the web options and VAPID key apply to the web only). `DevicePush` reports its `platform` (WEB/ANDROID/IOS) and `tappedRoutes` (a push the person tapped while the app was in the background or closed). `NotificationCenter` registers with that platform, exposes `routeOpens`, catches up on missed notifications on reconnect and on return to the app, and never throws at sign-out.
- Customer app: `AppDependencies.notifications`, started when signed in (`app_shell.dart`): bell, permission banner, toast for live arrivals, opens `/my-trips...` when a push is tapped. Stopped in the profile sign-out, while the session is still valid.
- Android: `POST_NOTIFICATIONS` permission, high-importance channel `high_priority_channel` (created in `MainActivity.kt`, named in the manifest and in the server's message), Google Services plugin applied only when `google-services.json` exists, so builds work without it.
- iOS: `UIBackgroundModes: remote-notification` in `Info.plist`.
- Server: pushes are high priority, kept for a day, and use the same channel.
- Background/closed delivery relies on the system showing the notification Firebase sends (title + body), so no custom background handler is needed.

## What only you can do (nothing below can be done in code)
1. Android: in the Firebase console (project `abra-travels`) add an Android app with package `com.abratravels.customer`, download `google-services.json` and put it at `apps/customer_app/android/app/google-services.json` (git-ignored; never commit it).
2. iOS (needs a Mac and an Apple Developer account): add an iOS app with the bundle ID in Firebase, download `GoogleService-Info.plist` into `ios/Runner/` via Xcode; in Xcode add the capabilities Push Notifications and Background Modes > Remote notifications; create an APNs key in the Apple developer site and upload it in Firebase > Project settings > Cloud Messaging.
3. Test on real devices: Android (app open, background, swiped away) and iPhone. Emulators without Google Play services cannot receive push.

## PENDING — real-device testing (agreed 2026-10-10: do after the development is finished)
Mobile push is code-complete but NOT verified. Still to do, in this order:
1. Add `apps/customer_app/android/app/google-services.json` (Firebase console > abra-travels > Add Android app, package `com.abratravels.customer`).
2. iOS (needs a Mac + Apple Developer account): `GoogleService-Info.plist`, Xcode capabilities (Push Notifications, Background Modes > Remote notifications), APNs key uploaded to Firebase.
3. Switch the backend to real push (`PUSH_PROVIDER=fcm` and the service-account path are already set in `backend/.env.development`) and restart the backend + worker.
4. Test on a real Android phone (or an emulator with Google Play services) and an iPhone: app open, app in background, app swiped away, tap opens `/my-trips...`, sign-out stops push, permission denied shows the hint.
5. Re-run backend e2e (`npm run test:e2e -- src/modules/notifications src/modules/onboarding`) and the customer app tests; look at the bell/banner in the customer app (no test covers the shell yet).
6. Decide whether to add a polling fallback (the Fleet app used 8 s polling as a safety net); today only reconnect/return-to-app catch-up exists.
Also pending from the user: SMTP login and WhatsApp (Meta) credentials/templates for the email/WhatsApp fallbacks; delete the original service-account key from Downloads.
