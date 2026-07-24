import '../models/day_summary.dart';
import '../models/user_profile.dart';
import 'advanced_analysis.dart';
import 'period_analytics.dart';

/// Dense, Google Health–style insight cards computed on-device (no network).
class HealthInsightsEngine {
  const HealthInsightsEngine();

  List<HealthInsightCard> build({
    required DaySummary day,
    required List<DaySummary> history,
    UserProfile profile = UserProfile.empty,
  }) {
    final sleep = const AdvancedAnalysis().sleep(
      day,
      profile: profile,
      history: history,
    );
    final heart = const AdvancedAnalysis().heartbeat(day, history);
    final hrv = const PeriodAnalytics().hrvReport(history);
    final week = const PeriodAnalytics().week(history, profile);
    final cards = <HealthInsightCard>[];

    cards.add(
      HealthInsightCard(
        category: 'Sleep',
        title: 'Sleep performance ${sleep.performance.toStringAsFixed(1)}%',
        body:
            'You slept ${_hm(day.sleepMinutes)} vs a ${_hm(sleep.neededMinutes)} need '
            '(${sleep.hoursVsNeedPercent.toStringAsFixed(1)}% of target). '
            'Efficiency ${sleep.efficiencyPercent.toStringAsFixed(1)}% · '
            'restorative ${sleep.restorativePercent.toStringAsFixed(1)}%. '
            'Stages of asleep time: deep ${sleep.deepPercent.toStringAsFixed(1)}% '
            '(${day.deepSleepMinutes}m) · REM ${sleep.remPercent.toStringAsFixed(1)}% '
            '(${day.remSleepMinutes}m) · light ${sleep.lightPercent.toStringAsFixed(1)}% '
            '(${day.lightSleepMinutes}m). '
            'Awake ${sleep.awakePercent.toStringAsFixed(1)}% of time in bed '
            '(${day.awakeMinutes}m). ${sleep.consistencyLabel}.',
        score: sleep.performance,
        accent: 'sleep',
      ),
    );

    if (day.hrvMs != null || day.restingHeartRate != null) {
      final hrvLine = day.hrvMs == null
          ? 'HRV not in today’s cloud summary.'
          : 'HRV ${day.hrvMs!.toStringAsFixed(1)} ms (${heart.hrvTrend})'
              '${hrv.baseline == null ? '' : ' · baseline ${hrv.baseline!.toStringAsFixed(1)} ms'}'
              '${hrv.weekDelta == null ? '' : ' · ${hrv.weekDelta! >= 0 ? '+' : ''}${hrv.weekDelta!.toStringAsFixed(1)} vs 7d'}.';
      final rhrLine = day.restingHeartRate == null
          ? ''
          : ' Resting HR ${day.restingHeartRate!.toStringAsFixed(1)} bpm (${heart.rhrTrend}).';
      final zones = day.heartRateZones;
      final zoneLine = zones == null || zones.total <= 0
          ? ''
          : ' Zone share: fat burn ${zones.percentOf(zones.fatBurnMinutes)}% · '
              'cardio ${zones.percentOf(zones.cardioMinutes)}% · '
              'peak ${zones.percentOf(zones.peakMinutes)}%.';
      cards.add(
        HealthInsightCard(
          category: 'Heart',
          title: 'Autonomic snapshot',
          body: '$hrvLine$rhrLine$zoneLine',
          score: day.hrvMs == null
              ? (100 - ((day.restingHeartRate ?? 60) - 50).abs() * 2)
                    .clamp(20, 90)
                    .toDouble()
              : ((day.hrvMs! / (hrv.baseline ?? day.hrvMs!)) * 70)
                  .clamp(20, 95)
                  .toDouble(),
          accent: 'heart',
        ),
      );
    }

    final recovery = day.recoveryScore ?? 0;
    final strain = day.strainScore ?? 0;
    cards.add(
      HealthInsightCard(
        category: 'Recovery',
        title: recovery >= 67
            ? 'High recovery — capacity is open'
            : recovery >= 34
                ? 'Moderate recovery — train with intent'
                : 'Low recovery — protect the system',
        body:
            'Recovery ${recovery.toStringAsFixed(0)} · readiness ${(day.readinessScore ?? recovery).toStringAsFixed(0)} · '
            'stress ${(day.stressScore ?? 0).toStringAsFixed(0)}. '
            'Strain ${strain.toStringAsFixed(1)} / 21 with ${(21 - strain).clamp(0, 21).toStringAsFixed(1)} remaining. '
            'Week avg recovery ${week.avgRecovery.toStringAsFixed(0)}, strain ${week.avgStrain.toStringAsFixed(1)}.',
        score: recovery,
        accent: 'recovery',
      ),
    );

    final activityScore = _activityScore(day);
    cards.add(
      HealthInsightCard(
        category: 'Activity',
        title: day.strainScore == null
            ? '${day.steps} steps'
            : 'Strain ${day.strainScore!.toStringAsFixed(1)} · ${day.steps} steps',
        body:
            '${day.activeCalories <= 0 ? 'Active calories pending sync' : '${day.activeCalories.toStringAsFixed(0)} active kcal'}'
            '${day.totalCalories == null ? '' : ' · ${day.totalCalories!.toStringAsFixed(0)} total'}'
            '${day.distanceMeters == null ? '' : ' · ${(day.distanceMeters! / 1000).toStringAsFixed(2)} km'}'
            ' · ${day.activeMinutes} active min · ${day.zoneMinutes} AZM. '
            '${day.exercises.isEmpty ? 'No workouts logged for this day.' : '${day.exercises.length} workout(s): ${day.exercises.map((e) => e.name).join(', ')}.'} '
            '${(day.sedentaryMinutes ?? 0) > 600 ? 'Sedentary time is elevated — insert movement breaks.' : 'Movement load looks reasonable for the day.'}',
        score: day.strainScore == null
            ? activityScore
            : (day.strainScore! / 21 * 100).clamp(5, 99),
        accent: 'strain',
      ),
    );

    if (day.spo2Percent != null || day.respiratoryRate != null) {
      final ox = const AdvancedAnalysis().oxygen(day);
      cards.add(
        HealthInsightCard(
          category: 'Vitals',
          title: ox.statusLabel,
          body:
              '${day.spo2Percent == null ? '' : 'SpO₂ avg ${day.spo2Percent!.toStringAsFixed(1)}%'}'
              '${ox.minPercent == null || ox.maxPercent == null ? '' : ' (range ${ox.minPercent!.toStringAsFixed(1)}–${ox.maxPercent!.toStringAsFixed(1)}%, ${ox.sampleCount} samples)'}'
              '${day.spo2Percent == null ? '' : '. '}'
              '${day.respiratoryRate == null ? '' : 'Resp. rate ${day.respiratoryRate!.toStringAsFixed(1)} br/min. '}'
              '${day.skinTempDeviation == null ? '' : 'Skin temp Δ ${day.skinTempDeviation!.toStringAsFixed(2)}°. '}'
              '${day.vo2Max == null && day.cardioFitnessScore == null ? '' : 'Cardio fitness ${(day.cardioFitnessScore ?? day.vo2Max)!.toStringAsFixed(1)}. '}',
          score: day.spo2Percent == null
              ? 70
              : ((day.spo2Percent! - 90) * 10).clamp(20, 99).toDouble(),
          accent: 'spo2',
        ),
      );
    }

    if (history.length >= 5) {
      cards.add(
        HealthInsightCard(
          category: 'Trends',
          title: '7-day trajectory',
          body: week.summary,
          score: week.avgRecovery,
          accent: 'recovery',
        ),
      );
    }

    return cards;
  }

  double _activityScore(DaySummary day) {
    final stepsPart = (day.steps / 10000 * 55).clamp(0.0, 55.0);
    final activePart = (day.activeMinutes / 45 * 25).clamp(0.0, 25.0);
    final workoutPart = (day.exercises.length * 10).clamp(0, 20).toDouble();
    return (stepsPart + activePart + workoutPart).clamp(5, 99);
  }

  String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

class HealthInsightCard {
  const HealthInsightCard({
    required this.category,
    required this.title,
    required this.body,
    required this.score,
    required this.accent,
  });

  final String category;
  final String title;
  final String body;
  final double score;
  final String accent;
}
