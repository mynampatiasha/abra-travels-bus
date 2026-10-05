import 'dart:ui';

/// Conversion between BCP-47 language tags (`en`, `en-IN`, `zh-Hant-TW`)
/// and [Locale]. Tags are how locales are stored, sent to the server
/// (`Accept-Language`) and named in resource files.
abstract final class LocaleTags {
  static final RegExp _language = RegExp(r'^[a-zA-Z]{2,3}$');
  static final RegExp _script = RegExp(r'^[a-zA-Z]{4}$');
  static final RegExp _region = RegExp(r'^([a-zA-Z]{2}|\d{3})$');

  /// Parses a BCP-47 tag (`-` or `_` separated). Returns null for anything
  /// that is not `language[-Script][-REGION]`. Further subtags (variants,
  /// extensions) are ignored.
  static Locale? tryParse(String? tag) {
    if (tag == null || tag.trim().isEmpty) return null;
    final parts = tag.trim().replaceAll('_', '-').split('-');
    if (!_language.hasMatch(parts.first)) return null;

    String? script;
    String? region;
    for (final part in parts.skip(1)) {
      if (script == null && region == null && _script.hasMatch(part)) {
        script = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      } else if (region == null && _region.hasMatch(part)) {
        region = part.toUpperCase();
      } else {
        break;
      }
    }
    return Locale.fromSubtags(
      languageCode: parts.first.toLowerCase(),
      scriptCode: script,
      countryCode: region,
    );
  }

  /// The BCP-47 tag of [locale]: `en`, `en-IN`, `zh-Hant-TW`.
  static String of(Locale locale) => locale.toLanguageTag();

  /// The form used in resource file names and by `package:intl`:
  /// `en`, `en_IN`, `zh_Hant_TW`.
  static String underscored(Locale locale) => of(locale).replaceAll('-', '_');
}
