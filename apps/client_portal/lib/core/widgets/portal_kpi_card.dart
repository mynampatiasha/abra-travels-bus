import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// KPI card matching the demo .kc card — icon + big number + label.
class PortalKpiCard extends StatelessWidget {
  const PortalKpiCard({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    this.isHighlighted = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;
  final bool isHighlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = iconColor ?? AbraColors.blue;
    final cardBg = isDark ? const Color(0xFF16222F) : Colors.white;
    final textCol = isDark ? Colors.white : AbraColors.textPrimary;
    final subtextCol = isDark ? const Color(0xFF9AA5B1) : AbraColors.textSecondary;
    final borderCol = isDark ? const Color(0xFF223447) : AbraColors.border;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(AbraRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AbraRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isHighlighted ? AbraColors.blue : borderCol,
              width: isHighlighted ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(AbraRadius.lg),
            boxShadow: isHighlighted ? AbraShadows.card : AbraShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AbraRadius.md),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AbraSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtextCol,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
