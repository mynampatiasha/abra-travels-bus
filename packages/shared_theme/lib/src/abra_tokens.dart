import 'package:flutter/widgets.dart';

/// Brand and neutral colours of the Abra Travels design system.
///
/// The brand is navy and blue: deep navy for navigation and headings,
/// professional blue for primary actions and selection, sky blue as an
/// accent on dark surfaces. Green, orange and red are used only for what
/// they mean (success, warning, failure), never as brand colours.
abstract final class AbraColors {
  // Brand.
  static const navy = Color(0xFF12304A);
  static const navySecondary = Color(0xFF0B3B6E);
  static const blue = Color(0xFF1677C8);
  static const brightBlue = Color(0xFF0878C9);
  static const skyBlue = Color(0xFF36BDF5);

  /// Deep blue: emphasis on light surfaces, the dark end of the action
  /// gradient, selected text on [skyContainer].
  static const deepBlue = Color(0xFF0B4EA2);
  static const lightBlue = Color(0xFFE8F6FD);

  /// Selected chips and seats (with [deepBlue] text).
  static const skyContainer = Color(0xFFDDF3FC);
  static const lightGray = Color(0xFFF3F5F7);
  static const white = Color(0xFFFFFFFF);

  // Meaning only: success and "available", warning and "pending".
  static const teal = Color(0xFF1B8A5A);
  static const orange = Color(0xFFF28C28);

  // Darker shades for small text on tinted backgrounds, where the colours
  // themselves do not reach the 4.5:1 contrast needed for text.
  static const tealDark = Color(0xFF146C46);
  static const blueDark = Color(0xFF0F5C9E);
  static const orangeDark = Color(0xFF8A4B00);

  // Tints for containers and backgrounds.
  static const blueContainer = lightBlue;
  static const tealContainer = Color(0xFFDDF1E7);
  static const orangeContainer = Color(0xFFFDEBD7);
  static const navyContainer = Color(0xFFE1E7EE);

  static const danger = Color(0xFFB3261E);
  static const dangerContainer = Color(0xFFF9DEDC);

  // Text and lines on light surfaces.
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF4A5B70);
  static const textDisabled = Color(0xFF9AA5B1);
  static const border = Color(0xFFD5DBE1);
  static const divider = Color(0xFFE4E8EC);
  static const scrim = Color(0x8012304A);

  // Text and lines on navy surfaces (side navigation, brand headers).
  static const onNavy = white;
  static const onNavyMuted = Color(0xFFB7C6D9);
  static const navyHover = Color(0x14FFFFFF);
  static const navyDivider = Color(0x1FFFFFFF);
}

/// Brand gradients. Used for major brand surfaces only: sign-in and
/// onboarding branding, hero headers, the main call to action.
abstract final class AbraGradients {
  /// The approved brand gradient (135 degrees): navy, blue, sky blue.
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AbraColors.navy, AbraColors.blue, AbraColors.skyBlue],
    stops: <double>[0, 0.58, 1],
  );

  /// The dark part of the brand gradient: white text stays readable on
  /// every point of it.
  static const brandDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AbraColors.navy, AbraColors.deepBlue, AbraColors.blue],
    stops: <double>[0, 0.55, 1],
  );

  /// Fill of the main call to action. White text meets 4.5:1 on both ends.
  static const action = LinearGradient(
    colors: <Color>[AbraColors.deepBlue, AbraColors.blue],
  );
}

/// Spacing scale in logical pixels. Layouts use these steps only.
abstract final class AbraSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii.
abstract final class AbraRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(xl));
}

/// Material elevation levels.
abstract final class AbraElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 6;
}

/// Shadows for surfaces that do not use Material elevation.
abstract final class AbraShadows {
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x1412304A), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x0F12304A), blurRadius: 6, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x2412304A), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Component sizes.
abstract final class AbraSizes {
  /// Minimum touch target (Material and Apple accessibility guidance).
  static const double minTouchTarget = 48;
  static const double buttonHeight = 48;
  static const double compactButtonHeight = 40;
  static const double iconSmall = 16;
  static const double icon = 24;
  static const double iconLarge = 48;
  static const double stateIllustration = 72;

  /// Widest a column of content grows on tablets and desktop.
  static const double maxContentWidth = 1200;
  static const double maxFormWidth = 480;

  /// Width of the side navigation of the management app.
  static const double sideNavigation = 256;
}

/// Animation durations.
abstract final class AbraDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}
