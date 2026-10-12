# Google sign-in and client verification

The applications are Flutter. Firebase Google authentication supplies an ID token; the backend verifies it and issues the existing Abra access token, refresh cookie/token and session. Password login, WhatsApp OTP, MFA, refresh, logout and RBAC remain in use.

## Customer and client journeys

- Customer: Continue with Google or Apple on the same sign-in form as WhatsApp OTP → normal customer account. Customers do not need company KYC.
- Client: Continue with Google → welcome/introduction → company name and admin-defined questions → conditional required/optional document checklist → upload documents → submit → under verification.
- Admin: a floating notification and inbox entry open the submission in Reviews. The review contains the KYC answer snapshot and document checklist. Review each document, then approve or reject the submission.
- Approval: the company becomes ACTIVE, the existing client session can access account features, and the owner receives the decision notification. Rejection includes document reasons and permits correction/resubmission.

Pending clients can use their own KYC, submissions, files, notifications and account/session endpoints. Other account APIs are blocked on the backend even if a user enters a dashboard URL manually. Only platform staff with review permission can decide KYC. Existing ACTIVE companies retain their approved access.

## Requirements and snapshots

Configure **Required documents** and **KYC configuration** in the admin app before clients start KYC. Company questions use the OPERATOR subject. The client saves answers on the server; the server computes the matching document requirements. Missing required answers and unavailable document rules block progression.

A submission keeps its initial configuration version, question definitions, answers and resulting requirements. Later configuration changes apply to future KYC starts, preserving the documents already being reviewed. Rejected submissions keep their submitted answers while the owner corrects rejected documents.

The new client questionnaire covers company verification. The existing separate bus onboarding remains available after company approval.

## Feature files

- Customer Google button: `apps/customer_app/lib/features/authentication/gate/sign_in_flow.dart` (existing OTP form).
- Client Google button: existing `apps/client_portal/lib/features/auth/sign_in_screen.dart`.
- Shared popup/provider UI: `packages/shared_authentication/lib/src/google_sign_in_button.dart`; token exchange uses existing AuthApi/AuthSessionManager.
- Client KYC screen: `apps/client_portal/lib/features/onboarding/client_kyc_based_screen.dart`.
- Client KYC backend: `backend/src/modules/onboarding/client_kyc.ts`.
- Google backend: `backend/src/modules/authentication/google_sign_in.ts`.
- Admin configuration: existing `admin_kyc_configuration.dart` and `admin_kyc_configuration.ts`.
- Notification screens: `client_notification_screen.dart` and `admin_notification_screen.dart` in their respective app's `features/notifications` directory.
- Onboarding notification backend: `backend/src/modules/notifications/notifications.ts`, reusing the existing persistence, dispatcher, realtime socket, push and queue infrastructure.

Routing, module registration, models and existing review/submission services connect these feature files to the application.

## Google and Apple setup

Flutter public configuration uses `--dart-define` values:

```text
ABRA_FIREBASE_API_KEY
ABRA_FIREBASE_AUTH_DOMAIN
ABRA_FIREBASE_PROJECT_ID
ABRA_FIREBASE_STORAGE_BUCKET
ABRA_FIREBASE_MESSAGING_SENDER_ID
ABRA_FIREBASE_APP_ID
ABRA_GOOGLE_SERVER_CLIENT_ID (native Google OAuth client)
```

The local ignored `build/google-sign-in-defines.json` contains the public web identifiers supplied for this project, plus the development API URL. Launch an app with:

```powershell
flutter run -d web-server --web-hostname localhost --web-port 5000 --dart-define-from-file=../../build/google-sign-in-defines.json
```

Apple sign-in also requires enabling the Apple provider in Firebase, configuring its Apple Developer service ID/keys and redirect URLs, and enabling Sign in with Apple capability for iOS. See [Firebase federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth).

Use port 3000 for admin and 5001 for customer. Enable Google in Firebase Authentication and authorize the development domain `localhost`. Production requires the real hosted domains and HTTPS. Android/iOS also require their registered Firebase app IDs, OAuth configuration, Android signing fingerprints and iOS URL schemes; web identifiers alone do not configure native builds.

Backend configuration:

```text
FIREBASE_PROJECT_ID=abra-travels
FCM_SERVICE_ACCOUNT_JSON=<absolute path to the real Firebase service-account JSON>
```

Alternatively use application-default credentials through `GOOGLE_APPLICATION_CREDENTIALS`. The backend verifies signature, audience/project, expiry, revocation, Google provider and verified email. Credentials are loaded server-side only. Service-account files and real environment files are ignored by Git.

At implementation verification, the project credential setting was empty and no service-account file or application-default credentials were found in the checked local locations. Live Google exchange and real device push require the actual credential file. Integration tests replace only the external Firebase verifier with a controlled verified identity; the application's HTTP authentication, sessions, MongoDB, Redis, KYC, approval and notification services run normally.

## Account linking

A linked Firebase UID signs into the same user. An existing local email account must prove its current Abra password before Google is linked; MFA remains required when enabled. A verified email alone never merges accounts. Accounts without a local password must sign in through their existing method and contact support for linking. Disabled users are refused.

The existing user collection has one unique email and one user type per account. Google cannot silently change a customer into client/staff, or vice versa. A request for a different app audience is refused. Roles and profile fields supplied by the frontend are rejected.

## Notifications

Run both backend API and worker. The worker relays stored outbox events to the notification handler; notifications are stored before live/push/channel delivery. Reviewer messages target platform staff who can review; decisions target the relevant company's owners. Inboxes support search, unread filtering, mark-as-read and device notification permission.

```powershell
npm run start:prod
npm run worker:prod
```

`GET /health/ready` reports connected queue workers. Browser/device push needs permission, Firebase service-account credentials, a configured FCM provider and the project's web-push/service-worker setup. Stored inbox notifications and live socket alerts remain separate from push delivery. Clients refresh verification status on live notifications and while waiting for review.

## Endpoints

- `POST /api/v1/auth/google`: ID token, CUSTOMER/CLIENT audience, accepted terms, device metadata, optional existing password for account linking.
- `POST /api/v1/auth/apple`: verified Apple Firebase ID token, customer audience and the same session/device rules.
- `GET /api/v1/client/kyc`: the authenticated client's company, verification status and question snapshot.
- `PUT /api/v1/client/kyc`: company name, introduction acceptance and answers.
- Existing onboarding submission/file/review/notification APIs perform uploads, submission, decisions and notification/device management.

## Verification

Tests cover Google popup success/cancellation/blocking, shared session exchange, customer OTP coexistence, introduction/questions, client approval navigation, conditional required/optional documents, API gate bypass attempts, admin review, notification destinations, safe linking, disabled users and duplicate identity prevention. Existing authentication, session, onboarding, notification and admin configuration regression suites were also run.

For local testing, use separate browser profiles for client, customer and admin: browsers share cookies across localhost ports.

To verify with a real Google account: configure the real service-account path, keep API and worker running, create admin questions/document rules, open the client app, accept the terms, choose Google, complete KYC, and submit. Open the admin notification, review/approve, then check the client's notification and account access. Repeat with a customer account to confirm normal customer access without company KYC.

## Client login methods

The client sign-in page has compact Google, Apple and WhatsApp-phone actions alongside email/phone + password. Google and Apple exchanges send CLIENT audience. WhatsApp codes are sent through the existing OTP delivery service; `/auth/client/otp/verify` consumes the code and registers only a pending operator owner on first use. Customer OTP endpoints retain their existing account types.

Every new client company starts with a mandatory company KYC draft. All sign-in methods use the same session issuer and company status gate. An approved company's account is never duplicated or re-submitted just because a linked login method is used.

After signing in, open **Login methods** in the portal header. Verify a WhatsApp code to link a phone; complete the provider popup to link Google or Apple; set a password using the existing password-management endpoint. Accounts already owned by another user cannot be merged through this dialog. Link a new phone before attempting phone sign-in, otherwise an unrecognised phone represents a new client registration. Apple private relay emails can be linked from the signed-in account without replacing its existing email. Each provider identity is stored separately, and linking never changes operator ID, roles or approval.

Apple still requires enabling/configuring the provider in Firebase and Apple Developer; automated tests control the external identity verifier rather than authenticating an Apple account.
