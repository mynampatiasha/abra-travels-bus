# Multilingual Architecture

Languages at launch: English (`en`, default), Kannada (`kn`), Telugu (`te`), Hindi (`hi`), Tamil (`ta`), Malayalam (`ml`), Marathi (`mr`), Bengali (`bn`). Adding a language = a row in `languages` + translation files; no code change.

## Flutter

- `packages/shared_localization` holds ARB files (`app_en.arb`, `app_kn.arb`, ...) generated with `flutter gen-l10n`.
- Runtime overrides: on start the app fetches `GET /translations?namespace=app&language=kn&since=<version>` and layers admin-edited strings over the bundled ARB values (cached locally). Missing key → English → missing key logged once.
- No user-facing string literals in widgets; a `custom_lint` rule flags literals inside `Text()`.
- Selected language is saved on the user (`preferredLanguage`) and locally for guests. Changing it rebuilds the app immediately.
- Fonts: Noto Sans subsets for each script.

## Backend

- `Accept-Language` or user preference → `RequestContext.language`.
- API error messages, notification templates, ticket PDF, WhatsApp replies and CMS content are language-keyed.
- City names, content pages and banner titles store `translations: { kn: ..., te: ... }`.

## Next.js public website

Locale routes such as `/kn/bus-tickets/bengaluru-to-tirupati`, with `hreflang` alternates and localized metadata.

## Admin

Languages screen (activate, set default), translation editor with search, missing-translation report per language, CSV import/export — permission `languages.manage`.
