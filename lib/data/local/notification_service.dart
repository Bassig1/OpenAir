import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local alerts with separate Android channels (Sleep / Heart / Workouts / Recovery).
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const _channelSleep = AndroidNotificationDetails(
    'openair_sleep',
    'Sleep',
    channelDescription: 'Overnight sleep performance and sleep debt alerts',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _channelHeart = AndroidNotificationDetails(
    'openair_heart',
    'Heart & vitals',
    channelDescription: 'Unusual heart rate and overnight vitals alerts',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _channelWorkouts = AndroidNotificationDetails(
    'openair_workouts',
    'Workouts',
    channelDescription: 'Workout complete and strain updates',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const _channelRecovery = AndroidNotificationDetails(
    'openair_recovery',
    'Recovery',
    channelDescription: 'Daily recovery and readiness briefings',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      _ready = true;
      return;
    }
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      // Explicit channels so users can mute Sleep vs Heart independently.
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'openair_sleep',
          'Sleep',
          description: 'Overnight sleep performance and sleep debt alerts',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'openair_heart',
          'Heart & vitals',
          description: 'Unusual heart rate and overnight vitals alerts',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'openair_workouts',
          'Workouts',
          description: 'Workout complete and strain updates',
          importance: Importance.defaultImportance,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'openair_recovery',
          'Recovery',
          description: 'Daily recovery and readiness briefings',
          importance: Importance.defaultImportance,
        ),
      );
      // Remove legacy single channel clutter if present (best-effort).
      await androidPlugin?.deleteNotificationChannel(
        channelId: 'openair_alerts',
      );
      _ready = true;
    } catch (_) {
      _ready = true;
    }
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails android,
    required String iosCategory,
  }) async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(
          threadIdentifier: iosCategory,
          categoryIdentifier: iosCategory,
        ),
      ),
    );
  }

  Future<void> unusualHeartbeat({
    required double bpm,
    required double baseline,
  }) {
    return _show(
      id: 1001,
      title: 'Heart check',
      body:
          'Recent reading ${bpm.round()} bpm vs typical resting ~${baseline.round()} bpm. Check how you feel.',
      android: _channelHeart,
      iosCategory: 'heart',
    );
  }

  Future<void> workoutComplete({
    required String name,
    required int minutes,
    required double? calories,
    required double strainDelta,
  }) {
    final kcal = calories == null ? '' : ' · ${calories.round()} kcal';
    return _show(
      id: 1002,
      title: 'Workout complete',
      body:
          '$name · ${minutes}m$kcal · estimated strain +${strainDelta.toStringAsFixed(1)}',
      android: _channelWorkouts,
      iosCategory: 'workouts',
    );
  }

  Future<void> sleepSummary({
    required String summary,
  }) {
    return _show(
      id: 1003,
      title: 'Sleep',
      body: summary,
      android: _channelSleep,
      iosCategory: 'sleep',
    );
  }

  Future<void> recoveryBrief({
    required String headline,
    required String body,
  }) {
    return _show(
      id: 1004,
      title: headline,
      body: body,
      android: _channelRecovery,
      iosCategory: 'recovery',
    );
  }
}
