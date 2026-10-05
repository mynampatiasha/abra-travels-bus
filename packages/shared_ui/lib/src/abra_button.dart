import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Visual weight of an [AbraButton].
enum AbraButtonVariant {
  /// The one main action of a screen, and payment actions (orange).
  callToAction,

  /// A regular primary action (blue).
  primary,

  /// A secondary action (outlined).
  secondary,

  /// A low-emphasis action (text only).
  text,
}

/// The standard button. While [isLoading] it shows a progress indicator and
/// cannot be pressed, which prevents double submission. A null [onPressed]
/// disables it.
class AbraButton extends StatelessWidget {
  const AbraButton({
    required this.label,
    required this.onPressed,
    this.variant = AbraButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AbraButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// Take the full available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading)
          const SizedBox.square(
            dimension: AbraSizes.iconSmall,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: AbraSizes.iconSmall + AbraSpacing.xs),
        if (isLoading || icon != null) const SizedBox(width: AbraSpacing.sm),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
    );

    final Widget button = switch (variant) {
      AbraButtonVariant.callToAction => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.tertiary,
          foregroundColor: scheme.onTertiary,
        ),
        child: content,
      ),
      AbraButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
      AbraButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
      AbraButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        child: content,
      ),
    };

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
