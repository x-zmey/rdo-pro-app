import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '/app_state.dart';
import '/backend/api_requests/api_calls.dart';
import '/firebase_options.dart';
import 'push_foreground_local_notifications.dart';
import 'push_sync_on_remote_message.dart';

const String _kInstallationIdKey = 'ff_push_installation_id';

bool _firebaseInitialized = false;
bool _listenersAttached = false;

String _pushPlatformForApi() {
  if (kIsWeb) {
    return 'web';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    default:
      return 'android';
  }
}

Future<String> _installationId() async {
  final prefs = FFAppState().prefs;
  var id = prefs.getString(_kInstallationIdKey);
  if (id == null || id.isEmpty) {
    id = const Uuid().v4();
    await prefs.setString(_kInstallationIdKey, id);
  }
  return id;
}

/// Inicializa Firebase + FCM e registra o token em [POST /api/notificacoes/dispositivo].
Future<void> initPushDeviceRegistration() async {
  if (_firebaseInitialized) {
    await syncPushDeviceToApi();
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firebase init falhou ($e). Use `flutterfire configure` e google-services. $st');
    }
    return;
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundSyncHandler);
  }

  await initForegroundLocalNotifications();
  attachPushSyncListeners();

  final messaging = FirebaseMessaging.instance;

  if (!kIsWeb) {
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  if (!_listenersAttached) {
    _listenersAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(syncPushDeviceToApi());
    });
  }

  await syncPushDeviceToApi();
}

/// Atualiza `user_devices` com o token FCM atual (mesmo projeto Firebase do servidor).
Future<void> syncPushDeviceToApi() async {
  if (!_firebaseInitialized) {
    return;
  }

  final authToken = FFAppState().UserToken.trim();
  if (authToken.isEmpty) {
    return;
  }

  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null || fcmToken.isEmpty) {
    return;
  }

  final installId = await _installationId();

  await NotificacaoRegistrarDispositivoCall.call(
    token: authToken,
    deviceId: installId,
    platform: _pushPlatformForApi(),
    deviceToken: fcmToken,
  );
}

Future<void> onLogoutPushCleanup() async {
  if (!_firebaseInitialized) {
    return;
  }
  try {
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {}
}
