import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

const priorityTags = ['en', 'hi', 'te', 'kn', 'ta', 'ml', 'mr', 'bn'];

Map<String, String> arb(String tag) =>
    parseArb(File('l10n/app_$tag.arb').readAsStringSync());

/// A small app wired the way the real apps will be.
class TestApp extends StatelessWidget {
  const TestApp({required this.controller, required this.delegate, super.key});

  final LocaleController controller;
  final AbraLocalizationsDelegate delegate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      locale: controller.locale,
      supportedLocales: controller.config.supportedLocales,
      localizationsDelegates: [
        delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) {
          final l10n = AbraLocalizations.of(context);
          return Scaffold(
            body: Column(
              children: [
                Text(
                  l10n.text(AbraStrings.commonRetry),
                  key: const Key('retry'),
                ),
                Text(
                  l10n.text(AbraStrings.stateEmptyTitle),
                  key: const Key('empty'),
                ),
                Text(
                  l10n.text(AbraStrings.commonRetryInSeconds, {'count': 3}),
                  key: const Key('plural'),
                ),
                Text(
                  Directionality.of(context).name,
                  key: const Key('direction'),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('translation resources', () {
    test(
      'AbraStrings and the English resource contain exactly the same keys',
      () {
        final english = arb('en').keys.toSet();
        expect(
          AbraStrings.all.difference(english),
          isEmpty,
          reason: 'keys without English text',
        );
        expect(
          english.difference(AbraStrings.all),
          isEmpty,
          reason: 'English text without a key constant',
        );
      },
    );

    test('keys follow the naming convention', () {
      final pattern = RegExp(
        r'^(common|language|state|validation)[A-Z][A-Za-z]+$',
      );
      for (final key in AbraStrings.all) {
        expect(pattern.hasMatch(key), isTrue, reason: key);
      }
    });

    test('English has real text for every key', () {
      arb('en').forEach((key, value) {
        expect(value.trim(), isNotEmpty, reason: key);
        expect(value, isNot(key));
      });
    });

    test('a resource file exists for every priority language', () {
      for (final tag in priorityTags) {
        expect(File('l10n/app_$tag.arb').existsSync(), isTrue, reason: tag);
      }
    });

    test('no language defines a key that English does not have', () {
      final english = arb('en').keys.toSet();
      for (final tag in priorityTags) {
        expect(arb(tag).keys.toSet().difference(english), isEmpty, reason: tag);
      }
    });

    test(
      'translated messages keep the placeholders of the English message',
      () {
        final placeholders = RegExp(r'\{(\w+)');
        Set<String> names(String message) =>
            placeholders.allMatches(message).map((m) => m.group(1)!).toSet();
        final english = arb('en');
        for (final tag in priorityTags.skip(1)) {
          arb(tag).forEach((key, value) {
            expect(names(value), names(english[key]!), reason: '$tag:$key');
          });
        }
      },
    );

    test(
      'reports how complete each language is (missing keys fall back to English)',
      () {
        final english = arb('en').keys.toSet();
        for (final tag in priorityTags) {
          final missing = english.difference(arb(tag).keys.toSet());
          // Informational: gaps are allowed and covered by the fallback.
          printOnFailure(
            '$tag: ${english.length - missing.length}/${english.length} translated',
          );
          expect(missing.length, lessThanOrEqualTo(english.length));
        }
      },
    );

    test('parseArb skips metadata and rejects non-objects', () {
      expect(
        parseArb('{"@@locale":"en","a":"A","@a":{"description":"d"},"n":5}'),
        {'a': 'A'},
      );
      expect(() => parseArb('[]'), throwsFormatException);
    });
  });

  group('AbraLocalizations lookup', () {
    AbraLocalizations localizations(
      List<Map<String, String>> layers, {
      List<String>? missing,
    }) => AbraLocalizations(
      locale: const Locale('hi', 'IN'),
      layers: layers,
      onMissingKey: (key, locale) =>
          missing?.add('${LocaleTags.of(locale)}:$key'),
    );

    test('uses the most specific layer that has the key', () {
      final l10n = localizations([
        {'a': 'regional'},
        {'a': 'language', 'b': 'language'},
        {'a': 'default', 'b': 'default', 'c': 'default'},
      ]);
      expect(l10n.text('a'), 'regional');
      expect(l10n.text('b'), 'language');
      expect(l10n.text('c'), 'default');
      expect(l10n.isTranslated('a'), isTrue);
      expect(l10n.isTranslated('c'), isFalse);
      expect(l10n.has('c'), isTrue);
    });

    test('a key missing everywhere returns the key and is reported once', () {
      final missing = <String>[];
      final l10n = localizations([
        {'a': 'x'},
      ], missing: missing);
      expect(l10n.text('nowhere'), 'nowhere');
      expect(l10n.text('nowhere'), 'nowhere');
      expect(missing, ['hi-IN:nowhere']);
      expect(l10n.missingKeys, {'nowhere'});
      expect(l10n.has('nowhere'), isFalse);
    });

    test('exposes direction and formatters for its locale', () async {
      await AbraFormatters.ensureInitialized();
      final hindi = localizations(const []);
      expect(hindi.isRtl, isFalse);
      expect(hindi.formatters.number(100000), '1,00,000');
      final arabic = AbraLocalizations(
        locale: const Locale('ar'),
        layers: const [],
      );
      expect(arabic.textDirection, TextDirection.rtl);
    });
  });

  group('MergedTranslationSource', () {
    final shared = MemoryTranslationSource({
      'en': {'commonRetry': 'Try again', 'commonOk': 'OK'},
      'hi': <String, String>{},
    });
    final app = MemoryTranslationSource({
      'en': {'homeTitle': 'Home', 'commonOk': 'Okay'},
    });
    const english = Locale('en');

    test('merges the messages of all sources; the first source wins', () async {
      final merged = MergedTranslationSource([app, shared]);
      expect(await merged.load(english), {
        'commonRetry': 'Try again',
        'commonOk': 'Okay',
        'homeTitle': 'Home',
      });
    });

    test('a locale that only some sources have is still found', () async {
      final merged = MergedTranslationSource([app, shared]);
      expect(await merged.load(const Locale('hi')), isEmpty);
    });

    test('a locale no source has is absent, so the fallback applies', () async {
      final merged = MergedTranslationSource([app, shared]);
      expect(await merged.load(const Locale('ta')), isNull);
    });
  });

  group('delegate', () {
    final config = AbraLocaleConfig();

    testWidgets('loads the bundled English resource', (tester) async {
      final l10n = await tester.runAsync(
        () =>
            AbraLocalizationsDelegate(config: config).load(const Locale('en')),
      );
      expect(l10n!.text(AbraStrings.commonRetry), 'Try again');
      expect(
        l10n.text(AbraStrings.commonRequestReference, {'requestId': 'req-7'}),
        'Reference: req-7',
      );
      expect(
        l10n.text(AbraStrings.commonRetryInSeconds, {'count': 1}),
        'Try again in 1 second',
      );
      expect(
        l10n.text(AbraStrings.commonRetryInSeconds, {'count': 30}),
        'Try again in 30 seconds',
      );
      expect(l10n.missingKeys, isEmpty);
    });

    testWidgets(
      'a priority language without translations falls back to English for every key',
      (tester) async {
        final missing = <String>[];
        final delegate = AbraLocalizationsDelegate(
          config: config,
          onMissingKey: (key, _) => missing.add(key),
        );
        final l10n = await tester.runAsync(
          () => delegate.load(const Locale('kn')),
        );
        for (final key in AbraStrings.all) {
          expect(l10n!.has(key), isTrue, reason: key);
        }
        expect(
          l10n!.text(AbraStrings.stateNetworkTitle),
          'No internet connection',
        );
        expect(l10n.isTranslated(AbraStrings.stateNetworkTitle), isFalse);
        expect(missing, isEmpty);
      },
    );

    testWidgets('supports exactly the configured languages', (tester) async {
      final delegate = AbraLocalizationsDelegate(config: config);
      expect(delegate.isSupported(const Locale('ta', 'IN')), isTrue);
      expect(delegate.isSupported(const Locale('ja')), isFalse);
    });

    testWidgets(
      'partial translations: translated keys are used, the rest fall back',
      (tester) async {
        final source = MemoryTranslationSource({
          'en': {
            'commonRetry': 'Try again',
            'stateEmptyTitle': 'Nothing here yet',
          },
          'es': {'commonRetry': 'Reintentar'},
          'es-MX': {'stateEmptyTitle': 'Aún no hay nada'},
        });
        final spanish = AbraLocaleConfig(
          languages: const [
            SupportedLanguage(Locale('en'), 'English'),
            SupportedLanguage(Locale('es'), 'Español'),
          ],
        );
        final delegate = AbraLocalizationsDelegate(
          config: spanish,
          source: source,
        );

        final mexico = await tester.runAsync(
          () => delegate.load(const Locale('es', 'MX')),
        );
        expect(mexico!.text('stateEmptyTitle'), 'Aún no hay nada'); // regional
        expect(mexico.text('commonRetry'), 'Reintentar'); // language
        final spain = await tester.runAsync(
          () => delegate.load(const Locale('es')),
        );
        expect(spain!.text('stateEmptyTitle'), 'Nothing here yet'); // default
      },
    );

    testWidgets('server-provided overrides win over bundled text, per key', (
      tester,
    ) async {
      final overrides = MemoryTranslationSource()
        ..put(const Locale('en'), {'commonRetry': 'Retry now'});
      final delegate = AbraLocalizationsDelegate(
        config: config,
        overrides: overrides,
      );
      final l10n = await tester.runAsync(
        () => delegate.load(const Locale('en')),
      );
      expect(l10n!.text(AbraStrings.commonRetry), 'Retry now');
      expect(l10n.text(AbraStrings.commonCancel), 'Cancel');
    });
  });

  group('in a running app', () {
    final english = {
      'commonRetry': 'Try again',
      'stateEmptyTitle': 'Nothing here yet',
      'commonRetryInSeconds':
          '{count, plural, one{Try again in # second} other{Try again in # seconds}}',
    };
    // Test data for a right-to-left language; not shipped translations.
    final source = MemoryTranslationSource({
      'en': english,
      'ar': {'commonRetry': 'RETRY-AR'},
      'hi': <String, String>{},
    });
    final config = AbraLocaleConfig(
      languages: const [
        SupportedLanguage(Locale('en'), 'English'),
        SupportedLanguage(Locale('hi'), 'हिन्दी'),
        SupportedLanguage(Locale('ar'), 'العربية'),
      ],
    );

    Future<LocaleController> pumpApp(
      WidgetTester tester, {
      List<Locale> device = const [Locale('en')],
    }) async {
      final controller = LocaleController(
        config: config,
        preferences: InMemoryPreferencesStore(),
        deviceLocales: device,
      );
      await tester.pumpWidget(
        TestApp(
          controller: controller,
          delegate: AbraLocalizationsDelegate(config: config, source: source),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('shows the device language at start', (tester) async {
      await pumpApp(tester, device: const [Locale('ar', 'EG')]);
      expect(textOf(tester, 'retry'), 'RETRY-AR');
      expect(textOf(tester, 'direction'), 'rtl');
    });

    testWidgets('switches language at runtime, including layout direction', (
      tester,
    ) async {
      final controller = await pumpApp(tester);
      expect(textOf(tester, 'retry'), 'Try again');
      expect(textOf(tester, 'direction'), 'ltr');
      expect(textOf(tester, 'plural'), 'Try again in 3 seconds');

      await controller.selectLocale(const Locale('ar'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'retry'), 'RETRY-AR');
      expect(textOf(tester, 'direction'), 'rtl');
      // Not translated in the test data: falls back to English, still rendered
      expect(textOf(tester, 'empty'), 'Nothing here yet');

      await controller.selectLocale(const Locale('hi'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'retry'), 'Try again');
      expect(textOf(tester, 'direction'), 'ltr');
    });
  });
}
