import 'package:flutter/material.dart';
import 'package:shared_theme/shared_theme.dart';

/// Where a step of a timeline is.
enum TimelineState { done, current, upcoming }

class TimelineStep {
  const TimelineStep({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final TimelineState state;
}

/// A vertical timeline: a dot per step (a tick when done, a ring now, empty
/// later) joined by a line. Used for the trip and for the refund. The state
/// is also in the semantics, not only in the colour.
class VerticalTimeline extends StatelessWidget {
  const VerticalTimeline({
    required this.steps,
    this.stateLabels = const <TimelineState, String>{},
    super.key,
  });

  final List<TimelineStep> steps;

  /// Spoken form of each state ("done", "now", "next").
  final Map<TimelineState, String> stateLabels;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Semantics(
              container: true,
              label:
                  '${stateLabels[steps[i].state] ?? ''} ${steps[i].title}. '
                  '${steps[i].subtitle}',
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: <Widget>[
                        _Dot(state: steps[i].state),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: steps[i].state == TimelineState.done
                                  ? AbraColors.blue
                                  : AbraColors.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AbraSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i < steps.length - 1 ? AbraSpacing.lg : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            steps[i].title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: steps[i].state == TimelineState.upcoming
                                  ? AbraColors.textSecondary
                                  : null,
                            ),
                          ),
                          Text(steps[i].subtitle, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final TimelineState state;

  @override
  Widget build(BuildContext context) => switch (state) {
    TimelineState.done => Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AbraColors.blue,
      ),
      child: const Icon(Icons.check_rounded, size: 14, color: AbraColors.white),
    ),
    TimelineState.current => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AbraColors.white,
        border: Border.all(color: AbraColors.blue, width: 5),
      ),
    ),
    TimelineState.upcoming => Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AbraColors.white,
        border: Border.all(color: const Color(0xFF9FB3C3), width: 2),
      ),
    ),
  };
}
