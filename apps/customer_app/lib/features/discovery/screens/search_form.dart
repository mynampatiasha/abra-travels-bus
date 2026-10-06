import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../controllers/search_form_controller.dart';
import '../controllers/travel_dates.dart';
import '../models/discovery_models.dart';
import '../widgets/discovery_text.dart';

/// The search form with the recently searched routes: the content of the
/// Home section and of `/search`.
class SearchFormView extends ConsumerWidget {
  const SearchFormView({super.key});

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

    return AbraPageContainer(
      maxWidth: AbraSizes.maxFormWidth,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AbraSpacing.lg),
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.text(CustomerStrings.homeHeading),
              style: textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AbraSpacing.lg),
          _FormField(
            label: l10n.text(CustomerStrings.searchFromLabel),
            value: form.from?.name,
            hint: l10n.text(CustomerStrings.searchFromHint),
            icon: Icons.trip_origin,
            error: problemFor(const {SearchFormProblem.originRequired}),
            onTap: () => _pickCity(context, ref, isOrigin: true),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              icon: const Icon(Icons.swap_vert),
              tooltip: l10n.text(CustomerStrings.searchSwap),
              onPressed: form.from == null && form.to == null
                  ? null
                  : controller.swap,
            ),
          ),
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
          const SizedBox(height: AbraSpacing.lg),
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
          const SizedBox(height: AbraSpacing.xl),
          AbraButton(
            label: l10n.text(CustomerStrings.searchButton),
            icon: Icons.search,
            variant: AbraButtonVariant.callToAction,
            expand: true,
            onPressed: () => _search(context, ref),
          ),
          if (form.recent.isNotEmpty) ...<Widget>[
            const SizedBox(height: AbraSpacing.xxl),
            Semantics(
              header: true,
              child: Text(
                l10n.text(CustomerStrings.searchRecentTitle),
                style: textTheme.titleMedium,
              ),
            ),
            for (final recent in form.recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: AbraSizes.minTouchTarget,
                leading: const Icon(Icons.history),
                title: Text(text.route(recent.from.name, recent.to.name)),
                onTap: () => controller.useRecent(recent),
              ),
          ],
        ],
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
    body: const SearchFormView(),
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
