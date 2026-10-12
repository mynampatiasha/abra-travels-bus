import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../l10n/customer_strings.dart';

/// The brand at the top of the sign-in screens: the Abra Travels logo and
/// name on the brand colours.
class AuthBrandBanner extends StatelessWidget {
  const AuthBrandBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AbraSpacing.xl),
      child: AbraBrandSurface(
        gradient: AbraGradients.brandDeep,
        borderRadius: AbraRadius.large,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AbraSpacing.lg,
            vertical: AbraSpacing.xl,
          ),
          child: Column(
            children: <Widget>[
              const AbraLogo(size: 72),
              const SizedBox(height: AbraSpacing.md),
              Text(
                l10n.text(CustomerStrings.appName),
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: AbraColors.white,
                ),
              ),
              Text(
                l10n.text(CustomerStrings.loginBrandTagline),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: AbraColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
