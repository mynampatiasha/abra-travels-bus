import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/async_value_view.dart';
import '../../../l10n/customer_strings.dart';
import '../controllers/trip_search_controller.dart';
import '../models/discovery_models.dart';

/// Picks the origin or destination city. Shows the popular cities first and
/// searches the backend as the customer types. Closes with the chosen city.
class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({required this.isOrigin, super.key});

  final bool isOrigin;

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  /// Typing pauses this long before the backend is asked, so a name typed
  /// at normal speed costs one request, not one per letter.
  static const _debounce = Duration(milliseconds: 300);

  final TextEditingController _input = TextEditingController();
  Timer? _pending;
  String _query = '';

  @override
  void dispose() {
    _pending?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _pending?.cancel();
    _pending = Timer(_debounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final suggestions = ref.watch(citySuggestionsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.text(
            widget.isOrigin
                ? CustomerStrings.cityPickerFromTitle
                : CustomerStrings.cityPickerToTitle,
          ),
        ),
      ),
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AbraSpacing.md),
              child: TextField(
                controller: _input,
                autofocus: true,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                autocorrect: false,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: l10n.text(CustomerStrings.cityPickerSearchLabel),
                  prefixIcon: const Icon(Icons.search),
                  counterText: '',
                ),
                onChanged: _onChanged,
              ),
            ),
            Expanded(
              child: AsyncValueView<List<City>>(
                value: suggestions,
                onRetry: () => ref.invalidate(citySuggestionsProvider(_query)),
                data: (context, cities) =>
                    _CityList(cities: cities, isSearching: _query.isNotEmpty),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityList extends StatelessWidget {
  const _CityList({required this.cities, required this.isSearching});

  final List<City> cities;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    if (cities.isEmpty) {
      return isSearching
          ? AbraStateView(
              kind: AbraStateKind.empty,
              title: l10n.text(CustomerStrings.cityPickerEmptyTitle),
              message: l10n.text(CustomerStrings.cityPickerEmptyMessage),
            )
          : Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(l10n.text(CustomerStrings.cityPickerTypeToSearch)),
            );
    }
    return ListView.builder(
      itemCount: cities.length + (isSearching ? 0 : 1),
      itemBuilder: (context, index) {
        if (!isSearching && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.xs),
            child: Semantics(
              header: true,
              child: Text(
                l10n.text(CustomerStrings.cityPickerPopular),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          );
        }
        final city = cities[index - (isSearching ? 0 : 1)];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: AbraSizes.minTouchTarget,
          leading: const Icon(Icons.location_city_outlined),
          title: Text(city.name),
          subtitle: city.state == null ? null : Text(city.state!),
          onTap: () => context.pop(city),
        );
      },
    );
  }
}
