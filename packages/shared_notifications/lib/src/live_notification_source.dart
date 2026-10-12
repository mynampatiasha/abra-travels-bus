import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import 'notification_item.dart';

/// The channel that tells an open app about a new notification at once.
abstract class LiveNotificationSource {
  /// New notifications as they arrive. Connects with the current access token
  /// and keeps reconnecting (with a fresh token) until [disconnect].
  Stream<NotificationItem> connect(Future<String?> Function() accessToken);

  Future<void> disconnect();
}

/// A live channel that can say when it is (re)established. Anything that arrived while it was
/// down was not delivered live, so the app fetches it from the server.
abstract interface class ReconnectingLiveSource {
  Stream<void> get connections;
}

/// Socket.IO to the API. It carries only notifications for the signed-in
/// person; the server accepts a connection only with a valid access token.
class SocketLiveNotificationSource
    implements LiveNotificationSource, ReconnectingLiveSource {
  SocketLiveNotificationSource(this._serverOrigin);

  final String _serverOrigin;
  io.Socket? _socket;
  StreamController<NotificationItem>? _controller;
  final StreamController<void> _connections =
      StreamController<void>.broadcast();
  Timer? _retry;
  var _attempt = 0;
  var _stopped = true;

  @override
  Stream<NotificationItem> connect(Future<String?> Function() accessToken) {
    _stopped = false;
    // Closed in disconnect()
    // ignore: close_sinks
    final controller = StreamController<NotificationItem>.broadcast();
    _controller = controller;
    unawaited(_open(accessToken));
    return controller.stream;
  }

  Future<void> _open(Future<String?> Function() accessToken) async {
    if (_stopped) return;
    final token = await accessToken();
    if (_stopped) return;
    if (token == null) {
      _scheduleRetry(accessToken);
      return;
    }
    _socket?.dispose();
    final socket = io.io(
      _serverOrigin,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .setAuth(<String, Object?>{'token': token})
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );
    _socket = socket;
    socket
      ..on('ready', (_) {
        _attempt = 0;
        _connections.add(null);
      })
      ..on('notification', (Object? payload) {
        if (payload is Map) {
          _controller?.add(
            NotificationItem.fromJson(<String, Object?>{
              ...Map<String, Object?>.from(payload),
              'read': false,
            }),
          );
        }
      })
      // An expired token or a lost connection: try again with the current token
      ..on('unauthorized', (_) => _scheduleRetry(accessToken))
      ..on('disconnect', (_) => _scheduleRetry(accessToken))
      ..on('connect_error', (_) => _scheduleRetry(accessToken))
      ..connect();
  }

  void _scheduleRetry(Future<String?> Function() accessToken) {
    if (_stopped || (_retry?.isActive ?? false)) return;
    _attempt += 1;
    final seconds = _attempt < 3 ? 2 * _attempt : (_attempt < 6 ? 10 : 30);
    _retry = Timer(
      Duration(seconds: seconds),
      () => unawaited(_open(accessToken)),
    );
  }

  @override
  Stream<void> get connections => _connections.stream;

  @override
  Future<void> disconnect() async {
    _stopped = true;
    _retry?.cancel();
    _socket?.dispose();
    _socket = null;
    await _controller?.close();
    _controller = null;
  }
}
