import 'dart:developer' as developer;

import 'log_redactor.dart';

enum LogLevel { debug, info, warning, error }

/// Logging contract used by the shared packages. Apps provide the
/// implementation (console in development, a crash reporter in production).
///
/// Implementations receive context that has already been redacted by
/// [AppLogger.log]; they must not add request bodies or headers themselves.
abstract class AppLogger {
  const AppLogger();

  /// Writes one entry. [context] is redacted before [write] sees it.
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final safe = LogRedactor.redact(context)! as Map<String, Object?>;
    write(level, message, safe);
  }

  void debug(String message, {Map<String, Object?> context = const {}}) =>
      log(LogLevel.debug, message, context: context);

  void info(String message, {Map<String, Object?> context = const {}}) =>
      log(LogLevel.info, message, context: context);

  void warning(String message, {Map<String, Object?> context = const {}}) =>
      log(LogLevel.warning, message, context: context);

  void error(String message, {Map<String, Object?> context = const {}}) =>
      log(LogLevel.error, message, context: context);

  /// Sink for an already redacted entry.
  void write(LogLevel level, String message, Map<String, Object?> context);
}

/// Discards everything. The default when an app configures no logger.
final class SilentLogger extends AppLogger {
  const SilentLogger();

  @override
  void write(LogLevel level, String message, Map<String, Object?> context) {}
}

/// Writes to the Dart developer log (IDE console / DevTools).
final class DeveloperLogger extends AppLogger {
  const DeveloperLogger({this.name = 'abra'});

  final String name;

  @override
  void write(LogLevel level, String message, Map<String, Object?> context) {
    developer.log(
      context.isEmpty ? message : '$message $context',
      name: name,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
    );
  }
}

/// One recorded entry of [MemoryLogger].
typedef LogEntry = ({
  LogLevel level,
  String message,
  Map<String, Object?> context,
});

/// Keeps entries in memory so tests can assert on what was logged.
final class MemoryLogger extends AppLogger {
  MemoryLogger();

  final List<LogEntry> entries = <LogEntry>[];

  @override
  void write(LogLevel level, String message, Map<String, Object?> context) {
    entries.add((level: level, message: message, context: context));
  }
}
