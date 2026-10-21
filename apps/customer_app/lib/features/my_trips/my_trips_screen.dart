import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';
import '../../core/ui/chips.dart';
import '../../core/ui/guest_prompt_card.dart';
import '../../core/ui/illustration.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/skeletons.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../authentication/gate/require_sign_in.dart';
import '../authentication/gate/sign_in_intent.dart';
import '../booking/repositories/booking_repository.dart';
import 'controllers/trips_controller.dart';
import 'models/trip_models.dart';
import 'widgets/booking_card.dart';

/// The My trips tab. Guests see why to sign in and a button for it (not an
/// error); signed-in customers see their bookings in three lists.
class MyTripsScreen extends ConsumerWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    return switch (ref.watch(authStateProvider)) {
      AuthSignedIn() => const _TripsBody(),
      // The stored session is still being checked.
      AuthUnknown() => const AbraLoadingView(),
      AuthSignedOut() => GuestPromptCard(
        icon: Icons.confirmation_number_outlined,
        title: l10n.text(CustomerStrings.myTripsGuestTitle),
        message: l10n.text(CustomerStrings.myTripsGuestMessage),
        actionLabel: l10n.text(CustomerStrings.gateAction),
        onAction: () => requireSignIn(
          context,
          const SignInIntent(returnLocation: AppRoutes.myTrips),
        ),
      ),
    };
  }
}

class _TripsBody extends ConsumerWidget {
  const _TripsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(myBookingsProvider);
    final kind = ref.watch(tripListKindProvider);
    final gutter = AbraResponsive.gutter(context);

    final Widget content = value.isLoading && !value.hasValue
        ? const CardListSkeleton()
        : AsyncValueView<List<Booking>>(
            value: value,
            onRetry: () => ref.invalidate(myBookingsProvider),
            data: (context, all) => _Lists(all: all, kind: kind),
          );

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myBookingsProvider.future),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: CustomerLayout.listMaxWidth,
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              gutter,
              AbraSpacing.lg,
              gutter,
              AbraSpacing.xl,
            ),
            child: Semantics(
              label: l10n.text(CustomerStrings.tripsTabsLabel),
              container: true,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _Lists extends ConsumerWidget {
  const _Lists({required this.all, required this.kind});

  final List<Booking> all;
  final TripListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final now = ref.read(bookingClockProvider)();
    final upcoming = bookingsOfKind(all, TripListKind.upcoming);
    final completed = bookingsOfKind(all, TripListKind.completed);
    final cancelled = bookingsOfKind(all, TripListKind.cancelled);
    final shown = switch (kind) {
      TripListKind.upcoming => upcoming,
      TripListKind.completed => completed,
      TripListKind.cancelled => cancelled,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentTabs<TripListKind>(
          segments: <(TripListKind, String)>[
            (
              TripListKind.upcoming,
              l10n.text(CustomerStrings.tripsTabUpcoming, <String, Object?>{
                'count': upcoming.length,
              }),
            ),
            (
              TripListKind.completed,
              l10n.text(CustomerStrings.tripsTabCompleted, <String, Object?>{
                'count': completed.length,
              }),
            ),
            (
              TripListKind.cancelled,
              l10n.text(CustomerStrings.tripsTabCancelled, <String, Object?>{
                'count': cancelled.length,
              }),
            ),
          ],
          selected: kind,
          onChanged: ref.read(tripListKindProvider.notifier).select,
        ),
        const SizedBox(height: AbraSpacing.md),
        if (shown.isEmpty)
          _EmptyList(kind: kind)
        else
          for (final booking in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AbraSpacing.md),
              child: BookingCard(
                booking: booking,
                now: now,
                onTap: () => context.push(
                  booking.status == BookingStatus.cancelled
                      ? AppRoutes.myTripRefund(booking.id)
                      : AppRoutes.myTrip(booking.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _EmptyList extends ConsumerWidget {
  const _EmptyList({required this.kind});

  final TripListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final (String title, String message) = switch (kind) {
      TripListKind.upcoming => (
        CustomerStrings.tripsEmptyUpcomingTitle,
        CustomerStrings.tripsEmptyUpcomingMessage,
      ),
      TripListKind.completed => (
        CustomerStrings.tripsEmptyCompletedTitle,
        CustomerStrings.tripsEmptyCompletedMessage,
      ),
      TripListKind.cancelled => (
        CustomerStrings.tripsEmptyCancelledTitle,
        CustomerStrings.tripsEmptyCancelledMessage,
      ),
    };
    final upcomingList = kind == TripListKind.upcoming;
    return AbraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.lg,
        vertical: AbraSpacing.xxl,
      ),
      child: Column(
        children: <Widget>[
          const StateIllustration(icon: Icons.directions_bus_outlined),
          const SizedBox(height: AbraSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              l10n.text(title),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            'Not connected yet - built in Phase 4',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          TextButton(
            onPressed: () => upcomingList
                ? context.go(AppRoutes.home)
                : ref
                      .read(tripListKindProvider.notifier)
                      .select(TripListKind.upcoming),
            child: Text(
              l10n.text(
                upcomingList
                    ? CustomerStrings.tripsSearchBuses
                    : CustomerStrings.tripsViewUpcoming,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
