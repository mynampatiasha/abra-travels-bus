import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';

import '../../core/ui/gradient_header.dart';
import '../../core/ui/state_views.dart';
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
    appBar: GradientAppBar(title: AbraLocalizations.of(context).text(titleKey)),
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
    return MessageStateView(
      icon: Icons.construction_rounded,
      badge: l10n.text(CustomerStrings.unavailableLabel),
      title: l10n.text(titleKey),
      message: l10n.text(CustomerStrings.unavailableMessage),
    );
  }
}
