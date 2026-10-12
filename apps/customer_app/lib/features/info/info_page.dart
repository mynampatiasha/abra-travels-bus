import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/app_info.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/state_views.dart';
import '../../l10n/customer_strings.dart';

enum InfoPageKind { terms, privacy, about }

/// Terms and conditions, privacy policy and About. Open to everyone. The
/// legal texts have not been written yet, so those pages say the content is
/// coming instead of showing invented text; About shows the tagline and
/// the version of the app.
class InfoPage extends StatelessWidget {
  const InfoPage({required this.kind, super.key});

  final InfoPageKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final title = l10n.text(switch (kind) {
      InfoPageKind.terms => CustomerStrings.infoTermsTitle,
      InfoPageKind.privacy => CustomerStrings.infoPrivacyTitle,
      InfoPageKind.about => CustomerStrings.infoAboutTitle,
    });
    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: switch (kind) {
        InfoPageKind.about => _About(),
        _ => MessageStateView(
          icon: kind == InfoPageKind.terms
              ? Icons.gavel_outlined
              : Icons.privacy_tip_outlined,
          badge: l10n.text(CustomerStrings.contentComingSoon),
          title: title,
          message: l10n.text(CustomerStrings.infoContentComingSoon),
        ),
      },
    );
  }
}

class _About extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: AbraResponsive.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth),
          child: Column(
            children: <Widget>[
              const AbraLogo(size: 88),
              const SizedBox(height: AbraSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.text(CustomerStrings.appName),
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AbraSpacing.xs),
              Text(
                l10n.text(CustomerStrings.splashTagline),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.xl),
              AbraCard(
                child: Text(
                  l10n.text(CustomerStrings.infoAboutBody),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
              Text(
                l10n.text(CustomerStrings.infoAboutVersion, <String, Object?>{
                  'version': AppInfo.version,
                }),
                style: textTheme.bodySmall?.copyWith(
                  color: AbraColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
