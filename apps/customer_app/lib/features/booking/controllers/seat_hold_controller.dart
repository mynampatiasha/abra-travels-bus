import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../models/booking_models.dart';

/// The seats a customer is holding for a trip, until [expiresAt].
@immutable
class SeatHold {
  const SeatHold({
    required this.lockId,
    required this.expiresAt,
    this.released = false,
  });

  final String lockId;
  final DateTime expiresAt;

  /// The hold was let go of on purpose (the booking is paid, or the hold ran
  /// out and the customer was told). Unlike "no hold", this never sends the
  /// customer back to the seats.
  final bool released;

  /// Whole seconds left at [now], never negative.
  int secondsLeft(DateTime now) {
    if (released) return 0;
    final left = expiresAt.difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }

  bool isExpired(DateTime now) => released || !expiresAt.isAfter(now);

  /// Seats are still held and can be paid for.
  bool isActive(DateTime now) => !isExpired(now);
}

/// The hold on the seats of [tripId]; null when nothing is held.
final seatHoldProvider =
    NotifierProvider.family<SeatHoldController, SeatHold?, String>(
      SeatHoldController.new,
    );

class SeatHoldController extends Notifier<SeatHold?> {
  SeatHoldController(this.tripId);

  final String tripId;

  @override
  SeatHold? build() => null;

  void start(SeatLock lock) =>
      state = SeatHold(lockId: lock.lockId, expiresAt: lock.expiresAt);

  /// Forgets the hold (it was let go of, so the seats are free again).
  void clear() => state = null;

  void release() {
    final hold = state;
    if (hold == null) return;
    state = SeatHold(
      lockId: hold.lockId,
      expiresAt: hold.expiresAt,
      released: true,
    );
  }
}

/// "09:58": minutes and seconds left, always two digits each.
String formatHold(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// When the customer is back choosing seats, a hold they still have on this trip is let go of: the
/// seats are theirs again to change, not held out of reach (the server shows a held seat as taken,
/// even to the person holding it). Nothing to do when there is no live hold. A failed call is
/// not an error: the hold simply runs out by itself.
Future<bool> releaseHeldSeats({
  required SeatHold? hold,
  required DateTime now,
  required Future<void> Function(String lockId) release,
  required void Function() clear,
}) async {
  if (hold == null || !hold.isActive(now)) {
    if (hold != null) clear();
    return false;
  }
  clear();
  try {
    await release(hold.lockId);
  } on Object {
    // The hold runs out within ten minutes anyway
  }
  return true;
}
