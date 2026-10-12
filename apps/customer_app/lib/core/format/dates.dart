import 'package:intl/intl.dart';
import 'package:shared_localization/shared_localization.dart';

/// A date as Indian travellers write it: weekday, day and month, without
/// the year ("Tue, 6 Oct"). English uses the Indian pattern; other
/// languages use their own.
String formatShortDate(AbraLocalizations l10n, DateTime date) {
  final tag = l10n.formatters.localeTag;
  try {
    return DateFormat.MMMEd(tag == 'en' ? 'en_IN' : tag).format(date);
  } on Object {
    return l10n.formatters.dateWithWeekday(date);
  }
}

/// A day and month without the weekday or year ("31 Oct").
String formatDayMonth(AbraLocalizations l10n, DateTime date) {
  final tag = l10n.formatters.localeTag;
  try {
    return DateFormat.MMMd(tag == 'en' ? 'en_IN' : tag).format(date);
  } on Object {
    return l10n.formatters.date(date);
  }
}
