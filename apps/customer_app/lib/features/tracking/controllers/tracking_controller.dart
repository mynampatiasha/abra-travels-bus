import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/repositories/booking_repository.dart';
import '../models/tracking_models.dart';
import '../repositories/tracking_repositories.dart';

/// How often the bus position is asked for while the screen is open.
const trackingPollEvery = Duration(seconds: 10);

/// The position of the bus of a booking. Reloads itself every
/// [trackingPollEvery]; an answer that fails keeps the last position (the
/// screen then shows how old it is) instead of clearing the screen.
final trackingProvider = AsyncNotifierProvider.autoDispose
    .family<TrackingController, TrackingSnapshot, String>(
      TrackingController.new,
    );

class TrackingController extends AsyncNotifier<TrackingSnapshot> {
  TrackingController(this.bookingId);

  final String bookingId;

  @override
  Future<TrackingSnapshot> build() {
    final timer = Timer.periodic(trackingPollEvery, (_) => refresh());
    ref.onDispose(timer.cancel);
    return ref.read(trackingRepositoryProvider).snapshot(bookingId);
  }

  /// Asks again. [retry] is the customer pressing "Retry" on a lost signal.
  Future<void> refresh({bool retry = false}) async {
    final previous = state.value;
    try {
      final next = await ref
          .read(trackingRepositoryProvider)
          .snapshot(bookingId, retry: retry);
      if (ref.mounted) state = AsyncData<TrackingSnapshot>(next);
    } on Object catch (error, stack) {
      if (!ref.mounted) return;
      // Keep what is on screen; only a first load can fail visibly.
      if (previous == null) state = AsyncError<TrackingSnapshot>(error, stack);
    }
  }
}

/// The current time once a second, for "last updated 12 s ago" and for the
/// moment a position becomes too old.
final secondTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.read(bookingClockProvider);
  final controller = StreamController<DateTime>();
  controller.add(clock());
  final timer = Timer.periodic(
    const Duration(seconds: 1),
    (_) => controller.add(clock()),
  );
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
