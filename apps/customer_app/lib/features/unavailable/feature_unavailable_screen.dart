import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../l10n/customer_strings.dart';

/// Stands in for a screen that a later milestone delivers. It exists so
/// that the route map and its guards are complete and testable; it states
/// plainly that the feature is not built and offers nothing that could be
/// mistaken for a working control.
class FeatureUnavailableScreen extends StatelessWidget {
  const FeatureUnavailableScreen({required this.titleKey, super.key});

  /// Message key of the name of the feature.
  final String titleKey;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AbraLocalizations.of(context).text(titleKey))),
    body: FeatureUnavailableBody(titleKey: titleKey),
  );
}

/// The content of [FeatureUnavailableScreen], for use inside the app shell
/// (which has its own app bar).
class FeatureUnavailableBody extends StatelessWidget {
  const FeatureUnavailableBody({required this.titleKey, super.key});

  final String titleKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AbraLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AbraPageContainer(
      maxWidth: AbraSizes.maxFormWidth,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AbraSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ExcludeSemantics(
                child: Icon(
                  Icons.construction,
                  size: AbraSizes.stateIllustration,
                  color: AbraColors.textSecondary,
                ),
              ),
              const SizedBox(height: AbraSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.text(titleKey),
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              Text(
                l10n.text(CustomerStrings.unavailableLabel),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: AbraColors.orangeDark,
                ),
              ),
              const SizedBox(height: AbraSpacing.sm),
              Text(
                l10n.text(CustomerStrings.unavailableMessage),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
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
