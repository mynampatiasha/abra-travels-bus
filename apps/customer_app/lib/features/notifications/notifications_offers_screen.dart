import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/async_value_view.dart';
import '../../core/format/dates.dart';
import '../../core/ui/adaptive_sheet.dart';
import '../../core/ui/chips.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/illustration.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/skeletons.dart';
import '../../core/ui/tonal_button.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../authentication/gate/sign_in_intent.dart';
import '../booking/controllers/ticket_actions.dart';
import '../booking/repositories/booking_repository.dart';
import 'controllers/notifications_controller.dart';
import 'models/notification_models.dart';

String _ago(AbraLocalizations l10n, DateTime time, DateTime now) {
  final difference = now.difference(time);
  if (difference.inMinutes < 1) {
    return l10n.text(CustomerStrings.notifJustNow);
  }
  if (difference.inMinutes < 60) {
    return l10n.text(CustomerStrings.notifMinutesAgo, <String, Object?>{
      'count': difference.inMinutes,
    });
  }
  if (difference.inHours < 24) {
    return l10n.text(CustomerStrings.notifHoursAgo, <String, Object?>{
      'count': difference.inHours,
    });
  }
  if (difference.inDays < 7) {
    return l10n.text(CustomerStrings.notifDaysAgo, <String, Object?>{
      'count': difference.inDays,
    });
  }
  return formatDayMonth(l10n, time);
}

/// The notifications of the signed-in customer, grouped Today and Earlier,
/// filtered by kind. A guest is asked to log in before this opens (the
/// route needs an account). Tapping a notification marks it read and opens
/// what it is about.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final value = ref.watch(notificationsProvider);
    final filter = ref.watch(notificationFilterProvider);
    final unread = value.value?.where((item) => !item.read).length ?? 0;
    final gutter = AbraResponsive.gutter(context);

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.notifTitle),
        subtitle: (value.value?.isNotEmpty ?? false)
            ? l10n.text(CustomerStrings.notifUnread, <String, Object?>{
                'count': unread,
              })
            : null,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.text(CustomerStrings.notifOffersAction),
            icon: const Icon(Icons.sell_outlined),
            onPressed: () => context.push(AppRoutes.offers),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
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
              child: value.isLoading && !value.hasValue
                  ? const CardListSkeleton()
                  : AsyncValueView<List<NotificationItem>>(
                      value: value,
                      onRetry: () => ref.invalidate(notificationsProvider),
                      data: (context, items) => _NotificationList(
                        items: items,
                        filter: filter,
                        unread: unread,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({
    required this.items,
    required this.filter,
    required this.unread,
  });

  final List<NotificationItem> items;
  final NotificationCategory? filter;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final shown = filterNotifications(items, filter);
    final now = ref.read(bookingClockProvider)();
    final groups = groupByDay(shown, now);
    final selector = ref.read(notificationFilterProvider.notifier);

    Widget chip(NotificationCategory? value, String key) => SelectChip(
      label: l10n.text(key),
      selected: filter == value,
      onSelected: (_) => selector.select(value),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (items.isNotEmpty)
          Semantics(
            container: true,
            label: l10n.text(CustomerStrings.notifFilters),
            child: Wrap(
              spacing: AbraSpacing.sm,
              runSpacing: AbraSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                chip(null, CustomerStrings.notifFilterAll),
                chip(
                  NotificationCategory.booking,
                  CustomerStrings.notifFilterBooking,
                ),
                chip(
                  NotificationCategory.offers,
                  CustomerStrings.notifFilterOffers,
                ),
                chip(
                  NotificationCategory.safety,
                  CustomerStrings.notifFilterSafety,
                ),
              ],
            ),
          ),
        if (items.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: unread == 0
                  ? null
                  : () =>
                        ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(l10n.text(CustomerStrings.notifMarkAllRead)),
            ),
          ),
        const SizedBox(height: AbraSpacing.sm),
        if (shown.isEmpty)
          const _Empty()
        else ...<Widget>[
          if (groups.today.isNotEmpty)
            _Group(
              titleKey: CustomerStrings.notifToday,
              items: groups.today,
              now: now,
            ),
          if (groups.earlier.isNotEmpty)
            _Group(
              titleKey: CustomerStrings.notifEarlier,
              items: groups.earlier,
              now: now,
            ),
        ],
      ],
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({
    required this.titleKey,
    required this.items,
    required this.now,
  });

  final String titleKey;
  final List<NotificationItem> items;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AbraSpacing.xs,
              AbraSpacing.xs,
              AbraSpacing.xs,
              AbraSpacing.sm - 2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.text(titleKey),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (var i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  _NotificationTile(item: items[i], now: now),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item, required this.now});

  final NotificationItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final category = NotificationCategory.of(item.type);
    final (
      IconData icon,
      Color background,
      Color foreground,
    ) = switch (category) {
      NotificationCategory.booking => (
        Icons.confirmation_number_outlined,
        AbraColors.lightBlue,
        AbraColors.blue,
      ),
      NotificationCategory.offers => (
        Icons.sell_outlined,
        AbraColors.skyContainer,
        AbraColors.deepBlue,
      ),
      NotificationCategory.safety => (
        Icons.shield_outlined,
        AbraColors.tealContainer,
        AbraColors.tealDark,
      ),
    };
    final time = _ago(l10n, item.createdAt, now);

    void open() {
      ref.read(notificationsProvider.notifier).markRead(item);
      final route = item.route;
      if (route != null && SignInIntent.isInAppLocation(route)) {
        context.push(route);
      }
    }

    return Semantics(
      button: true,
      label:
          '${item.read ? '' : '${l10n.text(CustomerStrings.notifUnreadDot)}. '}'
          '${item.title}. ${item.body}. $time',
      excludeSemantics: true,
      onTap: open,
      child: InkWell(
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AbraSpacing.md + 2,
              vertical: AbraSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: AbraRadius.medium,
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Icon(icon, size: 20, color: foreground),
                  ),
                ),
                const SizedBox(width: AbraSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: item.read
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                      Text(item.body, style: textTheme.bodySmall),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(time, style: textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
                if (!item.read)
                  const Padding(
                    padding: EdgeInsets.only(
                      top: AbraSpacing.sm - 2,
                      left: AbraSpacing.sm,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AbraColors.blue,
                      ),
                      child: SizedBox.square(dimension: 10),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.lg,
        vertical: AbraSpacing.xxl,
      ),
      child: Column(
        children: <Widget>[
          const StateIllustration(icon: Icons.notifications_none_rounded),
          const SizedBox(height: AbraSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              l10n.text(CustomerStrings.notifEmptyTitle),
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            l10n.text(CustomerStrings.notifEmptyMessage),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          TextButton(
            onPressed: () =>
                ref.read(notificationFilterProvider.notifier).select(null),
            child: Text(l10n.text(CustomerStrings.notifShowAll)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- offers

/// Offers and promotions: a carousel of banners, then the offers with a
/// code to copy and their terms. Open to guests.
class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  String? _copied;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(Offer offer) async {
    final l10n = AbraLocalizations.of(context);
    await ref.read(copyTextProvider)(offer.code);
    if (!mounted) return;
    setState(() => _copied = offer.code);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = null);
    });
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            l10n.text(CustomerStrings.offersCodeCopied, <String, Object?>{
              'code': offer.code,
            }),
          ),
        ),
      );
  }

  Future<void> _terms(Offer offer) async {
    final l10n = AbraLocalizations.of(context);
    await showAdaptiveSheet<void>(
      context,
      builder: (context) => SheetScaffold(
        title: l10n.text(CustomerStrings.offersTermsTitle),
        onClose: () => Navigator.of(context).pop(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final line in offer.terms)
              Padding(
                padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: AbraSpacing.sm),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AbraColors.textSecondary,
                        ),
                        child: SizedBox.square(dimension: 5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        footer: AbraButton(
          label: l10n.text(CustomerStrings.offersGotIt),
          variant: AbraButtonVariant.primary,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showOffer(String code) {
    final context = _keys[code]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: AbraDurations.normal,
        alignment: 0.1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final offers = ref.watch(offersProvider);
    final banners = ref.watch(offerBannersProvider);
    final now = ref.read(bookingClockProvider)();
    final gutter = AbraResponsive.gutter(context);

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.offersTitle),
        subtitle: l10n.text(CustomerStrings.offersSubtitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(offersProvider)
            ..invalidate(offerBannersProvider);
          await ref.read(offersProvider.future);
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                gutter,
                AbraSpacing.lg,
                gutter,
                AbraSpacing.xl,
              ),
              child: offers.isLoading && !offers.hasValue
                  ? const CardListSkeleton()
                  : AsyncValueView<List<Offer>>(
                      value: offers,
                      onRetry: () => ref.invalidate(offersProvider),
                      data: (context, all) {
                        final valid = all
                            .where((offer) => offer.isValidOn(now))
                            .toList();
                        if (valid.isEmpty) return const _NoOffers();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (banners.value?.isNotEmpty ?? false) ...<Widget>[
                              _BannerCarousel(
                                banners: banners.value!
                                    .where(
                                      (b) => valid.any((o) => o.code == b.code),
                                    )
                                    .toList(),
                                onView: _showOffer,
                              ),
                              const SizedBox(height: AbraSpacing.lg),
                            ],
                            _OfferGrid(
                              offers: valid,
                              keys: _keys,
                              copied: _copied,
                              now: now,
                              onCopy: _copy,
                              onTerms: _terms,
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoOffers extends StatelessWidget {
  const _NoOffers();

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AbraSpacing.lg,
        vertical: AbraSpacing.xxl,
      ),
      child: Column(
        children: <Widget>[
          const StateIllustration(icon: Icons.sell_outlined),
          const SizedBox(height: AbraSpacing.lg),
          Text(
            l10n.text(CustomerStrings.offersEmptyTitle),
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall,
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            l10n.text(CustomerStrings.offersEmptyMessage),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable banners with page dots; "View offer" scrolls to the offer.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, required this.onView});

  final List<OfferBanner> banners;
  final ValueChanged<String> onView;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  PageController? _controller;
  double _fraction = 0.88;
  int _page = 0;

  static const _gradients = <LinearGradient>[
    AbraGradients.brand,
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[AbraColors.deepBlue, AbraColors.skyBlue],
    ),
    LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[AbraColors.navy, AbraColors.deepBlue],
    ),
  ];

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final banners = widget.banners;
    if (banners.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones show one banner with the next peeking in; wider spaces show
        // several of a fixed comfortable width.
        final fraction = banners.length == 1
            ? 1.0
            : (constraints.maxWidth < 600
                  ? 0.88
                  : (400 / constraints.maxWidth).clamp(0.3, 0.88));
        if (_controller == null || _fraction != fraction) {
          _controller?.dispose();
          _fraction = fraction;
          _controller = PageController(
            viewportFraction: fraction,
            initialPage: _page,
          );
        }
        final scale = MediaQuery.textScalerOf(context).scale(1);
        return Semantics(
          container: true,
          label: l10n.text(CustomerStrings.offersCarousel),
          child: Column(
            children: <Widget>[
              // Tall enough for the text at the chosen text size.
              SizedBox(
                height: 164 * scale.clamp(1.0, 1.5),
                child: PageView.builder(
                  controller: _controller,
                  padEnds: false,
                  itemCount: banners.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AbraSpacing.md,
                      ),
                      child: Semantics(
                        container: true,
                        label:
                            '${banner.title}. ${banner.subtitle}. '
                            '${l10n.text(CustomerStrings.offersCarouselPage, <String, Object?>{'page': index + 1, 'total': banners.length})}',
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient:
                                _gradients[banner.style % _gradients.length],
                            borderRadius: AbraRadius.large,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AbraSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        banner.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.titleLarge?.copyWith(
                                          color: AbraColors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: AbraSpacing.xs),
                                      Text(
                                        banner.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AbraColors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AbraColors.white,
                                    foregroundColor: AbraColors.navy,
                                    minimumSize: const Size(
                                      AbraSizes.minTouchTarget,
                                      AbraSizes.buttonHeight,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: AbraRadius.medium,
                                    ),
                                  ),
                                  onPressed: () => widget.onView(banner.code),
                                  child: Text(
                                    l10n.text(CustomerStrings.offersViewOffer),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (banners.length > 1) ...<Widget>[
                const SizedBox(height: AbraSpacing.sm),
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var i = 0; i < banners.length; i++)
                        AnimatedContainer(
                          duration: AbraDurations.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page
                                ? AbraColors.blue
                                : const Color(0xFFB7C4CF),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OfferGrid extends StatelessWidget {
  const _OfferGrid({
    required this.offers,
    required this.keys,
    required this.copied,
    required this.now,
    required this.onCopy,
    required this.onTerms,
  });

  final List<Offer> offers;
  final Map<String, GlobalKey> keys;
  final String? copied;
  final DateTime now;
  final ValueChanged<Offer> onCopy;
  final ValueChanged<Offer> onTerms;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // One column on phones, two from a comfortable width.
      final columns = constraints.maxWidth >= 640 ? 2 : 1;
      final width =
          (constraints.maxWidth - (columns - 1) * AbraSpacing.md) / columns;
      return Wrap(
        spacing: AbraSpacing.md,
        runSpacing: AbraSpacing.md,
        children: <Widget>[
          for (final offer in offers)
            SizedBox(
              width: width,
              child: _OfferCard(
                key: keys.putIfAbsent(offer.code, GlobalKey.new),
                offer: offer,
                copied: copied == offer.code,
                onCopy: () => onCopy(offer),
                onTerms: () => onTerms(offer),
              ),
            ),
        ],
      );
    },
  );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.copied,
    required this.onCopy,
    required this.onTerms,
    super.key,
  });

  final Offer offer;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AbraSpacing.md,
            runSpacing: AbraSpacing.sm,
            children: <Widget>[
              CustomPaint(
                painter: const _DashedBorder(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AbraSpacing.md,
                    vertical: AbraSpacing.sm - 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AbraColors.lightBlue,
                    borderRadius: AbraRadius.medium,
                  ),
                  child: Text(
                    offer.code,
                    style: textTheme.titleSmall?.copyWith(
                      color: AbraColors.deepBlue,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Semantics(
                label: l10n.text(
                  CustomerStrings.offersCopyCodeSemantics,
                  <String, Object?>{'code': offer.code},
                ),
                excludeSemantics: true,
                button: true,
                onTap: onCopy,
                child: TonalButton(
                  label: l10n.text(
                    copied
                        ? CustomerStrings.offersCopied
                        : CustomerStrings.offersCopy,
                  ),
                  icon: copied
                      ? Icons.check_rounded
                      : Icons.content_copy_rounded,
                  onPressed: onCopy,
                ),
              ),
            ],
          ),
          const SizedBox(height: AbraSpacing.sm),
          Text(
            offer.description,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AbraSpacing.xs),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                l10n.text(CustomerStrings.offersValidTill, <String, Object?>{
                  'date': formatDayMonth(l10n, offer.validTill),
                }),
                style: textTheme.bodySmall,
              ),
              TextButton(
                onPressed: onTerms,
                child: Text(l10n.text(CustomerStrings.offersTermsApply)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dashed blue outline of a coupon code.
class _DashedBorder extends CustomPainter {
  const _DashedBorder();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AbraRadius.md),
        ),
      );
    final paint = Paint()
      ..color = AbraColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => false;
}
