import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';

import '../app/customer_app.dart';
import '../app/providers.dart';
import '../app/startup_failure_app.dart';
import 'app_dependencies.dart';
import 'customer_environment.dart';
import 'error_handling.dart';

/// Starts the customer app: error handling first, then configuration and
/// the long-lived services, then the widget tree.
///
/// The stored session is checked after the first frame (see
/// `StartupController`), so the app never waits on the network to appear.
Future<void> bootstrap({
  CustomerEnvironment environment = const CustomerEnvironment.fromDartDefines(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  const AppLogger logger = kReleaseMode
      ? SilentLogger()
      : DeveloperLogger(name: 'abra.customer');
  installErrorHandlers(logger);

  try {
    final dependencies = await AppDependencies.create(
      config: environment.toAppConfig(),
      logger: logger,
    );
    runApp(
      ProviderScope(
        overrides: [appDependenciesProvider.overrideWithValue(dependencies)],
        child: const CustomerApp(),
      ),
    );
  } on Object catch (error, stack) {
    // A wrong build configuration or unusable device storage. There is
    // nothing safe to run, so say so instead of showing a blank screen.
    reportError(logger, error, stack, source: 'bootstrap');
    runApp(const StartupFailureApp());
  }
}
