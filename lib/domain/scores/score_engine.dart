import '../models/day_summary.dart';
import '../models/health_extras.dart';

/// OpenAir-computed scores inspired by recovery / strain / sleep UX patterns.
/// Transparent heuristics — not Whoop's proprietary algorithms.
class ScoreEngine {
  const ScoreEngine();

  static const baselineSleepNeedMinutes = 8 * 60;

  List<DaySummary> scoreDays(List<DaySummary> days) {
    if (days.isEmpty) return days;
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final scored = <DaySummary>[];
    var rollingDebt = 0;

    for (var i = 0; i < sorted.length; i++) {
      final day = sorted[i];
      final history = sorted.sublist(0, i + 1);
      final sleepScore = _sleepScore(day);
      final strain = _strainScore(day);
      final need = _sleepNeededMinutes(day, history, strain);
      final debtDelta = need - day.sleepMinutes;
      rollingDebt = (rollingDebt + debtDelta).clamp(-180, 480);
      final breakdown = _recoveryBreakdown(day, history, sleepScore, need);
      final recovery = _recoveryFromBreakdown(breakdown);

      scored.add(
        day.copyWith(
          sleepScore: sleepScore,
          strainScore: strain,
          recoveryScore: recovery,
          sleepNeededMinutes: need,
          sleepDebtMinutes: rollingDebt,
          recoveryBreakdown: breakdown,
        ),
      );
    }
    return scored;
  }

  double _sleepScore(DaySummary day) {
    const needMinutes = baselineSleepNeedMinutes;
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
    final fromMinutes = (day.activeMinutes / 90) * 8;
    final fromZones = (day.zoneMinutes / 60) * 6;
    final fromCalories = (day.activeCalories / 700) * 4;
    final fromWorkouts = (day.exercises.length * 1.5).clamp(0.0, 4.0);
    final fromHr = day.maxHeartRate == null
        ? 0.0
        : (((day.maxHeartRate! - 100) / 80) * 4).clamp(0.0, 4.0);
    final zones = day.heartRateZones;
    final fromPeak = zones == null ? 0.0 : (zones.peakMinutes / 20) * 2;
    final score = (fromMinutes +
            fromZones +
            fromCalories +
            fromWorkouts +
            fromHr +
            fromPeak)
        .clamp(0.0, 21.0);
    return double.parse(score.toStringAsFixed(1));
  }

  int _sleepNeededMinutes(
    DaySummary day,
    List<DaySummary> history,
    double strain,
  ) {
    // Higher recent strain → slightly more sleep need (Whoop-like).
    final strainBoost = (strain / 21 * 75).round();
    final recentSleep = history.length < 3
        ? day.sleepMinutes
        : (history
                    .sublist(history.length - 3)
                    .map((d) => d.sleepMinutes)
                    .reduce((a, b) => a + b) /
                3)
            .round();
    final baseline = ((baselineSleepNeedMinutes + recentSleep) / 2).round();
    return (baseline + strainBoost - 30).clamp(6 * 60, 10 * 60);
  }

  RecoveryBreakdown _recoveryBreakdown(
    DaySummary day,
    List<DaySummary> history,
    double sleepScore,
    int sleepNeeded,
  ) {
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

    final sleepContribution = sleepScore;
    double hrvContribution = 50;
    if (day.hrvMs != null && hrvBaseline > 0) {
      final ratio = (day.hrvMs! / hrvBaseline).clamp(0.5, 1.5);
      hrvContribution = (ratio * 70).clamp(15.0, 95.0);
    }
    double rhrContribution = 50;
    if (day.restingHeartRate != null) {
      final delta = rhrBaseline - day.restingHeartRate!;
      rhrContribution = (50 + delta * 3).clamp(10.0, 90.0);
    }
    double spo2Contribution = 70;
    if (day.spo2Percent != null) {
      if (day.spo2Percent! < 94) {
        spo2Contribution = 35;
      } else if (day.spo2Percent! >= 97) {
        spo2Contribution = 90;
      } else {
        spo2Contribution = 65;
      }
    }

    return RecoveryBreakdown(
      sleepContribution: double.parse(sleepContribution.toStringAsFixed(1)),
      hrvContribution: double.parse(hrvContribution.toStringAsFixed(1)),
      rhrContribution: double.parse(rhrContribution.toStringAsFixed(1)),
      spo2Contribution: double.parse(spo2Contribution.toStringAsFixed(1)),
      sleepNeededMinutes: sleepNeeded,
      sleepDebtMinutes: (sleepNeeded - day.sleepMinutes),
    );
  }

  double _recoveryFromBreakdown(RecoveryBreakdown b) {
    final score = (b.sleepContribution * 0.45) +
        (b.hrvContribution * 0.25) +
        (b.rhrContribution * 0.20) +
        (b.spo2Contribution * 0.10);
    return double.parse(score.clamp(1.0, 99.0).toStringAsFixed(1));
  }

  double _avg(Iterable<double> values, {required double fallback}) {
    final list = values.toList();
    if (list.isEmpty) return fallback;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
