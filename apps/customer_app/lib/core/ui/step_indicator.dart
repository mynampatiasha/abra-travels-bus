import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

/// Progress dots (onboarding): the current one is a wide pill. Announced
/// once as [semanticLabel] ("Step 2 of 3").
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    required this.count,
    required this.current,
    required this.semanticLabel,
    this.onDark = false,
    super.key,
  });

  final int count;
  final int current;
  final String semanticLabel;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final duration = AbraMotion.isReduced(context)
        ? Duration.zero
        : AbraDurations.normal;
    return Semantics(
      liveRegion: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var dot = 0; dot < count; dot++)
              AnimatedContainer(
                duration: duration,
                curve: AbraMotion.enter,
                margin: const EdgeInsets.symmetric(horizontal: AbraSpacing.xs),
                height: 8,
                width: dot == current ? 24 : 8,
                decoration: BoxDecoration(
                  color: dot == current
                      ? (onDark ? AbraColors.white : AbraColors.blue)
                      : (onDark
                            ? AbraColors.navyDivider
                            : AbraColors.navyContainer),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AbraRadius.pill),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The steps of a flow (Trip → Seats → Passengers → Payment): numbered
/// circles joined by a line; done steps show a check. Labels wrap under
/// their circle and are hidden on very narrow screens, where the current
/// step's label is shown under the row instead.
class StepIndicator extends StatelessWidget {
  const StepIndicator({required this.labels, required this.current, super.key});

  final List<String> labels;

  /// Index of the step the user is on.
  final int current;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels = constraints.maxWidth / labels.length >= 72;
        return Semantics(
          label: '${current + 1}/${labels.length}: ${labels[current]}',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: i == 0
                                      ? const SizedBox.shrink()
                                      : _Line(isDone: i <= current),
                                ),
                                _Dot(index: i, current: current),
                                Expanded(
                                  child: i == labels.length - 1
                                      ? const SizedBox.shrink()
                                      : _Line(isDone: i < current),
                                ),
                              ],
                            ),
                            if (showLabels) ...<Widget>[
                              const SizedBox(height: AbraSpacing.xs),
                              Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: textTheme.labelSmall?.copyWith(
                                  color: i == current
                                      ? AbraColors.deepBlue
                                      : AbraColors.textSecondary,
                                  fontWeight: i == current
                                      ? FontWeight.w700
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
                if (!showLabels) ...<Widget>[
                  const SizedBox(height: AbraSpacing.xs),
                  Text(
                    labels[current],
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: AbraColors.deepBlue,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index, required this.current});

  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDone = index < current;
    final isCurrent = index == current;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone || isCurrent ? AbraColors.blue : AbraColors.white,
        border: Border.all(
          color: isDone || isCurrent ? AbraColors.blue : AbraColors.border,
          width: 2,
        ),
      ),
      child: isDone
          ? const Icon(Icons.check, size: 16, color: AbraColors.white)
          : Text(
              '${index + 1}',
              textScaler: TextScaler.noScaling,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isCurrent ? AbraColors.white : AbraColors.textSecondary,
              ),
            ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.isDone});

  final bool isDone;

  @override
  Widget build(BuildContext context) =>
      Container(height: 2, color: isDone ? AbraColors.blue : AbraColors.border);
}
