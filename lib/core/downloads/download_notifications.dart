import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DownloadNotifications {
  DownloadNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialized;
  final Map<int, int> _lastProgress = {};

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> initialize({bool requestPermission = false}) async {
    if (!_supported) return;
    _initialized ??= _plugin
        .initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
        )
        .then((_) {});
    await _initialized;
    if (!requestPermission) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: false, sound: false);
    }
  }

  Future<void> progress(
    int downloadId,
    String title, {
    required int done,
    required int total,
  }) async {
    if (!_supported) return;
    await _ready();
    final percent = total > 0 ? (done * 100 ~/ total).clamp(0, 100) : null;
    if (percent != null && _lastProgress[downloadId] == percent) return;
    if (percent != null) _lastProgress[downloadId] = percent;
    await _show(
      downloadId,
      title,
      percent == null ? 'Preparing download' : 'Downloading · $percent%',
      progress: percent,
      ongoing: true,
    );
  }

  Future<void> completed(int downloadId, String title) async {
    if (!_supported) return;
    await _ready();
    _lastProgress.remove(downloadId);
    await _show(downloadId, title, 'Download complete', progress: 100);
  }

  Future<void> failed(int downloadId, String title) async {
    if (!_supported) return;
    await _ready();
    _lastProgress.remove(downloadId);
    await _show(downloadId, title, 'Download failed');
  }

  Future<void> paused(int downloadId, String title) async {
    if (!_supported) return;
    await _ready();
    await _show(downloadId, title, 'Download paused');
  }

  Future<void> cancel(int downloadId) async {
    if (!_supported) return;
    await _ready();
    _lastProgress.remove(downloadId);
    await _plugin.cancel(id: _notificationId(downloadId));
  }

  Future<void> _ready() async {
    try {
      await initialize();
    } catch (_) {
      // A missing or denied notification plugin must not stop a download.
    }
  }

  Future<void> _show(
    int downloadId,
    String title,
    String body, {
    int? progress,
    bool ongoing = false,
  }) async {
    try {
      await _plugin.show(
        id: _notificationId(downloadId),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'downloads',
            'Downloads',
            channelDescription: 'Video download progress',
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            onlyAlertOnce: true,
            ongoing: ongoing,
            autoCancel: !ongoing,
            showProgress: progress != null,
            maxProgress: 100,
            progress: progress ?? 0,
            indeterminate: progress == null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          ),
        ),
      );
    } catch (_) {
      // Notification delivery is best-effort; persisted download state remains.
    }
  }

  int _notificationId(int downloadId) => 100000 + downloadId;
}
