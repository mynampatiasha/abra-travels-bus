import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_authentication/shared_authentication.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../../app/providers.dart';
import '../../../core/ui/gradient_header.dart';
import '../../../core/ui/guest_prompt_card.dart';
import '../../../l10n/customer_strings.dart';
import '../../../routing/app_routes.dart';
import 'require_sign_in.dart';
import 'sign_in_intent.dart';

/// Wraps every screen that needs an account (the router applies it to each
/// location that is not public). Signed in: the screen. Otherwise a guest
/// card in its place, and — when the screen was opened that way, for
/// example by a link — the sign-in sheet once. After signing in the screen
/// itself appears; the location never changes, so Back behaves as usual.
class SignInRequired extends ConsumerStatefulWidget {
  const SignInRequired({
    required this.location,
    required this.child,
    this.titleKey,
    super.key,
  });

  /// The location of the screen, kept as the place to return to.
  final String location;
  final Widget child;

  /// Title of the screen's bar while the guest card is shown.
  final String? titleKey;

  @override
  ConsumerState<SignInRequired> createState() => _SignInRequiredState();
}

class _SignInRequiredState extends ConsumerState<SignInRequired> {
  @override
  void initState() {
    super.initState();
    if (ref.read(authStateProvider) is AuthSignedOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(authStateProvider) is! AuthSignedIn) {
          _signIn();
        }
      });
    }
  }

  Future<void> _signIn() =>
      requireSignIn(context, SignInIntent(returnLocation: widget.location));

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    if (auth is AuthSignedIn) return widget.child;
    final l10n = AbraLocalizations.of(context);
    final canPop = GoRouter.of(context).canPop();
    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(widget.titleKey ?? CustomerStrings.appName),
        leading: canPop
            ? null
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: l10n.text(CustomerStrings.navHome),
                onPressed: () => context.go(AppRoutes.home),
              ),
      ),
      body: auth is AuthUnknown
          ? const AbraLoadingView()
          : GuestPromptCard(
              title: l10n.text(CustomerStrings.gateRequiredTitle),
              message: l10n.text(CustomerStrings.gateRequiredMessage),
              actionLabel: l10n.text(CustomerStrings.gateAction),
              onAction: _signIn,
            ),
    );
  }
}
