import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/health_extras.dart';

/// Manual workouts — SharedPreferences so Android, iOS, and web all work
/// (path_provider / dart:io is not available on Flutter web).
class WorkoutStore {
  static const _key = 'manual_workouts_v1';

  Future<List<ExerciseSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ExerciseSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveAll(List<ExerciseSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(sessions.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<ExerciseSession>> upsert(ExerciseSession session) async {
    final all = await loadAll();
    final next = [
      session,
      ...all.where((e) => e.id != session.id),
    ]..sort((a, b) => b.start.compareTo(a.start));
    await saveAll(next);
    return next;
  }

  Future<List<ExerciseSession>> remove(String id) async {
    final next = (await loadAll()).where((e) => e.id != id).toList();
    await saveAll(next);
    return next;
  }
}
