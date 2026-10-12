import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/failure_text.dart';
import '../../l10n/portal_strings.dart';
import '../onboarding/onboarding_repository.dart';

/// Adds a bus for the owner's company. It waits for approval until its
/// documents are checked. Returns the new bus's id, or null when cancelled.
Future<String?> showAddBusDialog(BuildContext context) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const _AddBusDialog(),
);

class _AddBusDialog extends ConsumerStatefulWidget {
  const _AddBusDialog();

  @override
  ConsumerState<_AddBusDialog> createState() => _AddBusDialogState();
}

class _AddBusDialogState extends ConsumerState<_AddBusDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _registration = TextEditingController();
  final _seats = TextEditingController();
  String? _busTypeId;
  List<JsonMap>? _busTypes;
  var _busy = false;
  String? _error;

  AbraLocalizations get _l10n => AbraLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    ref
        .read(onboardingRepositoryProvider)
        .busTypes()
        .then((types) {
          if (mounted) setState(() => _busTypes = types);
        })
        .catchError((Object error) {
          if (mounted) setState(() => _error = failureText(_l10n, error));
        });
  }

  @override
  void dispose() {
    _name.dispose();
    _registration.dispose();
    _seats.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bus = await ref
          .read(onboardingRepositoryProvider)
          .addBus(<String, Object?>{
            'name': _name.text.trim(),
            'registrationNumber': _registration.text.trim(),
            'busTypeId': _busTypeId,
            'seatCapacity': int.parse(_seats.text.trim()),
          });
      if (mounted) Navigator.of(context).pop('${bus['id']}');
    } on Object catch (error) {
      if (mounted) setState(() => _error = failureText(_l10n, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_l10n.text(PortalStrings.addBusTitle)),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: _l10n.text(PortalStrings.busName),
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? _l10n.text(PortalStrings.fieldRequired)
                    : null,
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _registration,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: _l10n.text(PortalStrings.busRegistration),
                ),
                validator: (value) => (value ?? '').trim().length < 5
                    ? _l10n.text(PortalStrings.fieldRequired)
                    : null,
              ),
              const SizedBox(height: AbraSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _busTypeId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _l10n.text(PortalStrings.busType),
                ),
                items: <DropdownMenuItem<String>>[
                  for (final type in _busTypes ?? const <JsonMap>[])
                    DropdownMenuItem<String>(
                      value: '${type['id']}',
                      child: Text('${type['name']}'),
                    ),
                ],
                onChanged: (value) => setState(() => _busTypeId = value),
                validator: (value) => value == null
                    ? _l10n.text(PortalStrings.fieldRequired)
                    : null,
              ),
              const SizedBox(height: AbraSpacing.md),
              TextFormField(
                controller: _seats,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _l10n.text(PortalStrings.busSeatCount),
                ),
                validator: (value) {
                  final seats = int.tryParse((value ?? '').trim());
                  return seats == null || seats < 1 || seats > 100
                      ? _l10n.text(PortalStrings.fieldRequired)
                      : null;
                },
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: AbraSpacing.md),
                Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AbraColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: Text(_l10n.text(AbraStrings.commonCancel)),
      ),
      AbraButton(
        label: _l10n.text(PortalStrings.addBusSave),
        isLoading: _busy,
        onPressed: _save,
      ),
    ],
  );
}
