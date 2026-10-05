import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// A small pill that shows a status, coloured by its meaning. The status is
/// always written out in [label]; colour is never the only signal.
class AbraStatusBadge extends StatelessWidget {
  const AbraStatusBadge({
    required this.label,
    this.tone = AbraStatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AbraStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = AbraStatusColors.from(context).of(tone);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: colors.foreground);

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.container,
            borderRadius: const BorderRadius.all(
              Radius.circular(AbraRadius.pill),
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AbraSpacing.md,
              vertical: AbraSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: AbraSizes.iconSmall,
                    color: colors.foreground,
                  ),
                  const SizedBox(width: AbraSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: textStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
