import 'dart:async';
import 'dart:convert';

import 'package:customer_app/features/authentication/login_screen.dart';
import 'package:customer_app/features/discovery/controllers/search_form_controller.dart';
import 'package:customer_app/features/discovery/controllers/travel_dates.dart';
import 'package:customer_app/features/discovery/models/discovery_models.dart';
import 'package:customer_app/features/discovery/screens/city_picker_screen.dart';
import 'package:customer_app/features/discovery/screens/search_results_screen.dart';
import 'package:customer_app/features/discovery/screens/trip_details_screen.dart';
import 'package:customer_app/features/discovery/widgets/discovery_text.dart';
import 'package:customer_app/features/discovery/widgets/trip_card.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_localization/shared_localization.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_app.dart';

const bengaluruId = '66f0c0ffee00000000000001';
const mysuruId = '66f0c0ffee00000000000002';
const hubballiId = '66f0c0ffee00000000000003';

Map<String, Object?> cityJson(String id, String name) => <String, Object?>{
  'id': id,
  'name': name,
  'state': 'Karnataka',
  'slug': name.toLowerCase(),
};

final bengaluru = cityJson(bengaluruId, 'Bengaluru');
final mysuru = cityJson(mysuruId, 'Mysuru');
final hubballi = cityJson(hubballiId, 'Hubballi');

String isoDate(DateTime date) => TravelDates.format(date);

/// The instant of [time] (HH:mm, India time) on [date], as the backend
/// sends it.
String indiaInstant(DateTime date, String time, {int plusDays = 0}) {
  final parts = time.split(':').map(int.parse).toList();
  return DateTime.utc(
    date.year,
    date.month,
    date.day + plusDays,
    parts[0],
    parts[1],
  ).subtract(const Duration(hours: 5, minutes: 30)).toIso8601String();
}

Map<String, Object?> tripJson(
  String id,
  DateTime date, {
  String operator = 'Abra Travels',
  String busName = 'Abra Express',
  String departure = '06:30',
  String arrival = '10:00',
  int arrivalPlusDays = 0,
  int durationMinutes = 210,
  int farePaise = 65000,
  int available = 20,
  bool detail = false,
}) {
  Map<String, Object?> point(
    String pointId,
    String name,
    String time, {
    int plusDays = 0,
  }) => <String, Object?>{
    'id': pointId,
    'name': name,
    'time': indiaInstant(date, time, plusDays: plusDays),
    if (detail) ...<String, Object?>{
      'city': <String, Object?>{'id': bengaluruId, 'name': 'Bengaluru'},
      'address': '$name, Main Road',
      'landmark': name == 'Central Bus Stand' ? 'Opposite City Mall' : null,
      'instructions': name == 'Central Bus Stand'
          ? 'Board at platform 4'
          : null,
      'contactPhone': null,
      'location': null,
    },
  };
  return <String, Object?>{
    'id': id,
    if (detail) 'status': 'SCHEDULED',
    'operator': <String, Object?>{'id': 'op-$operator', 'name': operator},
    'bus': <String, Object?>{
      'name': busName,
      'typeKey': 'AC_SLEEPER',
      'typeName': 'AC Sleeper',
      'isAc': true,
      'berthType': 'SLEEPER',
      'amenities': <String>['WIFI', 'CHARGING_POINT', 'HOT_TOWEL'],
      if (detail) 'registrationNumber': 'KA01AB1234',
    },
    'origin': <String, Object?>{'id': bengaluruId, 'name': 'Bengaluru'},
    'destination': <String, Object?>{'id': mysuruId, 'name': 'Mysuru'},
    if (detail)
      'stops': <Object?>[
        <String, Object?>{'id': hubballiId, 'name': 'Mandya'},
      ],
    'travelDate': isoDate(date),
    'timezone': 'Asia/Kolkata',
    'departureAt': indiaInstant(date, departure),
    'arrivalAt': indiaInstant(date, arrival, plusDays: arrivalPlusDays),
    'durationMinutes': durationMinutes,
    'fare': <String, Object?>{'startingPaise': farePaise, 'currency': 'INR'},
    'seats': <String, Object?>{
      'total': 36,
      'available': available,
      'isSoldOut': available == 0,
    },
    'boardingPoints': <Object?>[
      point('bp-1', 'Central Bus Stand', departure),
      point('bp-2', 'Second Stage', '06:50'),
    ],
    'droppingPoints': <Object?>[
      point('dp-1', 'Town Hall', arrival, plusDays: arrivalPlusDays),
    ],
  };
}

const filterOptionsJson = <String, Object?>{
  'total': 3,
  'busTypes': <Object?>[
    <String, Object?>{
      'key': 'AC_SLEEPER',
      'name': 'AC Sleeper',
      'isAc': true,
      'berthType': 'SLEEPER',
      'count': 2,
    },
    <String, Object?>{
      'key': 'NON_AC_SEATER',
      'name': 'Non-AC Seater',
      'isAc': false,
      'berthType': 'SEATER',
      'count': 1,
    },
  ],
  'operators': <Object?>[
    <String, Object?>{
      'id': '66f0c0ffee000000000000a1',
      'name': 'Abra Travels',
      'count': 2,
    },
    <String, Object?>{
      'id': '66f0c0ffee000000000000a2',
      'name': 'Kaveri Lines',
      'count': 1,
    },
  ],
  'amenities': <Object?>[
    <String, Object?>{'key': 'WIFI', 'count': 2},
    <String, Object?>{'key': 'BLANKET', 'count': 1},
  ],
  'departureWindows': <Object?>[
    <String, Object?>{
      'key': 'EARLY_MORNING',
      'fromMinute': 0,
      'toMinute': 360,
      'count': 0,
    },
    <String, Object?>{
      'key': 'MORNING',
      'fromMinute': 360,
      'toMinute': 720,
      'count': 1,
    },
    <String, Object?>{
      'key': 'AFTERNOON',
      'fromMinute': 720,
      'toMinute': 1080,
      'count': 1,
    },
    <String, Object?>{
      'key': 'NIGHT',
      'fromMinute': 1080,
      'toMinute': 1440,
      'count': 1,
    },
  ],
  'fare': <String, Object?>{
    'minPaise': 35000,
    'maxPaise': 90000,
    'currency': 'INR',
  },
};

/// Answers the discovery endpoints like the backend. Tests replace single
/// answers; every request is recorded by the adapter.
class FakeDiscoveryBackend {
  bool isOnline = true;
  List<Map<String, Object?>> popularCities = <Map<String, Object?>>[
    bengaluru,
    mysuru,
  ];
  List<Map<String, Object?>> Function(String query) citySearch = (query) =>
      <Map<String, Object?>>[bengaluru, mysuru, hubballi]
          .where(
            (city) => (city['name']! as String).toLowerCase().startsWith(
              query.toLowerCase(),
            ),
          )
          .toList();
  FakeResponse Function(RecordedRequest request)? search;
  FakeResponse Function(RecordedRequest request)? trip;
  List<Map<String, Object?>> trips = <Map<String, Object?>>[];

  Future<FakeResponse> call(RecordedRequest request) async {
    if (!isOnline) throw connectionError(request);
    final query = request.options.queryParameters;
    final path = request.path;
    if (path == 'cities') {
      final text = query['query'] as String?;
      return FakeResponse.ok(text == null ? popularCities : citySearch(text));
    }
    if (path == 'trips/search') {
      if (search != null) return search!(request);
      final page = query['page']! as int;
      final size = query['pageSize']! as int;
      return FakeResponse.ok(
        trips.skip((page - 1) * size).take(size).toList(),
        meta: <String, Object?>{
          'page': page,
          'pageSize': size,
          'total': trips.length,
        },
      );
    }
    if (path == 'trips/search/filters') {
      return FakeResponse.ok(filterOptionsJson);
    }
    if (path.startsWith('trips/')) {
      if (trip != null) return trip!(request);
      return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
    }
    if (path == 'me') return currentUserResponse;
    return FakeResponse.error(404, 'RESOURCE_NOT_FOUND');
  }
}

/// The location of the page on top, including pages opened with `push`.
GoRouterLocation locationOf(WidgetTester tester) {
  final configuration = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).routerDelegate.currentConfiguration;
  final top = configuration.matches.last;
  return GoRouterLocation(
    top is ImperativeRouteMatch ? top.matches.uri : configuration.uri,
  );
}

extension type GoRouterLocation(Uri uri) {
  String get path => uri.path;
  Map<String, String> get query => uri.queryParameters;
}

Future<void> open(WidgetTester tester, String location) async {
  ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).go(location);
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

List<RecordedRequest> requestsTo(TestApp app, String path) =>
    app.adapter.requests.where((request) => request.path == path).toList();

Map<String, Object?> lastQuery(TestApp app, String path) =>
    Map<String, Object?>.of(requestsTo(app, path).last.options.queryParameters);

void main() {
  late FakeDiscoveryBackend backend;
  late TestApp app;
  late DateTime today;

  Future<void> start(
    WidgetTester tester, {
    Map<String, String> stored = const {},
    Size size = const Size(400, 900),
    Map<String, String> preferences = const {},
  }) async {
    backend = FakeDiscoveryBackend();
    app = TestApp(handler: (request) => backend(request), stored: stored);
    for (final entry in preferences.entries) {
      await app.preferences.setString(entry.key, entry.value);
    }
    today = TravelDates.today(tester.binding.clock.now());
    await app.pump(tester, size: size);
  }

  String results(DateTime date) =>
      '/search/results?origin=$bengaluruId&originName=Bengaluru'
      '&destination=$mysuruId&destinationName=Mysuru&date=${isoDate(date)}';

  Future<void> pickCity(
    WidgetTester tester,
    String field,
    String city, {
    String? typing,
  }) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^$field,')));
    await settle(tester);
    expect(find.byType(CityPickerScreen), findsOneWidget);
    if (typing != null) {
      await tester.enterText(find.byType(TextField), typing);
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
    }
    await tester.tap(find.widgetWithText(ListTile, city));
    await settle(tester);
  }

  Future<void> tapSearch(WidgetTester tester) async {
    final button = find.widgetWithText(AbraButton, 'Search buses');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await settle(tester);
  }

  group('home search form', () {
    testWidgets('a guest sees the form with today selected, and no request is '
        'made until they act', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);

      expect(locationOf(tester).path, '/home');
      expect(find.text('Where are you travelling?'), findsOneWidget);
      expect(find.bySemanticsLabel('From, Select origin city'), findsOneWidget);
      expect(
        find.bySemanticsLabel('To, Select destination city'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Today'))
            .selected,
        isTrue,
      );
      expect(app.adapter.requests, isEmpty);
      handle.dispose();
    });

    testWidgets('searching with nothing chosen explains what is missing and '
        'sends nothing', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await tapSearch(tester);

      expect(
        find.text('Select where you are travelling from.'),
        findsOneWidget,
      );
      expect(find.text('Select where you are travelling to.'), findsOneWidget);
      expect(locationOf(tester).path, '/home');
      expect(app.adapter.requests, isEmpty);
      // Announced to screen readers
      expect(
        tester
            .getSemantics(find.text('Select where you are travelling from.'))
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets(
      'the same city twice is refused; swapping exchanges the cities',
      (tester) async {
        final handle = tester.ensureSemantics();
        await start(tester);
        await pickCity(tester, 'From', 'Bengaluru');
        await pickCity(tester, 'To', 'Bengaluru');
        await tapSearch(tester);
        expect(
          find.text('Origin and destination must be different.'),
          findsOneWidget,
        );
        expect(requestsTo(app, 'trips/search'), isEmpty);

        await pickCity(tester, 'To', 'Mysuru');
        expect(
          find.text('Origin and destination must be different.'),
          findsNothing,
        );
        await tester.tap(find.byTooltip('Swap origin and destination'));
        await tester.pump();
        expect(find.bySemanticsLabel('From, Mysuru'), findsOneWidget);
        expect(find.bySemanticsLabel('To, Bengaluru'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('a complete search opens the results for the chosen cities and '
        'date, as a guest, without a token', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      backend.trips = [tripJson('t1', today.add(const Duration(days: 1)))];
      await pickCity(tester, 'From', 'Bengaluru');
      await pickCity(tester, 'To', 'Mysuru');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
      await tester.pump();
      await tapSearch(tester);

      final tomorrow = isoDate(today.add(const Duration(days: 1)));
      expect(locationOf(tester).path, '/search/results');
      expect(locationOf(tester).query, {
        'origin': bengaluruId,
        'originName': 'Bengaluru',
        'destination': mysuruId,
        'destinationName': 'Mysuru',
        'date': tomorrow,
      });
      final request = requestsTo(app, 'trips/search').single;
      expect(request.options.queryParameters, {
        'from': bengaluruId,
        'to': mysuruId,
        'date': tomorrow,
        'sort': 'DEPARTURE_EARLIEST',
        'page': 1,
        'pageSize': 20,
      });
      expect(request.header('Authorization'), isNull);
      expect(find.byType(TripCard), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      handle.dispose();
    });

    testWidgets('a signed-in customer searches the same way, still without '
        'sending the token', (tester) async {
      await start(tester, stored: storedSession);
      await open(tester, results(today));
      expect(
        requestsTo(app, 'trips/search').single.header('Authorization'),
        isNull,
      );
    });

    testWidgets('/search shows the same form as a screen of its own', (
      tester,
    ) async {
      await start(tester);
      await open(tester, '/search');
      expect(find.text('Where are you travelling?'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Search buses'), findsOneWidget);
    });
  });

  group('travel date', () {
    testWidgets('the calendar offers today up to 90 days ahead and the chosen '
        'day is used', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^Travel date,')));
      await settle(tester);

      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, TravelDates.asLocalDate(today));
      expect(
        picker.lastDate,
        TravelDates.asLocalDate(today.add(const Duration(days: 90))),
      );

      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.byType(DatePickerDialog), findsNothing);
      handle.dispose();
    });

    testWidgets('Today and Tomorrow set the date', (tester) async {
      await start(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tomorrow'));
      await tester.pump();
      expect(
        container.read(searchFormControllerProvider).date,
        today.add(const Duration(days: 1)),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
      await tester.pump();
      expect(container.read(searchFormControllerProvider).date, today);
    });

    test('dates are India calendar dates, whatever the phone is set to', () {
      // 20:00 UTC is already the next day in India
      expect(
        TravelDates.today(DateTime.utc(2026, 10, 5, 20)),
        DateTime.utc(2026, 10, 6),
      );
      expect(
        TravelDates.today(DateTime.utc(2026, 10, 5, 18, 29)),
        DateTime.utc(2026, 10, 5),
      );
      expect(TravelDates.format(DateTime.utc(2026, 3, 7)), '2026-03-07');
      expect(TravelDates.tryParse('2026-10-09'), DateTime.utc(2026, 10, 9));
      for (final bad in ['2026-02-30', '09-10-2026', '2026-1-5', '', null]) {
        expect(TravelDates.tryParse(bad), isNull, reason: '$bad');
      }
      final now = DateTime.utc(2026, 10, 5, 6);
      expect(TravelDates.isSearchable(DateTime.utc(2026, 10, 5), now), isTrue);
      expect(TravelDates.isSearchable(DateTime.utc(2026, 10, 4), now), isFalse);
      expect(TravelDates.isSearchable(DateTime.utc(2027, 1, 3), now), isTrue);
      expect(TravelDates.isSearchable(DateTime.utc(2027, 1, 4), now), isFalse);
    });

    test('trip times are the clock time in India', () {
      final wall = TravelDates.wallClock(
        DateTime.utc(2026, 10, 5, 19, 15),
        'Asia/Kolkata',
      );
      expect(
        [wall.year, wall.month, wall.day, wall.hour, wall.minute],
        [2026, 10, 6, 0, 45],
      );
    });
  });

  group('city picker', () {
    testWidgets(
      'shows the popular cities first, then what matches the typing',
      (tester) async {
        final handle = tester.ensureSemantics();
        await start(tester);
        await tester.tap(find.bySemanticsLabel(RegExp('^From,')));
        await settle(tester);

        expect(find.widgetWithText(AppBar, 'Travelling from'), findsOneWidget);
        expect(find.text('Popular cities'), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(2));
        expect(
          requestsTo(app, 'cities').single.options.queryParameters,
          isEmpty,
        );

        await tester.enterText(find.byType(TextField), 'hu');
        await tester.pump(const Duration(milliseconds: 350));
        await settle(tester);
        expect(lastQuery(app, 'cities'), {'query': 'hu'});
        expect(find.text('Popular cities'), findsNothing);
        expect(find.widgetWithText(ListTile, 'Hubballi'), findsOneWidget);
        expect(find.text('Karnataka'), findsOneWidget);

        await tester.tap(find.widgetWithText(ListTile, 'Hubballi'));
        await settle(tester);
        expect(find.bySemanticsLabel('From, Hubballi'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('typing quickly asks the backend once, not per letter', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^To,')));
      await settle(tester);
      expect(find.widgetWithText(AppBar, 'Travelling to'), findsOneWidget);

      for (final text in ['m', 'my', 'mys']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(
        requestsTo(
          app,
          'cities',
        ).map((r) => r.options.queryParameters['query']),
        [null, 'mys'],
      );
      handle.dispose();
    });

    testWidgets('no match, no connection and retry', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^From,')));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(find.text('No city found'), findsOneWidget);

      backend.isOnline = false;
      await tester.enterText(find.byType(TextField), 'be');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester);
      expect(find.text('No internet connection'), findsOneWidget);

      backend.isOnline = true;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.widgetWithText(ListTile, 'Bengaluru'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('closing the picker without choosing changes nothing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^From,')));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      expect(find.bySemanticsLabel('From, Select origin city'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without popular cities it asks the customer to type', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      backend.popularCities = [];
      await tester.tap(find.bySemanticsLabel(RegExp('^From,')));
      await settle(tester);
      expect(find.text('Type the name of a city.'), findsOneWidget);
      handle.dispose();
    });
  });

  group('recent searches', () {
    testWidgets('a search is remembered on the device and fills the form '
        'again', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      await pickCity(tester, 'From', 'Bengaluru');
      await pickCity(tester, 'To', 'Mysuru');
      await tapSearch(tester);
      await tester.pageBack();
      await settle(tester);

      final stored =
          jsonDecode(
                app.preferences.getString(
                  SearchFormController.recentSearchesKey,
                )!,
              )
              as List;
      expect(stored, hasLength(1));
      expect(find.text('Recent searches'), findsOneWidget);

      await tester.tap(find.byTooltip('Swap origin and destination'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ListTile, 'Bengaluru to Mysuru'));
      await tester.pump();
      expect(find.bySemanticsLabel('From, Bengaluru'), findsOneWidget);
      expect(find.bySemanticsLabel('To, Mysuru'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'stored routes are shown at start; unreadable data is ignored',
      (tester) async {
        await start(
          tester,
          preferences: {
            SearchFormController.recentSearchesKey: jsonEncode([
              {'from': bengaluru, 'to': mysuru},
            ]),
          },
        );
        expect(
          find.widgetWithText(ListTile, 'Bengaluru to Mysuru'),
          findsOneWidget,
        );

        await start(
          tester,
          preferences: {SearchFormController.recentSearchesKey: '{not json'},
        );
        expect(find.text('Recent searches'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('search results', () {
    testWidgets('lists the buses with times at the place of travel, fare and '
        'seats', (tester) async {
      await start(tester);
      backend.trips = [
        tripJson('t1', today),
        tripJson(
          't2',
          today,
          operator: 'Kaveri Lines',
          departure: '13:15',
          arrival: '16:15',
          farePaise: 35000,
          available: 2,
        ),
        tripJson(
          't3',
          today,
          departure: '22:45',
          arrival: '02:45',
          arrivalPlusDays: 1,
          farePaise: 90000,
          available: 0,
        ),
      ];
      await open(tester, results(today));

      expect(
        find.widgetWithText(AppBar, 'Bengaluru to Mysuru'),
        findsOneWidget,
      );
      expect(find.text('3 buses'), findsOneWidget);
      expect(find.byType(TripCard), findsNWidgets(3));
      final first = find.byType(TripCard).first;
      for (final text in [
        'Abra Travels',
        'AC Sleeper · AC',
        '3h 30m',
        '20 seats left',
      ]) {
        expect(
          find.descendant(of: first, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(of: first, matching: find.textContaining('6:30')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.textContaining('10:00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.textContaining('650')),
        findsOneWidget,
      );
      expect(find.text('2 seats left'), findsOneWidget);
      expect(find.text('Sold out'), findsOneWidget);
      expect(find.text('Arrives next day'), findsOneWidget);
    });

    testWidgets('a card reads as one sentence for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      backend.trips = [tripJson('t1', today)];
      await open(tester, results(today));
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Abra Travels, AC Sleeper · AC\. Departs 6:30.*arrives 10:00.*20 seats left\.$',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('shows progress while loading', (tester) async {
      await start(tester);
      final answer = Completer<FakeResponse>();
      backend.search = (_) => throw StateError('unused');
      app.adapter.handler = (request) =>
          request.path == 'trips/search' ? answer.future : backend(request);
      ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(customerRouterProvider).go(results(today));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(AbraLoadingView), findsOneWidget);
      expect(find.byType(TripCard), findsNothing);

      answer.complete(
        FakeResponse.ok(
          <Object?>[],
          meta: {'page': 1, 'pageSize': 20, 'total': 0},
        ),
      );
      await settle(tester);
      expect(find.byType(AbraLoadingView), findsNothing);
    });

    testWidgets('no buses: says so and suggests another date', (tester) async {
      await start(tester);
      await open(tester, results(today));
      expect(find.text('No buses found'), findsOneWidget);
      expect(find.textContaining('Try another date'), findsOneWidget);
      expect(find.text('No buses'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Clear filters'), findsNothing);
    });

    for (final (name, response, title) in [
      (
        'server failure',
        FakeResponse.error(
          500,
          'INTERNAL_ERROR',
          message: 'aggregate failed at stage 3',
        ),
        'Service unavailable',
      ),
      (
        'too many searches',
        FakeResponse.error(
          429,
          'RATE_LIMITED',
          details: {'retryAfterSeconds': 30},
        ),
        'Too many attempts',
      ),
    ]) {
      testWidgets('$name: explained without technical detail', (tester) async {
        await start(tester);
        backend.search = (_) => response;
        await open(tester, results(today));
        expect(find.text(title), findsOneWidget);
        expect(find.textContaining('aggregate'), findsNothing);
        expect(find.byType(TripCard), findsNothing);
      });
    }

    testWidgets('no connection: says so, and retry loads the buses', (
      tester,
    ) async {
      await start(tester);
      backend
        ..trips = [tripJson('t1', today)]
        ..isOnline = false;
      await open(tester, results(today));
      expect(find.text('No internet connection'), findsOneWidget);

      backend.isOnline = true;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.byType(TripCard), findsOneWidget);
    });

    testWidgets('a link with missing or malformed values is explained, with a '
        'way back to searching', (tester) async {
      await start(tester);
      for (final location in [
        '/search/results',
        '/search/results?origin=$bengaluruId&destination=$mysuruId&date=2026-02-30',
        '/search/results?origin=abc&destination=$mysuruId&date=${isoDate(today)}',
        '/search/results?origin=$bengaluruId&destination=$bengaluruId&date=${isoDate(today)}',
      ]) {
        await open(tester, location);
        expect(
          find.text('This search cannot be shown'),
          findsOneWidget,
          reason: location,
        );
      }
      expect(requestsTo(app, 'trips/search'), isEmpty);
      await tester.tap(find.widgetWithText(AbraButton, 'Search buses'));
      await settle(tester);
      expect(locationOf(tester).path, '/home');
    });
  });

  group('day switching', () {
    testWidgets('next and previous day search again for that date', (
      tester,
    ) async {
      await start(tester);
      final tomorrow = today.add(const Duration(days: 1));
      final dayAfter = today.add(const Duration(days: 2));
      await open(tester, results(tomorrow));
      final text = DiscoveryText(
        AbraLocalizations.of(tester.element(find.byType(SearchResultsScreen))),
      );
      expect(find.text(text.date(tomorrow)), findsOneWidget);

      await tester.tap(find.byTooltip('Next day'));
      await settle(tester);
      expect(lastQuery(app, 'trips/search')['date'], isoDate(dayAfter));
      expect(find.text(text.date(dayAfter)), findsOneWidget);

      await tester.tap(find.byTooltip('Previous day'));
      await settle(tester);
      expect(lastQuery(app, 'trips/search')['date'], isoDate(tomorrow));
      await tester.tap(find.byTooltip('Previous day'));
      await settle(tester);
      expect(lastQuery(app, 'trips/search')['date'], isoDate(today));
      // Today is the first searchable day
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );

      // Days do not stack as screens: one step back leaves the results
      await tester.pageBack();
      await settle(tester);
      expect(find.byType(SearchResultsScreen), findsNothing);
    });

    testWidgets('cannot go before today or beyond the last searchable day', (
      tester,
    ) async {
      await start(tester);
      await open(tester, results(today));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNotNull,
      );

      await open(tester, results(today.add(const Duration(days: 90))));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('sorting', () {
    testWidgets('choosing an order asks the backend for that order', (
      tester,
    ) async {
      await start(tester);
      backend.trips = [tripJson('t1', today)];
      await open(tester, results(today));

      for (final (label, wire) in [
        ('Price: lowest first', 'FARE_LOWEST'),
        ('Duration: shortest first', 'DURATION_SHORTEST'),
        ('Departure: latest first', 'DEPARTURE_LATEST'),
        ('Price: highest first', 'FARE_HIGHEST'),
        ('Departure: earliest first', 'DEPARTURE_EARLIEST'),
      ]) {
        await tester.tap(find.byTooltip('Sort'));
        await settle(tester);
        await tester.tap(find.text(label).last);
        await settle(tester);
        expect(lastQuery(app, 'trips/search')['sort'], wire, reason: label);
        expect(lastQuery(app, 'trips/search')['page'], 1);
      }
    });
  });

  group('filters', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('Filter'));
      await settle(tester);
      expect(find.text('Filters'), findsOneWidget);
    }

    Future<void> apply(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AbraButton, 'Show buses'));
      await settle(tester);
    }

    testWidgets('offers only what occurs in the search, with counts, and the '
        'backend does the filtering', (tester) async {
      await start(tester);
      backend.trips = [tripJson('t1', today)];
      await open(tester, results(today));
      await openSheet(tester);

      expect(
        requestsTo(app, 'trips/search/filters').single.options.queryParameters,
        {'from': bengaluruId, 'to': mysuruId, 'date': isoDate(today)},
      );
      for (final label in [
        'AC Sleeper (2)',
        'Non-AC Seater (1)',
        'Abra Travels (2)',
        'Wi-Fi (2)',
        'Blanket (1)',
        '6 AM to 12 PM (1)',
        'After 6 PM (1)',
      ]) {
        expect(
          find.widgetWithText(FilterChip, label),
          findsOneWidget,
          reason: label,
        );
      }
      // A window with no buses is not offered
      expect(find.textContaining('Before 6 AM'), findsNothing);

      for (final label in [
        // Top to bottom: the sheet builds its sections as they scroll in
        '6 AM to 12 PM (1)',
        'After 6 PM (1)',
        'AC Sleeper (2)',
        'AC',
        'Kaveri Lines (1)',
        'Wi-Fi (2)',
      ]) {
        final chip = find.widgetWithText(FilterChip, label);
        await tester.scrollUntilVisible(
          chip,
          120,
          scrollable: find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(chip);
        await tester.pump();
      }
      await apply(tester);

      final query = lastQuery(app, 'trips/search');
      expect(query['busTypes'], 'AC_SLEEPER');
      expect(query['departureWindows'], 'MORNING,NIGHT');
      expect(query['amenities'], 'WIFI');
      expect(query['operatorIds'], '66f0c0ffee000000000000a2');
      expect(query['ac'], 'true');
      expect(query['page'], 1);
      expect(
        find.text('6'),
        findsOneWidget,
      ); // badge with the number of filters
    });

    testWidgets('closing the sheet without applying changes nothing', (
      tester,
    ) async {
      await start(tester);
      backend.trips = [tripJson('t1', today)];
      await open(tester, results(today));
      await openSheet(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'AC Sleeper (2)'));
      await tester.pump();
      await tester.tapAt(const Offset(200, 20));
      await settle(tester);
      expect(requestsTo(app, 'trips/search'), hasLength(1));
    });

    testWidgets('filters that leave no buses can be cleared from the empty '
        'state; Reset clears them in the sheet', (tester) async {
      await start(tester);
      backend.search = (request) {
        final filtered = request.options.queryParameters.containsKey(
          'busTypes',
        );
        return FakeResponse.ok(
          filtered ? <Object?>[] : [tripJson('t1', today)],
          meta: {'page': 1, 'pageSize': 20, 'total': filtered ? 0 : 1},
        );
      };
      await open(tester, results(today));
      await openSheet(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Non-AC Seater (1)'));
      await tester.pump();
      await apply(tester);
      expect(find.text('No buses match your filters.'), findsOneWidget);

      await tester.tap(find.widgetWithText(AbraButton, 'Clear filters'));
      await settle(tester);
      expect(find.byType(TripCard), findsOneWidget);
      expect(lastQuery(app, 'trips/search').containsKey('busTypes'), isFalse);

      await openSheet(tester);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'AC Sleeper (2)'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pump();
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(FilterChip, 'AC Sleeper (2)'),
            )
            .selected,
        isFalse,
      );
    });

    testWidgets('filter values that cannot be loaded are explained in the '
        'sheet', (tester) async {
      await start(tester);
      backend.trips = [tripJson('t1', today)];
      await open(tester, results(today));
      backend.isOnline = false;
      await tester.tap(find.text('Filter'));
      await settle(tester);
      expect(find.text('No internet connection'), findsOneWidget);
      backend.isOnline = true;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.widgetWithText(FilterChip, 'AC Sleeper (2)'), findsOneWidget);
    });

    test(
      'filters are compared by value, so the same choice is the same search',
      () {
        const a = TripFilters(busTypes: {'A', 'B'}, isAc: true);
        const b = TripFilters(busTypes: {'B', 'A'}, isAc: true);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a.activeCount, 3);
        expect(a.copyWith(isAc: () => null), isNot(a));
        expect(TripFilters.none.isEmpty, isTrue);
      },
    );
  });

  group('more results', () {
    testWidgets('further pages are loaded on request and never repeat a bus', (
      tester,
    ) async {
      await start(tester);
      backend.trips = [
        for (var i = 0; i < 25; i++) tripJson('t$i', today, busName: 'Bus $i'),
      ];
      await open(tester, results(today));
      expect(find.text('25 buses'), findsOneWidget);

      final more = find.widgetWithText(AbraButton, 'Show more buses');
      await tester.scrollUntilVisible(
        more,
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(more);
      await settle(tester);

      expect(
        requestsTo(
          app,
          'trips/search',
        ).map((r) => r.options.queryParameters['page']),
        [1, 2],
      );
      // All 25 are on the list now: scrolling to the end finds the last bus
      // and no further "more" button.
      await tester.scrollUntilVisible(
        find.byType(TripCard).last,
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, -30000),
        8000,
      );
      await settle(tester);
      expect(find.widgetWithText(AbraButton, 'Show more buses'), findsNothing);
    });

    testWidgets('a page that fails to load keeps the buses shown and can be '
        'retried', (tester) async {
      await start(tester);
      backend.trips = [for (var i = 0; i < 25; i++) tripJson('t$i', today)];
      await open(tester, results(today));
      final more = find.widgetWithText(AbraButton, 'Show more buses');
      await tester.scrollUntilVisible(
        more,
        600,
        scrollable: find.byType(Scrollable).last,
      );

      backend.isOnline = false;
      await tester.tap(more);
      await settle(tester);
      expect(find.text('More buses could not be loaded.'), findsOneWidget);
      expect(find.byType(TripCard), findsWidgets);

      backend.isOnline = true;
      final retry = find.widgetWithText(AbraButton, 'Try again');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await settle(tester);
      expect(find.text('More buses could not be loaded.'), findsNothing);
      expect(
        requestsTo(app, 'trips/search').last.options.queryParameters['page'],
        2,
      );
    });
  });

  group('trip details', () {
    testWidgets('opening a result loads the trip and shows bus, timings, fare, '
        'boarding and dropping points', (tester) async {
      await start(tester);
      backend
        ..trips = [tripJson('66f0c0ffee0000000000abcd', today)]
        ..trip = (_) => FakeResponse.ok(
          tripJson('66f0c0ffee0000000000abcd', today, detail: true),
        );
      await open(tester, results(today));
      await tester.tap(find.byType(TripCard));
      await settle(tester);

      expect(locationOf(tester).path, '/trip/66f0c0ffee0000000000abcd');
      expect(
        requestsTo(
          app,
          'trips/66f0c0ffee0000000000abcd',
        ).single.header('Authorization'),
        isNull,
      );
      expect(find.byType(TripDetailsScreen), findsOneWidget);
      expect(
        find.widgetWithText(AppBar, 'Bengaluru to Mysuru'),
        findsOneWidget,
      );
      for (final text in [
        'Abra Travels',
        'Abra Express',
        'AC Sleeper · AC',
        'Bus number KA01AB1234',
        '3h 30m',
        'Via Mandya',
        '20 seats left',
        'Amenities',
        'Wi-Fi',
        'Charging point',
        'Hot towel', // an amenity this version does not know: shown readable, not as a key
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.textContaining('650'), findsOneWidget);

      Future<void> see(List<String> texts) async {
        for (final text in texts) {
          await tester.scrollUntilVisible(
            find.text(text),
            120,
            scrollable: find.byType(Scrollable).last,
          );
          expect(find.text(text), findsOneWidget, reason: text);
        }
      }

      await see([
        'Boarding points',
        'Central Bus Stand',
        'Central Bus Stand, Main Road',
        'Landmark: Opposite City Mall',
        'Board at platform 4',
        'Second Stage',
      ]);
      expect(find.textContaining('6:50'), findsOneWidget);
      await see(['Dropping points', 'Town Hall', 'Town Hall, Main Road']);
    });

    testWidgets('booking is stated as unavailable, not offered as a button', (
      tester,
    ) async {
      await start(tester);
      backend.trip = (_) => FakeResponse.ok(
        tripJson('66f0c0ffee0000000000abcd', today, detail: true),
      );
      await open(tester, '/trip/66f0c0ffee0000000000abcd');
      await tester.scrollUntilVisible(
        find.textContaining('not available in the app yet'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byType(AbraButton), findsNothing);
    });

    testWidgets('a guest can open a trip from a link; back leads to home', (
      tester,
    ) async {
      await start(tester);
      backend.trip = (_) => FakeResponse.ok(
        tripJson('66f0c0ffee0000000000abcd', today, detail: true),
      );
      await open(tester, '/trip/66f0c0ffee0000000000abcd');
      expect(find.byType(TripDetailsScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('a trip that is gone is explained, with a way back to '
        'searching', (tester) async {
      await start(tester);
      await open(tester, '/trip/66f0c0ffee0000000000dead');
      expect(find.text('This bus is no longer available'), findsOneWidget);
      await tester.tap(find.widgetWithText(AbraButton, 'Search buses'));
      await settle(tester);
      expect(locationOf(tester).path, '/home');
    });

    testWidgets('no connection: says so, and retry loads the trip', (
      tester,
    ) async {
      await start(tester);
      backend
        ..trip = ((_) => FakeResponse.ok(
          tripJson('66f0c0ffee0000000000abcd', today, detail: true),
        ))
        ..isOnline = false;
      await open(tester, '/trip/66f0c0ffee0000000000abcd');
      expect(find.text('No internet connection'), findsOneWidget);
      backend.isOnline = true;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('Abra Travels'), findsOneWidget);
    });

    testWidgets('personal screens still need sign-in from here', (
      tester,
    ) async {
      await start(tester);
      await open(tester, '/trip/66f0c0ffee0000000000abcd/seats');
      expect(locationOf(tester).path, '/login');
      await open(tester, '/seats');
      expect(locationOf(tester).path, '/login');
    });
  });

  group('accessibility and layout', () {
    testWidgets('results and trip details meet the tap-target, labelling and '
        'contrast guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester);
      backend
        ..trips = [tripJson('t1', today), tripJson('t2', today, available: 0)]
        ..trip = (_) => FakeResponse.ok(tripJson('t1', today, detail: true));
      for (final location in [
        results(today),
        '/trip/66f0c0ffee0000000000abcd',
      ]) {
        await open(tester, location);
        await expectLater(
          tester,
          meetsGuideline(androidTapTargetGuideline),
          reason: location,
        );
        await expectLater(
          tester,
          meetsGuideline(labeledTapTargetGuideline),
          reason: location,
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: location,
        );
      }
      handle.dispose();
    });

    testWidgets('home, results and details fit a small phone with large text '
        'and a tablet', (tester) async {
      for (final (size, scale) in [
        (const Size(320, 568), 2.0),
        (const Size(900, 1200), 1.0),
      ]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await start(tester, size: size);
        backend
          ..trips = [tripJson('t1', today)]
          ..trip = (_) => FakeResponse.ok(tripJson('t1', today, detail: true));
        expect(tester.takeException(), isNull, reason: 'home $size');
        await open(tester, results(today));
        expect(find.byType(TripCard), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'results $size');
        await open(tester, '/trip/66f0c0ffee0000000000abcd');
        expect(tester.takeException(), isNull, reason: 'details $size');
      }
    });
  });

  group('models and text', () {
    test('a result with a missing required field is a server fault, not a '
        'crash later', () {
      final json = tripJson('t1', DateTime.utc(2026, 10, 9))..remove('fare');
      expect(() => TripSummary.fromJson(json), throwsA(anything));
    });

    test('search links are read back exactly and reject bad input', () {
      final ok = SearchResultsArguments.tryParse(
        Uri.parse(
          '/search/results?origin=$bengaluruId&originName=Bengaluru&destination=$mysuruId&destinationName=Mysuru&date=2026-10-09',
        ),
      )!;
      expect(
        ok.criteria,
        const TripSearchCriteria(
          fromCityId: bengaluruId,
          toCityId: mysuruId,
          date: '2026-10-09',
        ),
      );
      expect(
        SearchResultsArguments.tryParse(Uri.parse('/search/results?origin=x')),
        isNull,
      );
    });

    testWidgets('unknown amenity and window keys are shown as readable text', (
      tester,
    ) async {
      await start(tester);
      final l10n = AbraLocalizations.of(
        tester.element(find.text('Where are you travelling?')),
      );
      final text = DiscoveryText(l10n);
      expect(text.amenity('WIFI'), 'Wi-Fi');
      expect(text.amenity('HOT_TOWEL'), 'Hot towel');
      expect(text.departureWindow('NIGHT'), 'After 6 PM');
      expect(text.duration(125), '2h 5m');
      expect(l10n.missingKeys, isEmpty);
    });
  });
}
