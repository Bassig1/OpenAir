import 'package:intl/intl.dart';

import '../models/day_summary.dart';
import '../models/health_extras.dart';
import '../models/user_profile.dart';

/// OpenAir recovery and strain scoring.
/// Transparent heuristics — not proprietary third-party algorithms.
class ScoreEngine {
  const ScoreEngine();

  static const baselineSleepNeedMinutes = 8 * 60;

  List<DaySummary> scoreDays(
    List<DaySummary> days, {
    UserProfile profile = UserProfile.empty,
  }) {
    if (days.isEmpty) return days;
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final scored = <DaySummary>[];
    var rollingDebt = 0;
    final baselineNeed = profile.sleepNeedBaselineMinutes;

    for (var i = 0; i < sorted.length; i++) {
      final day = sorted[i];
      final history = sorted.sublist(0, i + 1);
      final sleepScore = _sleepScore(day, baselineNeed);
      final strain = _strainScore(day, profile);
      final need = _sleepNeededMinutes(day, history, strain, baselineNeed);
      rollingDebt = (rollingDebt + (need - day.sleepMinutes)).clamp(-180, 480);
      final breakdown = _recoveryBreakdown(day, history, sleepScore, need);
      final recovery = _recoveryFromBreakdown(breakdown);
      final stress = _stressScore(day, history, strain, sleepScore);
      final readiness = _readinessScore(recovery, sleepScore, strain, stress);
      final stressMgmt = (100 - stress).clamp(1.0, 99.0);
      final cardio = _cardioFitness(day);
      final insights = _insights(
        day: day.copyWith(
          recoveryScore: recovery,
          strainScore: strain,
          sleepScore: sleepScore,
          stressScore: stress,
          readinessScore: readiness,
        ),
        recovery: recovery,
        strain: strain,
        sleepScore: sleepScore,
        stress: stress,
        readiness: readiness,
        debt: rollingDebt,
      );

      scored.add(
        day.copyWith(
          sleepScore: sleepScore,
          strainScore: strain,
          recoveryScore: recovery,
          sleepNeededMinutes: need,
          sleepDebtMinutes: rollingDebt,
          recoveryBreakdown: breakdown,
          stressScore: double.parse(stress.toStringAsFixed(1)),
          readinessScore: double.parse(readiness.toStringAsFixed(1)),
          stressManagementScore: double.parse(stressMgmt.toStringAsFixed(1)),
          cardioFitnessScore: cardio,
          insights: insights,
        ),
      );
    }
    return scored;
  }

  WeeklyReport buildWeeklyReport(List<DaySummary> days) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    final week = sorted.length > 7
        ? sorted.sublist(sorted.length - 7)
        : sorted;
    if (week.isEmpty) {
      final now = DateTime.now();
      return WeeklyReport(
        start: now,
        end: now,
        avgRecovery: 0,
        avgStrain: 0,
        avgSleepScore: 0,
        avgSleepMinutes: 0,
        totalSteps: 0,
        totalWorkouts: 0,
        avgStress: 0,
        avgReadiness: 0,
        bestRecoveryDay: '—',
        hardestStrainDay: '—',
        insights: const [],
      );
    }

    double avg(double Function(DaySummary d) f) =>
        week.map(f).reduce((a, b) => a + b) / week.length;

    final best = week.reduce(
      (a, b) => (a.recoveryScore ?? 0) >= (b.recoveryScore ?? 0) ? a : b,
    );
    final hardest = week.reduce(
      (a, b) => (a.strainScore ?? 0) >= (b.strainScore ?? 0) ? a : b,
    );
    final fmt = DateFormat('EEE');

    final reportInsights = <InsightItem>[
      InsightItem(
        title: 'Weekly recovery',
        body:
            'Average recovery ${avg((d) => d.recoveryScore ?? 0).toStringAsFixed(0)}. '
            'Best day: ${fmt.format(best.date)}.',
        category: 'recovery',
      ),
      InsightItem(
        title: 'Training load',
        body:
            'Average strain ${avg((d) => d.strainScore ?? 0).toStringAsFixed(1)} with '
            '${week.fold<int>(0, (a, d) => a + d.exercises.length)} workouts.',
        category: 'strain',
      ),
      InsightItem(
        title: 'Sleep consistency',
        body:
            'Avg sleep score ${avg((d) => d.sleepScore ?? 0).toStringAsFixed(0)} · '
            '${(avg((d) => d.sleepMinutes.toDouble()) / 60).toStringAsFixed(1)}h / night.',
        category: 'sleep',
      ),
    ];

    return WeeklyReport(
      start: week.first.date,
      end: week.last.date,
      avgRecovery: double.parse(avg((d) => d.recoveryScore ?? 0).toStringAsFixed(1)),
      avgStrain: double.parse(avg((d) => d.strainScore ?? 0).toStringAsFixed(1)),
      avgSleepScore: double.parse(avg((d) => d.sleepScore ?? 0).toStringAsFixed(1)),
      avgSleepMinutes: avg((d) => d.sleepMinutes.toDouble()),
      totalSteps: week.fold<int>(0, (a, d) => a + d.steps),
      totalWorkouts: week.fold<int>(0, (a, d) => a + d.exercises.length),
      avgStress: double.parse(avg((d) => d.stressScore ?? 0).toStringAsFixed(1)),
      avgReadiness: double.parse(avg((d) => d.readinessScore ?? 0).toStringAsFixed(1)),
      bestRecoveryDay: fmt.format(best.date),
      hardestStrainDay: fmt.format(hardest.date),
      insights: reportInsights,
    );
  }

  double _sleepScore(DaySummary day, int baselineNeed) {
    final needMinutes = baselineNeed.toDouble();
    final durationRatio = (day.sleepMinutes / needMinutes).clamp(0.0, 1.15);
    final asSleep =
        (day.deepSleepMinutes + day.remSleepMinutes + day.lightSleepMinutes)
            .clamp(1, 100000);
    final quality =
        ((day.deepSleepMinutes + day.remSleepMinutes) / asSleep).clamp(0.0, 1.0);
    final awakePenalty = (day.awakeMinutes / 60).clamp(0.0, 0.25);
    return double.parse(
      (((durationRatio * 70) + (quality * 35) - (awakePenalty * 20))
              .clamp(0.0, 100.0))
          .toStringAsFixed(1),
    );
  }

  double _strainScore(DaySummary day, UserProfile profile) {
    // Weight Fitbit Active Zone Minutes + calories hardest — light steps alone
    // shouldn't look like a maxed-out day.
    final fromZones = (day.zoneMinutes / 45) * 8;
    final fromCalories = (day.activeCalories / 600) * 5;
    final fromSteps = (day.steps / 12000) * 3;
    final fromMinutes = (day.activeMinutes / 120) * 3;
    final fromWorkouts = (day.exercises.length * 1.8).clamp(0.0, 5.0);
    final maxHrCap = profile.estimatedMaxHeartRate ?? 190;
    final fromHr = day.maxHeartRate == null
        ? 0.0
        : (((day.maxHeartRate! - 110) / (maxHrCap - 110).clamp(40, 120)) * 3)
            .clamp(0.0, 3.0);
    final zones = day.heartRateZones;
    final fromPeak = zones == null
        ? 0.0
        : ((zones.cardioMinutes + zones.peakMinutes * 1.5) / 25) * 2;
    final raw = fromZones +
        fromCalories +
        fromSteps +
        fromMinutes +
        fromWorkouts +
        fromHr +
        fromPeak;
    // If Google Health returned no activity at all, stay at 0 (don't invent strain).
    final hasSignal = day.steps > 0 ||
        day.activeCalories > 0 ||
        day.zoneMinutes > 0 ||
        day.activeMinutes > 0 ||
        day.exercises.isNotEmpty;
    if (!hasSignal) return 0;
    return double.parse(raw.clamp(0.0, 21.0).toStringAsFixed(1));
  }

  int _sleepNeededMinutes(
    DaySummary day,
    List<DaySummary> history,
    double strain,
    int baselineNeed,
  ) {
    final strainBoost = (strain / 21 * 75).round();
    final recentSleep = history.length < 3
        ? day.sleepMinutes
        : (history
                    .sublist(history.length - 3)
                    .map((d) => d.sleepMinutes)
                    .reduce((a, b) => a + b) /
                3)
            .round();
    final debtBoost = recentSleep < baselineNeed - 45 ? 20 : 0;
    return (baselineNeed + strainBoost + debtBoost).clamp(6 * 60, 10 * 60);
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

    double hrvContribution = 50;
    if (day.hrvMs != null && hrvBaseline > 0) {
      hrvContribution =
          ((day.hrvMs! / hrvBaseline).clamp(0.5, 1.5) * 70).clamp(15.0, 95.0);
    }
    double rhrContribution = 50;
    if (day.restingHeartRate != null) {
      rhrContribution =
          (50 + (rhrBaseline - day.restingHeartRate!) * 3).clamp(10.0, 90.0);
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
      sleepContribution: double.parse(sleepScore.toStringAsFixed(1)),
      hrvContribution: double.parse(hrvContribution.toStringAsFixed(1)),
      rhrContribution: double.parse(rhrContribution.toStringAsFixed(1)),
      spo2Contribution: double.parse(spo2Contribution.toStringAsFixed(1)),
      sleepNeededMinutes: sleepNeeded,
      sleepDebtMinutes: sleepNeeded - day.sleepMinutes,
    );
  }

  double _recoveryFromBreakdown(RecoveryBreakdown b) {
    return double.parse(
      ((b.sleepContribution * 0.45) +
              (b.hrvContribution * 0.25) +
              (b.rhrContribution * 0.20) +
              (b.spo2Contribution * 0.10))
          .clamp(1.0, 99.0)
          .toStringAsFixed(1),
    );
  }

  double _stressScore(
    DaySummary day,
    List<DaySummary> history,
    double strain,
    double sleepScore,
  ) {
    final hrvBaseline = _avg(
      history.where((d) => d.hrvMs != null).map((d) => d.hrvMs!),
      fallback: day.hrvMs ?? 40,
    );
    var stress = 40.0;
    if (day.hrvMs != null && hrvBaseline > 0) {
      final ratio = day.hrvMs! / hrvBaseline;
      stress += (1.1 - ratio).clamp(-0.4, 0.6) * 40;
    }
    if (day.restingHeartRate != null) {
      stress += ((day.restingHeartRate! - 58) / 20).clamp(-0.3, 0.5) * 25;
    }
    stress += (strain / 21) * 20;
    stress += ((70 - sleepScore) / 70).clamp(0.0, 1.0) * 20;
    if ((day.sedentaryMinutes ?? 0) > 600) stress += 8;
    if ((day.skinTempDeviation ?? 0).abs() > 0.4) stress += 6;
    return stress.clamp(5.0, 95.0);
  }

  double _readinessScore(
    double recovery,
    double sleepScore,
    double strain,
    double stress,
  ) {
    // Fitbit-style Daily Readiness composite.
    final yesterdayStrainPenalty = (strain / 21) * 15;
    return (recovery * 0.5 + sleepScore * 0.3 + (100 - stress) * 0.2 -
            yesterdayStrainPenalty * 0.35)
        .clamp(1.0, 99.0);
  }

  double? _cardioFitness(DaySummary day) {
    if (day.vo2Max != null) {
      // Map VO2 to 0–100-ish fitness index.
      return double.parse(
        (((day.vo2Max! - 25) / 35) * 100).clamp(1.0, 99.0).toStringAsFixed(1),
      );
    }
    return null;
  }

  List<InsightItem> _insights({
    required DaySummary day,
    required double recovery,
    required double strain,
    required double sleepScore,
    required double stress,
    required double readiness,
    required int debt,
  }) {
    final items = <InsightItem>[];
    if (recovery >= 67) {
      items.add(const InsightItem(
        title: 'High recovery',
        body: 'Green day — good window for high strain training.',
        category: 'recovery',
      ));
    } else if (recovery < 34) {
      items.add(const InsightItem(
        title: 'Low recovery',
        body: 'Prioritize easy movement, hydration, and earlier bedtime.',
        category: 'recovery',
      ));
    }
    if (sleepScore < 70) {
      items.add(InsightItem(
        title: 'Sleep opportunity',
        body:
            'Sleep performance is ${sleepScore.toStringAsFixed(0)}. Aim for your sleep need tonight.',
        category: 'sleep',
      ));
    }
    if (debt > 60) {
      items.add(InsightItem(
        title: 'Sleep debt building',
        body: 'About ${(debt / 60).toStringAsFixed(1)}h of debt — bank an earlier night.',
        category: 'sleep',
      ));
    }
    if (strain >= 14) {
      items.add(const InsightItem(
        title: 'High strain day',
        body: 'Strong load logged. Pair with quality sleep and lower tomorrow if recovery dips.',
        category: 'strain',
      ));
    }
    if (stress >= 65) {
      items.add(const InsightItem(
        title: 'Elevated stress',
        body: 'HRV/RHR patterns look taxed. Try a 5–10 min downshift (walk or breathwork).',
        category: 'stress',
      ));
    }
    if (readiness >= 70 && strain < 8) {
      items.add(const InsightItem(
        title: 'Unused capacity',
        body: 'Readiness is solid and strain is low — room to push if you feel good.',
        category: 'strain',
      ));
    }
    if (day.exercises.isNotEmpty) {
      items.add(InsightItem(
        title: 'Workout detected',
        body:
            '${day.exercises.length} session(s) including ${day.exercises.first.name}.',
        category: 'strain',
      ));
    }
    return items;
  }

  double _avg(Iterable<double> values, {required double fallback}) {
    final list = values.toList();
    if (list.isEmpty) return fallback;
    return list.reduce((a, b) => a + b) / list.length;
  }
}
