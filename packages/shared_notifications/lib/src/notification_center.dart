import 'dart:async';

import 'package:flutter/widgets.dart';

import 'device_push.dart';
import 'live_notification_source.dart';
import 'notification_item.dart';
import 'notifications_repository.dart';

/// Everything an app needs to show notifications: the list, the unread count,
/// the live channel for an open app and the push registration for a closed
/// one. The server stores every notification first, so reconnecting or
/// reopening the app always shows what was missed.
class NotificationCenter extends ChangeNotifier with WidgetsBindingObserver {
  NotificationCenter({
    required NotificationsRepository repository,
    required LiveNotificationSource live,
    DevicePush? push,
  }) : _repository = repository,
       _live = live,
       _push = push;

  final NotificationsRepository _repository;
  final LiveNotificationSource _live;
  final DevicePush? _push;

  final List<NotificationItem> _items = <NotificationItem>[];
  final StreamController<NotificationItem> _arrivals =
      StreamController<NotificationItem>.broadcast();
  StreamSubscription<NotificationItem>? _liveSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<void>? _connectionSubscription;
  StreamSubscription<String>? _tapSubscription;
  final StreamController<String> _routeOpens =
      StreamController<String>.broadcast();
  var _unread = 0;
  var _loading = false;
  Object? _error;
  var _started = false;
  var _pushEnabled = false;
  var _permission = PushPermission.unsupported;
  var _loadedOnce = false;
  var _catchingUp = false;

  List<NotificationItem> get items =>
      List<NotificationItem>.unmodifiable(_items);
  int get unreadCount => _unread;
  bool get isLoading => _loading;
  Object? get error => _error;

  /// Whether this browser or phone is registered for push.
  bool get pushEnabled => _pushEnabled;

  /// Whether push is possible at all in this app.
  bool get pushAvailable => _push != null;

  /// What the person decided about notifications on this device. Drives the
  /// "turn on notifications" prompt and the "blocked" hint.
  PushPermission get pushPermission => _permission;

  /// A notification that has just arrived live, for a toast.
  Stream<NotificationItem> get arrivals => _arrivals.stream;

  /// The screen of a push notification the person tapped (phones only).
  Stream<String> get routeOpens => _routeOpens.stream;

  /// Starts after sign-in. Safe to call again.
  Future<void> start(Future<String?> Function() accessToken) async {
    if (_started) return;
    _started = true;
    _liveSubscription = _live.connect(accessToken).listen(_onArrival);
    if (_live case final ReconnectingLiveSource reconnecting) {
      // The channel came back after a drop: fetch what was sent meanwhile
      _connectionSubscription = reconnecting.connections.listen(
        (_) => unawaited(catchUp()),
      );
    }
    WidgetsFlutterBinding.ensureInitialized();
    WidgetsBinding.instance.addObserver(this);
    _tapSubscription = _push?.tappedRoutes.listen(
      _routeOpens.add,
      // Firebase is not set up on this build: nothing to open
      onError: (Object _) {},
    );
    unawaited(_startPush());
    await refresh();
  }

  /// Registers this device only when the person has already allowed it; the
  /// question itself is asked from a button (some browsers refuse to show it
  /// otherwise).
  Future<void> _startPush() async {
    final push = _push;
    if (push == null) return;
    _permission = await push.permission();
    notifyListeners();
    if (_permission == PushPermission.granted) await enablePush();
  }

  /// Back in the foreground: the app may have been asleep for a while.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(catchUp());
  }

  /// Fetches what the server stored while this app was not listening
  /// (offline, asleep, reconnecting) and announces what is new and unread
  /// exactly like a live arrival, so the screen can react the same way.
  Future<void> catchUp() async {
    if (!_started || !_loadedOnce || _catchingUp) return;
    _catchingUp = true;
    try {
      final page = await _repository.list();
      final count = await _repository.unreadCount();
      if (!_started) return;
      final known = <String>{for (final item in _items) item.id};
      final fresh = <NotificationItem>[
        for (final item in page.items)
          if (!item.read && !known.contains(item.id)) item,
      ];
      _items
        ..clear()
        ..addAll(page.items);
      _unread = count;
      notifyListeners();
      // Oldest first, so the newest is the one the person sees last
      for (final item in fresh.reversed) {
        _arrivals.add(item);
      }
    } on Object {
      // Offline: the next reconnect or return to the app tries again.
    } finally {
      _catchingUp = false;
    }
  }

  /// Stops at sign-out (call it while the session is still valid, so this
  /// device is removed from the person's push list).
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    final live = _liveSubscription;
    final tokens = _tokenSubscription;
    final connections = _connectionSubscription;
    final taps = _tapSubscription;
    _tapSubscription = null;
    if (taps != null) unawaited(taps.cancel());
    _liveSubscription = null;
    _tokenSubscription = null;
    _connectionSubscription = null;
    // Listening stops at once; waiting for the cancel to be confirmed adds nothing
    if (live != null) unawaited(live.cancel());
    if (tokens != null) unawaited(tokens.cancel());
    if (connections != null) unawaited(connections.cancel());
    _loadedOnce = false;
    await _live.disconnect();
    final push = _push;
    if (push != null) {
      final token = await push.disable();
      if (token != null) {
        try {
          await _repository.removeDevice(token);
        } on Object {
          // The session is already gone; the token was deleted on the device
          // and the server drops it on the next failed send.
        }
      }
    }
    _items.clear();
    _unread = 0;
    _pushEnabled = false;
    _permission = PushPermission.unsupported;
    notifyListeners();
  }

  /// Asks the person to allow push (call it from a button too: some browsers
  /// only show the question after a tap).
  Future<void> enablePush() async {
    final push = _push;
    if (push == null) return;
    final token = await push.enable();
    if (token == null) {
      // The person said no, or the browser cannot do push
      _permission = await push.permission();
      notifyListeners();
      return;
    }
    _permission = PushPermission.granted;
    try {
      await _repository.registerDevice(token, platform: push.platform);
      _pushEnabled = true;
      _tokenSubscription ??= push.tokenRefreshes.listen(
        (next) => unawaited(
          _repository.registerDevice(next, platform: push.platform),
        ),
      );
      notifyListeners();
    } on Object {
      // The server could not be reached; the next start tries again.
    }
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repository.list();
      final count = await _repository.unreadCount();
      _items
        ..clear()
        ..addAll(page.items);
      _unread = count;
      _loadedOnce = true;
    } on Object catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.read) return;
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index >= 0) _items[index] = item.asRead();
    if (_unread > 0) _unread -= 1;
    notifyListeners();
    try {
      _unread = await _repository.markRead(item.id);
    } on Object {
      // Kept as read here; the next refresh shows the server's truth.
    }
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].asRead();
    }
    _unread = 0;
    notifyListeners();
    try {
      await _repository.markAllRead();
    } on Object {
      // See markRead.
    }
  }

  void _onArrival(NotificationItem item) {
    if (_items.any((candidate) => candidate.id == item.id)) return;
    _items.insert(0, item);
    _unread += 1;
    _arrivals.add(item);
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started) WidgetsBinding.instance.removeObserver(this);
    unawaited(_liveSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_tapSubscription?.cancel());
    unawaited(_routeOpens.close());
    unawaited(_arrivals.close());
    super.dispose();
  }
}
