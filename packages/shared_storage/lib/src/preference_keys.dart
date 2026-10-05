/// Keys of the non-sensitive settings shared by the apps. Credentials are
/// never stored under these keys.
abstract final class PreferenceKeys {
  /// BCP-47 tag of the language the user selected; absent means "follow the
  /// device language".
  static const localeTag = 'abra.preferences.locale_tag';
}
