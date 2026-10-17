import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/tonal_button.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../booking/controllers/url_launcher_provider.dart';
import 'controllers/tracking_controller.dart';
import 'models/tracking_models.dart';
import 'widgets/sos_hold_button.dart';
import 'widgets/tracking_map.dart';

/// Where the bus is: the map, when it arrives at the customer's stop, how
/// fresh the position is and who drives. A position older than three minutes
/// is shown as lost, never as live. Share trip and SOS are one tap away.
class LiveTrackingScreen extends ConsumerWidget {
  const LiveTrackingScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(trackingProvider(bookingId));
    final snapshot = value.value;
    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.trackTitle),
        subtitle: snapshot == null
            ? null
            : l10n.text(CustomerStrings.trackSubtitle, <String, Object?>{
                'operator': snapshot.operatorName,
                'bus': snapshot.busNumber,
              }),
      ),
      bottomNavigationBar: _TrackBar(bookingId: bookingId),
      body: value.when(
        data: (snapshot) =>
            _TrackBody(bookingId: bookingId, snapshot: snapshot),
        loading: () => const AbraLoadingView(),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(AbraSpacing.xxl),
            child: Text(
              'Not connected yet - built in Phase 5',
              style: TextStyle(color: AbraColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackBody extends ConsumerWidget {
  const _TrackBody({required this.bookingId, required this.snapshot});

  final String bookingId;
  final TrackingSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final now = ref.watch(secondTickProvider).value ?? DateTime.now();
    final stale = snapshot.isStale(now);
    final minutesAgo = now.difference(snapshot.lastPingAt).inMinutes;
    final spec = MapSpec(
      busProgress: snapshot.busProgress,
      stopProgress: snapshot.stopProgress,
      isStale: stale,
      stopLabel: snapshot.stopName,
      semanticsLabel: stale
          ? l10n.text(CustomerStrings.trackMapStale, <String, Object?>{
              'minutes': minutesAgo,
            })
          : l10n.text(CustomerStrings.trackMapLive, <String, Object?>{
              'minutes': snapshot.etaMinutes,
              'stop': snapshot.stopName,
            }),
    );

    final panel = _Panel(
      bookingId: bookingId,
      snapshot: snapshot,
      stale: stale,
      now: now,
    );

    if (CustomerLayout.hasTwoColumns(context) &&
        !CustomerLayout.isShort(context)) {
      // Wide: the map takes the space, the details sit beside it.
      return Row(
        children: <Widget>[
          Expanded(child: TrackingMap(spec: spec)),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AbraSpacing.lg),
              child: panel,
            ),
          ),
        ],
      );
    }
    final gutter = AbraResponsive.gutter(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AbraSpacing.lg,
            gutter,
            AbraSpacing.lg,
          ),
          children: <Widget>[
            if (stale) ...<Widget>[
              _StaleBanner(snapshot: snapshot, minutes: minutesAgo),
              const SizedBox(height: AbraSpacing.md),
            ],
            ClipRRect(
              borderRadius: AbraRadius.large,
              child: AspectRatio(
                aspectRatio: 360 / 250,
                child: TrackingMap(spec: spec),
              ),
            ),
            const SizedBox(height: AbraSpacing.md),
            _EtaCard(
              bookingId: bookingId,
              snapshot: snapshot,
              stale: stale,
              now: now,
            ),
            const SizedBox(height: AbraSpacing.md),
            _DriverCard(snapshot: snapshot),
          ],
        ),
      ),
    );
  }
}

/// The details beside the map on wide screens.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.bookingId,
    required this.snapshot,
    required this.stale,
    required this.now,
  });

  final String bookingId;
  final TrackingSnapshot snapshot;
  final bool stale;
  final DateTime now;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (stale) ...<Widget>[
        _StaleBanner(
          snapshot: snapshot,
          minutes: now.difference(snapshot.lastPingAt).inMinutes,
        ),
        const SizedBox(height: AbraSpacing.md),
      ],
      _EtaCard(
        bookingId: bookingId,
        snapshot: snapshot,
        stale: stale,
        now: now,
      ),
      const SizedBox(height: AbraSpacing.md),
      _DriverCard(snapshot: snapshot),
    ],
  );
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.snapshot, required this.minutes});

  final TrackingSnapshot snapshot;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final place = snapshot.lastKnownPlace;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7),
          borderRadius: AbraRadius.medium,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: Color(0xFF7A4B00),
              ),
              const SizedBox(width: AbraSpacing.sm),
              Expanded(
                child: Text(
                  place == null
                      ? l10n.text(
                          CustomerStrings.trackStaleBannerNoPlace,
                          <String, Object?>{'minutes': minutes},
                        )
                      : l10n.text(
                          CustomerStrings.trackStaleBanner,
                          <String, Object?>{'minutes': minutes, 'place': place},
                        ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7A4B00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtaCard extends ConsumerWidget {
  const _EtaCard({
    required this.bookingId,
    required this.snapshot,
    required this.stale,
    required this.now,
  });

  final String bookingId;
  final TrackingSnapshot snapshot;
  final bool stale;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final eta = stale
        ? l10n.text(CustomerStrings.trackEtaApprox, <String, Object?>{
            'from': snapshot.etaMinutes - 5,
            'to': snapshot.etaMinutes + 5,
          })
        : l10n.text(CustomerStrings.trackEtaMinutes, <String, Object?>{
            'minutes': snapshot.etaMinutes,
          });
    final seconds = now.difference(snapshot.lastPingAt).inSeconds;
    final age = stale
        ? l10n.text(CustomerStrings.trackLastSeen, <String, Object?>{
            'minutes': now.difference(snapshot.lastPingAt).inMinutes,
          })
        : snapshot.distanceKm == null
        ? l10n.text(CustomerStrings.trackLastUpdatedShort, <String, Object?>{
            'seconds': seconds < 0 ? 0 : seconds,
          })
        : l10n.text(CustomerStrings.trackLastUpdated, <String, Object?>{
            'seconds': seconds < 0 ? 0 : seconds,
            'distance': l10n.formatters.decimal(
              snapshot.distanceKm!,
              fractionDigits: 1,
            ),
          });
    final tone = stale
        ? AbraStatusTone.warning
        : snapshot.isDelayed
        ? AbraStatusTone.warning
        : AbraStatusTone.success;
    final badge = stale
        ? CustomerStrings.trackSignalLost
        : snapshot.isDelayed
        ? CustomerStrings.trackDelayed
        : CustomerStrings.trackOnTime;
    final color = tone == AbraStatusTone.success
        ? AbraColors.tealDark
        : AbraColors.orangeDark;

    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            container: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        stale
                            ? l10n.text(CustomerStrings.trackStaleEta)
                            : l10n.text(
                                CustomerStrings.trackArriving,
                                <String, Object?>{'stop': snapshot.stopName},
                              ),
                        style: textTheme.bodySmall,
                      ),
                      Text(
                        eta,
                        style: textTheme.headlineMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                AbraStatusBadge(label: l10n.text(badge), tone: tone),
              ],
            ),
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(age, style: textTheme.bodySmall),
          if (stale) ...<Widget>[
            const SizedBox(height: AbraSpacing.md),
            Wrap(
              spacing: AbraSpacing.md,
              runSpacing: AbraSpacing.sm,
              children: <Widget>[
                TonalButton(
                  label: l10n.text(CustomerStrings.trackCallOperator),
                  icon: Icons.call_rounded,
                  onPressed: snapshot.operatorPhone == null
                      ? null
                      : () => _call(ref, snapshot.operatorPhone!),
                ),
                AbraButton(
                  label: l10n.text(CustomerStrings.trackRetry),
                  icon: Icons.refresh_rounded,
                  variant: AbraButtonVariant.secondary,
                  onPressed: () => ref
                      .read(trackingProvider(bookingId).notifier)
                      .refresh(retry: true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _call(WidgetRef ref, String phone) => ref.read(
  urlLauncherProvider,
)(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')));

class _DriverCard extends ConsumerWidget {
  const _DriverCard({required this.snapshot});

  final TrackingSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      child: Row(
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AbraColors.lightBlue,
            ),
            child: Padding(
              padding: EdgeInsets.all(AbraSpacing.md),
              child: Icon(Icons.person_rounded, color: AbraColors.blue),
            ),
          ),
          const SizedBox(width: AbraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.text(CustomerStrings.trackDriver, <String, Object?>{
                    'driver': snapshot.driverName,
                  }),
                  style: textTheme.titleSmall,
                ),
                Text(
                  l10n.text(CustomerStrings.trackDriverLine, <String, Object?>{
                    'bus': snapshot.busNumber,
                    'type': snapshot.busTypeName,
                  }),
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (snapshot.driverPhone != null)
            IconButton.filled(
              tooltip: l10n.text(CustomerStrings.trackCallDriver),
              style: IconButton.styleFrom(
                backgroundColor: AbraColors.lightBlue,
                foregroundColor: AbraColors.blue,
                minimumSize: const Size.square(AbraSizes.minTouchTarget),
              ),
              onPressed: () => _call(ref, snapshot.driverPhone!),
              icon: const Icon(Icons.call_rounded),
            ),
        ],
      ),
    );
  }
}

/// "Share trip" and the red "SOS", always in reach.
class _TrackBar extends StatelessWidget {
  const _TrackBar({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final gutter = AbraResponsive.gutter(context);
    final share = TonalButton(
      label: l10n.text(CustomerStrings.trackShareTrip),
      icon: Icons.share_rounded,
      expand: true,
      onPressed: () => context.push(AppRoutes.myTripShare(bookingId)),
    );
    final sos = FilledButton(
      style: FilledButton.styleFrom(
        // The darker red keeps white text readable at this size.
        backgroundColor: SafetyColors.ring,
        foregroundColor: AbraColors.white,
        minimumSize: const Size(
          AbraSizes.minTouchTarget,
          AbraSizes.buttonHeight,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AbraRadius.medium),
      ),
      onPressed: () => context.push(AppRoutes.myTripSafety(bookingId)),
      child: Text(l10n.text(CustomerStrings.trackSos)),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.white,
        boxShadow: AbraShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                gutter,
                AbraSpacing.md,
                gutter,
                AbraSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(child: share),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(child: sos),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
