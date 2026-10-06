import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';

/// A city customers travel between (`GET /cities`).
@immutable
final class City {
  const City({required this.id, required this.name, this.state});

  factory City.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return City(
      id: reader.string('id'),
      name: reader.string('name'),
      state: reader.stringOrNull('state'),
    );
  }

  final String id;

  /// In the language of the request when the backend has a translation.
  final String name;
  final String? state;

  JsonMap toJson() => <String, Object?>{'id': id, 'name': name, 'state': state};

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A named thing referred to by id (operator, city).
@immutable
final class NamedRef {
  const NamedRef({required this.id, required this.name});

  factory NamedRef.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return NamedRef(id: reader.string('id'), name: reader.string('name'));
  }

  final String id;
  final String name;
}

@immutable
final class TripBus {
  const TripBus({
    required this.name,
    required this.typeKey,
    required this.typeName,
    required this.isAc,
    required this.berthType,
    required this.amenities,
    this.registrationNumber,
  });

  factory TripBus.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return TripBus(
      name: reader.string('name'),
      typeKey: reader.string('typeKey'),
      typeName: reader.string('typeName'),
      isAc: reader.boolean('isAc'),
      berthType: reader.string('berthType'),
      amenities: reader.stringList('amenities'),
      registrationNumber: reader.stringOrNull('registrationNumber'),
    );
  }

  final String name;
  final String typeKey;

  /// English name of the bus type, as maintained by the platform.
  final String typeName;
  final bool isAc;
  final String berthType;

  /// Amenity keys such as `WIFI`. Unknown keys are shown as they are.
  final List<String> amenities;

  /// Only in trip details.
  final String? registrationNumber;
}

/// A boarding or dropping point of a trip.
@immutable
final class TripPoint {
  const TripPoint({
    required this.id,
    required this.name,
    required this.time,
    this.cityName,
    this.address,
    this.landmark,
    this.instructions,
    this.contactPhone,
  });

  factory TripPoint.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    final city = json['city'];
    return TripPoint(
      id: reader.string('id'),
      name: reader.string('name'),
      time: reader.dateTime('time'),
      cityName: city is Map ? NamedRef.fromJson(asJsonMap(city)).name : null,
      address: reader.stringOrNull('address'),
      landmark: reader.stringOrNull('landmark'),
      instructions: reader.stringOrNull('instructions'),
      contactPhone: reader.stringOrNull('contactPhone'),
    );
  }

  final String id;
  final String name;

  /// The instant the bus is at the point.
  final DateTime time;

  // Only in trip details:
  final String? cityName;
  final String? address;
  final String? landmark;
  final String? instructions;
  final String? contactPhone;
}

/// A trip on sale, as a search result (`GET /trips/search`).
@immutable
class TripSummary {
  const TripSummary({
    required this.id,
    required this.operator,
    required this.bus,
    required this.origin,
    required this.destination,
    required this.travelDate,
    required this.timezone,
    required this.departureAt,
    required this.arrivalAt,
    required this.durationMinutes,
    required this.startingFarePaise,
    required this.currency,
    required this.totalSeats,
    required this.availableSeats,
    required this.isSoldOut,
    required this.boardingPoints,
    required this.droppingPoints,
  });

  factory TripSummary.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    final fare = JsonReader(reader.object('fare'));
    final seats = JsonReader(reader.object('seats'));
    return TripSummary(
      id: reader.string('id'),
      operator: NamedRef.fromJson(reader.object('operator')),
      bus: TripBus.fromJson(reader.object('bus')),
      origin: NamedRef.fromJson(reader.object('origin')),
      destination: NamedRef.fromJson(reader.object('destination')),
      travelDate: reader.string('travelDate'),
      timezone: reader.string('timezone'),
      departureAt: reader.dateTime('departureAt'),
      arrivalAt: reader.dateTime('arrivalAt'),
      durationMinutes: reader.integer('durationMinutes'),
      startingFarePaise: fare.integer('startingPaise'),
      currency: fare.string('currency'),
      totalSeats: seats.integer('total'),
      availableSeats: seats.integer('available'),
      isSoldOut: seats.boolean('isSoldOut'),
      boardingPoints: reader.objectList('boardingPoints', TripPoint.fromJson),
      droppingPoints: reader.objectList('droppingPoints', TripPoint.fromJson),
    );
  }

  final String id;
  final NamedRef operator;
  final TripBus bus;
  final NamedRef origin;
  final NamedRef destination;

  /// `YYYY-MM-DD` in [timezone].
  final String travelDate;
  final String timezone;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final int durationMinutes;

  /// Lowest fare of any seat, in paise. For display only: the amount to pay
  /// is calculated by the backend when booking.
  final int startingFarePaise;
  final String currency;
  final int totalSeats;
  final int availableSeats;
  final bool isSoldOut;
  final List<TripPoint> boardingPoints;
  final List<TripPoint> droppingPoints;
}

/// One trip in full (`GET /trips/:tripId`).
@immutable
final class TripDetail extends TripSummary {
  const TripDetail({
    required super.id,
    required super.operator,
    required super.bus,
    required super.origin,
    required super.destination,
    required super.travelDate,
    required super.timezone,
    required super.departureAt,
    required super.arrivalAt,
    required super.durationMinutes,
    required super.startingFarePaise,
    required super.currency,
    required super.totalSeats,
    required super.availableSeats,
    required super.isSoldOut,
    required super.boardingPoints,
    required super.droppingPoints,
    required this.stops,
  });

  factory TripDetail.fromJson(JsonMap json) {
    final summary = TripSummary.fromJson(json);
    return TripDetail(
      id: summary.id,
      operator: summary.operator,
      bus: summary.bus,
      origin: summary.origin,
      destination: summary.destination,
      travelDate: summary.travelDate,
      timezone: summary.timezone,
      departureAt: summary.departureAt,
      arrivalAt: summary.arrivalAt,
      durationMinutes: summary.durationMinutes,
      startingFarePaise: summary.startingFarePaise,
      currency: summary.currency,
      totalSeats: summary.totalSeats,
      availableSeats: summary.availableSeats,
      isSoldOut: summary.isSoldOut,
      boardingPoints: summary.boardingPoints,
      droppingPoints: summary.droppingPoints,
      stops: JsonReader(json).objectList('stops', NamedRef.fromJson),
    );
  }

  /// Cities the bus passes through, in order.
  final List<NamedRef> stops;
}

/// One page of search results.
@immutable
final class TripPage {
  const TripPage({
    required this.trips,
    required this.page,
    required this.total,
  });

  final List<TripSummary> trips;
  final int page;

  /// Number of trips matching the search and its filters, over all pages.
  final int total;
}

/// A value a search can be filtered by, with how many trips have it.
@immutable
final class FilterOption {
  const FilterOption({
    required this.key,
    required this.label,
    required this.count,
  });

  final String key;

  /// Text from the backend (operator name, bus type name). Amenities and
  /// departure windows are labelled by the app from [key].
  final String label;
  final int count;
}

/// What a search can be filtered by (`GET /trips/search/filters`).
@immutable
final class SearchFilterOptions {
  const SearchFilterOptions({
    required this.total,
    required this.busTypes,
    required this.operators,
    required this.amenities,
    required this.departureWindows,
    this.minFarePaise,
    this.maxFarePaise,
  });

  factory SearchFilterOptions.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    FilterOption option(
      JsonMap item, {
      String keyField = 'key',
      String? labelField,
    }) {
      final itemReader = JsonReader(item);
      final key = itemReader.string(keyField);
      return FilterOption(
        key: key,
        label: labelField == null ? key : itemReader.string(labelField),
        count: itemReader.integer('count'),
      );
    }

    final fare = json['fare'];
    final fareReader = fare is Map ? JsonReader(asJsonMap(fare)) : null;
    return SearchFilterOptions(
      total: reader.integer('total'),
      busTypes: reader.objectList(
        'busTypes',
        (item) => option(item, labelField: 'name'),
      ),
      operators: reader.objectList(
        'operators',
        (item) => option(item, keyField: 'id', labelField: 'name'),
      ),
      amenities: reader.objectList('amenities', option),
      departureWindows: reader.objectList('departureWindows', option),
      minFarePaise: fareReader?.integer('minPaise'),
      maxFarePaise: fareReader?.integer('maxPaise'),
    );
  }

  final int total;
  final List<FilterOption> busTypes;
  final List<FilterOption> operators;
  final List<FilterOption> amenities;
  final List<FilterOption> departureWindows;
  final int? minFarePaise;
  final int? maxFarePaise;
}

/// Order of search results. Sorting is done by the backend.
enum TripSort {
  departureEarliest('DEPARTURE_EARLIEST'),
  departureLatest('DEPARTURE_LATEST'),
  fareLowest('FARE_LOWEST'),
  fareHighest('FARE_HIGHEST'),
  durationShortest('DURATION_SHORTEST');

  const TripSort(this.wireValue);

  final String wireValue;
}

/// Filters chosen by the customer. All filtering is done by the backend.
@immutable
final class TripFilters {
  const TripFilters({
    this.departureWindows = const <String>{},
    this.busTypes = const <String>{},
    this.operatorIds = const <String>{},
    this.amenities = const <String>{},
    this.isAc,
    this.maxFarePaise,
  });

  final Set<String> departureWindows;
  final Set<String> busTypes;
  final Set<String> operatorIds;
  final Set<String> amenities;
  final bool? isAc;
  final int? maxFarePaise;

  static const none = TripFilters();

  /// Number of filters in effect, for the badge on the filter button.
  int get activeCount =>
      departureWindows.length +
      busTypes.length +
      operatorIds.length +
      amenities.length +
      (isAc == null ? 0 : 1) +
      (maxFarePaise == null ? 0 : 1);

  bool get isEmpty => activeCount == 0;

  TripFilters copyWith({
    Set<String>? departureWindows,
    Set<String>? busTypes,
    Set<String>? operatorIds,
    Set<String>? amenities,
    bool? Function()? isAc,
    int? Function()? maxFarePaise,
  }) => TripFilters(
    departureWindows: departureWindows ?? this.departureWindows,
    busTypes: busTypes ?? this.busTypes,
    operatorIds: operatorIds ?? this.operatorIds,
    amenities: amenities ?? this.amenities,
    isAc: isAc == null ? this.isAc : isAc(),
    maxFarePaise: maxFarePaise == null ? this.maxFarePaise : maxFarePaise(),
  );

  String get _signature => <Object?>[
    (departureWindows.toList()..sort()).join(','),
    (busTypes.toList()..sort()).join(','),
    (operatorIds.toList()..sort()).join(','),
    (amenities.toList()..sort()).join(','),
    isAc,
    maxFarePaise,
  ].join('|');

  @override
  bool operator ==(Object other) =>
      other is TripFilters && other._signature == _signature;

  @override
  int get hashCode => _signature.hashCode;
}

/// A search: where from, where to and when. Value-equal, so it can key
/// cached results.
@immutable
final class TripSearchCriteria {
  const TripSearchCriteria({
    required this.fromCityId,
    required this.toCityId,
    required this.date,
  });

  final String fromCityId;
  final String toCityId;

  /// `YYYY-MM-DD`.
  final String date;

  @override
  bool operator ==(Object other) =>
      other is TripSearchCriteria &&
      other.fromCityId == fromCityId &&
      other.toCityId == toCityId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(fromCityId, toCityId, date);
}

/// A search with its filters and order.
@immutable
final class TripSearchRequest {
  const TripSearchRequest({
    required this.criteria,
    this.filters = TripFilters.none,
    this.sort = TripSort.departureEarliest,
  });

  final TripSearchCriteria criteria;
  final TripFilters filters;
  final TripSort sort;

  @override
  bool operator ==(Object other) =>
      other is TripSearchRequest &&
      other.criteria == criteria &&
      other.filters == filters &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(criteria, filters, sort);
}
