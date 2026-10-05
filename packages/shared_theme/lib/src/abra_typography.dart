import 'package:flutter/material.dart';

import 'abra_tokens.dart';

/// Text styles of the design system, on top of the Material 3 type scale.
abstract final class AbraTypography {
  /// Builds the text theme. [fontFamily] is optional: without it the
  /// platform font is used, which already covers every script (Latin,
  /// Devanagari, Telugu, Kannada, Tamil, Malayalam, Bengali, Arabic, CJK).
  ///
  /// Line heights are left at the Material defaults on purpose: Indic and
  /// Arabic scripts need more vertical room than Latin, and fixed tight
  /// heights clip them.
  static TextTheme textTheme({String? fontFamily}) {
    final base = Typography.material2021(
      platform: TargetPlatform.android,
    ).black;
    TextStyle style(TextStyle? source, FontWeight weight) => source!.copyWith(
      fontFamily: fontFamily,
      fontWeight: weight,
      color: AbraColors.textPrimary,
    );

    return TextTheme(
      displayLarge: style(base.displayLarge, FontWeight.w700),
      displayMedium: style(base.displayMedium, FontWeight.w700),
      displaySmall: style(base.displaySmall, FontWeight.w700),
      headlineLarge: style(base.headlineLarge, FontWeight.w700),
      headlineMedium: style(base.headlineMedium, FontWeight.w700),
      headlineSmall: style(base.headlineSmall, FontWeight.w600),
      titleLarge: style(base.titleLarge, FontWeight.w600),
      titleMedium: style(base.titleMedium, FontWeight.w600),
      titleSmall: style(base.titleSmall, FontWeight.w600),
      bodyLarge: style(base.bodyLarge, FontWeight.w400),
      bodyMedium: style(base.bodyMedium, FontWeight.w400),
      bodySmall: style(
        base.bodySmall,
        FontWeight.w400,
      ).copyWith(color: AbraColors.textSecondary),
      labelLarge: style(base.labelLarge, FontWeight.w600),
      labelMedium: style(base.labelMedium, FontWeight.w600),
      labelSmall: style(base.labelSmall, FontWeight.w600),
    );
  }
}
