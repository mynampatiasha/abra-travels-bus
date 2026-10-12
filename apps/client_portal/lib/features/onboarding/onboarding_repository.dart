import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// One onboarding file (the company's or a bus's) with its checklist.
final onboardingFileProvider = FutureProvider.autoDispose
    .family<JsonMap, String>(
      (ref, id) => ref.watch(onboardingRepositoryProvider).file(id),
    );

/// What the dashboard shows: the company's file, and the owner's buses with
/// the state of each bus's file.
class DashboardData {
  const DashboardData({
    required this.company,
    required this.buses,
    required this.busFiles,
  });

  final JsonMap? company;
  final List<JsonMap> buses;

  /// The files of the buses, by bus id.
  final Map<String, JsonMap> busFiles;
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final repository = ref.watch(onboardingRepositoryProvider);
  final results = await Future.wait<List<JsonMap>>(<Future<List<JsonMap>>>[
    repository.files(),
    repository.buses(),
  ]);
  final files = results[0];
  return DashboardData(
    company: files
        .where((file) => file['subjectType'] == 'OPERATOR')
        .firstOrNull,
    buses: results[1],
    busFiles: <String, JsonMap>{
      for (final file in files)
        if (file['busId'] != null) '${file['busId']}': file,
    },
  );
});

/// The bus owner's side of the API: their onboarding files and buses. The
/// backend limits everything to the owner's own company.
class OnboardingRepository {
  OnboardingRepository(this._client);

  final ApiClient _client;

  Future<List<JsonMap>> files() async => (await _client.get(
    'onboarding/submissions',
    query: <String, Object?>{'pageSize': 100},
  )).decodeList((json) => json).toList(growable: false);

  Future<JsonMap> file(String id) async => (await _client.get(
    'onboarding/submissions/$id',
  )).decodeObject((json) => json);

  Future<List<JsonMap>> buses() async => (await _client.get(
    'catalogue/buses',
    query: <String, Object?>{'pageSize': 100},
  )).decodeList((json) => json).toList(growable: false);

  Future<List<JsonMap>> busTypes() async => (await _client.get(
    'catalogue/bus-types',
    query: <String, Object?>{'pageSize': 100, 'active': 'true'},
  )).decodeList((json) => json).toList(growable: false);

  Future<JsonMap> addBus(JsonMap body) async => (await _client.post(
    'catalogue/buses',
    body: body,
  )).decodeObject((json) => json);

  /// Starts the documents file of a bus (asking again returns the same one).
  Future<JsonMap> busFile(String busId) async => (await _client.post(
    'onboarding/submissions',
    body: <String, Object?>{'busId': busId},
  )).decodeObject((json) => json);

  /// Uploads one file for a document type and returns its id. The server checks
  /// the real type and size against the document's rules.
  Future<String> upload({
    required String documentTypeId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final response = await _client.postForm(
      'files',
      FormData.fromMap(<String, Object?>{
        'documentTypeId': documentTypeId,
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return '${response.decodeObject((json) => json)['id']}';
  }

  Future<JsonMap> setDocument(
    String id,
    String documentTypeId, {
    required List<String> fileIds,
    String? expiryDate,
  }) async => (await _client.put(
    'onboarding/submissions/$id/documents/$documentTypeId',
    body: <String, Object?>{'fileIds': fileIds, 'expiryDate': ?expiryDate},
  )).decodeObject((json) => json);

  Future<JsonMap> submit(String id) async => (await _client.post(
    'onboarding/submissions/$id/submit',
  )).decodeObject((json) => json);

  Future<Uint8List> fileBytes(String fileId) =>
      _client.getBytes('files/$fileId/content');

  // ---- the invitation link (no session yet)

  Future<JsonMap> inspectInvitation(String token) async => (await _client.post(
    'onboarding/invitations/inspect',
    body: <String, Object?>{'token': token},
    authenticated: false,
  )).decodeObject((json) => json);

  Future<void> acceptInvitation({
    required String token,
    required String password,
    String? name,
  }) async {
    await _client.post(
      'onboarding/invitations/accept',
      body: <String, Object?>{
        'token': token,
        'password': password,
        'name': ?name,
      },
      authenticated: false,
    );
  }
}
