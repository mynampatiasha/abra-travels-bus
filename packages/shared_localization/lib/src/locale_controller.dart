import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_core/shared_core.dart';

import 'abra_locale_config.dart';
import 'locale_tags.dart';
import 'text_direction_resolver.dart';

/// The language the app is shown in, and the user's choice.
///
/// - No choice stored: the app follows the device language (when it is
///   offered), otherwise the default locale.
/// - [selectLocale] switches immediately and is remembered across restarts.
/// - Listeners are notified on every change; `MaterialApp(locale:
///   controller.locale)` inside a `ListenableBuilder` switches the whole
///   app at runtime, including text direction.
class LocaleController extends ChangeNotifier {
  LocaleController({
    required AbraLocaleConfig config,
    required PreferencesStore preferences,
    List<Locale>? deviceLocales,
    this.preferenceKey = 'abra.preferences.locale_tag',
  }) : _config = config,
       _preferences = preferences,
       _deviceLocales = deviceLocales ?? PlatformDispatcher.instance.locales {
    _userSelected = LocaleTags.tryParse(_preferences.getString(preferenceKey));
    _locale = _resolve();
  }

  final AbraLocaleConfig _config;
  final PreferencesStore _preferences;

  /// Key of the stored language tag in [PreferencesStore].
  final String preferenceKey;

  List<Locale> _deviceLocales;
  Locale? _userSelected;
  late Locale _locale;

  AbraLocaleConfig get config => _config;

  /// The locale in use.
  Locale get locale => _locale;

  /// BCP-47 tag of [locale], for the `Accept-Language` header.
  String get languageTag => LocaleTags.of(_locale);

  /// The language the user chose, or null when following the device.
  Locale? get userSelected => _userSelected;

  bool get followsDevice => _userSelected == null;

  TextDirection get textDirection => TextDirectionResolver.of(_locale);

  Locale _resolve() => _config.resolve(
    userSelected: _userSelected,
    deviceLocales: _deviceLocales,
  );

  void _apply() {
    final next = _resolve();
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
  }

  /// Switches to [locale] and remembers it. Null returns to following the
  /// device language. A locale that is not offered is ignored and false is
  /// returned.
  Future<bool> selectLocale(Locale? locale) async {
    if (locale == null) {
      _userSelected = null;
      await _preferences.remove(preferenceKey);
      _apply();
      return true;
    }
    final matched = _config.match(locale);
    if (matched == null) return false;
    _userSelected = matched;
    await _preferences.setString(preferenceKey, LocaleTags.of(matched));
    _apply();
    return true;
  }

  /// Tells the controller that the device languages changed (from
  /// `WidgetsBindingObserver.didChangeLocales`). Only matters while
  /// following the device.
  void updateDeviceLocales(List<Locale> locales) {
    _deviceLocales = locales;
    _apply();
  }
}
