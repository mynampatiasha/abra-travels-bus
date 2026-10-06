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
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp.router(
        routerConfig: ref.watch(adminRouterProvider),
        debugShowCheckedModeBanner: false,
        theme: AbraTheme.light(),
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
}
