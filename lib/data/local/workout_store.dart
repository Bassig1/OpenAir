import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../domain/models/health_extras.dart';

class WorkoutStore {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'manual_workouts.json'));
  }

  Future<List<ExerciseSession>> loadAll() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ExerciseSession.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  Future<void> saveAll(List<ExerciseSession> sessions) async {
    final file = await _file();
    final encoded = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded);
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
