import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '/app_state.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/sync_push_runner.dart';
import '/firebase_options.dart';
import 'push_foreground_local_notifications.dart';

bool _remoteMessageRequestsSync(RemoteMessage message) {
  final d = message.data;
  final module = (d['module'] ?? '').toString().toLowerCase().trim();
  if (module == 'sync') return true;
  final type = (d['type'] ?? '').toString().toLowerCase().trim();
  if (type == 'sync' || type == 'full_sync') return true;
  final action = (d['action'] ?? d['rdopro_action'] ?? '')
      .toString()
      .toLowerCase()
      .trim();
  if (action == 'sync' || action == 'full_sync') return true;
  return false;
}

/// Handler em isolate separado — precisa reinicializar Firebase, SQLite e prefs.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundSyncHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_remoteMessageRequestsSync(message)) {
    return;
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Push sync background: Firebase.init falhou: $e');
    }
    return;
  }
  try {
    await SQLiteManager.initialize();
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Push sync background: SQLite init falhou: $e');
    }
  }
  final app = FFAppState();
  try {
    await app.initializePersistedState();
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Push sync background: FFAppState init falhou: $e');
    }
    return;
  }
  if (app.UserToken.trim().isEmpty) {
    return;
  }
  try {
    await runFullSyncPipelineFromPush();
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Push sync background: pipeline erro: $e $st');
    }
  }
}

bool _listenersAttached = false;

/// Registra listeners FCM para disparar sync quando o [data] do push indicar.
/// Chame após [Firebase.initializeApp], uma vez (ex.: em [initPushDeviceRegistration]).
void attachPushSyncListeners() {
  if (_listenersAttached) {
    return;
  }
  _listenersAttached = true;

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (_remoteMessageRequestsSync(message)) {
      final token = FFAppState().UserToken.trim();
      if (token.isNotEmpty) {
        unawaited(runFullSyncPipelineFromPush());
      }
    }
    // Em foreground o FCM não exibe banner; notificações vindas do backend têm `notification` + `data`.
    unawaited(maybeShowForegroundNotificationFromRemoteMessage(message));
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (!_remoteMessageRequestsSync(message)) {
      return;
    }
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      return;
    }
    unawaited(runFullSyncPipelineFromPush());
  });

  unawaited(_handleInitialMessage());
}

Future<void> _handleInitialMessage() async {
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null && _remoteMessageRequestsSync(initial)) {
    final token = FFAppState().UserToken.trim();
    if (token.isNotEmpty) {
      await runFullSyncPipelineFromPush();
    }
  }
}
