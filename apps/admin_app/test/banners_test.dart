import 'dart:typed_data';

import 'package:admin_app/features/banners/admin_banners_api.dart';
import 'package:admin_app/features/banners/admin_banners_manage.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:admin_app/shell/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Finder navItem(String label) => find.descendant(
  of: find.byType(AdminShell),
  matching: find.widgetWithText(ListTile, label),
);

Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

Persona staffWith(Set<String> permissions) => Persona(
  name: 'Kavya Content',
  userType: 'STAFF',
  roleKey: 'CONTENT',
  permissions: permissions,
);

FakeBackend withBanner(Persona persona) {
  final backend = FakeBackend(persona);
  backend.add('banners', <String, Object?>{
    'title': 'Diwali sale',
    'subtitle': 'Up to 25% off',
    'buttonText': 'Book now',
    'linkType': 'OFFER',
    'linkValue': 'DIWALI25',
    'placement': 'HOME_TOP',
    'language': 'ALL',
    'startsAt': '2026-10-12T00:00:00.000',
    'endsAt': '2026-10-31T23:59:59.999',
    'sortOrder': 1,
    'isActive': true,
    'status': 'SCHEDULED',
    'imageUrl': null,
    'externalImageUrl': null,
  });
  return backend;
}

/// The header of a PNG image of [width] × [height] (enough to read its size).
Uint8List pngOf(int width, int height) {
  final bytes = ByteData(40)
    ..setUint32(0, 0x89504E47)
    ..setUint32(4, 0x0D0A1A0A)
    ..setUint32(8, 13)
    ..setUint32(12, 0x49484452)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes.buffer.asUint8List();
}

/// The number on the summary card labelled [label].
Finder statCard(String label, String count) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_StatCard',
    ),
  ),
  matching: find.text(count),
);

Future<TestAdmin> openBanners(WidgetTester tester, Persona persona) async {
  final app = TestAdmin.signedIn(withBanner(persona));
  await app.pump(tester);
  await open(tester, AdminRoutes.banners);
  return app;
}

void main() {
  group('banners: permissions', () {
    testWidgets('with banners.manage only: the page and the menu item, '
        'every action except Delete', (tester) async {
      await openBanners(
        tester,
        staffWith(const {PermissionKeys.bannersManage}),
      );

      expect(navItem('Banners'), findsOneWidget);
      expect(find.text('CONTENT'), findsOneWidget);
      expect(find.text('Diwali sale'), findsOneWidget);
      expect(find.text('12 Oct – 31 Oct 2026'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Upload image'), findsOneWidget);
      expect(find.byTooltip('Disable'), findsOneWidget);
      expect(find.byTooltip('Preview'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(find.widgetWithText(AbraButton, 'Add'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Export'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Import'), findsOneWidget);
    });

    testWidgets('banners.delete adds Delete, which asks first and removes '
        'the banner', (tester) async {
      final app = await openBanners(
        tester,
        staffWith(const {
          PermissionKeys.bannersManage,
          PermissionKeys.bannersDelete,
        }),
      );
      final id = app.backend.of('banners').single['id'];

      await tapOn(tester, find.byTooltip('Delete'));
      expect(find.text('Delete Diwali sale?'), findsOneWidget);
      await tapOn(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete'),
        ),
      );

      expect(app.requestsTo('admin/banners/$id', 'DELETE'), hasLength(1));
      expect(app.backend.of('banners'), isEmpty);
      expect(find.text('Banner deleted.'), findsOneWidget);
      expect(find.text('Diwali sale'), findsNothing);
    });

    testWidgets('without banners.manage the menu item is hidden and the page '
        'is not reachable', (tester) async {
      final app = await openBanners(
        tester,
        staffWith(const {
          PermissionKeys.tripsRead,
          PermissionKeys.bannersDelete,
        }),
      );

      expect(navItem('Banners'), findsNothing);
      expect(find.text('No access'), findsOneWidget);
      expect(
        app.adapter.requests.where((r) => r.path.startsWith('admin/')),
        isEmpty,
      );
    });
  });

  group('banners: editing', () {
    testWidgets('the summary cards follow a change made from the list', (
      tester,
    ) async {
      final app = await openBanners(
        tester,
        staffWith(const {PermissionKeys.bannersManage}),
      );
      final id = app.backend.of('banners').single['id'];
      // Like the backend: a disabled banner is Inactive.
      app.backend.overrides['POST admin/banners/$id/active'] = (request) {
        final record = app.backend.of('banners').single
          ..['isActive'] = false
          ..['status'] = 'INACTIVE';
        return FakeResponse.ok(record);
      };
      expect(statCard('Scheduled', '1'), findsOneWidget);
      expect(statCard('Inactive', '0'), findsOneWidget);

      await tapOn(tester, find.byTooltip('Disable'));
      await tapOn(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Disable'),
        ),
      );

      expect(statCard('Scheduled', '0'), findsOneWidget);
      expect(statCard('Inactive', '1'), findsOneWidget);
    });

    testWidgets('adding a banner with both images: Save creates it, then '
        'uploads each image', (tester) async {
      final app = await openBanners(
        tester,
        staffWith(const {PermissionKeys.bannersManage}),
      );
      final files = <(String, Uint8List)>[
        ('mobile.png', pngOf(1200, 525)),
        ('square.png', pngOf(800, 800)),
      ];
      pickBannerImage = () async => files.removeAt(0);
      addTearDown(() => pickBannerImage = () async => null);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Add'));
      expect(find.text('Mobile image'), findsOneWidget);
      expect(find.text('Desktop / tablet image (optional)'), findsOneWidget);
      expect(find.text('Recommended 1200 × 525 px (16:7).'), findsOneWidget);
      expect(find.text('Shown only when a link is set.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Monsoon offers',
      );
      await tester.pump();
      // The preview shows what is typed.
      expect(
        find.descendant(
          of: find.byType(BannerPreview),
          matching: find.text('Monsoon offers'),
        ),
        findsOneWidget,
      );

      await tapOn(
        tester,
        find.widgetWithText(AbraButton, 'Choose image').first,
      );
      await tapOn(tester, find.widgetWithText(AbraButton, 'Choose image'));
      expect(find.text('mobile.png · 1 KB. Uploaded when you save.'), findsOne);
      // A square desktop image is allowed, with a warning.
      expect(
        find.textContaining('800 × 800 px; 4:1 works best'),
        findsOneWidget,
      );
      expect(find.textContaining('16:7 works best'), findsNothing);
      expect(app.requestsTo('admin/banners', 'POST'), isEmpty);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));

      final body = app.requestsTo('admin/banners', 'POST').single.body! as Map;
      expect(body['title'], 'Monsoon offers');
      expect(body['linkType'], 'NONE');
      expect(body['placement'], 'HOME_TOP');
      expect(body['language'], 'ALL');
      expect(body['isActive'], isTrue);
      final created = app.backend.of('banners').last;
      final id = created['id'];
      expect(
        app.requestsTo('admin/banners/$id/image?variant=mobile', 'POST'),
        hasLength(1),
      );
      expect(
        app.requestsTo('admin/banners/$id/image?variant=desktop', 'POST'),
        hasLength(1),
      );
      expect(created['desktopImageUrl'], isNotNull);
      expect(find.text('Add banner'), findsNothing);
      // The new banner is listed with its desktop image marked.
      expect(find.text('Monsoon offers'), findsOneWidget);
      expect(find.text('Desktop'), findsOneWidget);
    });

    testWidgets('an image that fails to upload stays in the form with its '
        'reason; saving again retries only what is left', (tester) async {
      final app = await openBanners(
        tester,
        staffWith(const {PermissionKeys.bannersManage}),
      );
      final id = app.backend.of('banners').single['id'];
      final desktopPath = 'admin/banners/$id/image?variant=desktop';
      app.backend.overrides['POST $desktopPath'] = (_) =>
          FakeResponse.error(500, 'INTERNAL_ERROR');
      final files = <(String, Uint8List)>[
        ('mobile.png', pngOf(1200, 525)),
        ('wide.png', pngOf(1920, 480)),
      ];
      pickBannerImage = () async => files.removeAt(0);
      addTearDown(() => pickBannerImage = () async => null);

      await tapOn(tester, find.byTooltip('Edit'));
      await tapOn(
        tester,
        find.widgetWithText(AbraButton, 'Choose image').first,
      );
      await tapOn(tester, find.widgetWithText(AbraButton, 'Choose image'));
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));

      expect(app.requestsTo('admin/banners/$id', 'PUT'), hasLength(1));
      expect(
        find.textContaining('The banner is saved, but an image could not'),
        findsOneWidget,
      );
      expect(find.textContaining('Not uploaded:'), findsOneWidget);
      expect(find.text('wide.png · 1 KB. Uploaded when you save.'), findsOne);
      expect(find.text('Edit banner'), findsOneWidget);

      app.backend.overrides.remove('POST $desktopPath');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));

      expect(app.requestsTo('admin/banners/$id', 'PUT'), hasLength(2));
      expect(
        app.requestsTo('admin/banners/$id/image?variant=mobile', 'POST'),
        hasLength(1),
      );
      expect(app.requestsTo(desktopPath, 'POST'), hasLength(2));
      expect(find.text('Edit banner'), findsNothing);
      expect(app.backend.of('banners').single['desktopImageUrl'], isNotNull);
    });

    testWidgets('Upload image opens the image section; Remove deletes an '
        'uploaded image on Save', (tester) async {
      final backend = withBanner(
        staffWith(const {PermissionKeys.bannersManage}),
      );
      final banner = backend.of('banners').single
        ..['desktopImageUrl'] = 'https://cdn.example.com/wide.png';
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester);
      await open(tester, AdminRoutes.banners);

      await tapOn(tester, find.byTooltip('Upload image'));
      expect(find.text('Banner images'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Title'), findsNothing);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Remove'));
      expect(find.text('Removed when you save.'), findsOneWidget);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save'));

      expect(
        app.requestsTo(
          'admin/banners/${banner['id']}/image?variant=desktop',
          'DELETE',
        ),
        hasLength(1),
      );
      expect(app.requestsTo('admin/banners/${banner['id']}', 'PUT'), isEmpty);
      expect(banner['desktopImageUrl'], isNull);
    });

    testWidgets('link types the app does not handle yet say "coming soon"', (
      tester,
    ) async {
      await openBanners(
        tester,
        staffWith(const {PermissionKeys.bannersManage}),
      );
      await tapOn(tester, find.byTooltip('Edit'));

      // The banner links to an offer.
      expect(find.text('Offer (coming soon)'), findsOneWidget);
      expect(
        find.textContaining("Customers will see a 'coming soon' screen"),
        findsOneWidget,
      );
    });

    test('image sizes are read from PNG, JPG and WebP headers', () {
      expect(bannerImageSizeOf(pngOf(1200, 525)), (1200, 525));
      final jpeg = Uint8List.fromList(<int>[
        0xFF, 0xD8, // start
        0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0 segment of 4 bytes
        0xFF, 0xC0, 0x00, 0x11, 0x08, 0x02, 0x0D, 0x04, 0xB0, // SOF0
        0, 0, 0, 0, 0, 0, 0, 0,
      ]);
      expect(bannerImageSizeOf(jpeg), (1200, 525));
      final webp = Uint8List(30)
        ..setAll(0, 'RIFF'.codeUnits)
        ..setAll(8, 'WEBPVP8X'.codeUnits)
        ..setAll(24, <int>[0x7F, 0x07, 0x00, 0xDF, 0x01, 0x00]);
      expect(bannerImageSizeOf(webp), (1920, 480));
      expect(bannerImageSizeOf(Uint8List(8)), isNull);
      expect(BannerImageVariant.mobile.isFarFrom(1200, 525), isFalse);
      expect(BannerImageVariant.desktop.isFarFrom(1200, 525), isTrue);
    });

    test('start and end days become the whole days as ISO times', () {
      final body = bannerBody(<String, Object?>{
        'title': 'A',
        'startsAt': '2026-10-12',
        'endsAt': '2026-10-31',
      });
      expect(
        DateTime.parse(body['startsAt']! as String).toLocal(),
        DateTime(2026, 10, 12),
      );
      expect(
        DateTime.parse(body['endsAt']! as String).toLocal(),
        DateTime(2026, 10, 31, 23, 59, 59, 999),
      );
      expect(bannerBody(<String, Object?>{'endsAt': null})['endsAt'], isNull);
    });

    test('a relative image path is resolved below /api/v1', () {
      final app = TestAdmin(FakeBackend(Persona.superAdmin));
      final api = BannersApi(
        app.dependencies.apiClient,
        app.dependencies.config.apiV1Url,
      );
      expect(
        api.imageUriOf(<String, Object?>{
          'imageUrl': 'banners/b1/image?v=123',
        }).toString(),
        'http://localhost:4000/api/v1/banners/b1/image?v=123',
      );
      expect(
        api.imageUriOf(<String, Object?>{
          'imageUrl': 'https://cdn.example.com/b.png',
        }).toString(),
        'https://cdn.example.com/b.png',
      );
      expect(api.imageUriOf(<String, Object?>{'imageUrl': null}), isNull);
    });

    test('images over 3 MB or of another type are refused before upload', () {
      expect(bannerImageProblem('banner.webp', 1024), isNull);
      expect(
        bannerImageProblem('banner.gif', 1024)?.$1,
        'bannerUploadWrongType',
      );
      expect(
        bannerImageProblem('banner.jpg', 3 * 1024 * 1024 + 1)?.$1,
        'bannerUploadTooLarge',
      );
    });
  });
}
