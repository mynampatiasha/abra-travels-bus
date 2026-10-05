import 'package:flutter/material.dart';

import 'abra_tokens.dart';

/// Meaning of a status colour.
enum AbraStatusTone { success, warning, info, danger, neutral }

/// Foreground and container colour of one status tone.
@immutable
class AbraTonePair {
  const AbraTonePair({required this.foreground, required this.container});

  final Color foreground;
  final Color container;

  static AbraTonePair lerp(AbraTonePair a, AbraTonePair b, double t) =>
      AbraTonePair(
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        container: Color.lerp(a.container, b.container, t)!,
      );
}

/// Status colours of the design system, available from the theme:
/// `Theme.of(context).extension<AbraStatusColors>()`.
///
/// Green means success, confirmed, available, completed; orange means
/// warning and time pressure; blue means information; red means failure.
/// Foregrounds are the darker shades of each hue so that status text meets
/// WCAG AA contrast on its tinted container.
@immutable
class AbraStatusColors extends ThemeExtension<AbraStatusColors> {
  const AbraStatusColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
    required this.neutral,
  });

  static const light = AbraStatusColors(
    success: AbraTonePair(
      foreground: AbraColors.tealDark,
      container: AbraColors.tealContainer,
    ),
    warning: AbraTonePair(
      foreground: AbraColors.orangeDark,
      container: AbraColors.orangeContainer,
    ),
    info: AbraTonePair(
      foreground: AbraColors.blueDark,
      container: AbraColors.blueContainer,
    ),
    danger: AbraTonePair(
      foreground: AbraColors.danger,
      container: AbraColors.dangerContainer,
    ),
    neutral: AbraTonePair(
      foreground: AbraColors.textSecondary,
      container: AbraColors.navyContainer,
    ),
  );

  final AbraTonePair success;
  final AbraTonePair warning;
  final AbraTonePair info;
  final AbraTonePair danger;
  final AbraTonePair neutral;

  /// The colours of [tone].
  AbraTonePair of(AbraStatusTone tone) => switch (tone) {
    AbraStatusTone.success => success,
    AbraStatusTone.warning => warning,
    AbraStatusTone.info => info,
    AbraStatusTone.danger => danger,
    AbraStatusTone.neutral => neutral,
  };

  /// The status colours of the nearest theme, or [light] when the theme has
  /// none.
  static AbraStatusColors from(BuildContext context) =>
      Theme.of(context).extension<AbraStatusColors>() ?? light;

  @override
  AbraStatusColors copyWith({
    AbraTonePair? success,
    AbraTonePair? warning,
    AbraTonePair? info,
    AbraTonePair? danger,
    AbraTonePair? neutral,
  }) => AbraStatusColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    info: info ?? this.info,
    danger: danger ?? this.danger,
    neutral: neutral ?? this.neutral,
  );

  @override
  AbraStatusColors lerp(AbraStatusColors? other, double t) {
    if (other == null) return this;
    return AbraStatusColors(
      success: AbraTonePair.lerp(success, other.success, t),
      warning: AbraTonePair.lerp(warning, other.warning, t),
      info: AbraTonePair.lerp(info, other.info, t),
      danger: AbraTonePair.lerp(danger, other.danger, t),
      neutral: AbraTonePair.lerp(neutral, other.neutral, t),
    );
  }
}
