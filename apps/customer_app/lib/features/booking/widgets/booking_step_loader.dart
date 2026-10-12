import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../core/async_value_view.dart';
import '../../../core/ui/gradient_header.dart';
import '../../../core/ui/skeletons.dart';
import '../../../routing/app_routes.dart';
import '../controllers/booking_context.dart';
import '../controllers/seat_hold_controller.dart';

/// The app bar and a loading or failure body for a booking step whose data
/// has not arrived. Once it has, [builder] builds the real step.
class BookingStepLoader extends ConsumerWidget {
  const BookingStepLoader({
    required this.tripId,
    required this.title,
    required this.builder,
    super.key,
  });

  final String tripId;
  final String title;
  final Widget Function(BuildContext context, BookingContext booking) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(bookingContextProvider(tripId));
    final booking = value.value;
    if (booking != null) {
      final paid = ref.read(seatHoldProvider(tripId))?.released ?? false;
      if (booking.seats.isEmpty && paid) {
        // The booking is paid and the seats cleared: this page is on its
        // way out, so it must not send the customer back to the seats.
        return const SizedBox.shrink();
      }
      if (booking.seats.isEmpty) {
        // Nothing chosen (a link opened cold, seats booked meanwhile).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go(AppRoutes.tripSeats(tripId));
        });
      } else {
        return builder(context, booking);
      }
    }
    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: value.isLoading || booking != null
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(AbraSpacing.lg),
              child: CardListSkeleton(),
            )
          : AsyncValueView<BookingContext>(
              value: value,
              onRetry: () => ref.invalidate(bookingContextProvider(tripId)),
              data: (context, booking) => const SizedBox.shrink(),
            ),
    );
  }
}
