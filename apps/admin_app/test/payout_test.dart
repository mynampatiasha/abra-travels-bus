// Screen test for "Payout modes and fees". Uses a fake server (no network) that answers
// with the same shapes as the backend (ids as `id`, operators as list rows).
import 'package:admin_app/features/payout/payout_cfg_admin_manage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_localization/shared_localization.dart';

class FakeServer {
  Map<String, dynamic>? settings;
  final List<Map<String, dynamic>> slabs = [
    {'id': 's48', 'hoursBefore': 48, 'refundPct': 100},
    {'id': 's24', 'hoursBefore': 24, 'refundPct': 75},
  ];
  final List<Map<String, dynamic>> removed = [];
  final List<Map<String, dynamic>> calls = [];
  String? refuse; // when set, PUT settings answers with this error

  final operators = [
    {
      'id': 'o1',
      'companyName': 'Kaveri Express Private Limited',
      'displayName': 'Kaveri Express',
      'status': 'ACTIVE',
      'payoutMode': 'MANUAL',
      'bank': {'accountLast4': '1234', 'ifsc': 'HDFC0001', 'status': 'PENDING'},
    },
    {
      'id': 'o2',
      'companyName': 'Godavari Travels',
      'displayName': null,
      'status': 'ACTIVE',
      'payoutMode': 'AUTO_SPLIT',
      'bank': {
        'accountLast4': '9999',
        'ifsc': 'SBIN0002',
        'status': 'VERIFIED',
      },
    },
    {
      'id': 'o3',
      'companyName': 'Waiting Operator',
      'displayName': null,
      'status': 'PENDING_APPROVAL',
      'payoutMode': 'MANUAL',
      'bank': null,
    },
  ];

  Future<dynamic> send(String method, String path, {Object? body}) async {
    calls.add({'m': method, 'p': path, 'b': body});
    if (method == 'GET' && path == '/admin/payout/settings') {
      return {'settings': settings};
    }
    if (method == 'PUT' && path == '/admin/payout/settings') {
      if (refuse != null) {
        // How the API client reports a refusal of the server
        throw AppException(
          ApiFailure(
            code: ApiErrorCodes.invalidStateTransition,
            message: refuse!,
            statusCode: 409,
          ),
        );
      }
      settings = Map<String, dynamic>.from(body as Map);
      return settings;
    }
    if (method == 'GET' && path == '/admin/payout/refund-slabs') {
      return List<Map<String, dynamic>>.from(slabs);
    }
    if (method == 'POST' && path == '/admin/payout/refund-slabs') {
      final b = Map<String, dynamic>.from(body as Map);
      slabs.add({'id': 'new${slabs.length}', ...b});
      return {};
    }
    if (method == 'DELETE' && path.startsWith('/admin/payout/refund-slabs/')) {
      final id = path.split('/').last;
      final s = slabs.firstWhere((e) => e['id'] == id);
      slabs.remove(s);
      removed.add(s);
      return {};
    }
    if (method == 'POST' && path.endsWith('/restore')) {
      final id = path.split('/')[path.split('/').length - 2];
      final s = removed.firstWhere((e) => e['id'] == id);
      removed.remove(s);
      slabs.add(s);
      return {};
    }
    if (method == 'GET' && path.startsWith('/admin/operators')) {
      return operators;
    }
    return {};
  }
}

Future<void> pump(
  WidgetTester t,
  FakeServer s, {
  bool canEdit = true,
  Size size = const Size(1200, 2400),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        AbraLocalizationsDelegate(
          config: AbraLocaleConfig(),
          source: MemoryTranslationSource(),
        ),
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: PayoutCfgAdminManageScreen(send: s.send, canEdit: canEdit),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows the page texts and leaves out operators waiting for approval',
    (t) async {
      await pump(t, FakeServer());
      expect(find.text('Payout modes and fees'), findsOneWidget);
      expect(
        find.text('How operators are paid, and what customers pay on top.'),
        findsOneWidget,
      );
      expect(find.text('Payout settings'), findsOneWidget);
      expect(find.text('Customer fees and coupons'), findsOneWidget);
      expect(find.text('Cancellation refund slabs'), findsOneWidget);
      expect(
        find.text('Operator payout modes and bank accounts'),
        findsOneWidget,
      );
      expect(find.text('Kaveri Express'), findsOneWidget);
      expect(find.text('Waiting Operator'), findsNothing);
      // nothing saved yet: a notice, not invented values
      expect(find.textContaining('Nothing is saved yet'), findsOneWidget);
    },
  );

  testWidgets('Super Admin can save; money goes to the server in paise', (
    t,
  ) async {
    final s = FakeServer();
    await pump(t, s);
    await t.enterText(find.byKey(const Key('f_gst')), '18');
    await t.enterText(find.byKey(const Key('f_fee')), '49');
    await t.enterText(find.byKey(const Key('f_min')), '1000');
    await t.tap(find.byKey(const Key('saveChanges')));
    await t.pumpAndSettle();
    expect(s.settings!['gstPct'], 18);
    expect(s.settings!['convenienceFee'], 4900);
    expect(s.settings!['minPayout'], 100000);
    expect(
      find.text('Saved. Applies to new bookings and settlements.'),
      findsOneWidget,
    );
  });

  testWidgets('bad GST and bad cycle are refused before sending', (t) async {
    final s = FakeServer();
    await pump(t, s);
    await t.enterText(find.byKey(const Key('f_gst')), '29');
    await t.enterText(find.byKey(const Key('f_cycle')), '0');
    await t.tap(find.byKey(const Key('saveChanges')));
    await t.pumpAndSettle();
    expect(find.text('GST must be 0 to 28'), findsOneWidget);
    expect(find.text('Cycle must be 1 day or more'), findsOneWidget);
    expect(s.calls.where((c) => c['m'] == 'PUT'), isEmpty);
  });

  testWidgets('shows the server message when Route cannot be switched off', (
    t,
  ) async {
    final s = FakeServer()
      ..refuse =
          'Route cannot be switched off: 2 operators are on Automatic payout.';
    await pump(t, s);
    await t.tap(find.byKey(const Key('routeSwitch')));
    await t.pump();
    await t.tap(find.byKey(const Key('saveChanges')));
    await t.pumpAndSettle();
    expect(find.textContaining('2 operators'), findsOneWidget);
  });

  testWidgets(
    'add slab, duplicate hours blocked, remove shows Undo and restores',
    (t) async {
      final s = FakeServer();
      await pump(t, s);
      await t.tap(find.byKey(const Key('addSlab')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('slabHours')), '24');
      await t.enterText(find.byKey(const Key('slabPct')), '60');
      await t.tap(find.byKey(const Key('slabSave')));
      await t.pumpAndSettle();
      expect(
        find.text('A slab for these hours already exists'),
        findsOneWidget,
      );
      await t.enterText(find.byKey(const Key('slabHours')), '12');
      await t.tap(find.byKey(const Key('slabSave')));
      await t.pumpAndSettle();
      expect(s.slabs.any((e) => e['hoursBefore'] == 12), isTrue);

      await t.tap(find.byKey(const Key('removeSlab_s24')));
      await t.pumpAndSettle();
      expect(s.slabs.any((e) => e['id'] == 's24'), isFalse);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(s.slabs.any((e) => e['id'] == 's24'), isTrue);
    },
  );

  testWidgets('warns when there is no 0-hour slab', (t) async {
    await pump(t, FakeServer());
    expect(find.textContaining('There is no 0-hour slab'), findsOneWidget);
  });

  testWidgets('Verify bank shows only for unverified banks', (t) async {
    await pump(t, FakeServer());
    expect(find.byKey(const Key('verifyBank_o1')), findsOneWidget);
    expect(find.byKey(const Key('verifyBank_o2')), findsNothing);
  });

  testWidgets('mode filter works', (t) async {
    await pump(t, FakeServer());
    await t.tap(find.byKey(const Key('modeFilter')));
    await t.pumpAndSettle();
    await t.tap(find.text('Automatic').last);
    await t.pumpAndSettle();
    expect(find.text('Godavari Travels'), findsOneWidget);
    expect(find.text('Kaveri Express'), findsNothing);
  });

  testWidgets('view-only users: fields disabled, buttons hidden', (t) async {
    await pump(t, FakeServer(), canEdit: false);
    expect(find.byKey(const Key('saveChanges')), findsNothing);
    expect(find.byKey(const Key('addSlab')), findsNothing);
    expect(find.byKey(const Key('changeMode_o1')), findsNothing);
    expect(find.byKey(const Key('verifyBank_o1')), findsNothing);
    final gst = t.widget<TextField>(find.byKey(const Key('f_gst')));
    expect(gst.enabled, isFalse);
    final route = t.widget<SwitchListTile>(
      find.byKey(const Key('routeSwitch')),
    );
    expect(route.onChanged, isNull);
  });

  testWidgets('phone width shows the list view without overflow', (t) async {
    await pump(t, FakeServer(), size: const Size(390, 2400));
    expect(t.takeException(), isNull);
    expect(find.text('Kaveri Express'), findsOneWidget);
  });

  testWidgets('demo list tools: one-line bank, Pending, search and Clear', (
    t,
  ) async {
    final s = FakeServer();
    s.operators.add({
      'id': 'o4',
      'companyName': 'No Bank Lines',
      'displayName': null,
      'status': 'ACTIVE',
      'payoutMode': 'MANUAL',
      'bank': null,
    });
    await pump(t, s);
    expect(find.text('XXXXXX1234 - HDFC0001'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('No bank account yet'), findsOneWidget);
    expect(find.byKey(const Key('verifyBank_o4')), findsNothing);
    expect(find.text('3 results'), findsOneWidget);

    await t.enterText(find.byKey(const Key('operatorSearch')), 'godavari');
    await t.pumpAndSettle();
    expect(find.text('Godavari Travels'), findsOneWidget);
    expect(find.text('Kaveri Express'), findsNothing);

    await t.tap(find.byKey(const Key('operatorsClear')));
    await t.pumpAndSettle();
    expect(find.text('Kaveri Express'), findsOneWidget);
    expect(find.text('3 results'), findsOneWidget);
  });
}
