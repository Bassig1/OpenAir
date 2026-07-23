import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local alerts for unusual HR, finished workouts, and sleep summaries.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    // flutter_local_notifications is not supported on web.
    if (kIsWeb) {
      _ready = true;
      return;
    }
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = true;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'openair_alerts',
        'OpenAir alerts',
        channelDescription: 'Heart, workout, and sleep alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> unusualHeartbeat({
    required double bpm,
    required double baseline,
  }) {
    return show(
      id: 1001,
      title: 'Unusual heart rate',
      body:
          'Recent reading ${bpm.round()} bpm vs typical resting ~${baseline.round()} bpm. Check how you feel.',
    );
  }

  Future<void> workoutComplete({
    required String name,
    required int minutes,
    required double? calories,
    required double strainDelta,
  }) {
    final kcal = calories == null ? '' : ' · ${calories.round()} kcal';
    return show(
      id: 1002,
      title: 'Workout complete',
      body:
          '$name · ${minutes}m$kcal · estimated strain +${strainDelta.toStringAsFixed(1)}',
    );
  }

  Future<void> sleepSummary({
    required String summary,
  }) {
    return show(
      id: 1003,
      title: 'Sleep summary',
      body: summary,
    );
  }
}
