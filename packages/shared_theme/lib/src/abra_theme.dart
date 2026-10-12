import 'package:flutter/material.dart';

import 'abra_status_colors.dart';
import 'abra_tokens.dart';
import 'abra_typography.dart';

/// The Abra Travels Material 3 theme. Every app uses
/// `MaterialApp(theme: AbraTheme.light())`, so buttons, fields, cards,
/// dialogs, sheets, chips and navigation look the same everywhere.
abstract final class AbraTheme {
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AbraColors.blue,
    onPrimary: AbraColors.white,
    primaryContainer: AbraColors.blueContainer,
    onPrimaryContainer: AbraColors.navy,
    secondary: AbraColors.navy,
    onSecondary: AbraColors.white,
    secondaryContainer: AbraColors.navyContainer,
    onSecondaryContainer: AbraColors.navy,
    // Navy on sky blue: white on sky blue does not meet text contrast.
    tertiary: AbraColors.skyBlue,
    onTertiary: AbraColors.navy,
    tertiaryContainer: AbraColors.lightBlue,
    onTertiaryContainer: AbraColors.navy,
    error: AbraColors.danger,
    onError: AbraColors.white,
    errorContainer: AbraColors.dangerContainer,
    onErrorContainer: Color(0xFF601410),
    surface: AbraColors.white,
    onSurface: AbraColors.textPrimary,
    onSurfaceVariant: AbraColors.textSecondary,
    surfaceContainerLowest: AbraColors.white,
    surfaceContainerLow: AbraColors.lightGray,
    surfaceContainer: AbraColors.lightGray,
    surfaceContainerHigh: AbraColors.navyContainer,
    surfaceContainerHighest: AbraColors.navyContainer,
    outline: AbraColors.border,
    outlineVariant: AbraColors.divider,
    scrim: AbraColors.scrim,
    inverseSurface: AbraColors.navy,
    onInverseSurface: AbraColors.white,
    inversePrimary: AbraColors.blueContainer,
  );

  /// The light theme. [fontFamily] is optional (see `AbraTypography`).
  static ThemeData light({String? fontFamily}) {
    const scheme = lightColorScheme;
    final textTheme = AbraTypography.textTheme(fontFamily: fontFamily);
    const buttonShape = RoundedRectangleBorder(borderRadius: AbraRadius.medium);
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AbraSpacing.xl,
      vertical: AbraSpacing.md,
    );
    const minimumButtonSize = Size(64, AbraSizes.buttonHeight);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AbraRadius.medium,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AbraColors.lightGray,
      textTheme: textTheme,
      fontFamily: fontFamily,
      dividerColor: AbraColors.divider,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const <ThemeExtension<dynamic>>[AbraStatusColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: AbraColors.navy,
        foregroundColor: AbraColors.white,
        elevation: AbraElevation.none,
        scrolledUnderElevation: AbraElevation.low,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: AbraColors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimumButtonSize,
          padding: buttonPadding,
          shape: buttonShape,
          // Brand blue as label text on the gray page background is below
          // 4.5:1, so button labels use its darker shade.
          foregroundColor: AbraColors.blueDark,
          side: const BorderSide(color: AbraColors.blue),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AbraSizes.minTouchTarget),
          shape: buttonShape,
          foregroundColor: AbraColors.blueDark,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AbraColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AbraSpacing.lg,
          vertical: AbraSpacing.md,
        ),
        border: inputBorder(AbraColors.border),
        enabledBorder: inputBorder(AbraColors.border),
        focusedBorder: inputBorder(AbraColors.blue, 2),
        errorBorder: inputBorder(AbraColors.danger),
        focusedErrorBorder: inputBorder(AbraColors.danger, 2),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AbraColors.textSecondary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AbraColors.textDisabled,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AbraColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x3312304A),
        elevation: AbraElevation.low,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AbraRadius.large,
          side: BorderSide(color: AbraColors.divider),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AbraColors.navy,
          borderRadius: AbraRadius.small,
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: AbraColors.white),
        waitDuration: const Duration(milliseconds: 400),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AbraColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AbraRadius.medium),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AbraColors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AbraColors.navy,
        headerForegroundColor: AbraColors.white,
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(Color(0x6612304A)),
        radius: Radius.circular(AbraRadius.pill),
        thickness: WidgetStatePropertyAll<double>(6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AbraColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: AbraElevation.high,
        shape: const RoundedRectangleBorder(
          borderRadius: AbraRadius.extraLarge,
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AbraColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AbraRadius.xl),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AbraColors.white,
        selectedColor: AbraColors.blueContainer,
        side: const BorderSide(color: AbraColors.border),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AbraSpacing.md,
          vertical: AbraSpacing.sm,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AbraColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AbraColors.blueContainer,
        elevation: AbraElevation.medium,
        shadowColor: AbraColors.navy,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AbraColors.blueDark
                : AbraColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AbraColors.blueDark
                : AbraColors.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AbraColors.navy,
        indicatorColor: AbraColors.blue,
        selectedIconTheme: const IconThemeData(color: AbraColors.white),
        unselectedIconTheme: const IconThemeData(color: AbraColors.onNavyMuted),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AbraColors.white,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AbraColors.onNavyMuted,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AbraColors.navy,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AbraColors.white,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AbraRadius.medium),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AbraColors.blue,
        linearTrackColor: AbraColors.blueContainer,
      ),
      dividerTheme: const DividerThemeData(
        color: AbraColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
