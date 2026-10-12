import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// One onboarding file with its documents, files, checklist and history.
final reviewDetailProvider = FutureProvider.autoDispose.family<JsonMap, String>(
  (ref, id) => ref.watch(reviewRepositoryProvider).detail(id),
);

/// The review side of onboarding (`/onboarding/submissions`). The backend
/// decides by permission and data scope; the screens only offer the actions.
class ReviewRepository {
  ReviewRepository(this._client);

  final ApiClient _client;

  Future<JsonMap> detail(String id) async => (await _client.get(
    'onboarding/submissions/$id',
  )).decodeObject((json) => json);

  Future<JsonMap> reviewDocument(
    String id,
    String documentTypeId, {
    required bool accept,
    String? reason,
  }) async => (await _client.post(
    'onboarding/submissions/$id/documents/$documentTypeId/review',
    body: <String, Object?>{
      'decision': accept ? 'APPROVED' : 'REJECTED',
      'reason': ?reason,
    },
  )).decodeObject((json) => json);

  Future<JsonMap> approve(String id) async => (await _client.post(
    'onboarding/submissions/$id/approve',
  )).decodeObject((json) => json);

  Future<JsonMap> sendBack(String id, {String? note}) async =>
      (await _client.post(
        'onboarding/submissions/$id/reject',
        body: <String, Object?>{'note': ?note},
      )).decodeObject((json) => json);

  /// The bytes of an uploaded document, for someone who may see it.
  Future<Uint8List> fileBytes(String fileId) =>
      _client.getBytes('files/$fileId/content');
}
