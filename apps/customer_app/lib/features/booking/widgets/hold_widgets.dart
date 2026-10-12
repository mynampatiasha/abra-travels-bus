import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../controllers/seat_hold_controller.dart';
import '../repositories/booking_repository.dart';

/// Rebuilds every second with the seconds left on the hold of [tripId], and
/// calls [onExpired] once when they run out. With no hold at all (a link
/// opened cold, the app restarted) the customer is sent back to the seats:
/// nothing in the booking steps works without held seats.
class HoldTicker extends ConsumerStatefulWidget {
  const HoldTicker({required this.tripId, required this.builder, super.key});

  final String tripId;
  final Widget Function(BuildContext context, int secondsLeft) builder;

  @override
  ConsumerState<HoldTicker> createState() => _HoldTickerState();
}

class _HoldTickerState extends ConsumerState<HoldTicker> {
  Timer? _timer;
  bool _expiredHandled = false;

  /// A hold was seen: a later "no hold" means somebody let go of it on
  /// purpose, not that the screen was opened cold.
  bool _sawHold = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hold = ref.watch(seatHoldProvider(widget.tripId));
    final now = ref.read(bookingClockProvider)();
    final left = hold?.secondsLeft(now) ?? 0;
    if (hold != null) _sawHold = true;
    // Let go of on purpose: nothing to watch and nowhere to send anyone.
    if (hold != null && hold.released) return widget.builder(context, 0);
    if ((hold == null && !_sawHold) || (hold != null && left == 0)) {
      if (!_expiredHandled) {
        _expiredHandled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go(
            hold == null
                ? AppRoutes.tripSeats(widget.tripId)
                : AppRoutes.tripHoldExpired(widget.tripId),
          );
        });
      }
    }
    return widget.builder(context, left);
  }
}

/// Watches the hold without showing it (sends the customer away when it
/// runs out).
class HoldWatcher extends StatelessWidget {
  const HoldWatcher({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context) => HoldTicker(
    tripId: tripId,
    builder: (context, left) => const SizedBox.shrink(),
  );
}

/// The countdown in the app bar: a clock and "09:58".
class HoldChip extends StatelessWidget {
  const HoldChip({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context) => HoldTicker(
    tripId: tripId,
    builder: (context, left) {
      final l10n = AbraLocalizations.of(context);
      final time = formatHold(left);
      return Semantics(
        label: l10n.text(CustomerStrings.holdChipSemantics, <String, Object?>{
          'time': time,
        }),
        excludeSemantics: true,
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: AbraSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AbraSpacing.md,
            vertical: AbraSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: AbraColors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AbraRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AbraColors.white,
              ),
              const SizedBox(width: AbraSpacing.xs + 2),
              Text(
                time,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AbraColors.white,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The amber banner "Seats held for 09:58. Pay before the timer ends."
class HoldBanner extends StatelessWidget {
  const HoldBanner({required this.tripId, this.messageKey, super.key});

  final String tripId;

  /// The sentence around the time; takes `{time}`.
  final String? messageKey;

  @override
  Widget build(BuildContext context) => HoldTicker(
    tripId: tripId,
    builder: (context, left) {
      final l10n = AbraLocalizations.of(context);
      final text = l10n.text(
        messageKey ?? CustomerStrings.holdBanner,
        <String, Object?>{'time': formatHold(left)},
      );
      return Semantics(
        container: true,
        liveRegion: false,
        label: text,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _bannerColor,
            borderRadius: AbraRadius.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AbraSpacing.md,
              vertical: AbraSpacing.md - 2,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: _bannerText,
                ),
                const SizedBox(width: AbraSpacing.sm),
                Expanded(
                  child: Text.rich(
                    _withBoldTime(
                      text,
                      formatHold(left),
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _bannerText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// [text] with the first [time] in bold.
  static TextSpan _withBoldTime(String text, String time, TextStyle? style) {
    final at = text.indexOf(time);
    if (at < 0) return TextSpan(text: text, style: style);
    return TextSpan(
      style: style,
      children: <InlineSpan>[
        TextSpan(text: text.substring(0, at)),
        TextSpan(
          text: time,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        TextSpan(text: text.substring(at + time.length)),
      ],
    );
  }

  static const Color _bannerColor = Color(0xFFFEF3C7);
  static const Color _bannerText = Color(0xFF7A4B00);
}
