import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

/// The integrations whose settings are managed here.
enum SettingsChannel {
  whatsapp('whatsapp'),
  email('email');

  const SettingsChannel(this.path);

  /// Path below `/settings/integrations`.
  final String path;
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// The settings of one integration, as the backend returns them. Secrets
/// (access token, password) are never in it, only whether they are set.
final settingsProvider = FutureProvider.autoDispose
    .family<JsonMap, SettingsChannel>(
      (ref, channel) => ref.watch(settingsRepositoryProvider).load(channel),
    );

/// The settings API (`/settings/integrations/...`). The backend decides by
/// permission who may read, change and test; only a Super Admin changes.
class SettingsRepository {
  SettingsRepository(this._client);

  final ApiClient _client;

  String _path(SettingsChannel channel, [String suffix = '']) =>
      'settings/integrations/${channel.path}$suffix';

  Future<JsonMap> load(SettingsChannel channel) async =>
      (await _client.get(_path(channel))).decodeObject((json) => json);

  /// Saves the fields in [body] and returns the settings after the change.
  Future<JsonMap> save(SettingsChannel channel, JsonMap body) async =>
      (await _client.put(
        _path(channel),
        body: body,
      )).decodeObject((json) => json);

  /// Tries the saved settings. A failed test is a normal answer
  /// (`ok: false`) with the reason in `message`.
  Future<JsonMap> test(
    SettingsChannel channel, {
    String action = '/test-connection',
    JsonMap body = const <String, Object?>{},
  }) async => (await _client.post(
    _path(channel, action),
    body: body,
  )).decodeObject((json) => json);
}
