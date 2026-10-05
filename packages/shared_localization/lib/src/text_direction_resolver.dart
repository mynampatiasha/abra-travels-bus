import 'dart:ui';

/// Decides whether a locale is written right-to-left.
///
/// Flutter mirrors layouts automatically from the active locale through
/// `Directionality`; widgets must use start/end (not left/right) insets and
/// alignments so that mirroring works. This resolver is for the cases where
/// code needs the direction of a locale directly.
abstract final class TextDirectionResolver {
  /// Languages written right-to-left: Arabic, Persian, Hebrew, Urdu,
  /// Pashto, Sindhi, Uyghur, Yiddish, Dhivehi, Central Kurdish, Kashmiri,
  /// N'Ko, Syriac, Rohingya.
  static const Set<String> rtlLanguages = <String>{
    'ar',
    'fa',
    'he',
    'iw',
    'ur',
    'ps',
    'sd',
    'ug',
    'yi',
    'dv',
    'ckb',
    'ks',
    'nqo',
    'syr',
    'rhg',
  };

  /// Scripts written right-to-left; a script subtag overrides the language
  /// (for example `pa-Arab` is RTL although `pa` is not).
  static const Set<String> rtlScripts = <String>{
    'Arab',
    'Hebr',
    'Thaa',
    'Syrc',
    'Nkoo',
    'Adlm',
    'Rohg',
  };

  static const Set<String> _ltrScripts = <String>{'Latn', 'Cyrl', 'Deva'};

  static bool isRtl(Locale locale) {
    final script = locale.scriptCode;
    if (script != null) {
      if (rtlScripts.contains(script)) return true;
      if (_ltrScripts.contains(script)) return false;
    }
    return rtlLanguages.contains(locale.languageCode.toLowerCase());
  }

  static TextDirection of(Locale locale) =>
      isRtl(locale) ? TextDirection.rtl : TextDirection.ltr;
}
