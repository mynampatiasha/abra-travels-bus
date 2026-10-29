import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../app/providers.dart';
import '../../../routing/app_routes.dart';
import '../../my_trips/controllers/trips_controller.dart';
import '../../my_trips/models/trip_models.dart';

class ActiveTripBanner extends ConsumerWidget {
  const ActiveTripBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (auth is! AuthSignedIn) return const SizedBox.shrink();

    final bookingsAsync = ref.watch(myBookingsProvider);
    final bookings = bookingsAsync.value ?? const <Booking>[];

    // Find any running or delayed booking
    final running = bookings.where((b) {
      return b.status == BookingStatus.confirmed &&
          b.ticket.departureAt.isBefore(DateTime.now().add(const Duration(hours: 1))) &&
          b.ticket.arrivalAt.isAfter(DateTime.now());
    }).firstOrNull;

    if (running == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(
        left: AbraSpacing.md,
        right: AbraSpacing.md,
        bottom: AbraSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AbraSpacing.md),
        decoration: BoxDecoration(
          color: AbraColors.white,
          borderRadius: AbraRadius.large,
          border: Border.all(
            color: AbraColors.danger.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AbraColors.danger.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AbraSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AbraColors.dangerContainer,
                    borderRadius: AbraRadius.small,
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_bus, size: 14, color: AbraColors.danger),
                      SizedBox(width: 4),
                      Text(
                        'TRIP IN PROGRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AbraColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AbraColors.danger,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AbraSpacing.sm,
                      vertical: AbraSpacing.xs,
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 14),
                  label: const Text('SOS', style: TextStyle(fontSize: 12)),
                  onPressed: () => context.push(AppRoutes.myTripSafety(running.id)),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),
            Text(
              '${running.ticket.originName} → ${running.ticket.destinationName}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AbraColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${running.ticket.operatorName} • ${running.ticket.busTypeName}',
              style: const TextStyle(
                fontSize: 12,
                color: AbraColors.textSecondary,
              ),
            ),
            const SizedBox(height: AbraSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                side: const BorderSide(color: AbraColors.blue),
                foregroundColor: AbraColors.blue,
              ),
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text('Track bus location'),
              onPressed: () => context.push(AppRoutes.myTripTrack(running.id)),
            ),
          ],
        ),
      ),
    );
  }
}
