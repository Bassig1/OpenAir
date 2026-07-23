import '../models/day_summary.dart';

/// OpenAir-computed scores inspired by recovery / strain / sleep UX patterns.
/// These are transparent heuristics — not Whoop's proprietary algorithms.
class ScoreEngine {
  const ScoreEngine();

  List<DaySummary> scoreDays(List<DaySummary> days) {
    if (days.isEmpty) return days;
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final scored = <DaySummary>[];

    for (var i = 0; i < sorted.length; i++) {
      final day = sorted[i];
      final history = sorted.sublist(0, i + 1);
      scored.add(
        day.copyWith(
          sleepScore: _sleepScore(day),
          strainScore: _strainScore(day),
          recoveryScore: _recoveryScore(day, history),
        ),
      );
    }
    return scored;
  }

  double _sleepScore(DaySummary day) {
    const needMinutes = 8 * 60;
    final durationRatio = (day.sleepMinutes / needMinutes).clamp(0.0, 1.15);
    final asSleep =
        (day.deepSleepMinutes + day.remSleepMinutes + day.lightSleepMinutes)
            .clamp(1, 100000);
    final quality =
        ((day.deepSleepMinutes + day.remSleepMinutes) / asSleep).clamp(0.0, 1.0);
    final awakePenalty = (day.awakeMinutes / 60).clamp(0.0, 0.25);
    final score = ((durationRatio * 70) + (quality * 35) - (awakePenalty * 20))
        .clamp(0.0, 100.0);
    return double.parse(score.toStringAsFixed(1));
  }

  double _strainScore(DaySummary day) {
    // 0–21 style scale for familiar UX.
    final fromMinutes = (day.activeMinutes / 90) * 12;
    final fromCalories = (day.activeCalories / 700) * 8;
    final fromHr = day.maxHeartRate == null
        ? 0.0
        : (((day.maxHeartRate! - 100) / 80) * 6).clamp(0.0, 6.0);
    final score = (fromMinutes + fromCalories + fromHr).clamp(0.0, 21.0);
    return double.parse(score.toStringAsFixed(1));
  }

  double _recoveryScore(DaySummary day, List<DaySummary> history) {
    final sleep = _sleepScore(day);
    final rhrBaseline = _avg(
      history
          .where((d) => d.restingHeartRate != null)
          .map((d) => d.restingHeartRate!),
      fallback: day.restingHeartRate ?? 60,
    );
    final hrvBaseline = _avg(
      history.where((d) => d.hrvMs != null).map((d) => d.hrvMs!),
      fallback: day.hrvMs ?? 40,
    );

    var score = sleep * 0.45;

    if (day.restingHeartRate != null) {
      final delta = rhrBaseline - day.restingHeartRate!;
      score += (50 + delta * 3).clamp(10.0, 90.0) * 0.25;
    } else {
      score += 40 * 0.25;
    }

    if (day.hrvMs != null && hrvBaseline > 0) {
      final ratio = (day.hrvMs! / hrvBaseline).clamp(0.5, 1.5);
      score += (ratio * 70).clamp(15.0, 95.0) * 0.25;
    } else {
      score += 45 * 0.25;
    }

    if (day.spo2Percent != null) {
      if (day.spo2Percent! < 94) {
        score -= 12;
      } else if (day.spo2Percent! >= 97) {
        score += 4;
      }
    }

    return double.parse(score.clamp(1.0, 99.0).toStringAsFixed(1));
  }

  double _avg(Iterable<double> values, {required double fallback}) {
    final list = values.toList();
    if (list.isEmpty) return fallback;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
