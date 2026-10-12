import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Where this browser or phone stands on showing notifications.
enum PushPermission {
  /// The browser or phone cannot do push.
  unsupported,

  /// The person has not been asked yet.
  notAsked,

  /// Allowed: the token can be registered.
  granted,

  /// Refused. Only the person can change this, in the browser or phone settings.
  denied,
}

/// Push messages that arrive when the app is closed. The app asks the person
/// once; the token it gets is what the server sends to.
abstract class DevicePush {
  /// What the person has decided, without asking again.
  Future<PushPermission> permission();

  /// Where the token is registered from: WEB, ANDROID or IOS.
  String get platform;

  /// The screen named by a notification the person tapped while the app was in
  /// the background or closed (the system showed it; the tap opens the app).
  /// Empty on the web, where the service worker handles the tap.
  Stream<String> get tappedRoutes;

  /// Asks for permission and returns this device's token, or null when the
  /// person said no or the browser cannot do push.
  Future<String?> enable();

  /// Forgets this device (sign-out). Returns the token that was removed.
  Future<String?> disable();

  /// A new token, when the browser or phone replaces the old one.
  Stream<String> get tokenRefreshes;
}

/// The public identifiers of the Abra Travels Firebase project. They are not
/// secrets (every web app ships them); the server's service account is.
abstract final class AbraFirebaseConfig {
  static const options = FirebaseOptions(
    apiKey: 'AIzaSyAR7ot7EBikOWOxEPPFEntqiuL3bsuZavI',
    appId: '1:626328346112:web:7a2e5c1e217607a25482e5',
    messagingSenderId: '626328346112',
    projectId: 'abra-travels',
    authDomain: 'abra-travels.firebaseapp.com',
    storageBucket: 'abra-travels.firebasestorage.app',
  );

  /// The Web Push certificate (VAPID public key) of the project.
  static const vapidKey =
      'BPZ2Voyr7V1RNKE41hXL6u3fvaYetvzB5cHsT6KdobjP5BJlKLv4pPKEMystw4eLo4nqaPSiRm66QdHoM9L46tM';
}

/// Firebase Cloud Messaging. On the web it needs `web/firebase-messaging-sw.js`
/// next to `index.html`, which shows the message while the app is closed.
class FirebaseDevicePush implements DevicePush {
  FirebaseDevicePush({
    this.options = AbraFirebaseConfig.options,
    this.vapidKey = AbraFirebaseConfig.vapidKey,
  });

  final FirebaseOptions options;
  final String vapidKey;
  String? _token;

  @override
  String get platform => kIsWeb
      ? 'WEB'
      : (defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID');

  /// On the web the identifiers above are used. On Android and iOS Firebase
  /// reads the project's own file (`google-services.json`,
  /// `GoogleService-Info.plist`) that is added to the app when it is built.
  Future<FirebaseMessaging> _messaging() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: kIsWeb ? options : null);
    }
    return FirebaseMessaging.instance;
  }

  @override
  Stream<String> get tappedRoutes async* {
    if (kIsWeb) return;
    final messaging = await _messaging();
    final opening = await messaging.getInitialMessage();
    final first = opening?.data['route'] as String?;
    if (first != null) yield first;
    await for (final message in FirebaseMessaging.onMessageOpenedApp) {
      final route = message.data['route'] as String?;
      if (route != null) yield route;
    }
  }

  @override
  Future<PushPermission> permission() async {
    try {
      final messaging = await _messaging();
      final settings = await messaging.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notAsked,
      };
    } on Object {
      return PushPermission.unsupported;
    }
  }

  @override
  Future<String?> enable() async {
    try {
      final messaging = await _messaging();
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return null;
      }
      _token = await messaging.getToken(vapidKey: kIsWeb ? vapidKey : null);
      return _token;
    } on Object {
      // Browser without push support, blocked service worker, offline...
      return null;
    }
  }

  @override
  Future<String?> disable() async {
    final token = _token;
    _token = null;
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseMessaging.instance.deleteToken();
      }
    } on Object {
      // Nothing to forget.
    }
    return token;
  }

  @override
  Stream<String> get tokenRefreshes async* {
    final messaging = await _messaging();
    yield* messaging.onTokenRefresh;
  }
}
