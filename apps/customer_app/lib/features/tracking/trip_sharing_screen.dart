import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/tonal_button.dart';
import '../../l10n/customer_strings.dart';
import '../booking/controllers/ticket_actions.dart';
import '../booking/controllers/url_launcher_provider.dart';
import '../booking/repositories/booking_repository.dart';
import 'controllers/safety_controllers.dart';
import 'models/tracking_models.dart';

/// Lets family follow the journey: a link with WhatsApp, SMS and copy, who
/// has opened it, and a way to stop at once.
class TripSharingScreen extends ConsumerStatefulWidget {
  const TripSharingScreen({required this.bookingId, super.key});

  final String bookingId;

  @override
  ConsumerState<TripSharingScreen> createState() => _TripSharingScreenState();
}

class _TripSharingScreenState extends ConsumerState<TripSharingScreen> {
  bool _busy = false;

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(duration: const Duration(seconds: 2), content: Text(message)),
    );

  Future<void> _toggle(bool start) async {
    if (_busy) return;
    final l10n = AbraLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final controller = ref.read(
        shareStateProvider(widget.bookingId).notifier,
      );
      await (start ? controller.start() : controller.stop());
      if (!mounted) return;
      _toast(
        l10n.text(
          start ? CustomerStrings.shareStarted : CustomerStrings.shareStopped,
        ),
      );
    } on Object {
      if (mounted) _toast(l10n.text(AbraStrings.stateErrorMessage));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(AbraLocalizations l10n, ShareState state) => l10n.text(
    CustomerStrings.shareMessage,
    <String, Object?>{'url': 'https://${state.url}'},
  );

  Future<void> _copy(ShareState state) async {
    final l10n = AbraLocalizations.of(context);
    await ref.read(copyTextProvider)('https://${state.url}');
    if (mounted) _toast(l10n.text(CustomerStrings.shareLinkCopied));
  }

  Future<void> _open(Uri uri) async {
    final l10n = AbraLocalizations.of(context);
    final opened = await ref.read(urlLauncherProvider)(uri);
    if (!opened && mounted) {
      _toast(l10n.text(CustomerStrings.shareOpenFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(shareStateProvider(widget.bookingId));
    final state = value.value;
    final gutter = AbraResponsive.gutter(context);
    final now = ref.read(bookingClockProvider)();

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.shareTitle),
        subtitle: l10n.text(CustomerStrings.shareSubtitle),
      ),
      bottomNavigationBar: state == null
          ? null
          : DecoratedBox(
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
                      child: state.isActive
                          ? AbraButton(
                              label: l10n.text(CustomerStrings.shareStop),
                              variant: AbraButtonVariant.secondary,
                              expand: true,
                              isLoading: _busy,
                              onPressed: () => _toggle(false),
                            )
                          : AbraButton(
                              label: l10n.text(CustomerStrings.shareStart),
                              variant: AbraButtonVariant.primary,
                              expand: true,
                              isLoading: _busy,
                              onPressed: () => _toggle(true),
                            ),
                    ),
                  ),
                ),
              ),
            ),
      body: AsyncValueView<ShareState>(
        value: value,
        onRetry: () => ref.invalidate(shareStateProvider(widget.bookingId)),
        data: (context, state) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: AbraResponsive.pagePadding(context),
              children: <Widget>[
                _Banner(state: state),
                const SizedBox(height: AbraSpacing.md),
                _LinkCard(
                  state: state,
                  onCopy: () => _copy(state),
                  onWhatsapp: () => _open(
                    Uri.https('wa.me', '/', <String, String>{
                      'text': _message(l10n, state),
                    }),
                  ),
                  onSms: () => _open(
                    Uri(
                      scheme: 'sms',
                      queryParameters: <String, String>{
                        'body': _message(l10n, state),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AbraSpacing.md),
                _PeopleCard(state: state, now: now),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.state});

  final ShareState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final on = state.isActive;
    final ends = state.endsAt;
    final time = ends == null ? '' : l10n.formatters.time(ends.toLocal());
    final text = on
        ? state.people.isEmpty
              ? l10n.text(
                  CustomerStrings.shareOnBannerNobody,
                  <String, Object?>{'time': time},
                )
              : l10n.text(CustomerStrings.shareOnBanner, <String, Object?>{
                  'count': state.people.length,
                  'time': time,
                })
        : l10n.text(CustomerStrings.shareOffBanner);
    final foreground = on ? AbraColors.tealDark : const Color(0xFF7A4B00);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: on ? AbraColors.tealContainer : const Color(0xFFFEF3C7),
          borderRadius: AbraRadius.medium,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                on ? Icons.share_rounded : Icons.info_outline_rounded,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: AbraSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
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

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.state,
    required this.onCopy,
    required this.onWhatsapp,
    required this.onSms,
  });

  final ShareState state;
  final VoidCallback onCopy;
  final VoidCallback onWhatsapp;
  final VoidCallback onSms;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final on = state.isActive;
    return AbraCard(
      child: Opacity(
        opacity: on ? 1 : 0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.text(CustomerStrings.shareLinkTitle),
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AbraSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    state.url ?? 'abra.in/t/…',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: l10n.text(CustomerStrings.shareCopyLink),
                  style: IconButton.styleFrom(
                    backgroundColor: AbraColors.lightBlue,
                    foregroundColor: AbraColors.blue,
                    minimumSize: const Size.square(AbraSizes.minTouchTarget),
                  ),
                  onPressed: on ? onCopy : null,
                  icon: const Icon(Icons.content_copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.sm),
            Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.sm,
              children: <Widget>[
                TonalButton(
                  label: l10n.text(CustomerStrings.shareWhatsapp),
                  icon: Icons.chat_rounded,
                  onPressed: on ? onWhatsapp : null,
                ),
                TonalButton(
                  label: l10n.text(CustomerStrings.shareSms),
                  icon: Icons.sms_rounded,
                  onPressed: on ? onSms : null,
                ),
                TonalButton(
                  label: l10n.text(CustomerStrings.shareCopyLink),
                  icon: Icons.link_rounded,
                  onPressed: on ? onCopy : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({required this.state, required this.now});

  final ShareState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final people = state.isActive ? state.people : const <SharePerson>[];
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.text(CustomerStrings.sharePeople),
              style: textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.xs),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
              child: Text(
                l10n.text(CustomerStrings.sharePeopleNone),
                style: textTheme.bodyMedium,
              ),
            ),
          for (final person in people)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(person.name, style: textTheme.titleSmall),
                        Text(
                          person.viewedAt == null
                              ? l10n.text(CustomerStrings.sharePersonNotOpened)
                              : l10n.text(
                                  CustomerStrings.sharePersonViewed,
                                  <String, Object?>{
                                    'minutes': now
                                        .difference(person.viewedAt!)
                                        .inMinutes,
                                  },
                                ),
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.link_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
