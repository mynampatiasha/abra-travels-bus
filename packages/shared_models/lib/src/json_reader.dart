/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

/// Thrown when a server response does not have the documented shape.
final class ModelParseException implements FormatException {
  const ModelParseException(this.message, [this.source]);

  @override
  final String message;

  @override
  final Object? source;

  @override
  int? get offset => null;

  @override
  String toString() => 'ModelParseException: $message';
}

/// Typed access to the fields of a [JsonMap]. A missing or wrongly typed
/// required field throws [ModelParseException] naming the field, so a
/// contract mismatch is reported instead of producing a half-filled model.
extension type const JsonReader(JsonMap json) {
  T _required<T>(String key) {
    final value = json[key];
    if (value is T) return value;
    throw ModelParseException(
      'field "$key" is ${value == null ? 'missing' : 'not a $T'}',
      key,
    );
  }

  T? _optional<T extends Object>(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is T) return value;
    throw ModelParseException('field "$key" is not a $T', key);
  }

  String string(String key) => _required<String>(key);

  String? stringOrNull(String key) => _optional<String>(key);

  bool boolean(String key) => _required<bool>(key);

  int integer(String key) => _required<num>(key).toInt();

  /// An ISO-8601 timestamp, or null.
  DateTime? dateTimeOrNull(String key) {
    final value = _optional<String>(key);
    return value == null ? null : DateTime.parse(value);
  }

  DateTime dateTime(String key) => DateTime.parse(string(key));

  JsonMap object(String key) =>
      asJsonMap(_required<Map<Object?, Object?>>(key));

  List<String> stringList(String key) => <String>[
    for (final item in _required<List<Object?>>(key))
      if (item is String)
        item
      else
        throw ModelParseException('field "$key" contains a non-string', key),
  ];

  List<T> objectList<T>(String key, T Function(JsonMap json) fromJson) => <T>[
    for (final item in _required<List<Object?>>(key))
      if (item is Map)
        fromJson(asJsonMap(item))
      else
        throw ModelParseException('field "$key" contains a non-object', key),
  ];
}

/// Converts a decoded JSON map (keys typed as Object?) to a [JsonMap].
JsonMap asJsonMap(Map<Object?, Object?> map) => <String, Object?>{
  for (final entry in map.entries) entry.key.toString(): entry.value,
};
