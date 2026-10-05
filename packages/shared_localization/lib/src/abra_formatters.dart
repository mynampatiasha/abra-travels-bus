import 'dart:ui';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'locale_tags.dart';

/// Locale-aware formatting of numbers, money, percentages, dates and times.
///
/// Formatting follows the conventions of the locale (digit grouping such as
/// 1,00,000 in India, decimal separators, month names, 12/24-hour clock).
/// A locale `package:intl` has no data for falls back to its language and
/// then to English, so formatting never throws for an unusual locale.
///
/// Presentation only: amounts are calculated by the backend; this class
/// just prints them.
class AbraFormatters {
  AbraFormatters(Locale locale) : localeTag = _supportedTag(locale);

  /// The `package:intl` locale used for formatting (e.g. `en_IN`, `hi`).
  final String localeTag;

  static bool _initialized = false;

  /// Loads the date symbols of all locales. Call before formatting dates
  /// (the localization delegate does this).
  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await initializeDateFormatting();
    _initialized = true;
  }

  static String _supportedTag(Locale locale) {
    for (final candidate in <String>[
      LocaleTags.underscored(locale),
      if (locale.countryCode != null)
        '${locale.languageCode}_${locale.countryCode}',
      locale.languageCode,
    ]) {
      if (NumberFormat.localeExists(candidate)) return candidate;
    }
    return 'en';
  }

  /// A whole or fractional number with locale grouping: `1,00,000`.
  String number(num value) =>
      NumberFormat.decimalPattern(localeTag).format(value);

  /// A number with exactly [fractionDigits] decimals: `12.50`.
  String decimal(num value, {int fractionDigits = 2}) =>
      (NumberFormat.decimalPattern(localeTag)
            ..minimumFractionDigits = fractionDigits
            ..maximumFractionDigits = fractionDigits)
          .format(value);

  /// A ratio as a percentage: `0.125` → `12.5%`.
  String percent(num ratio, {int maxFractionDigits = 1}) =>
      (NumberFormat.percentPattern(
        localeTag,
      )..maximumFractionDigits = maxFractionDigits).format(ratio);

  /// An amount of money in major units: `currency(1250.5)` → `₹1,250.50`.
  String currency(num amount, {String currencyCode = 'INR'}) =>
      NumberFormat.simpleCurrency(
        locale: localeTag,
        name: currencyCode,
      ).format(amount);

  /// An amount stored in minor units (paise, cents), as the API sends it:
  /// `currencyFromMinor(125050)` → `₹1,250.50`.
  String currencyFromMinor(int minorUnits, {String currencyCode = 'INR'}) {
    final format = NumberFormat.simpleCurrency(
      locale: localeTag,
      name: currencyCode,
    );
    var divisor = 1;
    for (var i = 0; i < (format.decimalDigits ?? 2); i++) {
      divisor *= 10;
    }
    return format.format(minorUnits / divisor);
  }

  /// A short form for large numbers: `12K`, `1.2M` (locale specific).
  String compact(num value) =>
      NumberFormat.compact(locale: localeTag).format(value);

  /// A calendar date: `5 Oct 2026`.
  String date(DateTime value) => DateFormat.yMMMd(localeTag).format(value);

  /// A date with weekday: `Mon, 5 Oct 2026`.
  String dateWithWeekday(DateTime value) =>
      DateFormat.yMMMEd(localeTag).format(value);

  /// A time of day in the locale's 12- or 24-hour convention.
  String time(DateTime value) => DateFormat.jm(localeTag).format(value);

  String dateTime(DateTime value) => '${date(value)}, ${time(value)}';
}
