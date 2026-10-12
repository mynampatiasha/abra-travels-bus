import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_notifications/shared_notifications.dart';

class _Tokens implements AuthTokenSource {
  @override
  Future<String?> accessToken() async => 'token';

  @override
  Future<bool> refreshAccessToken() async => false;

  @override
  Future<void> onSessionRejected() async {}
}

class _FakeLive implements LiveNotificationSource, ReconnectingLiveSource {
  // ignore: close_sinks
  final controller = StreamController<NotificationItem>.broadcast();
  // ignore: close_sinks
  final reconnects = StreamController<void>.broadcast();
  var disconnected = false;

  @override
  Stream<NotificationItem> connect(Future<String?> Function() accessToken) =>
      controller.stream;

  @override
  Stream<void> get connections => reconnects.stream;

  @override
  Future<void> disconnect() async => disconnected = true;
}

class _FakePush implements DevicePush {
  _FakePush({
    this.token = 'device-token-aaaaaaaaaaaaaaaaaaaa',
    PushPermission? state,
  }) : state =
           state ??
           (token == null ? PushPermission.notAsked : PushPermission.granted);

  final String? token;
  PushPermission state;
  var disabled = false;

  @override
  Future<PushPermission> permission() async => state;

  @override
  String get platform => 'ANDROID';

  // ignore: close_sinks
  final taps = StreamController<String>.broadcast();

  @override
  Stream<String> get tappedRoutes => taps.stream;

  @override
  Future<String?> enable() async => token;

  @override
  Future<String?> disable() async {
    disabled = true;
    return token;
  }

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();
}

NotificationItem _item(String id, {bool read = false}) => NotificationItem(
  id: id,
  type: 'onboarding.approved',
  title: 'Company approved',
  body: 'Alpha Lines has been approved.',
  data: const <String, String>{'route': '/onboarding/s1'},
  read: read,
  createdAt: DateTime(2026, 10, 7),
);

class _FakeRepository implements NotificationsRepository {
  final stored = <NotificationItem>[_item('1'), _item('2')];
  final registered = <String>[];
  final removed = <String>[];
  var unread = 2;

  @override
  Future<NotificationPage> list({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) async => NotificationPage(items: List.of(stored), total: stored.length);

  @override
  Future<int> unreadCount() async => unread;

  @override
  Future<int> markRead(String id) async => --unread;

  @override
  Future<void> markAllRead() async => unread = 0;

  @override
  Future<void> registerDevice(String token, {String platform = 'WEB'}) async =>
      registered.add(token);

  @override
  Future<void> removeDevice(String token) async => removed.add(token);
}

void main() {
  group('NotificationItem', () {
    test('reads the API shape, with string data and a route', () {
      final item = NotificationItem.fromJson(<String, Object?>{
        'id': 'n1',
        'type': 'onboarding.rejected',
        'title': 'Documents need fixing',
        'body': 'GST: blurred',
        'data': <String, Object?>{'route': '/onboarding/s1', 'n': 3},
        'read': false,
        'createdAt': '2026-10-07T10:00:00.000Z',
      });
      expect(item.route, '/onboarding/s1');
      expect(item.data['n'], '3');
      expect(item.read, isFalse);
      expect(item.asRead().read, isTrue);
    });
  });

  group('NotificationsRepository', () {
    test(
      'lists, counts, reads and registers devices against the API',
      () async {
        final adapter = FakeHttpAdapter((request) async {
          switch ('${request.options.method} ${request.path}') {
            case 'GET notifications':
              return FakeResponse(200, <String, Object?>{
                'success': true,
                'data': <Object?>[
                  <String, Object?>{
                    'id': 'n1',
                    'type': 'onboarding.approved',
                    'title': 'Company approved',
                    'body': 'ok',
                    'data': <String, Object?>{},
                    'read': false,
                    'createdAt': '2026-10-07T10:00:00.000Z',
                  },
                ],
                'meta': <String, Object?>{
                  'page': 1,
                  'pageSize': 20,
                  'total': 1,
                },
              });
            case 'GET notifications/unread-count':
              return FakeResponse.ok(<String, Object?>{'count': 4});
            case 'POST notifications/n1/read':
              return FakeResponse.ok(<String, Object?>{'count': 3});
            default:
              return FakeResponse.ok(<String, Object?>{});
          }
        });
        final client = ApiClient(
          config: AppConfig(
            environment: AppEnvironment.test,
            appKind: AppKind.admin,
            apiBaseUrl: Uri.parse('http://localhost:4000'),
          ),
          dio: Dio()..httpClientAdapter = adapter,
        )..attachTokenSource(_Tokens());
        final repository = NotificationsRepository(client);

        final page = await repository.list(unreadOnly: true);
        expect(page.items.single.title, 'Company approved');
        expect(page.total, 1);
        expect(
          adapter.requests.first.options.queryParameters['unread'],
          'true',
        );
        expect(await repository.unreadCount(), 4);
        expect(await repository.markRead('n1'), 3);
        await repository.registerDevice('device-token-aaaaaaaaaaaaaaaaaaaa');
        expect(adapter.requests.last.body, <String, Object?>{
          'token': 'device-token-aaaaaaaaaaaaaaaaaaaa',
          'platform': 'WEB',
        });
      },
    );
  });

  group('NotificationCenter', () {
    late _FakeRepository repository;
    late _FakeLive live;
    late _FakePush push;
    late NotificationCenter center;

    setUp(() {
      repository = _FakeRepository();
      live = _FakeLive();
      push = _FakePush();
      center = NotificationCenter(
        repository: repository,
        live: live,
        push: push,
      );
    });

    tearDown(() => center.dispose());

    test(
      'loads the list and the unread count and registers the device',
      () async {
        await center.start(() async => 'token');
        await pumpEventQueue();
        expect(center.items, hasLength(2));
        expect(center.unreadCount, 2);
        expect(repository.registered, ['device-token-aaaaaaaaaaaaaaaaaaaa']);
        expect(center.pushEnabled, isTrue);
      },
    );

    test(
      'a live arrival goes to the top, counts as unread and is announced',
      () async {
        await center.start(() async => 'token');
        final arrived = center.arrivals.first;
        live.controller.add(_item('3'));
        expect((await arrived).id, '3');
        expect(center.items.first.id, '3');
        expect(center.unreadCount, 3);
        // the same notification again (reconnect, or push and socket together) is ignored
        live.controller.add(_item('3'));
        await pumpEventQueue();
        expect(center.items, hasLength(3));
        expect(center.unreadCount, 3);
      },
    );

    test(
      'a person who has not decided yet is asked from a button, not at start',
      () async {
        final undecided = _FakePush(state: PushPermission.notAsked);
        final fresh = NotificationCenter(
          repository: repository,
          live: live,
          push: undecided,
        );
        addTearDown(fresh.dispose);
        await fresh.start(() async => 'token');
        await pumpEventQueue();
        expect(fresh.pushPermission, PushPermission.notAsked);
        expect(repository.registered, isEmpty);
        await fresh.enablePush();
        expect(fresh.pushPermission, PushPermission.granted);
        expect(repository.registered, ['device-token-aaaaaaaaaaaaaaaaaaaa']);
      },
    );

    test('a refusal is remembered so the app can explain it', () async {
      final refused = _FakePush(token: null, state: PushPermission.notAsked);
      final fresh = NotificationCenter(
        repository: repository,
        live: live,
        push: refused,
      );
      addTearDown(fresh.dispose);
      await fresh.start(() async => 'token');
      refused.state = PushPermission.denied;
      await fresh.enablePush();
      expect(fresh.pushPermission, PushPermission.denied);
      expect(fresh.pushEnabled, isFalse);
    });

    test(
      'catching up announces what was missed while the app was away',
      () async {
        await center.start(() async => 'token');
        await pumpEventQueue();
        final arrivals = <String>[];
        final subscription = center.arrivals.listen(
          (item) => arrivals.add(item.id),
        );
        addTearDown(subscription.cancel);
        // Sent while the socket was down: stored by the server, never delivered live
        repository.stored.insert(0, _item('9'));
        repository.unread = 3;
        live.reconnects.add(null);
        await pumpEventQueue();
        expect(arrivals, ['9']);
        expect(center.items.first.id, '9');
        expect(center.unreadCount, 3);
        // Nothing new: nothing is announced twice
        await center.catchUp();
        expect(arrivals, ['9']);
      },
    );

    test('reading one lowers the count; reading all clears it', () async {
      await center.start(() async => 'token');
      await center.markRead(center.items.first);
      expect(center.unreadCount, 1);
      expect(center.items.first.read, isTrue);
      await center.markAllRead();
      expect(center.unreadCount, 0);
      expect(center.items.every((item) => item.read), isTrue);
    });

    test('without push permission it still works', () async {
      final quiet = NotificationCenter(
        repository: repository,
        live: live,
        push: _FakePush(token: null),
      );
      addTearDown(quiet.dispose);
      await quiet.start(() async => 'token');
      await pumpEventQueue();
      expect(quiet.items, hasLength(2));
      expect(quiet.pushEnabled, isFalse);
      expect(repository.registered, isEmpty);
    });

    test(
      'stopping at sign-out removes this device and clears the list',
      () async {
        await center.start(() async => 'token');
        await pumpEventQueue();
        await center.stop();
        expect(live.disconnected, isTrue);
        expect(push.disabled, isTrue);
        expect(repository.removed, ['device-token-aaaaaaaaaaaaaaaaaaaa']);
        expect(center.items, isEmpty);
        expect(center.unreadCount, 0);
      },
    );
  });

  test('timeAgo speaks in words', () {
    final now = DateTime(2026, 10, 7, 12);
    expect(
      timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
      'just now',
    );
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      timeAgo(now.subtract(const Duration(hours: 3)), now: now),
      '3 h ago',
    );
    expect(timeAgo(now.subtract(const Duration(days: 2)), now: now), '2 d ago');
    expect(timeAgo(DateTime(2026, 9, 1), now: now), '01/09/2026');
  });
}
