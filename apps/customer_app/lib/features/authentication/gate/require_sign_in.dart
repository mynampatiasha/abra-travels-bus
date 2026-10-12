import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../core/ui/adaptive_sheet.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import '../../../routing/router_location.dart';
import '../otp_sign_in_controller.dart';
import 'sign_in_flow.dart';
import 'sign_in_intent.dart';

/// The login gate. Every action that needs an account goes through here.
///
/// - Signed in: returns true at once.
/// - Otherwise the sign-in sheet opens above the current screen (a dialog
///   on wide screens, a page on short ones). [intent] is kept meanwhile, also
///   on the device for a few minutes, so the app can come back to it after a
///   restart. The screen underneath keeps everything that was chosen.
/// - Returns true once the customer has signed in (new customers are
///   created by the backend on their first code), false when they closed
///   the sheet; nothing else changes then.
///
/// Only one sheet is ever open: a second call while it is (a double tap, a
/// screen built twice) waits for the same answer.
Future<bool> requireSignIn(BuildContext context, SignInIntent intent) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(authStateProvider) is AuthSignedIn) {
    return Future<bool>.value(true);
  }
  final open = _openSheets[container];
  if (open != null) return open;
  final shown = _showGate(
    context,
    container,
    intent,
  ).whenComplete(() => _openSheets[container] = null);
  _openSheets[container] = shown;
  return shown;
}

/// The sheet open in each app (one container per app; tests start many).
final Expando<Future<bool>> _openSheets = Expando<Future<bool>>();

Future<bool> _showGate(
  BuildContext context,
  ProviderContainer container,
  SignInIntent intent,
) async {
  final pending = container.read(pendingSignInIntentProvider.notifier);
  // Stored while the sheet opens; nothing waits for the device storage.
  final saved = pending.save(intent);
  await showAdaptiveSheet<bool>(
    context,
    builder: (context) => const SignInGateSheet(),
  );
  await saved;
  await pending.clear();
  return container.read(authStateProvider) is AuthSignedIn;
}

/// [requireSignIn], then on to [SignInIntent.continueTo] (pushed above the
/// current screen, so Back returns to it).
Future<void> continueAfterSignIn(
  BuildContext context,
  SignInIntent intent,
) async {
  final signedIn = await requireSignIn(context, intent);
  final next = intent.continueTo;
  if (!signedIn || next == null || !context.mounted) return;
  await context.push(next);
}

/// The location on screen now, to come back to after sign-in.
String currentLocation(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  return router == null ? AppRoutes.home : topLocationOf(router).toString();
}

/// The content of the sign-in sheet: the sign-in flow, or — while the
/// stored session is still being checked — that check (with a retry when
/// the server could not be reached). Closes itself once signed in.
class SignInGateSheet extends ConsumerStatefulWidget {
  const SignInGateSheet({super.key});

  @override
  ConsumerState<SignInGateSheet> createState() => _SignInGateSheetState();
}

class _SignInGateSheetState extends ConsumerState<SignInGateSheet> {
  bool _isClosing = false;

  void _close(bool signedIn) {
    if (_isClosing) return;
    _isClosing = true;
    Navigator.of(context).pop(signedIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    ref.listen(authStateProvider, (_, next) {
      if (next is AuthSignedIn) _close(true);
    });
    final auth = ref.watch(authStateProvider);
    final title = l10n.text(CustomerStrings.gateTitle);

    if (auth is AuthUnknown) {
      final startup = ref.watch(startupControllerProvider);
      final failure = startup.failure;
      return SheetScaffold(
        title: title,
        body: failure == null
            ? AbraLoadingView(
                label: l10n.text(CustomerStrings.startupCheckingSession),
              )
            : AbraFailureView(
                failure: failure,
                onRetry: ref
                    .read(startupControllerProvider.notifier)
                    .restoreSession,
              ),
      );
    }

    return SignInFlow(
      builder: (context, step, content, onBackToPhone) => SheetScaffold(
        title: title,
        leading: step == SignInStepView.code
            ? BackButton(onPressed: onBackToPhone)
            : null,
        onClose: () {
          ref.read(otpSignInControllerProvider.notifier).clearProblem();
          _close(false);
        },
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (step == SignInStepView.phone) ...<Widget>[
              const _GateBrand(),
              const SizedBox(height: AbraSpacing.lg),
            ],
            content,
          ],
        ),
      ),
    );
  }
}

/// The small brand strip at the top of the sign-in sheet.
class _GateBrand extends StatelessWidget {
  const _GateBrand();

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return AbraBrandSurface(
      gradient: AbraGradients.brandDeep,
      borderRadius: AbraRadius.large,
      child: Padding(
        padding: const EdgeInsets.all(AbraSpacing.lg),
        child: Row(
          children: <Widget>[
            const AbraLogo(size: 44),
            const SizedBox(width: AbraSpacing.md),
            Expanded(
              child: Text(
                l10n.text(CustomerStrings.gateMessage),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AbraColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
