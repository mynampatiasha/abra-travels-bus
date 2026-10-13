import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/failure_text.dart';
import '../../../l10n/admin_strings.dart';
import '../catalogue_repository.dart';
import 'resource_page.dart';

/// One line of a detail window: what it is and its value.
class DetailLine {
  const DetailLine(this.labelKey, this.value);

  final String labelKey;
  final String value;
}

/// The label of [value] in [labels] (value to message key), or the value as
/// it is when unknown.
String optionLabel(
  AbraLocalizations l10n,
  Map<String, String> labels,
  Object? value,
) {
  final key = labels['$value'];
  return key == null ? '${value ?? ''}' : l10n.text(key);
}

/// Yes or No.
String yesNo(AbraLocalizations l10n, Object? value) =>
    l10n.text(value == true ? AdminStrings.formYes : AdminStrings.formNo);

/// The View button of a list row: opens a read-only window with the record as
/// the server has it now (`GET <path>/<id>`).
RowAction viewAction({
  required CatalogueRepository repository,
  required String path,
  required String Function(JsonMap record) titleOf,
  required List<DetailLine> Function(AbraLocalizations l10n, JsonMap record)
  linesOf,
}) => RowAction(AdminStrings.actionView, Icons.visibility_outlined, (
  context,
  record,
) async {
  final l10n = AbraLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final JsonMap fresh;
  try {
    fresh = await repository.get('$path/${record['id']}');
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    // The record may be gone since the list was loaded
    return true;
  }
  if (!context.mounted) return false;
  await showRecordDetail(
    context,
    title: titleOf(fresh),
    lines: linesOf(l10n, fresh),
  );
  return false;
});

/// A read-only window of labelled values.
Future<void> showRecordDetail(
  BuildContext context, {
  required String title,
  required List<DetailLine> lines,
}) {
  final l10n = AbraLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: AbraSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 170,
                        child: Text(
                          l10n.text(line.labelKey),
                          style: Theme.of(dialogContext).textTheme.bodySmall
                              ?.copyWith(color: AbraColors.textSecondary),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          line.value.isEmpty ? '-' : line.value,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.text(AbraStrings.commonClose)),
        ),
      ],
    ),
  );
}

/// How long the Undo of a delete stays on screen.
const deleteUndoTime = Duration(seconds: 8);

/// The Delete button of a list row: asks first, deletes (`DELETE <path>/<id>`,
/// a soft delete the server refuses while other records use the record, with
/// a sentence that says what uses it) and offers Undo for a few seconds
/// (`POST <path>/<id>/restore`).
RowAction deleteAction({
  required CatalogueRepository repository,
  required String path,
  required String Function(JsonMap record) nameOf,
}) => RowAction(AdminStrings.actionDelete, Icons.delete_outline, (
  context,
  record,
) async {
  final l10n = AbraLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // The list is reloaded after Undo, when this row's widgets may be gone
  final container = ProviderScope.containerOf(context);
  final name = nameOf(record);
  final id = '${record['id']}';

  final confirmed = await showAbraConfirmDialog(
    context,
    title: l10n.text(AdminStrings.deleteTitle, <String, Object?>{'name': name}),
    message: l10n.text(AdminStrings.deleteMessage),
    confirmLabel: l10n.text(AdminStrings.actionDelete),
    isDestructive: true,
  );
  if (!confirmed) return false;

  try {
    await repository.delete('$path/$id');
  } on Object catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(failureText(l10n, error))));
    return false;
  }
  messenger.showSnackBar(
    SnackBar(
      duration: deleteUndoTime,
      content: Text(
        l10n.text(AdminStrings.deleteDone, <String, Object?>{'name': name}),
      ),
      action: SnackBarAction(
        label: l10n.text(AdminStrings.deleteUndo),
        onPressed: () async {
          try {
            await repository.post('$path/$id/restore');
            container.invalidate(resourceListProvider);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n.text(AdminStrings.deleteRestored, <String, Object?>{
                    'name': name,
                  }),
                ),
              ),
            );
          } on Object catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text(failureText(l10n, error))),
            );
          }
        },
      ),
    ),
  );
  return true;
});
