import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/home/home_banner_carousel.dart';
import 'package:customer_app/features/home/home_banners_repository.dart';
import 'package:customer_app/features/unavailable/feature_unavailable_screen.dart';
import 'package:customer_app/routing/customer_router.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';

import 'support/fake_home_banners.dart';
import 'support/test_app.dart';

const bengaluruId = '66f0c0ffee00000000000001';
const mysuruId = '66f0c0ffee00000000000002';

HomeBanner banner(
  int number, {
  BannerLinkType linkType = BannerLinkType.none,
  String linkValue = '',
  String? buttonText,
}) => HomeBanner(
  id: 'banner-$number',
  title: 'Banner title $number',
  subtitle: 'Banner subtitle $number',
  buttonText: buttonText,
  linkType: linkType,
  linkValue: linkValue,
);

/// The location of the page on top, including pages opened with `push`.
Uri locationOf(WidgetTester tester) {
  final configuration = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  ).read(customerRouterProvider).routerDelegate.currentConfiguration;
  final top = configuration.matches.last;
  return top is ImperativeRouteMatch ? top.matches.uri : configuration.uri;
}

Finder dot(int current, int total) =>
    find.bySemanticsLabel('Banner $current of $total');

bool isSelected(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).flagsCollection.isSelected;

/// The banners sit below the search form (demo order), so scroll them into view.
Future<void> showCarousel(WidgetTester tester) async {
  final pager = find.byType(PageView);
  final home = find
      .ancestor(
        of: find.text('Where are you travelling?'),
        matching: find.byType(Scrollable),
      )
      .first;
  if (home.evaluate().isEmpty) return;
  final position = tester.state<ScrollableState>(home).position;
  // Home builds its sections lazily: step down until the banners exist.
  for (var i = 0; i < 20 && pager.evaluate().isEmpty; i++) {
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(position.pixels + 300);
    await tester.pump();
  }
  if (pager.evaluate().isEmpty) {
    // No banners on this Home: go back to the top as it opened.
    position.jumpTo(0);
    await tester.pump();
    return;
  }
  await tester.ensureVisible(pager);
  await tester.pump();
}

void main() {
  group('banners repository', () {
    test(
      'asks for the live Home banners without a token, in the selected '
      'language, and resolves relative image paths against the API',
      () async {
        final app = TestApp(
          handler: (request) async => FakeResponse.ok(<Object?>[
            <String, Object?>{
              'id': 'b1',
              'title': 'Monsoon offer',
              'subtitle': 'Save on Mysuru trips',
              'buttonText': 'Book now',
              'linkType': 'ROUTE_SEARCH',
              'linkValue': '$bengaluruId:$mysuruId',
              'imageUrl': 'banners/b1/image?v=123',
              'desktopImageUrl': 'banners/b1/image?variant=desktop&v=123',
            },
            <String, Object?>{
              'id': 'b2',
              'title': 'Absolute image',
              'linkType': 'URL',
              'linkValue': 'https://abra.example/offers',
              'imageUrl': 'https://cdn.abra.example/b2.jpg',
            },
            <String, Object?>{
              'id': 'b3',
              'title': 'No image, unknown link',
              'linkType': 'SOMETHING_NEW',
              'imageUrl': null,
            },
            // Malformed entries are skipped, not fatal.
            <String, Object?>{'id': 'b4'},
            'not a banner',
            <String, Object?>{
              'id': 'b5',
              'title': 'Insecure image',
              'imageUrl': 'http://cdn.abra.example/b5.jpg',
            },
          ]),
        );
        final repository = HomeBannersRepository(
          app.dependencies.apiClient,
          imageBase: app.dependencies.config.apiV1Url,
        );

        final banners = await repository.homeTop();

        final request = app.adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, 'banners');
        expect(request.options.queryParameters, {'placement': 'HOME_TOP'});
        expect(request.header('Authorization'), isNull);
        expect(request.header('Accept-Language'), 'en');

        expect(banners.map((banner) => banner.id), ['b1', 'b2', 'b3', 'b5']);
        expect(
          banners[0].imageUrl.toString(),
          'http://localhost:4000/api/v1/banners/b1/image?v=123',
        );
        expect(
          banners[0].desktopImageUrl.toString(),
          'http://localhost:4000/api/v1/banners/b1/image?variant=desktop&v=123',
        );
        expect(banners[1].desktopImageUrl, isNull);
        expect(banners[0].linkType, BannerLinkType.routeSearch);
        expect(banners[0].buttonText, 'Book now');
        expect(
          banners[1].imageUrl.toString(),
          'https://cdn.abra.example/b2.jpg',
        );
        expect(banners[2].imageUrl, isNull);
        expect(banners[2].linkType, BannerLinkType.none);
        expect(banners[2].subtitle, isNull);
        expect(banners[3].imageUrl, isNull, reason: 'only https is accepted');
      },
    );

    test('a failed request surfaces as AppException', () async {
      final app = TestApp(handler: connectionErrorHandler);
      final repository = HomeBannersRepository(
        app.dependencies.apiClient,
        imageBase: app.dependencies.config.apiV1Url,
      );
      await expectLater(repository.homeTop(), throwsA(isA<AppException>()));
    });
  });

  group('banner carousel on Home', () {
    Future<TestApp> start(
      WidgetTester tester,
      FakeHomeBannersRepository banners, {
      Future<FakeResponse> Function(RecordedRequest request)? handler,
    }) async {
      final app = TestApp(banners: banners, handler: handler);
      await app.pump(tester);
      await showCarousel(tester);
      return app;
    }

    testWidgets('is hidden when there are no banners', (tester) async {
      final repository = FakeHomeBannersRepository();
      await start(tester, repository);

      expect(repository.calls, 1);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Where are you travelling?'), findsOneWidget);
    });

    testWidgets('is hidden when the banners cannot be loaded', (tester) async {
      await start(
        tester,
        FakeHomeBannersRepository.failing(const AppException(NetworkFailure())),
      );

      expect(find.byType(PageView), findsNothing);
      expect(find.text('Where are you travelling?'), findsOneWidget);
    });

    testWidgets('three banners show dots and move on every four seconds, '
        'round to the first again', (tester) async {
      final handle = tester.ensureSemantics();
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[
          banner(1),
          banner(2),
          banner(3),
        ]),
      );

      expect(find.text('Banner title 1'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Banner title 1. Banner subtitle 1'),
        findsOneWidget,
      );
      for (var i = 1; i <= 3; i++) {
        expect(dot(i, 3), findsOneWidget);
      }
      expect(isSelected(tester, dot(1, 3)), isTrue);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(isSelected(tester, dot(1, 3)), isTrue, reason: 'not yet');

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(isSelected(tester, dot(2, 3)), isTrue);
      expect(find.text('Banner title 2'), findsOneWidget);

      for (final expected in [3, 1]) {
        await tester.pump(HomeBannerCarousel.autoAdvanceInterval);
        await tester.pump(const Duration(milliseconds: 500));
        expect(isSelected(tester, dot(expected, 3)), isTrue);
      }

      // A dot opens its banner.
      await tester.tap(dot(3, 3));
      await tester.pumpAndSettle();
      expect(isSelected(tester, dot(3, 3)), isTrue);
      handle.dispose();
    });

    testWidgets('stands still while another screen covers Home', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[banner(1), banner(2)]),
      );

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(customerRouterProvider).pop();
      await tester.pumpAndSettle();

      expect(isSelected(tester, dot(1, 2)), isTrue);
      handle.dispose();
    });

    testWidgets('does not move by itself when motion is reduced', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[banner(1), banner(2)]),
      );

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(isSelected(tester, dot(1, 2)), isTrue);
      handle.dispose();
    });

    testWidgets('one banner has no dots and stays put', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester, FakeHomeBannersRepository(<HomeBanner>[banner(1)]));

      expect(find.text('Banner title 1'), findsOneWidget);
      expect(dot(1, 1), findsNothing);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('Banner title 1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a route banner runs the search for its two cities', (
      tester,
    ) async {
      final app = await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[
          banner(
            1,
            linkType: BannerLinkType.routeSearch,
            linkValue: '$bengaluruId:$mysuruId',
            buttonText: 'Book now',
          ),
        ]),
        handler: (request) async => request.path == 'trips/search'
            ? FakeResponse.ok(
                const <Object?>[],
                meta: const <String, Object?>{
                  'page': 1,
                  'pageSize': 20,
                  'total': 0,
                },
              )
            : FakeResponse.error(404, 'RESOURCE_NOT_FOUND'),
      );

      final button = find.widgetWithText(FilledButton, 'Book now');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      final location = locationOf(tester);
      expect(location.path, '/search/results');
      expect(location.queryParameters['origin'], bengaluruId);
      expect(location.queryParameters['destination'], mysuruId);
      final search = app.adapter.requests.firstWhere(
        (request) => request.path == 'trips/search',
      );
      expect(search.options.queryParameters['from'], bengaluruId);
      expect(search.options.queryParameters['to'], mysuruId);
    });

    testWidgets('tapping the card opens it too; an offer shows the '
        'not-built screen', (tester) async {
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[
          banner(1, linkType: BannerLinkType.offer, linkValue: 'MONSOON'),
        ]),
      );

      // The words let the tap through to the card underneath.
      await tester.tap(find.text('Banner title 1'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Offer'), findsOneWidget);
    });

    testWidgets('bad route data does nothing', (tester) async {
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[
          banner(
            1,
            linkType: BannerLinkType.routeSearch,
            linkValue: 'not-a-route',
            buttonText: 'Go',
          ),
        ]),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Go'));
      await tester.pumpAndSettle();
      expect(locationOf(tester).path, '/home');
    });

    testWidgets('a relative image is loaded from the API address', (
      tester,
    ) async {
      final app = TestApp();
      final resolved = HomeBanner.fromJson(<String, Object?>{
        'id': 'b1',
        'title': 'With image',
        'imageUrl': 'banners/b1/image?v=123',
      }, imageBase: app.dependencies.config.apiV1Url);
      await start(tester, FakeHomeBannersRepository(<HomeBanner>[resolved]));

      final image = tester.widget<Image>(find.byType(Image).first);
      expect(
        (image.image as NetworkImage).url,
        'http://localhost:4000/api/v1/banners/b1/image?v=123',
      );
      // The picture fails to load in tests: the gradient stays, no error.
      expect(find.text('With image'), findsOneWidget);
    });

    testWidgets('pull-to-refresh on Home loads the banners again', (
      tester,
    ) async {
      final repository = FakeHomeBannersRepository(<HomeBanner>[banner(1)]);
      await start(tester, repository);
      expect(repository.calls, 1);

      repository.banners = <HomeBanner>[banner(2)];
      // Back to the top of Home, where pulling down refreshes.
      tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: find.byType(PageView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      await tester.pump();
      await tester.fling(
        find.text('Where are you travelling?'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repository.calls, 2);
      expect(find.text('Banner title 2'), findsOneWidget);
    });

    group('responsive layout', () {
      HomeBanner pictured(int number) => HomeBanner(
        id: 'banner-$number',
        title: 'Banner title $number',
        subtitle: 'Banner subtitle $number',
        imageUrl: Uri.parse('https://cdn.abra.example/$number-phone.jpg'),
        desktopImageUrl: Uri.parse(
          'https://cdn.abra.example/$number-desktop.jpg',
        ),
      );

      Future<void> startAt(
        WidgetTester tester,
        Size size,
        List<HomeBanner> banners,
      ) async {
        final app = TestApp(banners: FakeHomeBannersRepository(banners));
        await app.pump(tester, size: size);
        await showCarousel(tester);
      }

      Finder bannerImage() => find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Image),
      );

      String imageUrl(WidgetTester tester) =>
          (tester.widget<Image>(bannerImage()).image as NetworkImage).url;

      testWidgets('a phone shows one full-width 16:7 card with the phone '
          'picture', (tester) async {
        await startAt(tester, const Size(390, 844), <HomeBanner>[
          pictured(1),
          pictured(2),
        ]);

        expect(bannerImage(), findsOneWidget);
        expect(imageUrl(tester), 'https://cdn.abra.example/1-phone.jpg');
        final card = tester.getRect(bannerImage());
        expect(card.width / card.height, closeTo(16 / 7, 0.01));
        expect(card.width, greaterThan(390 - 2 * 24 - 1));
        expect(find.text('Banner title 2'), findsNothing);
      });

      testWidgets('a desktop shows one centred 4:1 banner with the desktop '
          'picture and no neighbours', (tester) async {
        await startAt(tester, const Size(1280, 800), <HomeBanner>[
          pictured(1),
          pictured(2),
          pictured(3),
        ]);

        expect(bannerImage(), findsOneWidget);
        expect(imageUrl(tester), 'https://cdn.abra.example/1-desktop.jpg');
        final card = tester.getRect(bannerImage());
        final pager = tester.getRect(find.byType(PageView));
        expect(card.width / card.height, closeTo(4, 0.01));
        expect(card.width, lessThanOrEqualTo(HomeBannerCarousel.maxWidth));
        expect(card.center.dx, closeTo(pager.center.dx, 0.5));
        // Nothing of another banner shows at rest.
        expect(find.text('Banner title 2'), findsNothing);
        expect(find.text('Banner title 3'), findsNothing);
      });

      testWidgets('a wide banner without a desktop picture uses the phone '
          'one', (tester) async {
        await startAt(tester, const Size(1024, 768), <HomeBanner>[
          HomeBanner(
            id: 'b1',
            title: 'Phone picture only',
            imageUrl: Uri.parse('https://cdn.abra.example/b1.jpg'),
          ),
        ]);

        expect(imageUrl(tester), 'https://cdn.abra.example/b1.jpg');
      });

      testWidgets('arrows appear on hover on wide screens and move between '
          'banners', (tester) async {
        final handle = tester.ensureSemantics();
        await startAt(tester, const Size(1280, 800), <HomeBanner>[
          pictured(1),
          pictured(2),
        ]);

        final next = find.byTooltip('Next page');
        expect(next, findsOneWidget);
        double opacity() => tester
            .widget<AnimatedOpacity>(
              find.ancestor(of: next, matching: find.byType(AnimatedOpacity)),
            )
            .opacity;
        expect(opacity(), 0);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.byType(PageView)));
        await tester.pumpAndSettle();
        expect(opacity(), 1);

        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(isSelected(tester, dot(2, 2)), isTrue);
        expect(find.text('Banner title 2'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('nothing overflows on phones, tablets and desktops, also '
          'with text at twice the size', (tester) async {
        final long = HomeBanner(
          id: 'long',
          title: 'Monsoon getaway: up to 30% off on overnight sleeper buses',
          subtitle:
              'Book Bengaluru to Mysuru, Hubballi and Mangaluru before '
              'Sunday and travel any day this month.',
          buttonText: 'Find buses now',
          linkType: BannerLinkType.offer,
          linkValue: 'MONSOON',
          imageUrl: Uri.parse('https://cdn.abra.example/long.jpg'),
        );
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final scale in <double>[1, 2]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          for (final size in const <Size>[
            Size(360, 640),
            Size(390, 844),
            Size(768, 1024),
            Size(1280, 800),
            Size(1440, 900),
            Size(1920, 1080),
          ]) {
            await startAt(tester, size, <HomeBanner>[long, pictured(2)]);
            expect(
              tester.takeException(),
              isNull,
              reason: '$size at text scale $scale',
            );
            expect(bannerImage(), findsOneWidget, reason: '$size');
          }
        }
      });
    });

    testWidgets('a banner that opens nothing has no button and ignores taps', (
      tester,
    ) async {
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[banner(1, buttonText: 'Go')]),
      );

      expect(find.text('Go'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(HomeBannerCarousel),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Banner title 1'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(locationOf(tester).path, '/home');
      expect(find.byType(FeatureUnavailableScreen), findsNothing);
    });

    testWidgets('a web banner says it cannot open yet while no browser is '
        'wired', (tester) async {
      await start(
        tester,
        FakeHomeBannersRepository(<HomeBanner>[
          banner(
            1,
            linkType: BannerLinkType.url,
            linkValue: 'https://abra.example/offers',
            buttonText: 'Read more',
          ),
        ]),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Read more'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    });
  });

  group('web banners', () {
    Future<void> openWith(
      WidgetTester tester,
      String linkValue,
      Future<bool> Function(Uri url) opener,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [externalUrlOpenerProvider.overrideWithValue(opener)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openBannerLink(
                  context,
                  ref,
                  banner(1, linkType: BannerLinkType.url, linkValue: linkValue),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets('open the https address in the browser', (tester) async {
      final opened = <Uri>[];
      await openWith(tester, ' https://abra.example/offers ', (url) async {
        opened.add(url);
        return true;
      });
      expect(opened, [Uri.parse('https://abra.example/offers')]);
      expect(find.byType(FeatureUnavailableScreen), findsNothing);
    });

    testWidgets('ignore an address that is not https', (tester) async {
      final opened = <Uri>[];
      for (final bad in ['http://abra.example', 'javascript:alert(1)', '']) {
        await openWith(tester, bad, (url) async {
          opened.add(url);
          return true;
        });
      }
      expect(opened, isEmpty);
    });
  });

  test('the provider reloads when the language changes', () async {
    final app = TestApp();
    final repository = FakeHomeBannersRepository(<HomeBanner>[banner(1)]);
    final container = ProviderContainer(
      overrides: [
        appDependenciesProvider.overrideWithValue(app.dependencies),
        homeBannersRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(homeBannersProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(homeBannersProvider.future);
    expect(repository.calls, 1);

    await app.dependencies.localeController.selectLocale(const Locale('hi'));
    await container.read(homeBannersProvider.future);
    expect(repository.calls, 2);
  });
}

Future<FakeResponse> connectionErrorHandler(RecordedRequest request) async =>
    throw connectionError(request);
