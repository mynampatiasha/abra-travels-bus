# Admin question-based KYC configuration

Open **KYC configuration** in the management app. One frontend feature file contains the Questions and Document rules tabs, forms, filters, bulk tools and preview. One backend feature file contains the schemas, validation, configuration service, controller and checklist evaluator.

Frontend: `apps/admin_app/lib/features/kyc/admin_kyc_configuration.dart`.
Backend: `backend/src/modules/system-settings/admin_kyc_configuration.ts`.

## Administration

1. Create the document types in **Required documents**. That existing catalogue owns upload formats, size and file-count limits, expiry requirements and instructions.
2. Create questions for the company or an individual bus. Supported types: choose one answer, choose several answers, and yes/no. Type each option in its own field, using Add option and Remove option. Internal identifiers are generated automatically, and existing option identities are retained when labels are edited. New questions are added at the end; admins do not type technical keys or `value | label` syntax.
3. Add a document rule for the same subject. Select an existing document, mark it required or optional, and add conditions based on question answers. Multiple conditions use AND or OR. Each condition matches any of its selected answers. A rule without conditions always shows its document.
4. Use **Preview checklist**, select answers and request the checklist. The backend returns applicable documents and unanswered required questions. A required matching rule takes precedence over optional matching rules for the same document; documents appear once. Inactive documents and rules are excluded.

Deleting a question referenced by any rule is refused; remove its dependent rules first. Disable active dependent rules before disabling a question. Existing question and rule keys cannot be edited through the forms. Editing referenced options is checked against the rules on the backend.

The page supports text search, company/bus, active/inactive and required/optional filters. Rules also have a document filter. Lists are paged in groups of ten.

## Import and export

**Export configuration** downloads all questions and rules as Excel (.xlsx) or CSV, regardless of current filters. Cells contain readable question text, answer labels and document names. Runtime version, credentials and internal keys are not exported.

**Import configuration** has two steps: download the Excel sample, then upload the completed .xlsx or .csv file (up to 2 MB). Keep its column headings. Use a Question row for each question and a Document rule row for each answer condition; rules with several conditions repeat the same rule name and settings. Document names must exist in Required documents. Separate condition answers with semicolons. The form shows a readable preview, reports row-level parsing errors, and validates references on the backend. Explicitly confirm replacement before saving. Import replaces the complete configuration in one audited transaction; invalid input changes nothing. Matching existing question/option/rule labels reuse their internal identities.

## Customer directory

The admin **Customers** section uses the existing scoped `GET /users?userType=CUSTOMER` API and `users.read` permission. It offers name/email/phone search, status and registered-login-method filters, paged contact cards, a details dialog, and Excel/CSV export of all matching customers. It shows registration and last sign-in times. Login methods are registered account capabilities, not a per-login audit history; missing values are shown explicitly. Credentials, tokens, Firebase identities and MFA secrets are never returned. This directory does not import authentication accounts.

## Project UI requirements agreed with the user

Use readable forms for nontechnical people, inspired by the supplied `hr-OJE.php` option builder. Generate technical identifiers internally. Keep layouts responsive and uncluttered. Include search, filters and export where meaningful. Whenever bulk import is applicable, offer an Excel sample followed by Excel/CSV upload, a readable preview, validation and confirmation. Do not expose raw JSON as a normal input form.

Maximums: 100 questions, 500 rules, 20 options per question, and 10 conditions per rule.

## API and access

All routes use the existing JWT/session, request validation, error envelope and RBAC:

| Method | Path below `/api/v1` | Permission |
|---|---|---|
| GET | `/settings/kyc-configuration` | `documents.read` |
| PUT | `/settings/kyc-configuration` | `documents.manage` |
| POST | `/settings/kyc-configuration/validate-import` | `documents.manage` |
| POST | `/settings/kyc-configuration/preview` | `documents.read` |

These administration routes require a platform staff account; operator accounts are refused even if they hold document permissions. Read-only staff can view, export and preview, but cannot create, edit, delete or import.

PUT and import validation receive the configuration plus `expectedVersion` and a change `reason`. PUT checks the stored revision in a transaction, increments it and writes the audit entry together. A stale edit returns HTTP 409; refresh before retrying so another administrator's work is not overwritten. The singleton uses a fixed MongoDB `_id` and is stored in `kyc_configuration`.

## Integration boundary

The client Google onboarding journey now consumes the server evaluator through `backend/src/modules/onboarding/client_kyc.ts`. Required answers and document rules are enforced, submissions preserve their question/answer/requirement snapshot, and backend access remains gated until platform approval. See [Google and client KYC flow](google-client-kyc-flow.md) for setup, credential requirements and verification.

## Verification

- Backend unit tests: matching conditions, optional/required precedence, missing and malformed answers, invalid references, import validation, platform-only access, revisions and audit behavior.
- HTTP integration tests: real authentication/RBAC, MongoDB persistence, preview, invalid imports, concurrent edits and deletion in a disposable test database.
- Flutter tests: question/rule CRUD, filters, pagination, JSON import/export, preview, read-only/operator restrictions, and desktop/mobile layout.
