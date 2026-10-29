import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_notifications/shared_notifications.dart';
import '../core/mock/driver_mock_db.dart';

class DriverTokenSource implements AuthTokenSource {
  String? token;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<bool> refreshAccessToken() async => false;

  @override
  Future<void> onSessionRejected() async {
    token = null;
  }
}

final driverTokenSourceProvider = Provider<DriverTokenSource>((ref) {
  return DriverTokenSource();
});

final driverApiClientProvider = Provider<ApiClient>((ref) {
  const baseUrl = String.fromEnvironment(
    'ABRA_API_BASE_URL',
    defaultValue: 'http://localhost:4003',
  );
  final config = AppConfig(
    environment: AppEnvironment.development,
    appKind: AppKind.driver,
    apiBaseUrl: Uri.parse(baseUrl),
    clientType: ClientType.mobile,
  );
  final client = ApiClient(
    config: config,
    logger: DeveloperLogger(),
    languageTag: () => ref.watch(driverLanguageProvider),
  );
  client.attachTokenSource(ref.watch(driverTokenSourceProvider));
  return client;
});

final driverNotificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(driverApiClientProvider));
});

final driverMockDbProvider = Provider<DriverMockDb>((ref) {
  final db = DriverMockDb.instance;
  db.init();
  ref.onDispose(db.dispose);
  return db;
});

// Active driver name
final currentDriverProvider = NotifierProvider<_CurrentDriverNotifier, String>(
  _CurrentDriverNotifier.new,
);

class _CurrentDriverNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String name) => state = name;
}

// Active language
final driverLanguageProvider = NotifierProvider<_LangNotifier, String>(
  _LangNotifier.new,
);

class _LangNotifier extends Notifier<String> {
  @override
  String build() => 'en';
  void set(String lang) => state = lang;
}

// Theme mode
final driverThemeModeProvider = NotifierProvider<_ThemeModeNotifier, ThemeMode>(
  _ThemeModeNotifier.new,
);

class _ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;
  void toggle() => state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}
