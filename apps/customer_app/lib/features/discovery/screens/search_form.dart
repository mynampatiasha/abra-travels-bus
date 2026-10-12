import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/brand_photo.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../../home/home_banner_carousel.dart';
import '../../home/home_banners_repository.dart';
import '../controllers/search_form_controller.dart';
import '../controllers/travel_dates.dart';
import '../models/discovery_models.dart';
import '../widgets/discovery_text.dart';

/// The search form with the recently searched routes: the content of the
/// Home section and of `/search`.
class SearchFormView extends ConsumerWidget {
  const SearchFormView({this.showBanners = true, super.key});

  /// The banner carousel on top, with pull-to-refresh: Home only.
  final bool showBanners;

  static const _problemMessages = <SearchFormProblem, String>{
    SearchFormProblem.originRequired: CustomerStrings.searchErrorOriginRequired,
    SearchFormProblem.destinationRequired:
        CustomerStrings.searchErrorDestinationRequired,
    SearchFormProblem.sameCity: CustomerStrings.searchErrorSameCity,
    SearchFormProblem.dateOutOfRange: CustomerStrings.searchErrorDate,
  };

  Future<void> _pickCity(
    BuildContext context,
    WidgetRef ref, {
    required bool isOrigin,
  }) async {
    final city = await context.push<City>(
      Uri(
        path: AppRoutes.cityPicker,
        queryParameters: <String, String>{'field': isOrigin ? 'from' : 'to'},
      ).toString(),
    );
    if (city == null) return;
    final controller = ref.read(searchFormControllerProvider.notifier);
    isOrigin ? controller.setFrom(city) : controller.setTo(city);
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final now = ref.read(discoveryClockProvider)();
    final form = ref.read(searchFormControllerProvider);
    final first = TravelDates.asLocalDate(TravelDates.today(now));
    final last = TravelDates.asLocalDate(TravelDates.lastSearchable(now));
    final current = TravelDates.asLocalDate(form.date);
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: current.isBefore(first) || current.isAfter(last)
          ? first
          : current,
    );
    if (picked != null) {
      ref.read(searchFormControllerProvider.notifier).setDate(picked);
    }
  }

  Future<void> _search(BuildContext context, WidgetRef ref) async {
    final search = await ref
        .read(searchFormControllerProvider.notifier)
        .submit();
    if (search == null || !context.mounted) return;
    await context.push(
      AppRoutes.searchResultsFor(
        fromId: search.from.id,
        fromName: search.from.name,
        toId: search.to.id,
        toName: search.to.name,
        date: TravelDates.format(search.date),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final textTheme = Theme.of(context).textTheme;
    final form = ref.watch(searchFormControllerProvider);
    final controller = ref.read(searchFormControllerProvider.notifier);
    final problems = form.showProblems
        ? controller.problems
        : const <SearchFormProblem>[];
    final today = TravelDates.today(ref.read(discoveryClockProvider)());
    final tomorrow = today.add(const Duration(days: 1));

    String? problemFor(Set<SearchFormProblem> relevant) {
      final problem = problems.where(relevant.contains).firstOrNull;
      return problem == null ? null : l10n.text(_problemMessages[problem]!);
    }

    final gutter = AbraResponsive.gutter(context);
    final isWide = AbraBreakpoint.of(context) == AbraBreakpoint.desktop;

    Widget centered(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );

    final searchCard = DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.white,
        borderRadius: AbraRadius.large,
        boxShadow: AbraShadows.raised,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // From and To as one pair, with the swap button between them.
            Stack(
              alignment: AlignmentDirectional.centerEnd,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _FormField(
                      label: l10n.text(CustomerStrings.searchFromLabel),
                      value: form.from?.name,
                      hint: l10n.text(CustomerStrings.searchFromHint),
                      icon: Icons.trip_origin,
                      error: problemFor(const {
                        SearchFormProblem.originRequired,
                      }),
                      onTap: () => _pickCity(context, ref, isOrigin: true),
                    ),
                    const SizedBox(height: AbraSpacing.md),
                    _FormField(
                      label: l10n.text(CustomerStrings.searchToLabel),
                      value: form.to?.name,
                      hint: l10n.text(CustomerStrings.searchToHint),
                      icon: Icons.location_on_outlined,
                      error: problemFor(const {
                        SearchFormProblem.destinationRequired,
                        SearchFormProblem.sameCity,
                      }),
                      onTap: () => _pickCity(context, ref, isOrigin: false),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AbraSpacing.md,
                  ),
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AbraColors.lightBlue,
                      foregroundColor: AbraColors.blueDark,
                      disabledBackgroundColor: AbraColors.lightGray,
                      side: const BorderSide(color: AbraColors.white, width: 3),
                    ),
                    icon: const Icon(Icons.swap_vert),
                    tooltip: l10n.text(CustomerStrings.searchSwap),
                    onPressed: form.from == null && form.to == null
                        ? null
                        : controller.swap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.md),
            _FormField(
              label: l10n.text(CustomerStrings.searchDateLabel),
              value: text.date(form.date),
              hint: '',
              icon: Icons.calendar_today_outlined,
              error: problemFor(const {SearchFormProblem.dateOutOfRange}),
              onTap: () => _pickDate(context, ref),
            ),
            const SizedBox(height: AbraSpacing.sm),
            Wrap(
              spacing: AbraSpacing.sm,
              children: <Widget>[
                ChoiceChip(
                  label: Text(l10n.text(CustomerStrings.searchToday)),
                  selected: form.date == today,
                  onSelected: (_) => controller.setDate(today),
                ),
                ChoiceChip(
                  label: Text(l10n.text(CustomerStrings.searchTomorrow)),
                  selected: form.date == tomorrow,
                  onSelected: (_) => controller.setDate(tomorrow),
                ),
              ],
            ),
            const SizedBox(height: AbraSpacing.lg),
            AbraButton(
              label: l10n.text(CustomerStrings.searchButton),
              icon: Icons.search,
              variant: AbraButtonVariant.callToAction,
              expand: true,
              onPressed: () => _search(context, ref),
            ),
          ],
        ),
      ),
    );

    final content = ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        if (showBanners) centered(const HomeBannerCarousel()),
        // The hero: the question, and the search itself on the brand colours.
        AbraBrandSurface(
          gradient: AbraGradients.brandDeep,
          showMotif: false,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AbraRadius.xl),
          ),
          child: Stack(
            children: <Widget>[
              // The bus photograph across the top of the hero, fading into
              // the brand colour so the words on it stay readable.
              Positioned.fill(child: _HeroPhoto(isWide: isWide)),
              Padding(
                padding: const EdgeInsets.only(
                  top: AbraSpacing.xl,
                  bottom: AbraSpacing.xl,
                ),
                child: centered(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          l10n.text(CustomerStrings.homeHeading),
                          style: textTheme.headlineSmall?.copyWith(
                            color: AbraColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AbraSpacing.xs),
                      Text(
                        l10n.text(CustomerStrings.homeSubtitle),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AbraColors.white,
                        ),
                      ),
                      SizedBox(
                        height: isWide
                            ? AbraSpacing.xl
                            : _heroPhotoHeight * 0.42,
                      ),
                      AbraEntrance(child: searchCard),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (form.recent.isNotEmpty) ...<Widget>[
          const SizedBox(height: AbraSpacing.xl),
          centered(
            Semantics(
              header: true,
              child: Text(
                l10n.text(CustomerStrings.searchRecentTitle),
                style: textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: AbraSpacing.sm),
          for (final (index, recent) in form.recent.indexed)
            centered(
              Padding(
                padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
                child: AbraEntrance(
                  index: index,
                  child: Material(
                    color: AbraColors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AbraRadius.medium,
                      side: BorderSide(color: AbraColors.divider),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      minTileHeight: AbraSizes.minTouchTarget,
                      leading: const Icon(
                        Icons.history,
                        color: AbraColors.blueDark,
                      ),
                      title: Text(
                        text.route(recent.from.name, recent.to.name),
                        style: textTheme.bodyLarge,
                      ),
                      trailing: const ExcludeSemantics(
                        child: Icon(
                          Icons.north_west,
                          size: AbraSizes.iconSmall,
                          color: AbraColors.textSecondary,
                        ),
                      ),
                      onTap: () => controller.useRecent(recent),
                    ),
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: AbraSpacing.xl),
        centered(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  l10n.text(CustomerStrings.homeTrustTitle),
                  style: textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              for (final (icon, key) in const <(IconData, String)>[
                (Icons.verified_outlined, CustomerStrings.homeTrustOperators),
                (Icons.sell_outlined, CustomerStrings.homeTrustFares),
                (Icons.schedule_outlined, CustomerStrings.homeTrustPoints),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: AbraColors.lightBlue,
                            borderRadius: AbraRadius.medium,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AbraSpacing.sm),
                            child: Icon(
                              icon,
                              color: AbraColors.blueDark,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.text(key),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AbraSpacing.xl),
      ],
    );
    if (!showBanners) return content;
    return RefreshIndicator(
      // A failed reload hides the banners; it is not an error of Home.
      onRefresh: () => ref
          .refresh(homeBannersProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
      child: content,
    );
  }

  static const double _contentWidth = 560;
  static const double _heroPhotoHeight = 250;
}

/// The bus photograph in the hero, dissolving into the brand colour so it
/// has no edge and the words on it stay readable.
///
/// Phone and tablet: across the top, behind the heading. Desktop: the
/// trailing half, beside the search card (a portrait photograph stretched
/// across a wide screen would show only a slice of the bus).
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 1,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: AlignmentDirectional.centerStart.resolve(
                Directionality.of(context),
              ),
              end: AlignmentDirectional.centerEnd.resolve(
                Directionality.of(context),
              ),
              colors: const <Color>[Color(0x00FFFFFF), Color(0xFFFFFFFF)],
              stops: const <double>[0.04, 0.5],
            ).createShader(bounds),
            child: const BrandPhoto(alignment: BrandPhoto.busAlignment),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: SearchFormView._heroPhotoHeight,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            stops: <double>[0.55, 1],
          ).createShader(bounds),
          child: const Stack(
            fit: StackFit.expand,
            children: <Widget>[
              BrandPhoto(alignment: BrandPhoto.busAlignment),
              // Darker at the top, where the heading is.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xE6071E3D), Color(0x00071E3D)],
                    stops: <double>[0, 0.6],
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

/// `/search`: the search form as a screen of its own.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        AbraLocalizations.of(context).text(CustomerStrings.routeSearchTitle),
      ),
    ),
    body: const SearchFormView(showBanners: false),
  );
}

/// A tappable field that opens a picker, with its error underneath.
class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.error,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value != null && value!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: '$label, ${hasValue ? value : hint}',
          child: InkWell(
            onTap: onTap,
            borderRadius: AbraRadius.medium,
            child: ExcludeSemantics(
              child: InputDecorator(
                isEmpty: !hasValue,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  prefixIcon: Icon(icon),
                  errorText: error == null ? null : '',
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                ),
                child: hasValue
                    ? Text(
                        value!,
                        style: theme.textTheme.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AbraSpacing.md,
              top: AbraSpacing.xs,
            ),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
