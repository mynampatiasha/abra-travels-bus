import 'package:shared_localization/shared_localization.dart';

import '../../../l10n/customer_strings.dart';
import '../controllers/travel_dates.dart';
import '../models/discovery_models.dart';

/// Words and numbers of the discovery screens, in one place so that every
/// screen says the same thing the same way.
class DiscoveryText {
  const DiscoveryText(this.l10n);

  final AbraLocalizations l10n;

  static const _amenityKeys = <String, String>{
    'WIFI': CustomerStrings.amenityWifi,
    'CHARGING_POINT': CustomerStrings.amenityChargingPoint,
    'BLANKET': CustomerStrings.amenityBlanket,
    'PILLOW': CustomerStrings.amenityPillow,
    'WATER_BOTTLE': CustomerStrings.amenityWaterBottle,
    'READING_LIGHT': CustomerStrings.amenityReadingLight,
    'CCTV': CustomerStrings.amenityCctv,
    'GPS_TRACKING': CustomerStrings.amenityGpsTracking,
    'TOILET': CustomerStrings.amenityToilet,
    'ENTERTAINMENT': CustomerStrings.amenityEntertainment,
    'SNACKS': CustomerStrings.amenitySnacks,
    'EMERGENCY_EXIT': CustomerStrings.amenityEmergencyExit,
    'FIRST_AID': CustomerStrings.amenityFirstAid,
  };

  static const _windowKeys = <String, String>{
    'EARLY_MORNING': CustomerStrings.windowEarlyMorning,
    'MORNING': CustomerStrings.windowMorning,
    'AFTERNOON': CustomerStrings.windowAfternoon,
    'NIGHT': CustomerStrings.windowNight,
  };

  static const _sortKeys = <TripSort, String>{
    TripSort.departureEarliest: CustomerStrings.sortDepartureEarliest,
    TripSort.departureLatest: CustomerStrings.sortDepartureLatest,
    TripSort.fareLowest: CustomerStrings.sortFareLowest,
    TripSort.fareHighest: CustomerStrings.sortFareHighest,
    TripSort.durationShortest: CustomerStrings.sortDurationShortest,
  };

  /// An amenity the app knows is named in the user's language; one added on
  /// the backend since this version shows as readable text, never as a key.
  String amenity(String key) {
    final messageKey = _amenityKeys[key];
    return messageKey == null ? _readable(key) : l10n.text(messageKey);
  }

  String departureWindow(String key) {
    final messageKey = _windowKeys[key];
    return messageKey == null ? _readable(key) : l10n.text(messageKey);
  }

  String sort(TripSort sort) => l10n.text(_sortKeys[sort]!);

  static String _readable(String key) {
    final words = key.toLowerCase().split('_').join(' ');
    return words.isEmpty ? key : words[0].toUpperCase() + words.substring(1);
  }

  String route(String from, String to) => l10n.text(
    CustomerStrings.searchRoute,
    <String, Object?>{'from': from, 'to': to},
  );

  String fare(int paise, String currency) =>
      l10n.formatters.currencyFromMinor(paise, currencyCode: currency);

  String fareFrom(TripSummary trip) => l10n.text(
    CustomerStrings.tripFareFrom,
    <String, Object?>{'fare': fare(trip.startingFarePaise, trip.currency)},
  );

  String duration(int minutes) =>
      l10n.text(CustomerStrings.tripDuration, <String, Object?>{
        'hours': l10n.formatters.number(minutes ~/ 60),
        'minutes': l10n.formatters.number(minutes % 60),
      });

  /// Clock time at the place of travel.
  String time(DateTime instant, String timezone) =>
      l10n.formatters.time(TravelDates.wallClock(instant, timezone));

  /// A date-only value with its weekday.
  String date(DateTime date) =>
      l10n.formatters.dateWithWeekday(TravelDates.asLocalDate(date));

  String seats(TripSummary trip) => trip.isSoldOut
      ? l10n.text(CustomerStrings.tripSoldOut)
      : l10n.text(CustomerStrings.tripSeatsLeft, <String, Object?>{
          'count': trip.availableSeats,
        });

  String airConditioning({required bool isAc}) =>
      l10n.text(isAc ? CustomerStrings.tripAc : CustomerStrings.tripNonAc);

  /// Calendar days between departure and arrival at the place of travel.
  int arrivalDayOffset(TripSummary trip) {
    final departure = TravelDates.wallClock(trip.departureAt, trip.timezone);
    final arrival = TravelDates.wallClock(trip.arrivalAt, trip.timezone);
    return DateTime(arrival.year, arrival.month, arrival.day)
        .difference(DateTime(departure.year, departure.month, departure.day))
        .inDays;
  }

  /// "Arrives next day", or null when the bus arrives the day it leaves.
  String? arrivesLater(TripSummary trip) {
    final days = arrivalDayOffset(trip);
    return days <= 0
        ? null
        : l10n.text(CustomerStrings.tripArrivesLater, <String, Object?>{
            'count': days,
          });
  }
}
