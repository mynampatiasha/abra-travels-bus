import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';

import '../../../app/providers.dart';
import '../../discovery/controllers/trip_selection_controller.dart';

/// The action a guest was taking when sign-in was required.
enum SignInIntentKind {
  /// Opening something personal (My trips, a protected link): signing in
  /// is all that is needed.
  generic,

  /// "Select seats" on a trip, with the boarding and dropping points and
  /// passengers chosen there.
  selectSeats,
}

/// What the customer was doing when the app asked them to sign in, so it
/// can carry on afterwards with everything still chosen. Holds locations,
/// ids and counts only: never a phone number, a code or a token.
@immutable
class SignInIntent {
  const SignInIntent({
    required this.returnLocation,
    this.continueTo,
    this.kind = SignInIntentKind.generic,
    this.selection = const <String, Object?>{},
    this.createdAt,
  });

  /// A stored intent, or null when the stored value is not usable.
  static SignInIntent? tryParse(String? stored) {
    if (stored == null) return null;
    try {
      final json = asJsonMap(jsonDecode(stored) as Map);
      final returnLocation = json['returnLocation'];
      final createdAt = DateTime.tryParse('${json['createdAt']}');
      if (returnLocation is! String ||
          !isInAppLocation(returnLocation) ||
          createdAt == null) {
        return null;
      }
      final continueTo = json['continueTo'];
      final kind = SignInIntentKind.values
          .where((value) => value.name == json['kind'])
          .firstOrNull;
      final selection = json['selection'];
      return SignInIntent(
        returnLocation: returnLocation,
        continueTo: continueTo is String && isInAppLocation(continueTo)
            ? continueTo
            : null,
        kind: kind ?? SignInIntentKind.generic,
        selection: selection is Map
            ? asJsonMap(selection)
            : const <String, Object?>{},
        createdAt: createdAt,
      );
    } on Object {
      return null;
    }
  }

  /// "Select seats" on [tripId] with [selection].
  factory SignInIntent.selectSeats({
    required String tripId,
    required String tripLocation,
    required String seatsLocation,
    required TripSelection selection,
  }) => SignInIntent(
    returnLocation: tripLocation,
    continueTo: seatsLocation,
    kind: SignInIntentKind.selectSeats,
    selection: <String, Object?>{'tripId': tripId, ...selection.toJson()},
  );

  /// The screen the customer was on. Re-opened after a restart.
  final String returnLocation;

  /// Where the action leads once signed in; null when the screen itself
  /// just shows its content (a tab, a protected link).
  final String? continueTo;
  final SignInIntentKind kind;
  final JsonMap selection;

  /// Set when the intent is stored.
  final DateTime? createdAt;

  SignInIntent stampedAt(DateTime time) => SignInIntent(
    returnLocation: returnLocation,
    continueTo: continueTo,
    kind: kind,
    selection: selection,
    createdAt: time,
  );

  String encode() => jsonEncode(<String, Object?>{
    'returnLocation': returnLocation,
    'continueTo': continueTo,
    'kind': kind.name,
    'selection': selection,
    'createdAt': createdAt?.toUtc().toIso8601String(),
  });

  /// Only paths inside the app are ever followed.
  static bool isInAppLocation(String location) {
    if (!location.startsWith('/') ||
        location.startsWith('//') ||
        location.contains(r'\')) {
      return false;
    }
    final uri = Uri.tryParse(location);
    return uri != null && !uri.hasScheme && !uri.hasAuthority;
  }

  /// Puts the kept selection back where the screens read it.
  void restoreSelection(ProviderContainer container) {
    if (kind != SignInIntentKind.selectSeats) return;
    final tripId = selection['tripId'];
    if (tripId is! String) return;
    container
        .read(tripSelectionProvider(tripId).notifier)
        .restore(TripSelection.fromJson(selection));
  }
}

/// The current time. Overridden in tests.
final intentClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The intent waiting for sign-in, kept in memory and, briefly, on the
/// device, so it survives the app being closed while the customer fetches
/// the code. Expires after [lifetime].
final pendingSignInIntentProvider =
    NotifierProvider<PendingSignInIntent, SignInIntent?>(
      PendingSignInIntent.new,
    );

class PendingSignInIntent extends Notifier<SignInIntent?> {
  static const preferenceKey = 'customer.pendingSignInIntent';
  static const lifetime = Duration(minutes: 15);

  PreferencesStore get _preferences =>
      ref.read(appDependenciesProvider).preferences;

  DateTime _now() => ref.read(intentClockProvider)();

  @override
  SignInIntent? build() {
    final stored = SignInIntent.tryParse(_preferences.getString(preferenceKey));
    if (stored == null || !_isFresh(stored)) {
      if (_preferences.getString(preferenceKey) != null) {
        _preferences.remove(preferenceKey);
      }
      return null;
    }
    return stored;
  }

  bool _isFresh(SignInIntent intent) {
    final createdAt = intent.createdAt;
    if (createdAt == null) return false;
    final age = _now().difference(createdAt);
    return !age.isNegative && age < lifetime;
  }

  /// The pending intent if it has not expired.
  SignInIntent? get fresh {
    final intent = state;
    return intent != null && _isFresh(intent) ? intent : null;
  }

  Future<void> save(SignInIntent intent) async {
    final stamped = intent.stampedAt(_now());
    state = stamped;
    await _preferences.setString(preferenceKey, stamped.encode());
  }

  Future<void> clear() async {
    state = null;
    await _preferences.remove(preferenceKey);
  }
}
