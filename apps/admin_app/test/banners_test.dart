import 'dart:typed_data';

import 'package:admin_app/features/banners/admin_banners_api.dart';
import 'package:admin_app/features/banners/admin_banners_manage.dart';
import 'package:admin_app/routing/admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_ui/shared_ui.dart';

import 'support/test_admin.dart';

Finder navItem(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_SideNavigation',
  ),
  matching: find.text(label),
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

/// The permissions of someone who may open the page and change things.
const manage = {PermissionKeys.bannersRead, PermissionKeys.bannersManage};

FakeBackend withBanner(Persona persona) {
  final backend = FakeBackend(persona);
  backend.add('banners', <String, Object?>{
    'title': 'Diwali sale',
    'subtitle': 'Up to 25% off',
    'buttonText': 'View offer',
    'linkType': 'OFFER',
    'linkValue': 'DIWALI25',
    'placement': 'HOME_TOP',
    'language': 'ALL',
    'colourStyle': 'NAVY_BLUE',
    'audience': 'ALL',
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

Finder inDialog(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

/// A tall screen, so the whole form fits and sits beside its preview.
const tall = Size(1600, 1800);

Future<TestAdmin> openBanners(
  WidgetTester tester,
  Persona persona, {
  Size size = const Size(1440, 900),
}) async {
  final app = TestAdmin.signedIn(withBanner(persona));
  await app.pump(tester, size: size);
  await open(tester, AdminRoutes.banners);
  return app;
}

void main() {
  group('banners: permissions', () {
    testWidgets('with banners.read only: the page and the menu item, the '
        'demo columns, and no buttons', (tester) async {
      await openBanners(tester, staffWith(const {PermissionKeys.bannersRead}));

      expect(navItem('Banners'), findsOneWidget);
      expect(find.text('Diwali sale'), findsOneWidget);
      expect(find.text('Up to 25% off'), findsOneWidget);
      for (final column in const [
        'Banner',
        'Status',
        'Runs',
        'Shown to',
        'Opens',
        'Order',
      ]) {
        expect(find.text(column), findsWidgets);
      }
      expect(find.text('12 Oct 2026 to 31 Oct 2026'), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Offer DIWALI25'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'New banner'), findsNothing);
      expect(find.widgetWithText(AbraButton, 'Export'), findsNothing);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Show earlier'), findsNothing);
    });

    testWidgets('banners.manage adds New banner, Edit, Unpublish, Duplicate, '
        'Archive and the order arrows, but not Delete', (tester) async {
      await openBanners(tester, staffWith(manage));

      expect(find.widgetWithText(AbraButton, 'New banner'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Unpublish'), findsOneWidget);
      expect(find.byTooltip('Duplicate'), findsOneWidget);
      expect(find.byTooltip('Archive'), findsOneWidget);
      expect(find.byTooltip('Show earlier'), findsOneWidget);
      expect(find.byTooltip('Show later'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
    });

    testWidgets('banners.delete adds Delete, which asks first, removes the '
        'banner and offers Undo', (tester) async {
      final app = await openBanners(
        tester,
        staffWith({...manage, PermissionKeys.bannersDelete}),
      );
      final id = app.backend.of('banners').single['id'];
      app.backend.overrides['POST admin/banners/$id/restore'] = (_) =>
          FakeResponse.ok(<String, Object?>{'id': id, 'deleted': false});

      await tapOn(tester, find.byTooltip('Delete'));
      expect(find.text('Delete Diwali sale?'), findsOneWidget);
      expect(
        find.text(
          'This removes it from every list. You can undo for a few '
          'seconds.',
        ),
        findsOneWidget,
      );
      await tapOn(tester, inDialog(find.text('Delete')));

      expect(app.requestsTo('admin/banners/$id', 'DELETE'), hasLength(1));
      expect(app.backend.of('banners'), isEmpty);
      expect(find.text('Diwali sale deleted.'), findsOneWidget);
      expect(find.text('Diwali sale'), findsNothing);

      await tapOn(tester, find.text('Undo'));
      expect(app.requestsTo('admin/banners/$id/restore', 'POST'), hasLength(1));
    });

    testWidgets('without banners.read the menu item is hidden and the page '
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

    testWidgets('Analytics tab shows built in Phase 7 message', (
      tester,
    ) async {
      await openBanners(tester, staffWith(manage));
      expect(find.text('All banners'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      await tapOn(tester, find.text('Analytics'));
      expect(
        find.text('Not connected yet - built in Phase 7'),
        findsOneWidget,
      );
      expect(
        find.text('impressions and clicks are not counted yet'),
        findsOneWidget,
      );
    });
  });

  group('banners: buttons of a row', () {
    testWidgets('Unpublish: no question asked, and the summary cards follow', (
      tester,
    ) async {
      final app = await openBanners(tester, staffWith(manage));
      final id = app.backend.of('banners').single['id'];
      // Like the backend: an unpublished banner is a Draft.
      app.backend.overrides['POST admin/banners/$id/active'] = (request) {
        final record = app.backend.of('banners').single
          ..['isActive'] = false
          ..['status'] = 'INACTIVE';
        return FakeResponse.ok(record);
      };
      expect(find.text('Scheduled'), findsWidgets);

      await tapOn(tester, find.byTooltip('Unpublish'));

      final body =
          app.requestsTo('admin/banners/$id/active', 'POST').single.body!
              as Map;
      expect(body['active'], isFalse);
      expect(find.text('Unpublished.'), findsOneWidget);
      expect(find.text('Draft'), findsWidgets);
      // A draft offers Publish instead
      expect(find.byTooltip('Publish'), findsOneWidget);
    });

    testWidgets('Duplicate makes a draft copy', (tester) async {
      final app = await openBanners(tester, staffWith(manage));
      final id = app.backend.of('banners').single['id'];
      app.backend.overrides['POST admin/banners/$id/duplicate'] = (_) {
        final copy = app.backend.add('banners', <String, Object?>{
          ...app.backend.of('banners').single,
          'title': 'Diwali sale (copy)',
          'isActive': false,
          'status': 'INACTIVE',
        });
        return FakeResponse.ok(copy);
      };

      await tapOn(tester, find.byTooltip('Duplicate'));

      expect(
        app.requestsTo('admin/banners/$id/duplicate', 'POST'),
        hasLength(1),
      );
      expect(find.text('Duplicated as a draft.'), findsOneWidget);
      expect(find.text('Diwali sale (copy)'), findsOneWidget);
    });

    testWidgets('Archive puts the banner away, and Undo brings it back', (
      tester,
    ) async {
      final app = await openBanners(tester, staffWith(manage));
      final id = app.backend.of('banners').single['id'];
      app.backend.overrides['POST admin/banners/$id/archive'] = (_) {
        final record = app.backend.of('banners').single
          ..['isActive'] = false
          ..['status'] = 'ARCHIVED';
        return FakeResponse.ok(record);
      };
      app.backend.overrides['POST admin/banners/$id/unarchive'] = (_) {
        final record = app.backend.of('banners').single
          ..['status'] = 'INACTIVE';
        return FakeResponse.ok(record);
      };

      await tapOn(tester, find.byTooltip('Archive'));

      expect(app.requestsTo('admin/banners/$id/archive', 'POST'), hasLength(1));
      expect(find.text('Archived.'), findsOneWidget);
      expect(find.text('Archived'), findsWidgets);
      // An archived banner can only be put back (or duplicated), not edited
      expect(find.byTooltip('Edit'), findsNothing);
      expect(find.byTooltip('Put back as draft'), findsOneWidget);

      await tapOn(tester, find.text('Undo'));
      expect(
        app.requestsTo('admin/banners/$id/unarchive', 'POST'),
        hasLength(1),
      );
      expect(find.text('Draft'), findsWidgets);
    });

    testWidgets('the order arrows move the banner one place', (tester) async {
      final app = await openBanners(tester, staffWith(manage));
      final id = app.backend.of('banners').single['id'];
      app.backend.overrides['PATCH admin/banners/order'] = (_) =>
          FakeResponse.ok(<Object?>[]);

      await tapOn(tester, find.byTooltip('Show earlier'));
      await tapOn(tester, find.byTooltip('Show later'));

      final moves = app.requestsTo('admin/banners/order', 'PATCH');
      expect(moves, hasLength(2));
      expect((moves.first.body! as Map)['id'], id);
      expect((moves.first.body! as Map)['direction'], 'up');
      expect((moves.last.body! as Map)['direction'], 'down');
    });
  });

  group('banners: the form', () {
    testWidgets('New banner has the demo fields, pictures and preview; Save '
        'draft keeps it unpublished', (tester) async {
      final app = await openBanners(tester, staffWith(manage), size: tall);

      await tapOn(tester, find.widgetWithText(AbraButton, 'New banner'));
      for (final label in const [
        'Title',
        'Subtitle',
        'Colour style',
        'Opens',
        'Offer code',
        'Shown to',
        'Starts',
        'Ends',
        'Order (higher shows first)',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Pictures'), findsOneWidget);
      expect(find.text('Desktop (1920 x 600)'), findsOneWidget);
      expect(find.text('Phone (800 x 600)'), findsOneWidget);
      expect(
        find.text('JPG, PNG or WebP, up to 1 MB. Checked on the server too.'),
        findsOneWidget,
      );
      expect(find.text('Customer app home'), findsOneWidget);
      expect(find.text('Preview as customers see it'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Save draft'), findsOneWidget);
      expect(find.widgetWithText(AbraButton, 'Publish'), findsOneWidget);

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

      await tapOn(tester, find.widgetWithText(AbraButton, 'Save draft'));

      final body = app.requestsTo('admin/banners', 'POST').single.body! as Map;
      expect(body['title'], 'Monsoon offers');
      expect(body['colourStyle'], 'NAVY_BLUE');
      expect(body['audience'], 'ALL');
      expect(body['linkType'], 'NONE'); // an offer without a code
      expect(body['placement'], 'HOME_TOP');
      expect(body['language'], 'ALL');
      expect(body['isActive'], isFalse);
      expect(find.text('Draft saved.'), findsOneWidget);
      expect(find.text('Monsoon offers'), findsOneWidget);
    });

    testWidgets('Publish with an offer code opens that offer', (tester) async {
      final app = await openBanners(tester, staffWith(manage));

      await tapOn(tester, find.widgetWithText(AbraButton, 'New banner'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Weekend offer',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Offer code'),
        'ABRA100',
      );
      await tester.pump();
      // The preview then shows the button of an offer.
      expect(
        find.descendant(
          of: find.byType(BannerPreview),
          matching: find.text('View offer'),
        ),
        findsOneWidget,
      );
      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));

      final body = app.requestsTo('admin/banners', 'POST').single.body! as Map;
      expect(body['linkType'], 'OFFER');
      expect(body['linkValue'], 'ABRA100');
      expect(body['buttonText'], 'View offer');
      expect(body['isActive'], isTrue);
      expect(find.text('Published.'), findsOneWidget);
    });

    testWidgets('only the field of the chosen kind of link is shown', (
      tester,
    ) async {
      await openBanners(tester, staffWith(manage));
      await tapOn(tester, find.byTooltip('Edit'));

      // The banner opens an offer.
      expect(find.widgetWithText(TextFormField, 'Offer code'), findsOneWidget);
      expect(find.text('Web address (https://)'), findsNothing);

      await tapOn(
        tester,
        find.ancestor(
          of: find.text('Opens'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tapOn(tester, find.text('A web link').last);

      expect(find.widgetWithText(TextFormField, 'Offer code'), findsNothing);
      expect(find.text('Web address (https://)'), findsOneWidget);
    });

    testWidgets('both pictures: Publish creates the banner, then uploads each '
        'picture', (tester) async {
      final app = await openBanners(tester, staffWith(manage), size: tall);
      // Desktop first, then phone, as in the demo
      final files = <(String, Uint8List)>[
        ('wide.png', pngOf(1920, 600)),
        ('square.png', pngOf(800, 800)),
      ];
      pickBannerImage = () async => files.removeAt(0);
      addTearDown(() => pickBannerImage = () async => null);

      await tapOn(tester, find.widgetWithText(AbraButton, 'New banner'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Monsoon offers',
      );
      await tapOn(
        tester,
        find.widgetWithText(AbraButton, 'Choose image').first,
      );
      await tapOn(tester, find.widgetWithText(AbraButton, 'Choose image'));
      expect(find.text('wide.png · 1 KB. Uploaded when you save.'), findsOne);
      // A square phone picture is allowed, with a warning.
      expect(
        find.textContaining('800 × 800 px; 4:3 works best'),
        findsOneWidget,
      );
      expect(app.requestsTo('admin/banners', 'POST'), isEmpty);

      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));

      final created = app.backend.of('banners').last;
      final id = created['id'];
      expect(
        app.requestsTo('admin/banners/$id/image?variant=desktop', 'POST'),
        hasLength(1),
      );
      expect(
        app.requestsTo('admin/banners/$id/image?variant=mobile', 'POST'),
        hasLength(1),
      );
      expect(find.text('New banner'), findsOneWidget); // only the button
      expect(find.text('Monsoon offers'), findsOneWidget);
    });

    testWidgets('a picture that fails to upload stays in the form with its '
        'reason; saving again retries only what is left', (tester) async {
      final app = await openBanners(tester, staffWith(manage), size: tall);
      final id = app.backend.of('banners').single['id'];
      final desktopPath = 'admin/banners/$id/image?variant=desktop';
      app.backend.overrides['POST $desktopPath'] = (_) =>
          FakeResponse.error(500, 'INTERNAL_ERROR');
      final files = <(String, Uint8List)>[
        ('wide.png', pngOf(1920, 600)),
        ('phone.png', pngOf(800, 600)),
      ];
      pickBannerImage = () async => files.removeAt(0);
      addTearDown(() => pickBannerImage = () async => null);

      await tapOn(tester, find.byTooltip('Edit'));
      await tapOn(
        tester,
        find.widgetWithText(AbraButton, 'Choose image').first,
      );
      await tapOn(tester, find.widgetWithText(AbraButton, 'Choose image'));
      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));

      expect(app.requestsTo('admin/banners/$id', 'PUT'), hasLength(1));
      expect(
        find.textContaining('The banner is saved, but an image could not'),
        findsOneWidget,
      );
      expect(find.textContaining('Not uploaded:'), findsOneWidget);
      expect(find.text('wide.png · 1 KB. Uploaded when you save.'), findsOne);
      expect(find.text('Edit banner'), findsOneWidget);

      app.backend.overrides.remove('POST $desktopPath');
      await tapOn(tester, find.widgetWithText(AbraButton, 'Publish'));

      expect(app.requestsTo('admin/banners/$id', 'PUT'), hasLength(2));
      expect(
        app.requestsTo('admin/banners/$id/image?variant=mobile', 'POST'),
        hasLength(1),
      );
      expect(app.requestsTo(desktopPath, 'POST'), hasLength(2));
      expect(find.text('Edit banner'), findsNothing);
    });

    testWidgets('Remove deletes an uploaded picture when the banner is saved', (
      tester,
    ) async {
      final backend = withBanner(staffWith(manage));
      final banner = backend.of('banners').single
        ..['desktopImageUrl'] = 'https://cdn.example.com/wide.png';
      final app = TestAdmin.signedIn(backend);
      await app.pump(tester, size: tall);
      await open(tester, AdminRoutes.banners);

      await tapOn(tester, find.byTooltip('Edit'));
      await tapOn(tester, find.widgetWithText(AbraButton, 'Remove'));
      expect(find.text('Removed when you save.'), findsOneWidget);
      await tapOn(tester, find.widgetWithText(AbraButton, 'Save draft'));

      expect(
        app.requestsTo(
          'admin/banners/${banner['id']}/image?variant=desktop',
          'DELETE',
        ),
        hasLength(1),
      );
      expect(
        app.requestsTo('admin/banners/${banner['id']}', 'PUT'),
        hasLength(1),
      );
      expect(banner['desktopImageUrl'], isNull);
    });
  });

  group('banners: helpers', () {
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
      // The pictures of the demo: phone 800 x 600, desktop 1920 x 600
      expect(BannerImageVariant.mobile.isFarFrom(800, 600), isFalse);
      expect(BannerImageVariant.desktop.isFarFrom(1920, 600), isFalse);
      expect(BannerImageVariant.desktop.isFarFrom(800, 600), isTrue);
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

    test('pictures over 1 MB or of another type are refused before upload', () {
      expect(bannerImageProblem('banner.webp', 1024), isNull);
      expect(
        bannerImageProblem('banner.gif', 1024)?.$1,
        'bannerUploadWrongType',
      );
      expect(
        bannerImageProblem('banner.jpg', 1024 * 1024 + 1)?.$1,
        'bannerUploadTooLarge',
      );
      expect(bannerImageProblem('banner.jpg', 1024 * 1024), isNull);
    });
  });
}
