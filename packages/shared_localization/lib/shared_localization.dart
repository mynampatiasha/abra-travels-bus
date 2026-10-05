/// Localization for every Abra Travels app.
///
/// Languages are data, not code: a language is added by registering its
/// locale in [AbraLocaleConfig] and supplying a translation resource. No
/// screen or business rule changes. Text that has no translation yet falls
/// back along the chain `exact locale → language → default locale`.
///
/// Translations only ever change wording. They never decide permissions,
/// prices, booking rules, payments or anything security related.
library;

export 'src/abra_formatters.dart';
export 'src/abra_locale_config.dart';
export 'src/abra_localizations.dart';
export 'src/abra_strings.dart';
export 'src/locale_controller.dart';
export 'src/locale_tags.dart';
export 'src/message_formatter.dart';
export 'src/text_direction_resolver.dart';
export 'src/translation_source.dart';
