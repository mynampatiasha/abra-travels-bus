import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../../shell/app_shell.dart';
import '../discovery/controllers/search_form_controller.dart';
import '../discovery/controllers/travel_dates.dart';
import '../discovery/models/discovery_models.dart';
import '../unavailable/feature_unavailable_screen.dart';
import 'home_banners_repository.dart';

/// The promotional banners at the top of Home: one banner at a time, moving
/// on by itself every few seconds.
///
/// Phones show a 16:7 card with the phone picture; tablets and desktops a
/// 4:1 card, at most [maxWidth] wide and centred, with the wide picture.
/// Shows a skeleton while loading and nothing at all when there are no
/// banners or they could not be loaded, so Home looks as it always did.
/// Moves on only while Home is on screen and the app is in the foreground,
/// never while touched or hovered and never when the device asks for
/// reduced motion.
class HomeBannerCarousel extends ConsumerWidget {
  const HomeBannerCarousel({super.key});

  static const autoAdvanceInterval = Duration(seconds: 4);
  static const slideDuration = Duration(milliseconds: 400);

  /// Screens at least this wide show the wide banner.
  static const double wideFrom = 600;
  static const double phoneAspectRatio = 16 / 7;
  static const double wideAspectRatio = 4;
  static const double maxWidth = 1200;

  /// Space from the app bar above and the search hero below.
  static const _padding = EdgeInsets.only(
    top: AbraSpacing.lg,
    bottom: AbraSpacing.md,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(homeBannersProvider);
    if (banners.hasError) return const SizedBox.shrink();
    final list = banners.value;
    if (list != null && list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: _padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _BannerLayout.of(context, constraints.maxWidth);
          if (list == null) {
            return AbraSkeletonGroup(
              child: Padding(
                padding: layout.cardPadding,
                child: AbraSkeleton(
                  height: layout.cardHeight,
                  radius: AbraRadius.lg,
                ),
              ),
            );
          }
          return _BannerPager(
            // New banners start over at the first one.
            key: ValueKey<String>(list.map((banner) => banner.id).join('|')),
            banners: list,
            layout: layout,
          );
        },
      ),
    );
  }
}

/// Size and place of the banner on screen. Every page of the pager is as
/// wide as the carousel and holds its card centred between side paddings,
/// so no neighbour shows while the carousel is at rest.
@immutable
class _BannerLayout {
  const _BannerLayout({
    required this.isWide,
    required this.cardWidth,
    required this.cardHeight,
    required this.side,
  });

  factory _BannerLayout.of(BuildContext context, double available) {
    final isWide =
        MediaQuery.sizeOf(context).width >= HomeBannerCarousel.wideFrom;
    final gutter = AbraResponsive.gutter(context);
    final cardWidth = math.max(
      0.0,
      math.min(available - 2 * gutter, HomeBannerCarousel.maxWidth),
    );
    return _BannerLayout(
      isWide: isWide,
      cardWidth: cardWidth,
      cardHeight:
          cardWidth /
          (isWide
              ? HomeBannerCarousel.wideAspectRatio
              : HomeBannerCarousel.phoneAspectRatio),
      side: (available - cardWidth) / 2,
    );
  }

  final bool isWide;
  final double cardWidth;
  final double cardHeight;

  /// Space on each side of the card.
  final double side;

  /// Around the card in its page; the vertical part leaves room for the
  /// shadow.
  EdgeInsets get cardPadding =>
      EdgeInsets.fromLTRB(side, AbraSpacing.xxs, side, AbraSpacing.sm);

  double get pageHeight => cardHeight + AbraSpacing.xxs + AbraSpacing.sm;
}

/// Opens what [banner] links to. Bad or unknown link data does nothing (or
/// shows the not-built screen); it never throws.
Future<void> openBannerLink(
  BuildContext context,
  WidgetRef ref,
  HomeBanner banner,
) async {
  switch (banner.linkType) {
    case BannerLinkType.none:
      return;
    case BannerLinkType.routeSearch:
      await _searchRoute(context, ref, banner.linkValue);
    case BannerLinkType.screen:
      final path = _screens[_screenKey(banner.linkValue)];
      if (path == null) {
        _showUnavailable(context, CustomerStrings.homeBannerLinkTitle);
      } else if (AppShell.tabs.any((tab) => tab.path == path)) {
        context.go(path);
      } else {
        await context.push(path);
      }
    case BannerLinkType.offer:
      // Offers are not built yet.
      _showUnavailable(context, CustomerStrings.homeBannerOfferTitle);
    case BannerLinkType.url:
      final url = Uri.tryParse(banner.linkValue.trim());
      if (url == null || !url.isScheme('https') || url.host.isEmpty) return;
      bool opened;
      try {
        opened = await ref.read(externalUrlOpenerProvider)(url);
      } on Object {
        opened = false;
      }
      // No browser could be opened (none is wired yet): say so.
      if (!opened && context.mounted) {
        _showUnavailable(context, CustomerStrings.homeBannerLinkTitle);
      }
  }
}

/// Screens a SCREEN banner may open, by route name. `myTrips`,
/// `my-trips`, `MY_TRIPS` and `/my-trips` all name the same screen.
final Map<String, String> _screens = <String, String>{
  for (final path in const <String>[
    AppRoutes.home,
    AppRoutes.myTrips,
    AppRoutes.support,
    AppRoutes.profile,
    AppRoutes.search,
    AppRoutes.language,
    AppRoutes.settings,
    AppRoutes.womenSafety,
    AppRoutes.liveTracking,
  ])
    _screenKey(path): path,
};

String _screenKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

void _showUnavailable(BuildContext context, String titleKey) {
  // Above the shell, like every other not-built screen.
  unawaited(
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => FeatureUnavailableScreen(titleKey: titleKey),
      ),
    ),
  );
}

/// Runs the search for `fromCityId:toCityId` on the date chosen in the
/// form (today when that date can no longer be searched). City names the
/// app already knows (the form, recent searches) fill the form too; the
/// banner itself carries only ids.
Future<void> _searchRoute(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final parts = value.split(':');
  final id = RegExp(r'^[0-9a-fA-F]{24}$');
  if (parts.length != 2 ||
      !id.hasMatch(parts[0].trim()) ||
      !id.hasMatch(parts[1].trim()) ||
      parts[0].trim() == parts[1].trim()) {
    return;
  }
  final fromId = parts[0].trim();
  final toId = parts[1].trim();

  final form = ref.read(searchFormControllerProvider);
  final known = <City>[
    ?form.from,
    ?form.to,
    for (final recent in form.recent) ...<City>[recent.from, recent.to],
  ];
  City? find(String cityId) =>
      known.where((city) => city.id == cityId).firstOrNull;
  final from = find(fromId);
  final to = find(toId);
  final controller = ref.read(searchFormControllerProvider.notifier);
  if (from != null) controller.setFrom(from);
  if (to != null) controller.setTo(to);

  final now = ref.read(discoveryClockProvider)();
  final date = TravelDates.isSearchable(form.date, now)
      ? form.date
      : TravelDates.today(now);
  await context.push(
    AppRoutes.searchResultsFor(
      fromId: fromId,
      fromName: from?.name ?? '',
      toId: toId,
      toName: to?.name ?? '',
      date: TravelDates.format(date),
    ),
  );
}

class _BannerPager extends ConsumerStatefulWidget {
  const _BannerPager({required this.banners, required this.layout, super.key});

  final List<HomeBanner> banners;
  final _BannerLayout layout;

  @override
  ConsumerState<_BannerPager> createState() => _BannerPagerState();
}

class _BannerPagerState extends ConsumerState<_BannerPager> {
  /// The pager has no end: it starts this many rounds in, so the customer
  /// can swipe back from the first banner to the last.
  static const _rounds = 1000;

  late final int _count = widget.banners.length;
  late final bool _loops = _count > 1;
  late int _page = _loops ? _count * _rounds : 0;
  late final PageController _controller = PageController(initialPage: _page);
  late final AppLifecycleListener _lifecycle;

  Timer? _timer;
  bool _isTouched = false;
  bool _isHovered = false;
  bool _hasFocus = false;
  bool _isOnScreen = true;
  bool _isReduced = false;
  bool _isForeground = true;

  int get _current => _page % _count;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _isForeground = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _isForeground = state == AppLifecycleState.resumed;
        _schedule();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tickers are off while another tab is shown or a screen covers Home.
    _isOnScreen = TickerMode.of(context);
    _isReduced = AbraMotion.isReduced(context);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Starts the wait for the next banner over, or stops it when the
  /// carousel should stand still.
  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_loops || _isReduced || !_isOnScreen || !_isForeground) return;
    if (_isTouched || _isHovered) return;
    _timer = Timer(HomeBannerCarousel.autoAdvanceInterval, _advance);
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    unawaited(
      _controller.nextPage(
        duration: HomeBannerCarousel.slideDuration,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _goToPage(int target) {
    if (!_controller.hasClients) return;
    if (_isReduced) {
      _controller.jumpToPage(target);
    } else {
      unawaited(
        _controller.animateToPage(
          target,
          duration: HomeBannerCarousel.slideDuration,
          curve: Curves.easeInOut,
        ),
      );
    }
  }

  void _goTo(int index) => _goToPage(_page - _current + index);

  void _setTouched(bool value) {
    _isTouched = value;
    // Released: moves on again one interval later.
    _schedule();
  }

  void _setHovered(bool value) {
    setState(() => _isHovered = value);
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final layout = widget.layout;
    Widget pager = SizedBox(
      height: layout.pageHeight,
      child: PageView.builder(
        controller: _controller,
        itemCount: _loops ? null : 1,
        onPageChanged: (page) {
          setState(() => _page = page);
          _schedule();
        },
        itemBuilder: (context, page) {
          final banner = widget.banners[page % _count];
          return Padding(
            padding: layout.cardPadding,
            child: _BannerCard(
              banner: banner,
              isWide: layout.isWide,
              onOpen: () => unawaited(openBannerLink(context, ref, banner)),
            ),
          );
        },
      ),
    );
    if (_loops && layout.isWide) {
      pager = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _hasFocus = value),
        child: Stack(
          children: <Widget>[
            pager,
            _arrow(context, isNext: false),
            _arrow(context, isNext: true),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MouseRegion(
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: Listener(
            onPointerDown: (_) => _setTouched(true),
            onPointerUp: (_) => _setTouched(false),
            onPointerCancel: (_) => _setTouched(false),
            child: pager,
          ),
        ),
        if (_loops)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (var index = 0; index < _count; index++)
                _Dot(
                  isActive: index == _current,
                  isReduced: _isReduced,
                  label: l10n.text(
                    CustomerStrings.homeBannerPosition,
                    <String, Object?>{'current': index + 1, 'total': _count},
                  ),
                  onTap: () => _goTo(index),
                ),
            ],
          ),
      ],
    );
  }

  /// Previous or next on wide screens, shown on hover or keyboard focus.
  Widget _arrow(BuildContext context, {required bool isNext}) {
    final layout = widget.layout;
    final isVisible = _isHovered || _hasFocus;
    final material = MaterialLocalizations.of(context);
    final inset = layout.side + AbraSpacing.sm;
    return PositionedDirectional(
      start: isNext ? null : inset,
      end: isNext ? inset : null,
      top: AbraSpacing.xxs,
      height: layout.cardHeight,
      child: Center(
        child: AnimatedOpacity(
          opacity: isVisible ? 1 : 0,
          duration: _isReduced
              ? Duration.zero
              : const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: !isVisible,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: AbraColors.white.withValues(alpha: 0.9),
                foregroundColor: AbraColors.navy,
              ),
              tooltip: isNext
                  ? material.nextPageTooltip
                  : material.previousPageTooltip,
              icon: Icon(isNext ? Icons.chevron_right : Icons.chevron_left),
              onPressed: () => _goToPage(_page + (isNext ? 1 : -1)),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.isWide,
    required this.onOpen,
  });

  final HomeBanner banner;
  final bool isWide;
  final VoidCallback onOpen;

  /// Behind every banner: shown when there is no image, while it loads and
  /// when it fails.
  static const _fallback = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AbraColors.navy, AbraColors.blue, AbraColors.skyBlue],
    stops: <double>[0, 0.6, 1],
  );

  /// Share of a wide card the words may take, on its leading side.
  static const _wideTextShare = 0.55;

  bool get _hasLink => banner.linkType != BannerLinkType.none;

  @override
  Widget build(BuildContext context) {
    final subtitle = banner.subtitle;
    final image = banner.imageFor(isWide: isWide);
    final textAlignment = isWide
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.bottomStart;

    return Semantics(
      container: true,
      button: _hasLink,
      label: subtitle == null ? banner.title : '${banner.title}. $subtitle',
      onTap: _hasLink ? onOpen : null,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: AbraRadius.large,
          boxShadow: AbraShadows.card,
        ),
        child: ClipRRect(
          borderRadius: AbraRadius.large,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const DecoratedBox(
                decoration: BoxDecoration(gradient: _fallback),
              ),
              if (image != null)
                Image.network(
                  image.toString(),
                  // Fills the card without stretching, cropped evenly.
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, isSynchronous) =>
                      isSynchronous
                      ? child
                      : AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: AbraMotion.isReduced(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: child,
                        ),
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              // Darkens the side the words are on (the bottom on phones, the
              // leading side on wide screens) so white text stays readable
              // on any picture.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: isWide
                        ? AlignmentDirectional.centerStart
                        : Alignment.bottomCenter,
                    end: isWide
                        ? AlignmentDirectional.centerEnd
                        : Alignment.topCenter,
                    colors: <Color>[
                      AbraColors.navy.withValues(alpha: 0.88),
                      AbraColors.navy.withValues(alpha: 0.4),
                      AbraColors.navy.withValues(alpha: 0),
                    ],
                    stops: isWide
                        ? const <double>[0, 0.45, 0.75]
                        : const <double>[0, 0.55, 1],
                  ),
                ),
              ),
              if (_hasLink)
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onOpen, excludeFromSemantics: true),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? AbraSpacing.xxl : AbraSpacing.lg,
                  vertical: AbraSpacing.lg,
                ),
                // Scales the words down rather than overflowing on small
                // screens or with large text.
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: textAlignment,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: textAlignment,
                      child: SizedBox(
                        width: isWide
                            ? constraints.maxWidth * _wideTextShare
                            : constraints.maxWidth,
                        child: _words(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _words(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = banner.subtitle;
    final buttonText = banner.buttonText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Taps on the words open the banner (InkWell underneath); the label
        // above reads them.
        IgnorePointer(
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  banner.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (isWide ? textTheme.titleLarge : textTheme.titleMedium)
                      ?.copyWith(
                        color: AbraColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AbraSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (isWide ? textTheme.bodyMedium : textTheme.bodySmall)
                        ?.copyWith(color: AbraColors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Only a banner that opens something has a button.
        if (_hasLink && buttonText != null)
          Padding(
            padding: const EdgeInsets.only(top: AbraSpacing.xs),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AbraColors.white,
                foregroundColor: AbraColors.navy,
                shape: const StadiumBorder(),
                minimumSize: const Size(
                  AbraSizes.minTouchTarget,
                  AbraSizes.compactButtonHeight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
                // At least 48 x 48 to touch, whatever its drawn size.
                tapTargetSize: MaterialTapTargetSize.padded,
                textStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onOpen,
              child: Text(
                buttonText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}

/// One position dot: a wider blue pill for the banner shown.
class _Dot extends StatelessWidget {
  const _Dot({
    required this.isActive,
    required this.isReduced,
    required this.label,
    required this.onTap,
  });

  final bool isActive;
  final bool isReduced;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: isActive,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: AbraSpacing.xl,
        height: AbraSpacing.xxl,
        child: Center(
          child: AnimatedContainer(
            duration: isReduced
                ? Duration.zero
                : HomeBannerCarousel.slideDuration,
            curve: Curves.easeInOut,
            width: isActive ? AbraSpacing.lg + AbraSpacing.xs : AbraSpacing.sm,
            height: AbraSpacing.sm,
            decoration: BoxDecoration(
              color: isActive ? AbraColors.blue : AbraColors.border,
              borderRadius: const BorderRadius.all(
                Radius.circular(AbraRadius.pill),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
