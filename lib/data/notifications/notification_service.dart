import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'sheep_downloads';
  static const _channelName = 'Downloads';
  static const _channelDesc = 'Notificações de download do Sheep';

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
        ));
    _initialized = true;
  }

  // Request POST_NOTIFICATIONS permission (Android 13+). Call from foreground only.
  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showDownloadComplete(
      String mangaTitle, String chapterTitle) async {
    await _plugin.show(
      chapterTitle.hashCode.abs() % 9999,
      mangaTitle,
      '$chapterTitle baixado',
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
            channelDescription: _channelDesc),
      ),
    );
  }

  Future<void> showDownloadFailed(String chapterTitle) async {
    await _plugin.show(
      chapterTitle.hashCode.abs() % 9999 + 50000,
      'Download falhou',
      chapterTitle,
      const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName,
            channelDescription: _channelDesc),
      ),
    );
  }
}
