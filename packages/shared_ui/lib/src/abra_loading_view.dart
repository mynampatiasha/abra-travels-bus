import 'package:flutter/material.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

/// Centered progress indicator for a screen or section that is loading.
/// Announces "Loading" to screen readers.
class AbraLoadingView extends StatelessWidget {
  const AbraLoadingView({this.label, this.onDark = false, super.key});

  /// Text under the indicator. Defaults to the translated "Loading…" for
  /// screen readers only.
  final String? label;

  /// True on navy and brand-gradient surfaces (white indicator and text).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final announcement =
        label ?? AbraLocalizations.of(context).text(AbraStrings.commonLoading);
    return Center(
      child: Semantics(
        label: announcement,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: onDark ? AbraColors.white : null),
            if (label != null) ...<Widget>[
              const SizedBox(height: AbraSpacing.lg),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: onDark ? AbraColors.white : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
