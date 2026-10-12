import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';

/// What the customer has chosen on a trip before booking: boarding point,
/// dropping point and how many travel. Kept while the trip is open and
/// through sign-in, so nothing has to be chosen twice. Seats chosen on the seat
/// screen are kept here too.
@immutable
class TripSelection {
  const TripSelection({
    this.boardingPointId,
    this.droppingPointId,
    this.passengers = 1,
    this.seatIds = const <String>[],
  });

  factory TripSelection.fromJson(JsonMap json) {
    final passengers = json['passengers'];
    return TripSelection(
      boardingPointId: json['boardingPointId'] as String?,
      droppingPointId: json['droppingPointId'] as String?,
      passengers: passengers is int && passengers >= minPassengers
          ? (passengers > maxPassengers ? maxPassengers : passengers)
          : 1,
      seatIds: _seatIdsFrom(json['seatIds']),
    );
  }

  static List<String> _seatIdsFrom(Object? value) {
    if (value is! List) return const <String>[];
    final ids = <String>[];
    for (final item in value) {
      if (item is String && item.isNotEmpty && !ids.contains(item)) {
        ids.add(item);
      }
      if (ids.length == maxSeats) break;
    }
    return List<String>.unmodifiable(ids);
  }

  /// The backend's search limits (`passengers` 1–6).
  static const minPassengers = 1;
  static const maxPassengers = 6;

  /// Seats in one booking.
  static const maxSeats = 6;

  final String? boardingPointId;
  final String? droppingPointId;
  final int passengers;

  /// The seats chosen on the seat screen, by the id the customer sees.
  final List<String> seatIds;

  JsonMap toJson() => <String, Object?>{
    'boardingPointId': boardingPointId,
    'droppingPointId': droppingPointId,
    'passengers': passengers,
    'seatIds': seatIds,
  };

  TripSelection copyWith({
    String? boardingPointId,
    String? droppingPointId,
    int? passengers,
    List<String>? seatIds,
  }) => TripSelection(
    boardingPointId: boardingPointId ?? this.boardingPointId,
    droppingPointId: droppingPointId ?? this.droppingPointId,
    passengers: passengers ?? this.passengers,
    seatIds: seatIds ?? this.seatIds,
  );

  @override
  bool operator ==(Object other) =>
      other is TripSelection &&
      other.boardingPointId == boardingPointId &&
      other.droppingPointId == droppingPointId &&
      other.passengers == passengers &&
      listEquals(other.seatIds, seatIds);

  @override
  int get hashCode => Object.hash(
    boardingPointId,
    droppingPointId,
    passengers,
    Object.hashAll(seatIds),
  );
}

/// The selection on one trip, by trip id.
final tripSelectionProvider =
    NotifierProvider.family<TripSelectionController, TripSelection, String>(
      TripSelectionController.new,
    );

class TripSelectionController extends Notifier<TripSelection> {
  TripSelectionController(this.tripId);

  final String tripId;

  @override
  TripSelection build() => const TripSelection();

  void selectBoardingPoint(String pointId) =>
      state = state.copyWith(boardingPointId: pointId);

  void selectDroppingPoint(String pointId) =>
      state = state.copyWith(droppingPointId: pointId);

  /// Replaces the chosen seats (at most [TripSelection.maxSeats]).
  void setSeats(List<String> seatIds) => state = state.copyWith(
    seatIds: List<String>.unmodifiable(seatIds.take(TripSelection.maxSeats)),
  );

  void setPassengers(int count) => state = state.copyWith(
    passengers: count.clamp(
      TripSelection.minPassengers,
      TripSelection.maxPassengers,
    ),
  );

  /// Chooses the first boarding and last dropping point when nothing is
  /// chosen yet, so "Select seats" always has a complete choice to keep.
  void applyDefaults({String? boardingPointId, String? droppingPointId}) {
    if (state.boardingPointId != null && state.droppingPointId != null) {
      return;
    }
    state = state.copyWith(
      boardingPointId: state.boardingPointId ?? boardingPointId,
      droppingPointId: state.droppingPointId ?? droppingPointId,
    );
  }

  /// Puts back a selection kept through sign-in (for example after the app
  /// was closed while the customer waited for the code).
  void restore(TripSelection selection) => state = selection;
}
