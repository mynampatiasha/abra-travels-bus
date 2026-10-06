import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Overridden in tests.
final discoveryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Travel dates and trip times.
///
/// Travel dates are calendar dates in India time, and trip times are shown
/// as the clock at the place of travel shows them, whatever timezone the
/// phone is set to. India has one timezone without daylight saving, so a
/// fixed offset is exact. A trip in another timezone would need a timezone
/// database; until then such a trip is shown in the phone's local time.
abstract final class TravelDates {
  static const indiaTimezone = 'Asia/Kolkata';
  static const _indiaOffset = Duration(hours: 5, minutes: 30);

  /// How far ahead the backend accepts searches.
  static const horizonDays = 90;

  /// Today's date in India, as a date-only value.
  static DateTime today(DateTime now) =>
      _dateOnly(now.toUtc().add(_indiaOffset));

  static DateTime lastSearchable(DateTime now) =>
      today(now).add(const Duration(days: horizonDays));

  static DateTime _dateOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// `YYYY-MM-DD`, the form the backend expects.
  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Parses `YYYY-MM-DD` into a date-only value, or null when [value] is not
  /// a real date.
  static DateTime? tryParse(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    return format(date) == value ? date : null;
  }

  /// Whether [date] can be searched today.
  static bool isSearchable(DateTime date, DateTime now) =>
      !date.isBefore(today(now)) && !date.isAfter(lastSearchable(now));

  /// [instant] as the wall clock in [timezone] shows it. The result is a
  /// plain date and time to hand to a formatter; it is not an instant.
  static DateTime wallClock(DateTime instant, String timezone) {
    if (timezone != indiaTimezone) return instant.toLocal();
    final shifted = instant.toUtc().add(_indiaOffset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
    );
  }

  /// A date-only value as a local date for formatters and the date picker.
  static DateTime asLocalDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
