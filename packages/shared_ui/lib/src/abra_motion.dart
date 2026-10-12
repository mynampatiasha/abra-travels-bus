import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Motion rules of the design system.
abstract final class AbraMotion {
  /// True when the person asked the device to reduce motion. Every animated
  /// shared widget checks this and shows its final state at once.
  static bool isReduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static const Curve enter = Curves.easeOutCubic;

  /// Delay between items that enter one after another.
  static const Duration stagger = Duration(milliseconds: 45);

  /// Items beyond this position enter together with it, so a long list
  /// never keeps the reader waiting.
  static const int maxStaggeredItems = 8;
}

/// Lets its child fade in and rise a few pixels when it first appears.
/// [index] staggers the items of a list. Does nothing when motion is
/// reduced. The child is in the tree and can be used from the first frame.
class AbraEntrance extends StatefulWidget {
  const AbraEntrance({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  @override
  State<AbraEntrance> createState() => _AbraEntranceState();
}

class _AbraEntranceState extends State<AbraEntrance>
    with SingleTickerProviderStateMixin {
  static const _rise = 12.0;

  late final Duration _delay =
      AbraMotion.stagger *
      widget.index.clamp(0, AbraMotion.maxStaggeredItems).toInt();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _delay + AbraDurations.slow,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / (_delay + AbraDurations.slow).inMilliseconds,
      1,
      curve: AbraMotion.enter,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AbraMotion.isReduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(
        offset: Offset(0, _rise * (1 - _progress.value)),
        child: child,
      ),
    ),
  );
}
