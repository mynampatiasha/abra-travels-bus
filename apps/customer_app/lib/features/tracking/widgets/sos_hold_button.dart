import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_theme/shared_theme.dart';

/// The red of the safety screens in the approved design.
abstract final class SafetyColors {
  static const Color sos = Color(0xFFEF4444);
  static const Color ring = Color(0xFFB91C1C);
  static const Color ringTrack = Color(0xFFFDE8E8);
}

/// How long the SOS button must be held.
const sosHoldDuration = Duration(seconds: 3);

/// The SOS button. It only fires when it has been held for the whole
/// [sosHoldDuration]: a ring fills while it is held, and letting go (or the
/// finger sliding away) before the ring is full cancels it and calls
/// [onReleasedEarly]. Space or Enter held down works the same way.
///
/// The seconds left show in the middle while holding. Light haptic feedback
/// marks the start, the middle and the moment it fires.
class SosHoldButton extends StatefulWidget {
  const SosHoldButton({
    required this.onTriggered,
    required this.onReleasedEarly,
    required this.semanticsLabel,
    required this.secondsLabel,
    required this.label,
    super.key,
  });

  /// The ring was full: send the alert.
  final VoidCallback onTriggered;
  final VoidCallback onReleasedEarly;

  /// "SOS. Press and hold for 3 seconds."
  final String semanticsLabel;

  /// The text for [seconds] left while holding ("2.4s").
  final String Function(double seconds) secondsLabel;

  /// "SOS".
  final String label;

  @override
  State<SosHoldButton> createState() => _SosHoldButtonState();
}

class _SosHoldButtonState extends State<SosHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: sosHoldDuration)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);

  bool _holding = false;
  bool _halfway = false;
  bool _focused = false;

  void _onTick() {
    if (!_halfway && _hold.value >= 0.5) {
      _halfway = true;
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holding) {
      _holding = false;
      HapticFeedback.heavyImpact();
      widget.onTriggered();
      // Back to the start for the next time.
      _hold.value = 0;
      _halfway = false;
    }
  }

  void _start() {
    if (_holding) return;
    _holding = true;
    _halfway = false;
    HapticFeedback.lightImpact();
    _hold.forward(from: 0);
  }

  void _end() {
    if (!_holding) return;
    _holding = false;
    _hold.stop();
    _hold.value = 0;
    _halfway = false;
    widget.onReleasedEarly();
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final progress = _hold.value;
    final left = (sosHoldDuration.inMilliseconds / 1000) * (1 - progress);
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: (node, event) {
          final isHoldKey =
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.enter;
          if (!isHoldKey) return KeyEventResult.ignored;
          if (event is KeyDownEvent) _start();
          if (event is KeyUpEvent) _end();
          return KeyEventResult.handled;
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _start(),
          onPointerUp: (_) => _end(),
          onPointerCancel: (_) => _end(),
          child: AnimatedScale(
            scale: _holding ? 0.96 : 1,
            duration: AbraDurations.fast,
            child: SizedBox.square(
              dimension: 176,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // The focus ring, for keyboard users.
                  if (_focused)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: AbraColors.skyBlue, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: SafetyColors.ringTrack,
                        color: SafetyColors.ring,
                      ),
                    ),
                  ),
                  Container(
                    width: 144,
                    height: 144,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: SafetyColors.sos,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66EF4444),
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Text(
                      _holding ? widget.secondsLabel(left) : widget.label,
                      style: textTheme.headlineMedium?.copyWith(
                        color: AbraColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
