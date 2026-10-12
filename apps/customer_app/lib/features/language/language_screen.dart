import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';
import '../../core/ui/gradient_header.dart';
import '../../core/ui/sticky_action_bar.dart';
import '../../l10n/customer_strings.dart';
import '../../routing/app_routes.dart';

/// Lets the user pick the app language, or follow the device. The choice
/// applies immediately and is remembered on the device. Also the last step
/// of the first launch ([isFirstLaunch]), with "Continue" to Home.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({this.isFirstLaunch = false, super.key});

  final bool isFirstLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AbraLocalizations.of(context);
    final controller = ref.watch(appDependenciesProvider).localeController;

    return Scaffold(
      appBar: GradientAppBar(
        title: l10n.text(CustomerStrings.languageTitle),
        automaticallyImplyLeading: !isFirstLaunch,
      ),
      bottomNavigationBar: isFirstLaunch
          ? StickyActionBar(
              actionLabel: l10n.text(AbraStrings.commonContinue),
              actionIcon: Icons.arrow_forward,
              onAction: () => context.go(AppRoutes.home),
            )
          : null,
      body: AbraPageContainer(
        maxWidth: AbraSizes.maxFormWidth,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: AbraSpacing.sm),
            children: <Widget>[
              _LanguageOption(
                label: l10n.text(AbraStrings.languageFollowDevice),
                isSelected: controller.followsDevice,
                onTap: () => controller.selectLocale(null),
              ),
              const Divider(),
              for (final language in controller.config.languages)
                _LanguageOption(
                  // A language is always listed under its own name.
                  label: language.nativeName,
                  locale: language.locale,
                  isSelected: controller.userSelected == language.locale,
                  onTap: () => controller.selectLocale(language.locale),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.locale,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = AbraLocalizations.of(
      context,
    ).text(CustomerStrings.languageSelected);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: ListTile(
        minTileHeight: AbraSizes.minTouchTarget,
        title: Text(label, locale: locale),
        // The check mark, not colour alone, shows the current choice.
        trailing: isSelected
            ? Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: selectedLabel,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
