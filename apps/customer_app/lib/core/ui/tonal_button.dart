import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// A quieter button than the main action: light-blue fill, blue text (the
/// "Apply" and "Verify" of the booking forms, "Change payment method").
/// Shows a progress ring and ignores taps while [isLoading].
class TonalButton extends StatelessWidget {
  const TonalButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AbraColors.lightBlue,
        foregroundColor: AbraColors.blueDark,
        minimumSize: const Size(
          AbraSizes.minTouchTarget,
          AbraSizes.buttonHeight,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AbraRadius.medium),
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: AbraSizes.iconSmall + 4,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: AbraSizes.iconSmall + 4),
                  const SizedBox(width: AbraSpacing.sm),
                ],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
              ],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
