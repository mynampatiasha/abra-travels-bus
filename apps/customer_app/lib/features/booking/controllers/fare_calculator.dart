import '../models/booking_models.dart';

/// The fare of a booking from the seat fares, without any widget so it can
/// be tested on its own. The amounts shown are an estimate: the backend
/// calculates the amount to pay when the booking is created.
abstract final class FareCalculator {
  /// GST on the base fare, in percent.
  static const gstPercent = 5;

  /// A flat fee per booking, in paise.
  static const convenienceFeePaise = 4900;

  /// [basePaise] is the sum of the seat fares. The discount never exceeds
  /// the base fare, so the total is never negative.
  static FareBreakup compute({required int basePaise, int discountPaise = 0}) {
    final discount = discountPaise.clamp(0, basePaise);
    return FareBreakup(
      basePaise: basePaise,
      gstPaise: gstOf(basePaise),
      convenienceFeePaise: basePaise == 0 ? 0 : convenienceFeePaise,
      discountPaise: discount,
    );
  }

  /// 5% of [basePaise], rounded to the nearest paisa (half up).
  static int gstOf(int basePaise) => (basePaise * gstPercent + 50) ~/ 100;
}
