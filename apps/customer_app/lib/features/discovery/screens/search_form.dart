import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_notifications/shared_notifications.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../../authentication/gate/require_sign_in.dart';
import '../../authentication/gate/sign_in_intent.dart';
import '../../home/home_banners_repository.dart';
import '../../home/widgets/active_trip_banner.dart';
import '../../home/widgets/home_offers_slider.dart';
import '../../home/widgets/home_promo_banners.dart';
import '../../home/widgets/popular_routes_section.dart';
import '../controllers/search_form_controller.dart';
import '../controllers/travel_dates.dart';
import '../models/discovery_models.dart';
import '../widgets/discovery_text.dart';

/// The search form with the recently searched routes: the content of the
/// Home section and of `/search`.
class SearchFormView extends ConsumerWidget {
  const SearchFormView({this.showBanners = true, super.key});

  /// The promotional sections: Home only.
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
    final auth = ref.watch(authStateProvider);
    final center = auth is AuthSignedIn
        ? ref.watch(appDependenciesProvider).notifications
        : null;

    String? problemFor(Set<SearchFormProblem> relevant) {
      final problem = problems.where(relevant.contains).firstOrNull;
      return problem == null ? null : l10n.text(_problemMessages[problem]!);
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTabletOrDesktop = screenWidth >= 720;
    final contentMaxWidth = screenWidth >= 1100 ? 1040.0 : (screenWidth >= 800 ? 760.0 : 560.0);
    final gutter = AbraResponsive.gutter(context);

    Widget centered(Widget child, {double? maxWidth}) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );

    final searchCard = DecoratedBox(
      decoration: BoxDecoration(
        color: AbraColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1412304A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.md),
        child: isTabletOrDesktop
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: _FormField(
                          label: l10n.text(CustomerStrings.searchFromLabel),
                          value: form.from?.name,
                          hint: l10n.text(CustomerStrings.searchFromHint),
                          icon: Icons.location_on_outlined,
                          error: problemFor(const {
                            SearchFormProblem.originRequired,
                          }),
                          onTap: () => _pickCity(context, ref, isOrigin: true),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AbraColors.white,
                            foregroundColor: AbraColors.blue,
                            disabledBackgroundColor: AbraColors.lightGray,
                            side: const BorderSide(color: AbraColors.divider, width: 1.5),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: l10n.text(CustomerStrings.searchSwap),
                          onPressed: form.from == null && form.to == null
                              ? null
                              : controller.swap,
                        ),
                      ),
                      Expanded(
                        child: _FormField(
                          label: l10n.text(CustomerStrings.searchToLabel),
                          value: form.to?.name,
                          hint: l10n.text(CustomerStrings.searchToHint),
                          icon: Icons.outlined_flag,
                          error: problemFor(const {
                            SearchFormProblem.destinationRequired,
                            SearchFormProblem.sameCity,
                          }),
                          onTap: () => _pickCity(context, ref, isOrigin: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.sm),
                  Row(
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(l10n.text(CustomerStrings.searchToday)),
                        selected: form.date == today,
                        onSelected: (_) => controller.setDate(today),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(l10n.text(CustomerStrings.searchTomorrow)),
                        selected: form.date == tomorrow,
                        onSelected: (_) => controller.setDate(tomorrow),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => _pickDate(context, ref),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: AbraColors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AbraColors.divider),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: AbraColors.blueDark,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    text.date(form.date),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AbraColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AbraSpacing.md),
                      SizedBox(
                        width: 190,
                        child: AbraButton(
                          label: l10n.text(CustomerStrings.searchButton),
                          icon: Icons.search,
                          variant: AbraButtonVariant.callToAction,
                          onPressed: () => _search(context, ref),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                            icon: Icons.location_on_outlined,
                            error: problemFor(const {
                              SearchFormProblem.originRequired,
                            }),
                            onTap: () => _pickCity(context, ref, isOrigin: true),
                          ),
                          const SizedBox(height: AbraSpacing.sm),
                          _FormField(
                            label: l10n.text(CustomerStrings.searchToLabel),
                            value: form.to?.name,
                            hint: l10n.text(CustomerStrings.searchToHint),
                            icon: Icons.outlined_flag,
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
                          end: AbraSpacing.sm,
                        ),
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: AbraColors.white,
                            foregroundColor: AbraColors.blue,
                            disabledBackgroundColor: AbraColors.lightGray,
                            side: const BorderSide(color: AbraColors.divider, width: 1.5),
                            elevation: 2,
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
                  const SizedBox(height: AbraSpacing.sm),
                  Row(
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(l10n.text(CustomerStrings.searchToday)),
                        selected: form.date == today,
                        onSelected: (_) => controller.setDate(today),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(l10n.text(CustomerStrings.searchTomorrow)),
                        selected: form.date == tomorrow,
                        onSelected: (_) => controller.setDate(tomorrow),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => _pickDate(context, ref),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: AbraColors.white,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AbraColors.divider),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: AbraColors.blueDark,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    text.date(form.date),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AbraColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AbraSpacing.md),
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
        // Hero Header matching the demo model:
        Container(
          decoration: const BoxDecoration(
            gradient: AbraGradients.brandDeep,
          ),
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 44),
          child: centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.directions_bus,
                          color: AbraColors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.text(CustomerStrings.appName),
                          style: const TextStyle(
                            color: AbraColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (center != null)
                          NotificationBell(
                            center: center,
                            color: AbraColors.white,
                            onOpen: (item) {
                              final route = item.route;
                              if (route != null && route.isNotEmpty) {
                                context.go(route);
                              }
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.language, color: AbraColors.white),
                          tooltip: l10n.text(CustomerStrings.languageChangeAction),
                          onPressed: () => context.push(AppRoutes.language),
                        ),
                        if (auth is AuthSignedOut)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AbraColors.white,
                            ),
                            icon: const Icon(Icons.login, size: 18),
                            onPressed: () => requireSignIn(
                              context,
                              SignInIntent(returnLocation: currentLocation(context)),
                            ),
                            label: Text(l10n.text(CustomerStrings.gateActionShort)),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.text(CustomerStrings.homeHeading),
                    style: textTheme.headlineSmall?.copyWith(
                      color: AbraColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.text(CustomerStrings.homeSubtitle),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AbraColors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Active Trip Banner directly under Hero:
        if (showBanners) ...[
          centered(const ActiveTripBanner()),
        ],

        // Search Card:
        const SizedBox(height: AbraSpacing.sm),
        centered(AbraEntrance(child: searchCard)),

        // Recent searches:
        if (form.recent.isNotEmpty) ...[
          const SizedBox(height: AbraSpacing.xs),
          centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.text(CustomerStrings.searchRecentTitle),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AbraColors.navy,
                    ),
                  ),
                ),
                const SizedBox(height: AbraSpacing.xs),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: form.recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final r = form.recent[index];
                      return ActionChip(
                        label: Text('${r.from.name} → ${r.to.name}'),
                        onPressed: () => controller.useRecent(r),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        // Promotional Banners, Offers, Popular Routes:
        if (showBanners) ...[
          const SizedBox(height: AbraSpacing.sm),
          centered(const HomePromoBanners()),
          const SizedBox(height: AbraSpacing.lg),
          centered(const HomeOffersSlider()),
          const SizedBox(height: AbraSpacing.lg),
          centered(const PopularRoutesSection()),
        ],

        // Good to know Section:
        const SizedBox(height: AbraSpacing.lg),
        centered(
          Container(
            decoration: BoxDecoration(
              color: AbraColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AbraColors.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AbraSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.text(CustomerStrings.homeTrustTitle),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(height: AbraSpacing.sm),
                if (isTabletOrDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final key in const <String>[
                        CustomerStrings.homeTrustOperators,
                        CustomerStrings.homeTrustFares,
                        CustomerStrings.homeTrustPoints,
                      ])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: AbraColors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.text(key),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AbraColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  for (final key in const <String>[
                    CustomerStrings.homeTrustOperators,
                    CustomerStrings.homeTrustFares,
                    CustomerStrings.homeTrustPoints,
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check,
                            color: AbraColors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.text(key),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AbraColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );

    if (!showBanners) return content;
    return RefreshIndicator(
      onRefresh: () => ref
          .refresh(homeBannersProvider.future)
          .then<void>((_) {}, onError: (Object _) {}),
      child: content,
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
