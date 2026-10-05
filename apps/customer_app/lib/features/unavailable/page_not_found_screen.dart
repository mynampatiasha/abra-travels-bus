import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';

/// Shown for a location the app does not have, for example an outdated or
/// mistyped link.
class PageNotFoundScreen extends StatelessWidget {
  const PageNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text(CustomerStrings.appName))),
      body: AbraPageContainer(
        child: AbraStateView(
          kind: AbraStateKind.notFound,
          actionLabel: l10n.text(CustomerStrings.navHome),
          // The guard sends a signed-out user on to sign-in.
          onAction: () => context.go(AppRoutes.home),
        ),
      ),
    );
  }
}
