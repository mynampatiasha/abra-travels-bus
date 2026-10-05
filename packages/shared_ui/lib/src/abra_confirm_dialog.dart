import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';

/// Asks the user to confirm an action. Returns true only when the confirm
/// button was pressed; dismissing the dialog counts as "no".
///
/// Use [isDestructive] for actions that cannot be undone (cancel a booking,
/// sign out everywhere): the confirm button is then shown in the error
/// colour.
Future<bool> showAbraConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final l10n = AbraLocalizations.of(dialogContext);
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel ?? l10n.text(AbraStrings.commonCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
