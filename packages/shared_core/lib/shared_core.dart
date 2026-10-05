/// Foundations shared by every Abra Travels app: configuration, result and
/// failure types, logging and storage contracts. Pure Dart, no Flutter.
library;

export 'src/config/app_config.dart';
export 'src/errors/api_error_codes.dart';
export 'src/errors/app_failure.dart';
export 'src/logging/app_logger.dart';
export 'src/logging/log_redactor.dart';
export 'src/result/result.dart';
export 'src/storage/in_memory_stores.dart';
export 'src/storage/preferences_store.dart';
export 'src/storage/secure_store.dart';
