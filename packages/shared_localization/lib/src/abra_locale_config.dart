import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'locale_tags.dart';

/// A language offered in the language picker.
@immutable
class SupportedLanguage {
  const SupportedLanguage(this.locale, this.nativeName);

  final Locale locale;

  /// The language's own name for itself, shown in the picker as is
  /// (never translated): "हिन्दी", "العربية", "Español".
  final String nativeName;

  String get tag => LocaleTags.of(locale);
}

/// Which languages an app offers and how a locale is chosen.
///
/// The list is plain data: adding Spanish, Arabic or Chinese means adding a
/// [SupportedLanguage] and a translation resource. Any BCP-47 locale works,
/// with or without script and region.
@immutable
class AbraLocaleConfig {
  AbraLocaleConfig({
    this.languages = priorityLanguages,
    this.defaultLocale = const Locale('en'),
  }) : assert(languages.isNotEmpty, 'at least one language is required') {
    if (!languages.any((language) => language.locale == defaultLocale)) {
      throw ArgumentError.value(
        defaultLocale,
        'defaultLocale',
        'must be one of the supported languages',
      );
    }
  }

  /// The languages Abra Travels launches with. Not a limit: pass a longer
  /// list to [AbraLocaleConfig] to offer more.
  static const List<SupportedLanguage> priorityLanguages = <SupportedLanguage>[
    SupportedLanguage(Locale('en'), 'English'),
    SupportedLanguage(Locale('hi'), 'हिन्दी'),
    SupportedLanguage(Locale('te'), 'తెలుగు'),
    SupportedLanguage(Locale('kn'), 'ಕನ್ನಡ'),
    SupportedLanguage(Locale('ta'), 'தமிழ்'),
    SupportedLanguage(Locale('ml'), 'മലയാളം'),
    SupportedLanguage(Locale('mr'), 'मराठी'),
    SupportedLanguage(Locale('bn'), 'বাংলা'),
  ];

  final List<SupportedLanguage> languages;

  /// Used when neither the user nor the device asks for a supported
  /// language, and as the last step of every translation fallback.
  final Locale defaultLocale;

  List<Locale> get supportedLocales => <Locale>[
    for (final language in languages) language.locale,
  ];

  /// The best supported locale for [requested], or null when its language
  /// is not offered. Preference: exact match, then same language and
  /// script, then same language and region, then same language.
  Locale? match(Locale requested) {
    Locale? best;
    var bestScore = 0;
    for (final candidate in supportedLocales) {
      if (candidate.languageCode != requested.languageCode) continue;
      final sameScript = candidate.scriptCode == requested.scriptCode;
      final sameRegion = candidate.countryCode == requested.countryCode;
      // A candidate that names a different script is a different writing
      // system (zh-Hans vs zh-Hant) and must not win over a neutral one.
      final conflictingScript =
          candidate.scriptCode != null &&
          requested.scriptCode != null &&
          !sameScript;
      final score = conflictingScript
          ? 1
          : sameScript && sameRegion
          ? 5
          : sameScript && candidate.countryCode == null
          ? 4
          : sameRegion
          ? 3
          : 2;
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  bool isSupported(Locale locale) => match(locale) != null;

  /// Chooses the locale to use:
  /// 1. the language the user selected, if it is offered;
  /// 2. otherwise the first device language that is offered;
  /// 3. otherwise [defaultLocale].
  Locale resolve({
    Locale? userSelected,
    List<Locale> deviceLocales = const <Locale>[],
  }) {
    if (userSelected != null) {
      final selected = match(userSelected);
      if (selected != null) return selected;
    }
    for (final deviceLocale in deviceLocales) {
      final matched = match(deviceLocale);
      if (matched != null) return matched;
    }
    return defaultLocale;
  }

  /// Locales to look a translation up in, most specific first:
  /// `zh-Hant-TW → zh-Hant → zh → default`. Duplicates removed.
  List<Locale> fallbackChain(Locale locale) {
    final chain = <Locale>[
      locale,
      if (locale.scriptCode != null && locale.countryCode != null)
        Locale.fromSubtags(
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode,
        ),
      Locale(locale.languageCode),
      defaultLocale,
    ];
    return <Locale>[
      for (var i = 0; i < chain.length; i++)
        if (!chain.sublist(0, i).contains(chain[i])) chain[i],
    ];
  }
}
