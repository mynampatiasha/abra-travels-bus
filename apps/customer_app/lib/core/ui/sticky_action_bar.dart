import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import 'responsive.dart';

/// The bar at the bottom of a booking step: what the choice costs (or a
/// short summary) and the one action that continues. Stays above the
/// system navigation and the home indicator. With large text the summary
/// and the button stack.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    required this.actionLabel,
    required this.onAction,
    this.title,
    this.subtitle,
    this.isLoading = false,
    this.actionIcon,
    this.captionFirst = false,
    this.summaryText,
    super.key,
  });

  /// Usually the price ("From ₹850").
  final String? title;

  /// Usually what the price is for ("23 seats left").
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;
  final IconData? actionIcon;

  /// Shows [subtitle] (a short caption such as "Total") above [title] (the
  /// amount), as the booking steps do.
  final bool captionFirst;

  /// Plain text (up to two lines) in place of [title] and [subtitle], for a
  /// summary such as "Hebbal Flyover 21:30 / to MGBS Bus Station 06:15".
  final String? summaryText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final gutter = AbraResponsive.gutter(context);
    final hasSummary = title != null || subtitle != null || summaryText != null;
    final titleText = title == null
        ? null
        : Text(
            title!,
            style: textTheme.titleLarge?.copyWith(color: AbraColors.navy),
          );
    final subtitleText = subtitle == null
        ? null
        : Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: AbraColors.textSecondary,
            ),
          );
    final summary = summaryText != null
        ? Text(
            summaryText!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (captionFirst) ...<Widget>[
                ?subtitleText,
                ?titleText,
              ] else ...<Widget>[?titleText, ?subtitleText],
            ],
          );
    final button = AbraButton(
      label: actionLabel,
      icon: actionIcon,
      variant: AbraButtonVariant.callToAction,
      isLoading: isLoading,
      expand: !hasSummary || CustomerLayout.shouldStack(context),
      onPressed: onAction,
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AbraColors.white,
        boxShadow: AbraShadows.raised,
      ),
      child: SafeArea(
        top: false,
        child: CenteredContent(
          padding: EdgeInsets.fromLTRB(
            gutter,
            AbraSpacing.md,
            gutter,
            AbraSpacing.md,
          ),
          child: !hasSummary
              ? button
              : CustomerLayout.shouldStack(context)
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    summary,
                    const SizedBox(height: AbraSpacing.sm),
                    button,
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(child: summary),
                    const SizedBox(width: AbraSpacing.lg),
                    Flexible(child: button),
                  ],
                ),
        ),
      ),
    );
  }
}
