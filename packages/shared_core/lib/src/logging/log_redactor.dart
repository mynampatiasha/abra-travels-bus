/// Removes credentials from data before it is logged. Matches the backend
/// redaction list, so the same things stay out of logs on both sides.
abstract final class LogRedactor {
  static const redacted = '[REDACTED]';

  /// Keys whose values are never logged, compared case-insensitively.
  static const Set<String> sensitiveKeys = <String>{
    'password',
    'currentpassword',
    'newpassword',
    'passwordhash',
    'otp',
    'otpcode',
    'totpcode',
    'code',
    'recoverycode',
    'recoverycodes',
    'mfatoken',
    'totpsecret',
    'secret',
    'token',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'apikey',
    'clientsecret',
    'cardnumber',
    'cvv',
    'bankaccountnumber',
  };

  static bool isSensitiveKey(String key) =>
      sensitiveKeys.contains(key.toLowerCase());

  /// Returns a deep copy of [value] with every sensitive entry replaced by
  /// [redacted]. Maps and lists are walked recursively.
  static Object? redact(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): isSensitiveKey(entry.key.toString())
              ? redacted
              : redact(entry.value),
      };
    }
    if (value is Iterable) {
      return <Object?>[for (final item in value) redact(item)];
    }
    return value;
  }

  /// Path of a request for logging: no query string, because queries can
  /// carry phone numbers or booking references.
  static String safePath(Uri uri) => uri.path;
}
