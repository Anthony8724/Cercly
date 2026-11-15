import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'fcm_promotion_message.dart';

abstract interface class FcmMessagingGateway {
  Future<bool> initialize();
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<void> setAutoInitEnabled(bool enabled);
  Future<String> register();
  Future<void> disableRegistration();
  Stream<String> get tokenRefreshes;
  Stream<FcmPromotionMessage> get foregroundMessages;
  Stream<FcmPromotionMessage> get openedMessages;
  Future<FcmPromotionMessage?> getInitialMessage();
}

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    // Notification payloads are displayed by the OS; no account/location
    // processing runs in this background isolate.
  }
}

class FirebaseMessagingGateway implements FcmMessagingGateway {
  FirebaseMessaging? _messaging;
  FirebaseMessaging get _instance => _messaging ??= FirebaseMessaging.instance;

  @override
  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
      _messaging = FirebaseMessaging.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _instance.requestPermission(
      alert: true,
      badge: false,
      sound: true,
      provisional: false,
    );
    return _allowed(settings.authorizationStatus);
  }

  @override
  Future<bool> hasPermission() async =>
      _allowed((await _instance.getNotificationSettings()).authorizationStatus);

  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      _instance.setAutoInitEnabled(enabled);

  bool _allowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  @override
  Future<String> register() async {
    final registered = Completer<String>();
    final subscription = _instance.onRegistered.listen(
      (installationId) {
        if (!registered.isCompleted) registered.complete(installationId);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!registered.isCompleted) {
          registered.completeError(error, stackTrace);
        }
      },
    );
    try {
      await _instance.register();
      return await registered.future.timeout(const Duration(seconds: 30));
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> disableRegistration() async {
    await _instance.setAutoInitEnabled(false);
    await _instance.unregister();
  }

  @override
  Stream<String> get tokenRefreshes => _instance.onRegistered;

  @override
  Stream<FcmPromotionMessage> get foregroundMessages => FirebaseMessaging
      .onMessage
      .map(_convert)
      .where((message) => message != null)
      .cast<FcmPromotionMessage>();

  @override
  Stream<FcmPromotionMessage> get openedMessages => FirebaseMessaging
      .onMessageOpenedApp
      .map(_convert)
      .where((message) => message != null)
      .cast<FcmPromotionMessage>();

  @override
  Future<FcmPromotionMessage?> getInitialMessage() async {
    final message = await _instance.getInitialMessage();
    return message == null ? null : _convert(message);
  }

  FcmPromotionMessage? _convert(RemoteMessage message) =>
      FcmPromotionMessage.parse(
        message.data,
        title: message.notification?.title,
        body: message.notification?.body,
      );
}
