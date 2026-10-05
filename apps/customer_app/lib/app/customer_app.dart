import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

import '../l10n/customer_strings.dart';
import '../routing/customer_router.dart';
import 'providers.dart';

/// Root widget: the Abra theme, the selected language and the router.
class CustomerApp extends ConsumerStatefulWidget {
  const CustomerApp({super.key});

  @override
  ConsumerState<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends ConsumerState<CustomerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Starts the check of the stored session.
    ref.read(startupControllerProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (locales == null) return;
    ref
        .read(appDependenciesProvider)
        .localeController
        .updateDeviceLocales(locales);
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = ref.watch(appDependenciesProvider);
    final localeController = dependencies.localeController;
    final router = ref.watch(customerRouterProvider);

    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) => MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        theme: AbraTheme.light(),
        locale: localeController.locale,
        supportedLocales: localeController.config.supportedLocales,
        localizationsDelegates: <LocalizationsDelegate<Object?>>[
          AbraLocalizationsDelegate(
            config: localeController.config,
            source: dependencies.translations,
            onMissingKey: (key, locale) => dependencies.logger.warning(
              'Missing translation',
              context: <String, Object?>{
                'key': key,
                'locale': LocaleTags.of(locale),
              },
            ),
          ),
          ...GlobalMaterialLocalizations.delegates,
        ],
        onGenerateTitle: (context) =>
            AbraLocalizations.of(context).text(CustomerStrings.appName),
      ),
    );
  }
}
