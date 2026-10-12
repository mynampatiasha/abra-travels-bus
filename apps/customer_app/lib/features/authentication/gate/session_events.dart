import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../core/ui/adaptive_sheet.dart';
import '../../../core/ui/illustration.dart';
import '../../../l10n/customer_strings.dart';
import 'require_sign_in.dart';
import 'sign_in_intent.dart';

/// Tells the customer that the server ended their session (expired,
/// revoked, signed out elsewhere). They stay on the screen they were on;
/// public screens keep working and personal ones show their guest card.
/// "Log in" opens the gate and returns to [location].
Future<void> showSessionEndedSheet(
  BuildContext context, {
  required String location,
}) async {
  final logIn = await showAdaptiveSheet<bool>(
    context,
    builder: (context) => const _SessionEndedSheet(),
  );
  if (logIn != true || !context.mounted) return;
  await requireSignIn(context, SignInIntent(returnLocation: location));
}

class _SessionEndedSheet extends StatelessWidget {
  const _SessionEndedSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SheetScaffold(
      title: l10n.text(CustomerStrings.sessionEndedTitle),
      body: Column(
        children: <Widget>[
          const StateIllustration(icon: Icons.lock_clock_outlined, size: 88),
          const SizedBox(height: AbraSpacing.lg),
          Text(
            l10n.text(CustomerStrings.sessionEndedMessage),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: AbraColors.textSecondary,
            ),
          ),
        ],
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AbraButton(
            label: l10n.text(CustomerStrings.gateAction),
            icon: Icons.login,
            variant: AbraButtonVariant.callToAction,
            expand: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: AbraSpacing.sm),
          AbraButton(
            label: l10n.text(CustomerStrings.sessionEndedLater),
            variant: AbraButtonVariant.text,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// After a restart, takes the customer back into the action that was
/// waiting for sign-in (if it is recent): the selection is put back and
/// the gate opens again; once signed in the action continues.
Future<void> resumePendingSignIn(
  BuildContext context,
  SignInIntent intent,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  intent.restoreSelection(container);
  await continueAfterSignIn(context, intent);
}
