import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../core/ui/gradient_header.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';
import 'auth_brand_banner.dart';
import 'gate/sign_in_flow.dart';

/// Sign-in as a page, for links to `/login` (and old `/otp` links). Inside
/// the app sign-in opens as a sheet over the current screen instead
/// (`requireSignIn`). Both use the same flow. After sign-in the router opens
/// the location in `from`, or Home.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    return SignInFlow(
      builder: (context, step, content, onBackToPhone) => Scaffold(
        appBar: GradientAppBar(
          title: l10n.text(
            step == SignInStepView.phone
                ? CustomerStrings.routeLoginTitle
                : CustomerStrings.routeOtpTitle,
          ),
          leading: step == SignInStepView.code
              ? BackButton(onPressed: onBackToPhone)
              : GoRouter.of(context).canPop()
              ? null
              : IconButton(
                  icon: const Icon(Icons.home_outlined),
                  tooltip: l10n.text(CustomerStrings.navHome),
                  onPressed: () => context.go(AppRoutes.home),
                ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: l10n.text(CustomerStrings.languageChangeAction),
              onPressed: () => context.push(AppRoutes.language),
            ),
          ],
        ),
        body: AbraPageContainer(
          maxWidth: AbraSizes.maxFormWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[const AuthBrandBanner(), content],
            ),
          ),
        ),
      ),
    );
  }
}
