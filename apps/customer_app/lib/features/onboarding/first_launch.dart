import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

/// Whether this device has already been shown the first-launch tour. The
/// tour and the language step appear once; afterwards the app opens on
/// Home. An ordinary setting, kept in preferences.
final welcomeSeenProvider = NotifierProvider<WelcomeSeen, bool>(
  WelcomeSeen.new,
);

class WelcomeSeen extends Notifier<bool> {
  static const preferenceKey = 'customer.welcomeSeen';

  @override
  bool build() =>
      ref.read(appDependenciesProvider).preferences.getBool(preferenceKey) ??
      false;

  /// Called when the customer leaves the tour, by any way.
  Future<void> markSeen() async {
    if (state) return;
    state = true;
    await ref
        .read(appDependenciesProvider)
        .preferences
        .setBool(preferenceKey, value: true);
  }
}
