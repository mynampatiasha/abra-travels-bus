# Multilingual Architecture

Languages at launch: English (`en`, default), Kannada (`kn`), Telugu (`te`), Hindi (`hi`), Tamil (`ta`), Malayalam (`ml`), Marathi (`mr`), Bengali (`bn`). Adding a language = a row in `languages` + translation files; no code change.

## Flutter

- `packages/shared_localization` holds ARB files (`l10n/app_en.arb`, `app_kn.arb`, ...). They are loaded at runtime (not `gen-l10n`), so a language is added as data: an ARB file plus an entry in `AbraLocaleConfig`. Any BCP-47 locale is accepted (script and region included); layout direction (RTL/LTR) follows the locale.
- Lookup order per key: region (`es-MX`) → language (`es`) → English. English is complete; the seven other launch languages currently ship without translations and show English until reviewed translations are supplied (no machine-made text is bundled).
- Keys are constants in `AbraStrings`; tests keep them identical to `app_en.arb` and reject unknown keys or changed placeholders in other languages.
- Translations are display text only. Permissions, roles, prices, booking and payment state always come from the backend as language-independent keys and values.
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
