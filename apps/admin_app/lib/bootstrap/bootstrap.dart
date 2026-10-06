import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_theme/shared_theme.dart';

import '../app/admin_app.dart';
import '../app/providers.dart';
import 'admin_environment.dart';
import 'app_dependencies.dart';
import 'error_handling.dart';

/// Starts the management app: error handling, configuration, services, then
/// the widget tree. The stored session is checked after the first frame.
Future<void> bootstrap({
  AdminEnvironment environment = const AdminEnvironment.fromDartDefines(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  const AppLogger logger = kReleaseMode
      ? SilentLogger()
      : DeveloperLogger(name: 'abra.admin');
  installErrorHandlers(logger);

  try {
    final dependencies = await AppDependencies.create(
      config: environment.toAppConfig(),
      logger: logger,
    );
    runApp(
      ProviderScope(
        overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
        child: const AdminApp(),
      ),
    );
  } on Object catch (error, stack) {
    reportError(logger, error, stack, source: 'bootstrap');
    // A wrong build configuration: nothing safe to run. The cause is in the
    // log; the screen shows no technical detail.
    runApp(
      MaterialApp(
        theme: AbraTheme.light(),
        home: const Scaffold(
          body: Center(
            child: Icon(
              Icons.error_outline,
              size: AbraSizes.stateIllustration,
              color: AbraColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
