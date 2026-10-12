import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import 'abra_motion.dart';

/// A placeholder block in the shape of content that is loading. Pulses
/// gently; stays still when motion is reduced.
class AbraSkeleton extends StatefulWidget {
  const AbraSkeleton({
    this.width,
    this.height = 14,
    this.radius = AbraRadius.sm,
    super.key,
  });

  /// A round placeholder, for an icon or avatar.
  const AbraSkeleton.circle({required double size, super.key})
    : width = size,
      height = size,
      radius = AbraRadius.pill;

  /// Null takes the available width.
  final double? width;
  final double height;
  final double radius;

  @override
  State<AbraSkeleton> createState() => _AbraSkeletonState();
}

class _AbraSkeletonState extends State<AbraSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AbraMotion.isReduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            AbraColors.navyContainer,
            AbraColors.lightGray,
            _controller.value,
          ),
          borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
        ),
        child: SizedBox(width: widget.width, height: widget.height),
      ),
    ),
  );
}

/// Announces "Loading" once for a group of skeletons, which are themselves
/// hidden from screen readers.
class AbraSkeletonGroup extends StatelessWidget {
  const AbraSkeletonGroup({required this.child, this.label, super.key});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label:
        label ?? AbraLocalizations.of(context).text(AbraStrings.commonLoading),
    child: child,
  );
}
