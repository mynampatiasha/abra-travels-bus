import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Visual weight of an [AbraButton].
enum AbraButtonVariant {
  /// The one main action of a screen, and payment actions (brand
  /// gradient).
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
          SizedBox.square(
            dimension: AbraSizes.iconSmall,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AbraButtonVariant.callToAction
                  ? AbraColors.white
                  : null,
            ),
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
      // The brand gradient under a transparent button, so focus, hover and
      // press feedback stay the standard ones.
      AbraButtonVariant.callToAction => DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : AbraGradients.action,
          color: onPressed == null
              ? scheme.onSurface.withValues(alpha: 0.12)
              : null,
          borderRadius: AbraRadius.medium,
          boxShadow: onPressed == null ? null : AbraShadows.card,
        ),
        child: FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: AbraColors.white,
            disabledForegroundColor: onPressed == null
                ? null
                : AbraColors.white,
            shadowColor: Colors.transparent,
          ),
          child: content,
        ),
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
