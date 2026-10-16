import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/mock/driver_mock_db.dart';

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
