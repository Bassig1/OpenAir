import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/health_extras.dart';

class JournalStore {
  static const _key = 'journal_entries_v1';

  Future<Map<String, JournalEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, JournalEntry.fromJson(Map<String, dynamic>.from(v as Map))),
    );
  }

  Future<JournalEntry> loadForDate(DateTime date) async {
    final all = await loadAll();
    final key = JournalEntry.keyFor(date);
    return all[key] ?? JournalEntry(dateKey: key);
  }

  Future<void> save(JournalEntry entry) async {
    final all = await loadAll();
    all[entry.dateKey] = entry;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
