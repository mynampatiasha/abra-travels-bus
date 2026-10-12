import '../../booking/models/booking_models.dart';
import '../models/trip_models.dart';

/// Works out a refund from the cancellation policy, without any widget so
/// it can be tested on its own. The amount shown is an estimate: the backend
/// calculates the real refund when the seats are cancelled. The convenience
/// fee is never refunded, so it is not part of [farePaise].
abstract final class CancellationCalculator {
  /// The rule that applies [hoursBefore] hours before departure: the one
  /// whose window `[toHoursBefore, fromHoursBefore)` holds it. No rule
  /// means no refund.
  static CancellationRule? ruleFor(
    List<CancellationRule> rules,
    int hoursBefore,
  ) {
    for (final rule in rules) {
      final upper = rule.fromHoursBefore;
      if (hoursBefore >= rule.toHoursBefore &&
          (upper == null || hoursBefore < upper)) {
        return rule;
      }
    }
    return null;
  }

  /// Whole hours from [now] to [departure], never negative.
  static int hoursBefore(DateTime departure, DateTime now) {
    final minutes = departure.difference(now).inMinutes;
    return minutes <= 0 ? 0 : minutes ~/ 60;
  }

  static CancellationQuote quote({
    required List<CancellationRule> rules,
    required DateTime departure,
    required DateTime now,
    required int farePaise,
  }) {
    final hours = hoursBefore(departure, now);
    final percent = ruleFor(rules, hours)?.refundPercent ?? 0;
    final refund = (farePaise * percent + 50) ~/ 100;
    return CancellationQuote(
      farePaise: farePaise,
      chargePaise: farePaise - refund,
      refundPaise: refund,
      refundPercent: percent,
      hoursBeforeDeparture: hours,
    );
  }
}
