import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Canal Android para avisos gerais (FCM não mostra banner em foreground sem isso).
const String _kAndroidChannelId = 'rdopro_default';
const String _kAndroidChannelName = 'Notificações';

final FlutterLocalNotificationsPlugin _foregroundNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _foregroundNotificationsInitialized = false;

/// Configura canal + permissões e deve ser chamado após [Firebase.initializeApp].
Future<void> initForegroundLocalNotifications() async {
  if (_foregroundNotificationsInitialized || kIsWeb) {
    return;
  }

  await _foregroundNotificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    ),
  );

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final android = _foregroundNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kAndroidChannelId,
        _kAndroidChannelName,
        description: 'Alertas do RDO Pro',
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();
  }

  _foregroundNotificationsInitialized = true;
}

/// Com app em primeiro plano, o sistema não mostra o banner da seção `notification` do FCM.
/// Esta função exibe uma notificação local com o mesmo título/corpo.
Future<void> maybeShowForegroundNotificationFromRemoteMessage(
  RemoteMessage message,
) async {
  if (!_foregroundNotificationsInitialized || kIsWeb) {
    return;
  }

  final n = message.notification;
  String title = (n?.title ?? '').trim();
  String body = (n?.body ?? '').trim();

  if (title.isEmpty && body.isEmpty) {
    title = (message.data['title'] ?? '').toString().trim();
    body = (message.data['message'] ?? message.data['body'] ?? '')
        .toString()
        .trim();
  }

  if (title.isEmpty && body.isEmpty) {
    return;
  }

  final rawId = message.data['notification_id'] ?? '';
  final parsed = int.tryParse(rawId.toString());
  final notificationId = (parsed ?? message.hashCode).abs() % 2147483647;

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _kAndroidChannelId,
      _kAndroidChannelName,
      channelDescription: 'Alertas do RDO Pro',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  await _foregroundNotificationsPlugin.show(
    id: notificationId,
    title: title,
    body: body.isEmpty ? ' ' : body,
    notificationDetails: details,
  );
}
