import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import '../../core/failure_text.dart';
import '../../l10n/portal_strings.dart';

/// Shown to a signed-in user who cannot be given the management screens:
/// not a staff account, two-step verification not set up, permissions not
/// loaded, or no section at all. Always offers sign-out.
class AccessGateScreen extends ConsumerWidget {
  const AccessGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final access = ref.watch(accessProvider);
    final signOutLabel = l10n.text(AbraStrings.commonSignOut);
    final signOut = ref.read(sessionManagerProvider).signOut;

    final Widget body = switch (access.level) {
      AccessLevel.notStaff => AbraStateView(
        kind: AbraStateKind.forbidden,
        title: l10n.text(PortalStrings.accessNotStaffTitle),
        message: l10n.text(PortalStrings.accessNotStaffMessage),
        actionLabel: signOutLabel,
        onAction: signOut,
      ),
      AccessLevel.mfaSetupRequired => AbraStateView(
        kind: AbraStateKind.forbidden,
        title: l10n.text(PortalStrings.accessMfaSetupTitle),
        message: l10n.text(PortalStrings.accessMfaSetupMessage),
        actionLabel: signOutLabel,
        onAction: signOut,
      ),
      AccessLevel.failed => AbraStateView(
        kind: AbraStateKind.error,
        title: l10n.text(PortalStrings.accessPermissionsFailedTitle),
        message: access.failure == null
            ? null
            : failureText(l10n, access.failure!),
        actionLabel: l10n.text(AbraStrings.commonRetry),
        onAction: ref.read(accessProvider.notifier).reload,
        secondaryActionLabel: signOutLabel,
        onSecondaryAction: signOut,
      ),
      AccessLevel.granted => AbraStateView(
        kind: AbraStateKind.forbidden,
        title: l10n.text(PortalStrings.accessNoSectionsTitle),
        message: l10n.text(PortalStrings.accessNoSectionsMessage),
        actionLabel: signOutLabel,
        onAction: signOut,
      ),
      AccessLevel.pending || AccessLevel.signedOut => const AbraLoadingView(),
    };
    return Scaffold(body: body);
  }
}
