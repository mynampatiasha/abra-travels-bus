import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import 'illustration.dart';

/// A centred message with a picture: a feature that is coming, content
/// that does not exist yet, or a list with nothing in it. For failures use
/// `AbraFailureView` (through `AsyncValueView`), which picks the right
/// wording for each kind of failure.
class MessageStateView extends StatelessWidget {
  const MessageStateView({
    required this.icon,
    required this.title,
    this.badge,
    this.message,
    this.actionLabel,
    this.onAction,
    this.footer,
    super.key,
  });

  final IconData icon;
  final String title;

  /// A short status above the title ("Coming soon").
  final String? badge;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Extra content under the message (a summary, a version number).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
                if (badge != null) ...<Widget>[
                  AbraStatusBadge(
                    label: badge!,
                    tone: AbraStatusTone.info,
                    icon: Icons.schedule,
                  ),
                  const SizedBox(height: AbraSpacing.md),
                ],
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall,
                  ),
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: AbraSpacing.sm),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AbraColors.textSecondary,
                    ),
                  ),
                ],
                if (footer != null) ...<Widget>[
                  const SizedBox(height: AbraSpacing.xl),
                  footer!,
                ],
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: AbraSpacing.xl),
                  AbraButton(
                    label: actionLabel!,
                    variant: AbraButtonVariant.secondary,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
