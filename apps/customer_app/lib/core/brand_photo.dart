import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// The Abra Travels photograph (bus on the highway, logo above it), cropped
/// to fill its box. [alignment] chooses the part that stays visible: the
/// logo is in the upper half, the bus in the lower half.
///
/// If the image cannot be shown, the brand gradient takes its place, so
/// whatever is drawn on top stays readable.
class BrandPhoto extends StatelessWidget {
  const BrandPhoto({this.alignment = Alignment.center, super.key});

  static const assetName = 'assets/images/welcome.webp';

  /// Keeps the logo and name in view.
  static const logoAlignment = Alignment(0, -0.5);

  /// Keeps the bus in view.
  static const busAlignment = Alignment(-0.2, 0.42);

  final Alignment alignment;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: DecoratedBox(
      decoration: const BoxDecoration(gradient: AbraGradients.brand),
      child: Image.asset(
        assetName,
        fit: BoxFit.cover,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, _, _) => const SizedBox.expand(),
      ),
    ),
  );
}
