import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';

import '../../core/ui/state_views.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import '../authentication/gate/require_sign_in.dart';
import '../authentication/gate/sign_in_intent.dart';

/// The Support tab: the help centre (open to everyone; its articles do not
/// exist yet, and it says so) and "Contact support", which needs an
/// account because a request is answered personally.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return MessageStateView(
      icon: Icons.support_agent_outlined,
      badge: l10n.text(CustomerStrings.contentComingSoon),
      title: l10n.text(CustomerStrings.supportHelpTitle),
      message: l10n.text(CustomerStrings.supportHelpMessage),
      actionLabel: l10n.text(CustomerStrings.supportContactAction),
      onAction: () => continueAfterSignIn(
        context,
        const SignInIntent(
          returnLocation: AppRoutes.support,
          continueTo: AppRoutes.supportContact,
        ),
      ),
    );
  }
}
