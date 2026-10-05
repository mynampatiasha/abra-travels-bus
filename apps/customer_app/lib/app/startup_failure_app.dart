import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../bootstrap/app_dependencies.dart';
import '../l10n/customer_strings.dart';

/// Shown instead of the app when it cannot start at all (unusable build
/// configuration or device storage). Offers no actions because none would
/// work; the cause is in the log, never on screen.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    this.translations = AppDependencies.bundledTranslations,
    super.key,
  });

  final TranslationSource translations;

  @override
  Widget build(BuildContext context) {
    final config = AbraLocaleConfig();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AbraTheme.light(),
      supportedLocales: config.supportedLocales,
      localeListResolutionCallback: (locales, _) =>
          config.resolve(deviceLocales: locales ?? const <Locale>[]),
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        AbraLocalizationsDelegate(config: config, source: translations),
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Builder(
        builder: (context) {
          final l10n = AbraLocalizations.of(context);
          return Scaffold(
            body: AbraPageContainer(
              child: AbraStateView(
                kind: AbraStateKind.error,
                title: l10n.text(CustomerStrings.startupFailedTitle),
                message: l10n.text(CustomerStrings.startupFailedMessage),
              ),
            ),
          );
        },
      ),
    );
  }
}
