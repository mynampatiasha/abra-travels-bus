import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_theme/shared_theme.dart';

/// Routes every uncaught error to [logger] and replaces Flutter's red
/// error box, so a defect never crashes the app silently and never shows
/// technical text to a customer.
///
/// Only the error type and the stack trace are recorded. Error messages are
/// left out because they can contain user input or server data.
void installErrorHandlers(AppLogger logger, {bool showDetails = kDebugMode}) {
  FlutterError.onError = (details) {
    reportError(logger, details.exception, details.stack, source: 'framework');
    if (showDetails) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(logger, error, stack, source: 'platform');
    return true; // Handled: the app keeps running.
  };
  ErrorWidget.builder = (details) => showDetails
      ? ErrorWidget(details.exception)
      : const BrokenWidgetFallback();
}

/// Records one uncaught error without its message.
void reportError(
  AppLogger logger,
  Object error,
  StackTrace? stack, {
  required String source,
}) {
  logger.error(
    'Uncaught error',
    context: <String, Object?>{
      'source': source,
      'type': error.runtimeType.toString(),
      'stack': ?stack?.toString(),
    },
  );
}

/// Shown in place of a widget that failed to build (release builds).
class BrokenWidgetFallback extends StatelessWidget {
  const BrokenWidgetFallback({super.key});

  @override
  Widget build(BuildContext context) {
    // May be built outside the app's Localizations, so nothing is assumed.
    final l10n = Localizations.of<AbraLocalizations>(
      context,
      AbraLocalizations,
    );
    final label = l10n?.text(AbraStrings.stateErrorTitle);
    return Semantics(
      label: label,
      child: const ColoredBox(
        color: AbraColors.lightGray,
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: AbraColors.textSecondary,
            size: AbraSizes.iconLarge,
          ),
        ),
      ),
    );
  }
}
