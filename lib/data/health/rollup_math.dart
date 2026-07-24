/// Pure helpers for Google Health dailyRollUp payloads.
///
/// Field names follow the v4 REST docs (e.g. kcalSum, beatsPerMinuteAvg,
/// sumInFatBurnHeartZone) — older aliases are accepted for safety.
library;

double? rollupNum(dynamic node, List<String> keys) {
  if (node is num) return node.toDouble();
  if (node is! Map) return null;
  final map = Map<String, dynamic>.from(node);
  for (final key in keys) {
    final v = map[key];
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v.replaceAll(RegExp(r'[^0-9.\-]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double? extractActiveEnergyKcal(Map<String, dynamic> point) {
  return rollupNum(point['activeEnergyBurned'], const [
    'kcalSum',
    'kcal_sum',
    'kilocaloriesSum',
    'sum',
  ]);
}

double? extractTotalCaloriesKcal(Map<String, dynamic> point) {
  return rollupNum(point['totalCalories'], const [
    'kcalSum',
    'kcal_sum',
    'kilocaloriesSum',
    'sum',
  ]);
}

double? extractSteps(Map<String, dynamic> point) {
  return rollupNum(point['steps'], const ['countSum', 'count_sum', 'sum']);
}

double? extractActiveMinutes(Map<String, dynamic> point) {
  final node = point['activeMinutes'];
  if (node is! Map) return null;
  final map = Map<String, dynamic>.from(node);
  final rows = map['activeMinutesRollupByActivityLevel'] as List<dynamic>? ??
      map['active_minutes_rollup_by_activity_level'] as List<dynamic>? ??
      const [];
  if (rows.isNotEmpty) {
    var total = 0.0;
    for (final raw in rows) {
      if (raw is! Map) continue;
      total += rollupNum(Map<String, dynamic>.from(raw), const [
            'activeMinutesSum',
            'active_minutes_sum',
            'minutesSum',
            'sum',
          ]) ??
          0;
    }
    return total;
  }
  return rollupNum(map, const [
    'activeMinutesSum',
    'minutesSum',
    'sum',
  ]);
}

({double total, int fat, int cardio, int peak})? extractActiveZoneMinutes(
  Map<String, dynamic> point,
) {
  final node = point['activeZoneMinutes'];
  if (node is! Map) return null;
  final map = Map<String, dynamic>.from(node);
  final fat = rollupNum(map, const [
        'sumInFatBurnHeartZone',
        'sum_in_fat_burn_heart_zone',
        'fatBurnMinutes',
      ])
          ?.round() ??
      0;
  final cardio = rollupNum(map, const [
        'sumInCardioHeartZone',
        'sum_in_cardio_heart_zone',
        'cardioMinutes',
      ])
          ?.round() ??
      0;
  final peak = rollupNum(map, const [
        'sumInPeakHeartZone',
        'sum_in_peak_heart_zone',
        'peakMinutes',
      ])
          ?.round() ??
      0;
  final total = fat + cardio + peak;
  if (total <= 0) {
    final fallback = rollupNum(map, const ['minutesSum', 'sum']);
    if (fallback == null || fallback <= 0) return null;
    return (total: fallback, fat: 0, cardio: 0, peak: 0);
  }
  return (total: total.toDouble(), fat: fat, cardio: cardio, peak: peak);
}

({double? avg, double? min, double? max}) extractHeartRateRollup(
  Map<String, dynamic> point,
) {
  final hr = point['heartRate'];
  if (hr is! Map) return (avg: null, min: null, max: null);
  final map = Map<String, dynamic>.from(hr);
  return (
    avg: rollupNum(map, const [
      'beatsPerMinuteAvg',
      'beatsPerMinuteAverage',
      'beats_per_minute_avg',
      'average',
    ]),
    min: rollupNum(map, const [
      'beatsPerMinuteMin',
      'beats_per_minute_min',
      'min',
    ]),
    max: rollupNum(map, const [
      'beatsPerMinuteMax',
      'beats_per_minute_max',
      'max',
    ]),
  );
}

/// CivilDateTime may be flat `{year,month,day}` or nested `{date:{...}}`.
DateTime? civilDate(Map? civil) {
  if (civil == null) return null;
  final nested = civil['date'];
  final map = nested is Map ? nested : civil;
  final y = map['year'];
  final m = map['month'];
  final d = map['day'];
  if (y is! num || m is! num || d is! num) return null;
  return DateTime(y.toInt(), m.toInt(), d.toInt());
}
