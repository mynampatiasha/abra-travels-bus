import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Page header with title + subtitle + action buttons — matches demo .ph.
class PortalSectionTitle extends StatelessWidget {
  const PortalSectionTitle({
    required this.title,
    this.subtitle,
    this.actions,
    this.breadcrumbs,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final List<String>? breadcrumbs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (breadcrumbs != null && breadcrumbs!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AbraSpacing.xs),
            child: Text(
              breadcrumbs!.join(' / '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AbraColors.textSecondary,
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AbraColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AbraColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: AbraSpacing.md),
              Wrap(spacing: AbraSpacing.sm, children: actions!),
            ],
          ],
        ),
      ],
    );
  }
}
