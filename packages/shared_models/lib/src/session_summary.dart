import 'package:meta/meta.dart';

import 'enums.dart';
import 'json_reader.dart';

/// One signed-in device of the user (`GET /me/sessions`).
@immutable
final class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.current,
    required this.clientType,
    required this.lastUsedAt,
    required this.expiresAt,
    this.deviceName,
    this.ip,
    this.userAgent,
    this.createdAt,
  });

  factory SessionSummary.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return SessionSummary(
      id: reader.string('id'),
      current: reader.boolean('current'),
      clientType: SessionClientType.fromWire(reader.string('clientType')),
      deviceName: reader.stringOrNull('deviceName'),
      ip: reader.stringOrNull('ip'),
      userAgent: reader.stringOrNull('userAgent'),
      createdAt: reader.dateTimeOrNull('createdAt'),
      lastUsedAt: reader.dateTime('lastUsedAt'),
      expiresAt: reader.dateTime('expiresAt'),
    );
  }

  final String id;

  /// This is the device making the request.
  final bool current;
  final SessionClientType clientType;
  final String? deviceName;
  final String? ip;
  final String? userAgent;
  final DateTime? createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
}
