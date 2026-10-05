import 'package:flutter/widgets.dart';

import 'abra_formatters.dart';
import 'abra_locale_config.dart';
import 'locale_tags.dart';
import 'message_formatter.dart';
import 'text_direction_resolver.dart';
import 'translation_source.dart';

/// Called when a key has no message in any locale of the fallback chain.
typedef MissingTranslationHandler = void Function(String key, Locale locale);

/// Translated text for one locale.
///
/// `AbraLocalizations.of(context).text(AbraStrings.commonRetry)`
///
/// Lookup order for a key: the active locale, then its language, then the
/// default locale. A key that exists nowhere is reported to
/// [onMissingKey] and the key itself is returned, so the gap is visible
/// and never crashes the screen.
class AbraLocalizations {
  AbraLocalizations({
    required this.locale,
    required List<Map<String, String>> layers,
    this.onMissingKey,
  }) : _layers = layers,
       formatters = AbraFormatters(locale);

  /// The locale the app is shown in.
  final Locale locale;

  /// Message maps, most specific first.
  final List<Map<String, String>> _layers;
  final MissingTranslationHandler? onMissingKey;

  /// Numbers, currency, dates and times formatted for [locale].
  final AbraFormatters formatters;

  /// Keys that were requested but have no message anywhere.
  final Set<String> missingKeys = <String>{};

  static AbraLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AbraLocalizations>(
      context,
      AbraLocalizations,
    );
    assert(
      localizations != null,
      'AbraLocalizationsDelegate is not registered in the app',
    );
    return localizations!;
  }

  TextDirection get textDirection => TextDirectionResolver.of(locale);

  bool get isRtl => TextDirectionResolver.isRtl(locale);

  /// True when [key] has a message in the active locale or a fallback.
  bool has(String key) => _layers.any((layer) => layer.containsKey(key));

  /// True when [key] is translated for the active locale itself (not taken
  /// from a fallback).
  bool isTranslated(String key) =>
      _layers.isNotEmpty && _layers.first.containsKey(key);

  /// The message for [key] with [args] filled in. Plural messages take
  /// their number from the argument named in the message (usually `count`).
  String text(String key, [Map<String, Object?> args = const {}]) {
    for (final layer in _layers) {
      final pattern = layer[key];
      if (pattern != null) {
        return MessageFormatter.format(
          pattern,
          LocaleTags.underscored(locale),
          args,
        );
      }
    }
    if (missingKeys.add(key)) onMissingKey?.call(key, locale);
    return key;
  }
}

/// Loads [AbraLocalizations] for the locale Flutter asks for.
///
/// ```dart
/// MaterialApp(
///   locale: localeController.locale,
///   supportedLocales: config.supportedLocales,
///   localizationsDelegates: [
///     AbraLocalizationsDelegate(config: config),
///     ...GlobalMaterialLocalizations.delegates,
///   ],
/// )
/// ```
class AbraLocalizationsDelegate
    extends LocalizationsDelegate<AbraLocalizations> {
  const AbraLocalizationsDelegate({
    required this.config,
    this.source = const AssetTranslationSource(),
    this.overrides,
    this.onMissingKey,
  });

  final AbraLocaleConfig config;

  /// Bundled translations.
  final TranslationSource source;

  /// Optional messages that take precedence over [source] — for example
  /// wording managed by administrators and downloaded at start-up.
  final TranslationSource? overrides;
  final MissingTranslationHandler? onMissingKey;

  @override
  bool isSupported(Locale locale) => config.isSupported(locale);

  @override
  Future<AbraLocalizations> load(Locale locale) async {
    await AbraFormatters.ensureInitialized();
    final layers = <Map<String, String>>[];
    for (final candidate in config.fallbackChain(locale)) {
      final overridden = await overrides?.load(candidate);
      if (overridden != null) layers.add(overridden);
      final bundled = await source.load(candidate);
      if (bundled != null) layers.add(bundled);
    }
    return AbraLocalizations(
      locale: locale,
      layers: layers,
      onMissingKey: onMissingKey,
    );
  }

  @override
  bool shouldReload(AbraLocalizationsDelegate old) =>
      old.config != config ||
      old.source != source ||
      old.overrides != overrides;
}
