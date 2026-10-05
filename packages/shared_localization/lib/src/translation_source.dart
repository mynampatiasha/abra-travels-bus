import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'locale_tags.dart';

/// Where translated messages come from. Returns the messages of exactly
/// [locale] (no fallback — that is done by the caller), or null when this
/// source has nothing for it.
///
/// Sources can be layered: bundled files first, then messages downloaded
/// from the server on top (see `AbraLocalizationsDelegate.overrides`).
abstract interface class TranslationSource {
  Future<Map<String, String>?> load(Locale locale);
}

/// Parses the content of an ARB file. Metadata entries (keys starting with
/// `@`) and non-text values are skipped.
Map<String, String> parseArb(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map) {
    throw const FormatException('An ARB file must contain a JSON object');
  }
  return <String, String>{
    for (final entry in decoded.entries)
      if (entry.key is String &&
          !(entry.key as String).startsWith('@') &&
          entry.value is String)
        entry.key as String: entry.value as String,
  };
}

/// Loads `l10n/app_<locale>.arb` from the assets of this package
/// (`app_en.arb`, `app_hi.arb`, `app_zh_Hant_TW.arb`).
class AssetTranslationSource implements TranslationSource {
  const AssetTranslationSource({
    AssetBundle? bundle,
    this.package = 'shared_localization',
    this.directory = 'l10n',
    this.filePrefix = 'app_',
  }) : _bundle = bundle;

  final AssetBundle? _bundle;

  /// Package that declares the assets; null for assets of the app itself.
  final String? package;
  final String directory;
  final String filePrefix;

  @override
  Future<Map<String, String>?> load(Locale locale) async {
    final file = '$directory/$filePrefix${LocaleTags.underscored(locale)}.arb';
    final bundle = _bundle ?? rootBundle;
    // An app sees package assets under packages/<name>/; the package's own
    // tests see them without the prefix.
    for (final key in <String>[
      if (package != null) 'packages/$package/$file',
      file,
    ]) {
      try {
        return parseArb(await bundle.loadString(key));
      } on FlutterError {
        continue; // No such asset: this locale has no bundled resource.
      }
    }
    return null;
  }
}

/// Translations held in memory: messages fetched from the server, or test
/// data. Keys are BCP-47 tags.
class MemoryTranslationSource implements TranslationSource {
  MemoryTranslationSource([
    Map<String, Map<String, String>> messages =
        const <String, Map<String, String>>{},
  ]) : _messages = <String, Map<String, String>>{...messages};

  final Map<String, Map<String, String>> _messages;

  /// Replaces the messages of one locale.
  void put(Locale locale, Map<String, String> messages) =>
      _messages[LocaleTags.of(locale)] = messages;

  @override
  Future<Map<String, String>?> load(Locale locale) async =>
      _messages[LocaleTags.of(locale)];
}

/// Several sources seen as one: the messages of every source that has the
/// locale are merged, and for a key defined more than once the source
/// listed first wins. Lets an app add its own resource files to the
/// shared ones:
///
/// ```dart
/// MergedTranslationSource([
///   AssetTranslationSource(package: null, filePrefix: 'customer_'),
///   AssetTranslationSource(),
/// ])
/// ```
class MergedTranslationSource implements TranslationSource {
  const MergedTranslationSource(this.sources);

  final List<TranslationSource> sources;

  @override
  Future<Map<String, String>?> load(Locale locale) async {
    Map<String, String>? merged;
    for (final source in sources.reversed) {
      final messages = await source.load(locale);
      if (messages != null) (merged ??= <String, String>{}).addAll(messages);
    }
    return merged;
  }
}
