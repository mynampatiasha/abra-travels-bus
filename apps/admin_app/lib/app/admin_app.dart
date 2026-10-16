import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../l10n/admin_strings.dart';
import '../routing/admin_router.dart';
import 'providers.dart';

/// Root widget of the management app.
class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  @override
  void initState() {
    super.initState();
    // Starts the check of the stored session.
    ref.read(startupProvider);
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = ref.watch(appDependenciesProvider);
    final localeController = dependencies.localeController;
    final themeMode = ref.watch(themeModeProvider);

    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp.router(
        routerConfig: ref.watch(adminRouterProvider),
        debugShowCheckedModeBanner: false,
        theme: AbraTheme.light(),
        darkTheme: _buildDarkTheme(),
        themeMode: themeMode,
        locale: localeController.locale,
        supportedLocales: localeController.config.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<Object?>>[
          AbraLocalizationsDelegate(
            config: localeController.config,
            source: dependencies.translations,
          ),
          ...GlobalMaterialLocalizations.delegates,
        ],
        onGenerateTitle: (context) =>
            AbraLocalizations.of(context).text(AdminStrings.appName),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    const darkBg = Color(0xFF0B1620);
    const darkCard = Color(0xFF13222F);
    const darkBorder = Color(0xFF2A3E50);
    const darkText = Color(0xFFE6EEF5);
    const darkMuted = Color(0xFF9FB6C9);

    final base = AbraTheme.light();
    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      canvasColor: darkBg,
      cardColor: darkCard,
      dividerColor: darkBorder,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: darkCard,
        onSurface: darkText,
        onSurfaceVariant: darkMuted,
        outline: darkBorder,
        outlineVariant: darkBorder,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: darkCard,
        foregroundColor: darkText,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
    );
  }
}
