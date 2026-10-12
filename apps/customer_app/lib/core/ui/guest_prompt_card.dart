import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import 'illustration.dart';
import 'responsive.dart';

/// Shown to a guest instead of something personal ("Log in to see your
/// trips"): a friendly picture, what signing in gives them, and the button
/// that opens sign-in. Not an error.
class GuestPromptCard extends StatelessWidget {
  const GuestPromptCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.lock_open_rounded,
    this.compact = false,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  /// A smaller, side-by-side card for the top of a list (Profile).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final button = AbraButton(
      label: actionLabel,
      icon: Icons.login,
      variant: AbraButtonVariant.callToAction,
      expand: true,
      onPressed: onAction,
    );

    if (compact) {
      final stack = CustomerLayout.shouldStack(context);
      final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(color: AbraColors.white),
            ),
          ),
          const SizedBox(height: AbraSpacing.xs),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: AbraColors.onNavyMuted,
            ),
          ),
        ],
      );
      return AbraBrandSurface(
        gradient: AbraGradients.brandDeep,
        borderRadius: AbraRadius.large,
        child: Padding(
          padding: const EdgeInsets.all(AbraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (stack)
                words
              else
                Row(
                  children: <Widget>[
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AbraColors.navyHover,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AbraSpacing.md),
                        child: ExcludeSemantics(
                          child: Icon(icon, color: AbraColors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: AbraSpacing.md),
                    Expanded(child: words),
                  ],
                ),
              const SizedBox(height: AbraSpacing.lg),
              // White on the gradient: the call to action of this card.
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AbraColors.white,
                  foregroundColor: AbraColors.deepBlue,
                  minimumSize: const Size.fromHeight(AbraSizes.buttonHeight),
                ),
                onPressed: onAction,
                icon: const Icon(Icons.login),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: AbraResponsive.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AbraSizes.maxFormWidth),
          child: AbraEntrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                StateIllustration(icon: icon),
                const SizedBox(height: AbraSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AbraSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: AbraColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AbraSpacing.xl),
                button,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
