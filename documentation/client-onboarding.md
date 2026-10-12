# Client (bus owner) onboarding

How a bus owner is checked and approved before anything of theirs can be sold. Agreed 2026-10-06. Nothing a client submits is live until a platform employee has reviewed and approved it.

## 1. Flow

```
Admin invites client ─► client signs in to the Client Portal ─► fills company profile + uploads documents
   ─► submits ─► PENDING ─► admin employee reviews every document
        ├─ all correct ─► APPROVED ─► operator / bus becomes ACTIVE
        └─ anything wrong ─► REJECTED, with a reason per document ─► client is notified
              ─► client fixes only the rejected items ─► resubmits ─► PENDING again
```

Two levels: the **company** (operator) is reviewed once; every **bus** is reviewed separately, so a new bus can be added later without redoing the company. A bus cannot be approved before its operator.

## 2. Parts and status

| # | Part | Status |
|---|---|---|
| 1 | Document types, managed by platform staff (backend + management app screen) | done 2026-10-06 |
| 2 | Files: private upload, type and size checks, authenticated download | done 2026-10-06 (S3 driver not yet tried against a real bucket) |
| 3 | Onboarding workflow: invite, submission, per-document review, status, history | done 2026-10-07 (backend; no screens yet) |
| – | Settings screen: WhatsApp + email (SMTP) credentials with connection tests ([settings-integrations.md](settings-integrations.md)) | done 2026-10-07 |
| 4 | Notifications: in-app real time, push when the app is closed, email / WhatsApp | not started |
| 5 | Management app: invite client, review queue, review screen | not started |
| 6 | Client Portal (separate Flutter web app, `apps/client_portal`) | not started |
| 7 | Full-flow test: invite → submit → reject with reason → notify → fix → resubmit → approve | not started |

## 3. Part 1: document types (done)

What a bus owner must upload is data, not code. Platform staff manage it in the management app (**Required documents**) with `documents.manage`; operator staff read the active list with `documents.read`.

Each type: `key` (permanent), `name`, `appliesTo` (`OPERATOR` or `BUS`, permanent), required or optional, has an expiry date, accepted file types (PDF, JPG, PNG), largest file (MB, 1–25), most files (1–10), instructions shown to the client, sort order, active.

- `GET /catalogue/document-types` — staff see every type (filters `appliesTo`, `active`); operator staff only ever get the active ones.
- `POST /catalogue/document-types`, `PUT /catalogue/document-types/:id`, `POST /catalogue/document-types/:id/active` — audited. Asking to change the key or `appliesTo` is refused.
- Types are disabled, never deleted, so past submissions stay readable. A changed rule applies to uploads from then on.
- First start fills an empty collection with a starting list (company: business registration, GST, PAN, owner ID, bank proof; bus: RC, permit, insurance, fitness, pollution (optional), photos). It never touches a collection that already has entries.

Code: `backend/src/modules/document-types/`, `apps/admin_app/lib/features/catalogue/pages/document_types_page.dart`.

## 3b. Part 2: files (done)

Backend module `backend/src/modules/files/`.

- `POST /files` (multipart: `file`, `documentTypeId`, and `operatorId` for platform staff) needs `documents.upload`. The file is checked against the document type it is uploaded for: the type must be active, the size within `maxFileSizeMb`, and the **real** type read from the file's first bytes (PDF, JPG, PNG) must be one the document type accepts. The declared type and the file name are never trusted. Nothing is stored for a refused upload.
- `GET /files/:id` and `GET /files/:id/content` need `documents.view`. Files belong to one operator: another operator's staff get "not found", platform staff can open any. The download is sent as an attachment, never cached, `nosniff`. Where the bytes live (storage key) is never sent to clients.
- Uploads go through the API (limit 25 MB, the largest any document type may allow), not pre-signed URLs; `documentation/api-architecture.md` keeps the 1 MB limit for JSON bodies.
- Storage is chosen by `STORAGE_DRIVER`: `local` (a folder, `STORAGE_LOCAL_ROOT`; development only, refused in production) or `s3` (any S3-compatible private bucket: AWS S3, Cloudflare R2, MinIO; needs `STORAGE_BUCKET`, `STORAGE_REGION`, `STORAGE_ACCESS_KEY`, `STORAGE_SECRET_KEY`, and `STORAGE_ENDPOINT` for non-AWS). The bucket must not be public.
- Not done yet, for step 3: a file is not yet attached to a submission, so abandoned uploads are not cleaned up; "most files per document" (`maxFiles`) is enforced when files are attached to a submission. Not done at all: virus scanning, upload rate limits.

## 3c. Part 3: the onboarding workflow (done)

Backend module `backend/src/modules/onboarding/`. Statuses, who may do what, and the effects.

**Invitation** (`operators.create`, platform staff; Super Admin and Admin)
- `POST /onboarding/invitations` `{ companyName, ownerName, email, phone? }` creates the company (`PENDING_APPROVAL`), its empty onboarding file, and emails the owner a link (`CLIENT_PORTAL_URL/accept-invite?token=...`) valid 7 days, usable once. Only a hash of the token is stored. If the email cannot be sent the invitation still exists (`emailStatus: FAILED`, `emailProblem`) and can be resent. Outside production the response also carries `inviteUrl` so a developer without a mail server can continue.
- `GET /onboarding/invitations`, `POST .../:id/resend` (new link, old one stops working), `POST .../:id/revoke`.
- Public: `POST /onboarding/invitations/inspect` `{token}` (company, owner, email for the sign-up page) and `POST .../accept` `{token, password, name?}`: creates the owner's account (OPERATOR_ADMIN of that company only). A bad, used, withdrawn or expired link is one answer: `RESOURCE_NOT_FOUND`.
- An address with an account, or already holding a pending invitation, cannot be invited.

**Onboarding files** (`/onboarding/submissions`): one per company (created at invitation) and one per bus (`POST` with `{busId}`). A bus an operator adds is `PENDING_APPROVAL` (platform staff add buses `ACTIVE`); trips can only be published for an `ACTIVE` bus, and an owner cannot activate a pending bus themselves.

```
DRAFT ──submit──► PENDING ──approve──► APPROVED   (company → ACTIVE / bus → ACTIVE)
  ▲                  │
  └──── fix & resubmit ◄── REJECTED ◄──reject──┘
```

| Action | Permission | Rules |
|---|---|---|
| list / open | `documents.view` | the owner sees only their own company's; with `status=PENDING` platform staff get the review queue, oldest first; the detail has the checklist (what is asked for and where each stands), `problems` (what blocks sending) and the history |
| `PUT .../documents/:typeId` `{fileIds, expiryDate?}`, `DELETE` | `documents.upload` | while DRAFT or REJECTED; files uploaded first with `POST /files` for the same type; at most the type's `maxFiles`; a file belongs to one submission; `expiryDate` (YYYY-MM-DD, not past) required for types that expire and refused for those that do not; after a rejection only rejected documents can change |
| `POST .../submit` | `documents.upload` | every required document in, none expired or still rejected (`VALIDATION_FAILED` lists what is missing); the company or bus must still await approval; resubmitting does not re-review approved documents |
| `POST .../documents/:typeId/review` `{decision, reason?}` | `documents.review` (sensitive; Super Admin, Admin) | only while PENDING; a rejection needs a reason (the owner reads it); can be changed until the file is decided |
| `POST .../approve` | `documents.review` | every document accepted and unexpired; no required document missing; a bus needs its company already approved; makes the company/bus live; audited |
| `POST .../reject` `{note?}` | `documents.review` | at least one document rejected with its reason and every document reviewed, so the owner sees everything to fix at once; audited |

Two people editing the same file at once cannot overwrite each other (changes are checked against the version read). Each submission keeps a history (created, submitted, each document decision, resubmitted, approved, rejected). Submit, approve and reject are audited and record `onboarding.submitted`, `onboarding.approved` and `onboarding.rejected` events in the outbox, for the notification engine (part 4); their payloads hold ids, the rejection note and the rejected documents' names and reasons, no secrets.

Not done: expiry reminders for documents that run out later (a job), clean-up of uploaded files that never reach a submission, and the screens (parts 5 and 6).

## 4. Notifications (part 4) — must also work when the app is closed

Three layers, because the portal will not always be open:

1. **Socket.IO** (inside the NestJS backend, free): instant update while the portal is open. The notification is stored first; the socket only tells the open page to refresh, so a dropped connection loses nothing.
2. **Push (Firebase Cloud Messaging, free):** browser/phone push when the portal is closed. Needs a Firebase project and a web push key.
3. **Email and WhatsApp:** the guaranteed fallback, sent from the background queue so a provider failure never blocks a review.

Approval and rejection (with the reason) trigger all three.

## 4. Notifications (live, push, email, WhatsApp)

The in-app list (`notifications` collection) is the record. The worker sends each event on four channels: Socket.IO (live, while the app is open), FCM push (works with the app closed; needs `backend/secrets/firebase-service-account.json` and `web/firebase-messaging-sw.js`, present in both web apps), email (Settings > Email) and WhatsApp (Settings > WhatsApp, template with two body params). Failed channels are retried alone; a notification is never duplicated per (user, event).

## 5. Screens

- Management app: Invitations, Reviews (queue + detail with per-document accept/reject and reasons), Required documents, Settings (icon cards: WhatsApp, Email, with test buttons).
- Client portal (`apps/client_portal`, serve on http://localhost:5000, matches `CORS_ALLOWED_ORIGINS` and `CLIENT_PORTAL_URL`): accept invitation, dashboard (company state, buses), documents checklist (upload, expiry, send for review, rejection reasons).

Build and serve locally:

    flutter build web --profile --dart-define=ABRA_ENV=development --dart-define=ABRA_API_BASE_URL=http://localhost:4000
    python -m http.server 5000   (from build/web; admin app uses 3000)
