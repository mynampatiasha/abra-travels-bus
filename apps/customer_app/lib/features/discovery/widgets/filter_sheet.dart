import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../l10n/customer_strings.dart';
import '../controllers/trip_search_controller.dart';
import '../models/discovery_models.dart';
import 'discovery_text.dart';

/// Opens the filter sheet. Returns the filters to apply, or null when the
/// sheet was dismissed without applying.
Future<TripFilters?> showTripFilterSheet(
  BuildContext context, {
  required TripSearchCriteria criteria,
  required TripFilters current,
}) => showModalBottomSheet<TripFilters>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _FilterSheet(criteria: criteria, initial: current),
);

/// Filters for a search. Only values that occur in the search are offered
/// (they come from the backend, with the number of buses for each), and
/// applying them runs the search again on the backend.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.criteria, required this.initial});

  final TripSearchCriteria criteria;
  final TripFilters initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TripFilters _filters = widget.initial;

  Set<String> _toggled(Set<String> values, String key) =>
      values.contains(key) ? ({...values}..remove(key)) : {...values, key};

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final text = DiscoveryText(l10n);
    final options = ref.watch(searchFilterOptionsProvider(widget.criteria));

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AbraSpacing.lg,
              end: AbraSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.text(CustomerStrings.filterTitle),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _filters.isEmpty
                      ? null
                      : () => setState(() => _filters = TripFilters.none),
                  child: Text(l10n.text(CustomerStrings.filterReset)),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<SearchFilterOptions>(
              value: options,
              onRetry: () =>
                  ref.invalidate(searchFilterOptionsProvider(widget.criteria)),
              data: (context, available) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: AbraSpacing.lg),
                children: <Widget>[
                  _ChipGroup(
                    title: l10n.text(CustomerStrings.filterDeparture),
                    options: available.departureWindows
                        .where((option) => option.count > 0)
                        .toList(),
                    label: (option) => text.departureWindow(option.key),
                    selected: _filters.departureWindows,
                    onToggle: (key) => setState(
                      () => _filters = _filters.copyWith(
                        departureWindows: _toggled(
                          _filters.departureWindows,
                          key,
                        ),
                      ),
                    ),
                  ),
                  _ChipGroup(
                    title: l10n.text(CustomerStrings.filterBusType),
                    options: available.busTypes,
                    label: (option) => option.label,
                    selected: _filters.busTypes,
                    onToggle: (key) => setState(
                      () => _filters = _filters.copyWith(
                        busTypes: _toggled(_filters.busTypes, key),
                      ),
                    ),
                  ),
                  _Section(
                    title: l10n.text(CustomerStrings.filterAirConditioning),
                    child: Wrap(
                      spacing: AbraSpacing.sm,
                      children: <Widget>[
                        for (final isAc in const <bool>[true, false])
                          FilterChip(
                            label: Text(text.airConditioning(isAc: isAc)),
                            selected: _filters.isAc == isAc,
                            onSelected: (selected) => setState(
                              () => _filters = _filters.copyWith(
                                isAc: () => selected ? isAc : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _ChipGroup(
                    title: l10n.text(CustomerStrings.filterOperator),
                    options: available.operators,
                    label: (option) => option.label,
                    selected: _filters.operatorIds,
                    onToggle: (key) => setState(
                      () => _filters = _filters.copyWith(
                        operatorIds: _toggled(_filters.operatorIds, key),
                      ),
                    ),
                  ),
                  _ChipGroup(
                    title: l10n.text(CustomerStrings.filterAmenities),
                    options: available.amenities,
                    label: (option) => text.amenity(option.key),
                    selected: _filters.amenities,
                    onToggle: (key) => setState(
                      () => _filters = _filters.copyWith(
                        amenities: _toggled(_filters.amenities, key),
                      ),
                    ),
                  ),
                  if (available.minFarePaise != null &&
                      available.maxFarePaise != null &&
                      available.maxFarePaise! > available.minFarePaise!)
                    _MaxFare(
                      minPaise: available.minFarePaise!,
                      maxPaise: available.maxFarePaise!,
                      value: _filters.maxFarePaise,
                      text: text,
                      onChanged: (value) => setState(
                        () => _filters = _filters.copyWith(
                          maxFarePaise: () => value,
                        ),
                      ),
                    ),
                  const SizedBox(height: AbraSpacing.lg),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AbraSpacing.lg),
            child: AbraButton(
              label: l10n.text(CustomerStrings.filterApply),
              variant: AbraButtonVariant.callToAction,
              expand: true,
              onPressed: () => Navigator.of(context).pop(_filters),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AbraSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: AbraSpacing.sm),
        child,
      ],
    ),
  );
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.options,
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<FilterOption> options;
  final String Function(FilterOption option) label;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    // A group with nothing to choose from is not shown at all.
    if (options.isEmpty) return const SizedBox.shrink();
    final l10n = AbraLocalizations.of(context);
    return _Section(
      title: title,
      child: Wrap(
        spacing: AbraSpacing.sm,
        children: <Widget>[
          for (final option in options)
            FilterChip(
              label: Text(
                l10n.text(CustomerStrings.filterOption, <String, Object?>{
                  'label': label(option),
                  'count': l10n.formatters.number(option.count),
                }),
              ),
              selected: selected.contains(option.key),
              onSelected: (_) => onToggle(option.key),
            ),
        ],
      ),
    );
  }
}

class _MaxFare extends StatelessWidget {
  const _MaxFare({
    required this.minPaise,
    required this.maxPaise,
    required this.value,
    required this.text,
    required this.onChanged,
  });

  final int minPaise;
  final int maxPaise;
  final int? value;
  final DiscoveryText text;
  final ValueChanged<int?> onChanged;

  /// Slider steps of ₹50, rounded outwards so both ends are reachable.
  static const _stepPaise = 5000;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final low = (minPaise ~/ _stepPaise) * _stepPaise;
    final high = ((maxPaise + _stepPaise - 1) ~/ _stepPaise) * _stepPaise;
    final current = (value ?? high).clamp(low, high);
    final label = l10n.text(
      CustomerStrings.filterMaxFareValue,
      <String, Object?>{'fare': text.fare(current, 'INR')},
    );
    return _Section(
      title: l10n.text(CustomerStrings.filterMaxFare),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label),
          Slider(
            value: current.toDouble(),
            min: low.toDouble(),
            max: high.toDouble(),
            divisions: ((high - low) ~/ _stepPaise).clamp(1, 200),
            label: label,
            semanticFormatterCallback: (value) => l10n.text(
              CustomerStrings.filterMaxFareValue,
              <String, Object?>{'fare': text.fare(value.round(), 'INR')},
            ),
            // The top of the range means "no limit".
            onChanged: (value) =>
                onChanged(value.round() >= high ? null : value.round()),
          ),
        ],
      ),
    );
  }
}
