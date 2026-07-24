import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/day_summary.dart';
import '../../domain/models/health_extras.dart';

/// Persists the last successful Google Health snapshot so the app opens with
/// real summaries immediately (no demo data, no forced reconnect).
class HealthCacheStore {
  static const _daysKey = 'health_cache_days_v5';
  static const _bodyKey = 'health_cache_body_v5';
  static const _devicesKey = 'health_cache_devices_v5';
  static const _syncedKey = 'health_cache_synced_at_v5';

  Future<CachedHealthBundle?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawDays = prefs.getString(_daysKey);
    if (rawDays == null || rawDays.isEmpty) return null;
    try {
      final list = jsonDecode(rawDays) as List<dynamic>;
      final days = list
          .map((e) => DaySummary.fromCacheJson(e as Map<String, dynamic>))
          .toList();
      BodySnapshot? body;
      final rawBody = prefs.getString(_bodyKey);
      if (rawBody != null && rawBody.isNotEmpty) {
        body = BodySnapshot.fromJson(
          jsonDecode(rawBody) as Map<String, dynamic>,
        );
      }
      final devices = <PairedDeviceInfo>[];
      final rawDevices = prefs.getString(_devicesKey);
      if (rawDevices != null && rawDevices.isNotEmpty) {
        final decoded = jsonDecode(rawDevices) as List<dynamic>;
        for (final item in decoded) {
          devices.add(
            PairedDeviceInfo.fromJson(item as Map<String, dynamic>),
          );
        }
      }
      final synced = DateTime.tryParse(prefs.getString(_syncedKey) ?? '');
      return CachedHealthBundle(
        days: days,
        body: body,
        devices: devices,
        syncedAt: synced,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required List<DaySummary> days,
    BodySnapshot? body,
    List<PairedDeviceInfo> devices = const [],
    DateTime? syncedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _daysKey,
      jsonEncode(days.map((d) => d.toCacheJson()).toList()),
    );
    if (body == null) {
      await prefs.remove(_bodyKey);
    } else {
      await prefs.setString(_bodyKey, jsonEncode(body.toJson()));
    }
    await prefs.setString(
      _devicesKey,
      jsonEncode(devices.map((d) => d.toJson()).toList()),
    );
    await prefs.setString(
      _syncedKey,
      (syncedAt ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_daysKey);
    await prefs.remove(_bodyKey);
    await prefs.remove(_devicesKey);
    await prefs.remove(_syncedKey);
  }
}

class CachedHealthBundle {
  const CachedHealthBundle({
    required this.days,
    this.body,
    this.devices = const [],
    this.syncedAt,
  });

  final List<DaySummary> days;
  final BodySnapshot? body;
  final List<PairedDeviceInfo> devices;
  final DateTime? syncedAt;
}
