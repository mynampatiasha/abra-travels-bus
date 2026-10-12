import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// The picture of an empty, guest or "coming soon" state: a symbol in a
/// white circle on a soft brand-gradient disc, with a small accent dot.
/// Decorative (excluded from semantics).
class StateIllustration extends StatelessWidget {
  const StateIllustration({required this.icon, this.size = 112, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AbraColors.skyContainer,
                  AbraColors.lightBlue.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: SizedBox.square(dimension: size),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AbraColors.white,
              shape: BoxShape.circle,
              boxShadow: AbraShadows.card,
            ),
            child: SizedBox.square(
              dimension: size * 0.62,
              child: Icon(icon, size: size * 0.32, color: AbraColors.deepBlue),
            ),
          ),
          PositionedDirectional(
            top: size * 0.1,
            end: size * 0.12,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AbraColors.skyBlue,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: size * 0.1),
            ),
          ),
        ],
      ),
    ),
  );
}
