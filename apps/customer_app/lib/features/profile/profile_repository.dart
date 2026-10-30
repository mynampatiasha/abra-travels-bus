import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';
import '../../core/async_value_view.dart';

/// The signed-in customer's profile (`GET /customer/profile`).
@immutable
final class CustomerProfile {
  const CustomerProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.language,
  });

  factory CustomerProfile.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return CustomerProfile(
      name: reader.stringOrNull('name') ?? '',
      email: reader.stringOrNull('email') ?? '',
      phone: reader.stringOrNull('phone') ?? '',
      language: reader.stringOrNull('language') ?? 'en',
    );
  }

  final String name;
  final String email;
  final String phone;
  final String language;
}

/// A problem to show in plain words, with the field it belongs to when the
/// server named one.
class ProfileProblem implements Exception {
  ProfileProblem(this.message, {this.field});

  final String message;
  final String? field;

  @override
  String toString() => message;

  factory ProfileProblem.from(Object error) {
    final failure = failureOf(error);
    if (failure is ApiFailure) {
      final issues = failure.details['issues'];
      if (issues is List && issues.isNotEmpty && issues.first is Map) {
        final first = issues.first as Map;
        final text = first['message'];
        final path = first['path'];
        if (text is String && text.isNotEmpty) {
          return ProfileProblem(
            text,
            field: path is String && path.isNotEmpty ? path.split('.').last : null,
          );
        }
      }
      if (failure.message.isNotEmpty && failure.statusCode < 500) {
        return ProfileProblem(failure.message);
      }
    }
    return ProfileProblem('Something went wrong. Check your connection and try again.');
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// The profile as the server holds it. Loaded again when the screen opens.
final customerProfileProvider = FutureProvider.autoDispose<CustomerProfile>(
  (ref) => ref.watch(profileRepositoryProvider).get(),
);

/// `/customer/profile` and `/customer/account`. Reads throw `AppException`;
/// the changes throw [ProfileProblem] with words the person can act on.
class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  Future<CustomerProfile> get() async {
    final response = await _client.get('customer/profile');
    return CustomerProfile.fromJson(_object(response.data));
  }

  Future<CustomerProfile> update({
    String? name,
    String? email,
    String? language,
  }) async {
    try {
      final response = await _client.patch(
        'customer/profile',
        body: <String, Object?>{
          'name': ?name,
          'email': ?email,
          'language': ?language,
        },
      );
      return CustomerProfile.fromJson(_object(response.data));
    } on Object catch (error) {
      throw ProfileProblem.from(error);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _client.delete('customer/account');
    } on Object catch (error) {
      throw ProfileProblem.from(error);
    }
  }
}

JsonMap _object(Object? data) {
  if (data is Map) return asJsonMap(data);
  throw const ModelParseException('the answer is not an object');
}
