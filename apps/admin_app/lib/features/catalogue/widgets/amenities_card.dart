import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';

/// Every amenity, switched off ones included (`GET admin/amenities`).
final amenitiesProvider = FutureProvider.autoDispose<List<JsonMap>>((
  ref,
) async {
  final page = await ref
      .watch(catalogueRepositoryProvider)
      .list(const ResourceQuery('admin/amenities', pageSize: 100));
  return page.items;
});

/// The Amenities card of the Bus types page: what operators can tick when they
/// add a bus. Each amenity is a chip with a switch; "Add amenity" makes a new
/// one. Switching one off keeps it on the buses that have it.
class AmenitiesCard extends ConsumerWidget {
  const AmenitiesCard({required this.canManage, super.key});

  /// Whether the person may add amenities and switch them (`catalogue.manage`).
  final bool canManage;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddAmenityDialog(),
    );
    if (added ?? false) ref.invalidate(amenitiesProvider);
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    JsonMap amenity,
  ) async {
    final l10n = AbraLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(catalogueRepositoryProvider).patch(
        'admin/amenities/${amenity['id']}/active',
        <String, Object?>{'active': amenity['isActive'] != true},
      );
      ref.invalidate(amenitiesProvider);
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final amenities = ref.watch(amenitiesProvider);
    return Padding(
      padding: const EdgeInsets.all(AbraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  l10n.text(AdminStrings.amenitiesTitle),
                  style: textTheme.titleMedium,
                ),
              ),
              if (canManage)
                AbraButton(
                  label: l10n.text(AdminStrings.amenityAdd),
                  icon: Icons.add,
                  variant: AbraButtonVariant.secondary,
                  onPressed: () => _add(context, ref),
                ),
            ],
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(
            l10n.text(AdminStrings.amenitiesHint),
            style: textTheme.bodySmall?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
          const SizedBox(height: AbraSpacing.md),
          amenities.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(
              failureText(l10n, error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (items) => items.isEmpty
                ? Text(l10n.text(AdminStrings.amenitiesEmpty))
                : Wrap(
                    spacing: AbraSpacing.sm,
                    runSpacing: AbraSpacing.sm,
                    children: <Widget>[
                      for (final amenity in items)
                        _AmenityChip(
                          amenity: amenity,
                          onToggle: canManage
                              ? () => _toggle(context, ref, amenity)
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// One amenity: its name and a switch (a tick when on, a cross when off). The
/// state is also in words for screen readers, never only in colour.
class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.amenity, required this.onToggle});

  final JsonMap amenity;

  /// Null when the person may only look.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final name = '${amenity['name']}';
    final isOn = amenity['isActive'] == true;
    final foreground = isOn ? AbraColors.deepBlue : AbraColors.textSecondary;
    return Semantics(
      container: true,
      label: l10n.text(
        isOn ? AdminStrings.amenityOn : AdminStrings.amenityOff,
        <String, Object?>{'name': name},
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isOn ? AbraColors.skyContainer : AbraColors.lightGray,
          borderRadius: BorderRadius.circular(AbraRadius.pill),
          border: Border.all(
            color: isOn ? AbraColors.skyBlue : AbraColors.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: AbraSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  decoration: isOn ? null : TextDecoration.lineThrough,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: foreground,
                tooltip: l10n.text(
                  AdminStrings.amenityToggle,
                  <String, Object?>{'name': name},
                ),
                icon: Icon(isOn ? Icons.check : Icons.close),
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add amenity: Amenity name*", with Cancel and Add. A refusal of the server
/// (the name exists already) is shown in the window.
class _AddAmenityDialog extends ConsumerStatefulWidget {
  const _AddAmenityDialog();

  @override
  ConsumerState<_AddAmenityDialog> createState() => _AddAmenityDialogState();
}

class _AddAmenityDialogState extends ConsumerState<_AddAmenityDialog> {
  final _name = TextEditingController();
  var _showError = false;
  var _saving = false;
  String? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AbraLocalizations.of(context);
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref.read(catalogueRepositoryProvider).post(
        'admin/amenities',
        <String, Object?>{'name': name},
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = failureText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.text(AdminStrings.amenityAddTitle)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AbraSpacing.md),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: l10n.text(AdminStrings.amenityName),
                errorText: _showError && _name.text.trim().length < 2
                    ? l10n.text(AdminStrings.formRequired)
                    : null,
              ),
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.text(AbraStrings.commonCancel)),
        ),
        AbraButton(
          label: l10n.text(AdminStrings.amenityAddConfirm),
          variant: AbraButtonVariant.primary,
          isLoading: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
