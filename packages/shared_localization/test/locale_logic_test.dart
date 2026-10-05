import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

void main() {
  group('LocaleTags (BCP-47)', () {
    test('parses language, script and region', () {
      expect(LocaleTags.tryParse('en'), const Locale('en'));
      expect(LocaleTags.tryParse('en-IN'), const Locale('en', 'IN'));
      expect(LocaleTags.tryParse('en_US'), const Locale('en', 'US'));
      expect(
        LocaleTags.tryParse('zh-Hant-TW'),
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
      );
      expect(LocaleTags.tryParse('ZH-hans-cn')!.toLanguageTag(), 'zh-Hans-CN');
      expect(LocaleTags.tryParse('es-419'), const Locale('es', '419'));
      expect(LocaleTags.tryParse('fil'), const Locale('fil'));
    });

    test('ignores variants and rejects non-tags', () {
      expect(LocaleTags.tryParse('de-DE-1996'), const Locale('de', 'DE'));
      for (final tag in [null, '', '  ', 'english', '12', '-IN', 'e']) {
        expect(LocaleTags.tryParse(tag), isNull, reason: '$tag');
      }
    });

    test('formats tags for the server and for resources', () {
      const locale = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      );
      expect(LocaleTags.of(locale), 'zh-Hant-TW');
      expect(LocaleTags.underscored(locale), 'zh_Hant_TW');
      expect(LocaleTags.of(const Locale('hi')), 'hi');
    });
  });

  group('AbraLocaleConfig', () {
    final config = AbraLocaleConfig();

    test(
      'launches with the eight priority languages, English first as default',
      () {
        expect(config.supportedLocales.map(LocaleTags.of), [
          'en',
          'hi',
          'te',
          'kn',
          'ta',
          'ml',
          'mr',
          'bn',
        ]);
        expect(config.defaultLocale, const Locale('en'));
        expect(
          config.languages.every((language) => language.nativeName.isNotEmpty),
          isTrue,
        );
      },
    );

    test('is not limited to those: any language can be added as data', () {
      final global = AbraLocaleConfig(
        languages: const [
          ...AbraLocaleConfig.priorityLanguages,
          SupportedLanguage(Locale('es'), 'Español'),
          SupportedLanguage(Locale('ar'), 'العربية'),
          SupportedLanguage(Locale('fr', 'CA'), 'Français (Canada)'),
          SupportedLanguage(
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
            '简体中文',
          ),
          SupportedLanguage(
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            '繁體中文',
          ),
          SupportedLanguage(Locale('sw'), 'Kiswahili'),
        ],
      );
      expect(global.isSupported(const Locale('es', 'MX')), isTrue);
      expect(global.match(const Locale('ar', 'EG')), const Locale('ar'));
      expect(global.match(const Locale('fr')), const Locale('fr', 'CA'));
      expect(
        global.match(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(
        global.match(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'CN',
          ),
        ),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
      expect(global.isSupported(const Locale('ja')), isFalse);
    });

    test('the default locale must be one of the languages', () {
      expect(
        () => AbraLocaleConfig(defaultLocale: const Locale('fr')),
        throwsArgumentError,
      );
    });

    test('regional device locales match their language', () {
      expect(config.match(const Locale('en', 'IN')), const Locale('en'));
      expect(config.match(const Locale('hi', 'IN')), const Locale('hi'));
      expect(config.match(const Locale('fr', 'FR')), isNull);
    });

    test(
      'resolution order: user choice, then device languages, then default',
      () {
        const device = [
          Locale('fr', 'FR'),
          Locale('ta', 'IN'),
          Locale('en', 'US'),
        ];
        expect(
          config.resolve(
            userSelected: const Locale('kn'),
            deviceLocales: device,
          ),
          const Locale('kn'),
        );
        expect(config.resolve(deviceLocales: device), const Locale('ta'));
        expect(
          config.resolve(deviceLocales: const [Locale('fr'), Locale('de')]),
          const Locale('en'),
        );
        expect(config.resolve(), const Locale('en'));
        // A stored choice that is no longer offered falls through to the device
        expect(
          config.resolve(
            userSelected: const Locale('ja'),
            deviceLocales: device,
          ),
          const Locale('ta'),
        );
      },
    );

    test(
      'fallback chain goes from most specific to the default, without duplicates',
      () {
        String chain(Locale locale) =>
            config.fallbackChain(locale).map(LocaleTags.of).join(' > ');
        expect(chain(const Locale('en')), 'en');
        expect(chain(const Locale('hi')), 'hi > en');
        expect(chain(const Locale('en', 'IN')), 'en-IN > en');
        expect(chain(const Locale('pt', 'BR')), 'pt-BR > pt > en');
        expect(
          chain(
            const Locale.fromSubtags(
              languageCode: 'zh',
              scriptCode: 'Hant',
              countryCode: 'TW',
            ),
          ),
          'zh-Hant-TW > zh-Hant > zh > en',
        );
      },
    );
  });

  group('text direction', () {
    test('right-to-left languages', () {
      for (final tag in [
        'ar',
        'ar-EG',
        'fa',
        'he',
        'ur',
        'ur-PK',
        'ps',
        'sd',
        'ug',
        'yi',
        'dv',
      ]) {
        expect(
          TextDirectionResolver.of(LocaleTags.tryParse(tag)!),
          TextDirection.rtl,
          reason: tag,
        );
      }
    });

    test('left-to-right languages, including every priority language', () {
      for (final tag in [
        'en',
        'hi',
        'te',
        'kn',
        'ta',
        'ml',
        'mr',
        'bn',
        'es',
        'fr',
        'ru',
        'zh-Hans',
        'ja',
        'ko',
        'th',
        'sw',
      ]) {
        expect(
          TextDirectionResolver.of(LocaleTags.tryParse(tag)!),
          TextDirection.ltr,
          reason: tag,
        );
      }
    });

    test('the script decides when it is given', () {
      expect(
        TextDirectionResolver.isRtl(LocaleTags.tryParse('pa-Arab')!),
        isTrue,
      );
      expect(TextDirectionResolver.isRtl(LocaleTags.tryParse('pa')!), isFalse);
      expect(
        TextDirectionResolver.isRtl(LocaleTags.tryParse('ks-Deva')!),
        isFalse,
      );
      expect(TextDirectionResolver.isRtl(LocaleTags.tryParse('ks')!), isTrue);
    });
  });

  group('MessageFormatter', () {
    test('fills placeholders and leaves unknown ones visible', () {
      expect(
        MessageFormatter.format('Reference: {requestId}', 'en', {
          'requestId': 'req-1',
        }),
        'Reference: req-1',
      );
      expect(MessageFormatter.format('Hello {name}', 'en'), 'Hello {name}');
      expect(MessageFormatter.format('Plain text', 'en'), 'Plain text');
      expect(
        MessageFormatter.format('{a} and {b}', 'en', {'a': 1, 'b': 'two'}),
        '1 and two',
      );
    });

    test('plurals in English', () {
      const pattern =
          '{count, plural, =0{No seats} one{# seat left} other{# seats left}}';
      expect(MessageFormatter.format(pattern, 'en', {'count': 0}), 'No seats');
      expect(
        MessageFormatter.format(pattern, 'en', {'count': 1}),
        '1 seat left',
      );
      expect(
        MessageFormatter.format(pattern, 'en', {'count': 12}),
        '12 seats left',
      );
    });

    test('plural categories follow the rules of the locale', () {
      const pattern =
          '{count, plural, zero{Z} one{O} two{T} few{F} many{M} other{X}}';
      String arabic(int count) =>
          MessageFormatter.format(pattern, 'ar', {'count': count});
      expect([0, 1, 2, 3, 11, 100].map(arabic), ['Z', 'O', 'T', 'F', 'M', 'X']);

      const russianPattern = '{count, plural, one{O} few{F} many{M} other{X}}';
      String russian(int count) =>
          MessageFormatter.format(russianPattern, 'ru', {'count': count});
      expect([1, 2, 5, 21].map(russian), ['O', 'F', 'M', 'O']);

      // Hindi treats 0 and 1 as "one"
      expect(
        MessageFormatter.format('{n, plural, one{एक} other{कई}}', 'hi', {
          'n': 0,
        }),
        'एक',
      );
    });

    test('a missing plural form falls back to "other"', () {
      expect(
        MessageFormatter.format('{count, plural, other{# items}}', 'ar', {
          'count': 2,
        }),
        '2 items',
      );
    });

    test('# is formatted for the locale; text around the plural is kept', () {
      const pattern =
          'Total: {count, plural, one{# booking} other{# bookings}} for {name}';
      expect(
        MessageFormatter.format(pattern, 'en_IN', {
          'count': 100000,
          'name': 'Asha',
        }),
        'Total: 1,00,000 bookings for Asha',
      );
      expect(
        MessageFormatter.format(pattern, 'en_US', {
          'count': 100000,
          'name': 'Asha',
        }),
        contains('100,000'),
      );
    });

    test('a plural without its number is left visible instead of guessing', () {
      expect(
        MessageFormatter.format(
          '{count, plural, one{# seat} other{# seats}}',
          'en',
        ),
        '{count}',
      );
    });
  });

  group('AbraFormatters', () {
    setUpAll(AbraFormatters.ensureInitialized);

    test('numbers use the grouping of the locale', () {
      expect(
        AbraFormatters(const Locale('en', 'IN')).number(1234567),
        '12,34,567',
      );
      expect(
        AbraFormatters(const Locale('en', 'US')).number(1234567),
        '1,234,567',
      );
      expect(
        AbraFormatters(const Locale('de')).number(1234567.5),
        '1.234.567,5',
      );
    });

    test('decimals and percentages', () {
      const en = Locale('en');
      expect(AbraFormatters(en).decimal(12.5), '12.50');
      expect(AbraFormatters(en).decimal(3, fractionDigits: 1), '3.0');
      expect(AbraFormatters(en).percent(0.125), '12.5%');
      expect(AbraFormatters(en).percent(0.5), '50%');
      expect(AbraFormatters(const Locale('de')).decimal(12.5), '12,50');
    });

    test(
      'currency, from major units and from the minor units the API sends',
      () {
        final india = AbraFormatters(const Locale('en', 'IN'));
        expect(india.currency(1250.5), '₹1,250.50');
        expect(india.currencyFromMinor(125050), '₹1,250.50');
        expect(india.currencyFromMinor(12345678), '₹1,23,456.78');
        expect(
          AbraFormatters(
            const Locale('en', 'US'),
          ).currency(1250.5, currencyCode: 'USD'),
          r'$1,250.50',
        );
        // Yen has no minor unit
        expect(
          AbraFormatters(
            const Locale('ja'),
          ).currencyFromMinor(1250, currencyCode: 'JPY'),
          contains('1,250'),
        );
      },
    );

    test('dates and times follow the locale', () {
      final moment = DateTime(2026, 10, 5, 22, 30);
      final en = AbraFormatters(const Locale('en', 'IN'));
      expect(en.date(moment), '5 Oct 2026');
      expect(en.time(moment), contains('10:30'));
      expect(en.dateTime(moment), startsWith('5 Oct 2026, '));
      expect(en.dateWithWeekday(moment), contains('Mon'));
      expect(
        AbraFormatters(const Locale('en', 'US')).date(moment),
        'Oct 5, 2026',
      );
      expect(AbraFormatters(const Locale('hi')).date(moment), contains('2026'));
      expect(AbraFormatters(const Locale('de')).time(moment), '22:30');
    });

    test('an unusual locale falls back to its language, then to English', () {
      expect(AbraFormatters(const Locale('hi', 'ZZ')).localeTag, 'hi');
      expect(AbraFormatters(const Locale('xx')).localeTag, 'en');
      expect(AbraFormatters(const Locale('xx')).number(1000), '1,000');
      expect(
        AbraFormatters(
          const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
            countryCode: 'TW',
          ),
        ).localeTag,
        'zh_TW',
      );
    });
  });

  group('LocaleController', () {
    final config = AbraLocaleConfig();

    test('follows the device language when the user has not chosen', () {
      final controller = LocaleController(
        config: config,
        preferences: InMemoryPreferencesStore(),
        deviceLocales: const [Locale('te', 'IN')],
      );
      expect(controller.locale, const Locale('te'));
      expect(controller.followsDevice, isTrue);
      expect(controller.languageTag, 'te');
    });

    test('uses the default when the device language is not offered', () {
      final controller = LocaleController(
        config: config,
        preferences: InMemoryPreferencesStore(),
        deviceLocales: const [Locale('fr', 'FR')],
      );
      expect(controller.locale, const Locale('en'));
    });

    test('switches at runtime, notifies, and remembers the choice', () async {
      final preferences = InMemoryPreferencesStore();
      final controller = LocaleController(
        config: config,
        preferences: preferences,
        deviceLocales: const [Locale('en', 'IN')],
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(await controller.selectLocale(const Locale('kn')), isTrue);
      expect(controller.locale, const Locale('kn'));
      expect(controller.followsDevice, isFalse);
      expect(notifications, 1);
      expect(preferences.getString('abra.preferences.locale_tag'), 'kn');

      // A new controller (app restart) starts in the remembered language
      final restarted = LocaleController(
        config: config,
        preferences: preferences,
        deviceLocales: const [Locale('en', 'IN')],
      );
      expect(restarted.locale, const Locale('kn'));
      expect(restarted.userSelected, const Locale('kn'));
    });

    test('selecting the current language again does not notify', () async {
      final controller = LocaleController(
        config: config,
        preferences: InMemoryPreferencesStore(),
        deviceLocales: const [Locale('hi')],
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.selectLocale(const Locale('hi'));
      expect(notifications, 0);
      expect(controller.followsDevice, isFalse);
    });

    test(
      'a language that is not offered is refused and nothing changes',
      () async {
        final preferences = InMemoryPreferencesStore();
        final controller = LocaleController(
          config: config,
          preferences: preferences,
          deviceLocales: const [Locale('en')],
        );
        expect(await controller.selectLocale(const Locale('ja')), isFalse);
        expect(controller.locale, const Locale('en'));
        expect(preferences.getString('abra.preferences.locale_tag'), isNull);
      },
    );

    test('clearing the choice returns to the device language', () async {
      final preferences = InMemoryPreferencesStore({
        'abra.preferences.locale_tag': 'bn',
      });
      final controller = LocaleController(
        config: config,
        preferences: preferences,
        deviceLocales: const [Locale('mr', 'IN')],
      );
      expect(controller.locale, const Locale('bn'));
      await controller.selectLocale(null);
      expect(controller.locale, const Locale('mr'));
      expect(preferences.getString('abra.preferences.locale_tag'), isNull);
    });

    test(
      'device language changes apply only while following the device',
      () async {
        final controller = LocaleController(
          config: config,
          preferences: InMemoryPreferencesStore(),
          deviceLocales: const [Locale('en')],
        );
        controller.updateDeviceLocales(const [Locale('ta', 'IN')]);
        expect(controller.locale, const Locale('ta'));

        await controller.selectLocale(const Locale('hi'));
        controller.updateDeviceLocales(const [Locale('ml')]);
        expect(controller.locale, const Locale('hi'));
      },
    );

    test('a corrupt stored value is ignored', () {
      final controller = LocaleController(
        config: config,
        preferences: InMemoryPreferencesStore({
          'abra.preferences.locale_tag': '%%%',
        }),
        deviceLocales: const [Locale('kn')],
      );
      expect(controller.locale, const Locale('kn'));
      expect(controller.followsDevice, isTrue);
    });

    test('reports text direction for right-to-left languages', () async {
      final controller = LocaleController(
        config: AbraLocaleConfig(
          languages: const [
            SupportedLanguage(Locale('en'), 'English'),
            SupportedLanguage(Locale('ar'), 'العربية'),
          ],
        ),
        preferences: InMemoryPreferencesStore(),
        deviceLocales: const [Locale('en')],
      );
      expect(controller.textDirection, TextDirection.ltr);
      await controller.selectLocale(const Locale('ar', 'SA'));
      expect(controller.locale, const Locale('ar'));
      expect(controller.textDirection, TextDirection.rtl);
    });
  });
}
