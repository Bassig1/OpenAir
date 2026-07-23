import 'package:flutter_test/flutter_test.dart';
import 'package:openair/domain/models/day_summary.dart';
import 'package:openair/domain/scores/advanced_analysis.dart';
import 'package:openair/domain/scores/score_engine.dart';

void main() {
  test('ScoreEngine + advanced analysis for final revision', () {
    final day = DaySummary(
      date: DateTime(2026, 7, 22),
      steps: 8000,
      activeCalories: 400,
      activeMinutes: 45,
      zoneMinutes: 30,
      restingHeartRate: 56,
      hrvMs: 42,
      spo2Percent: 97.5,
      sleepMinutes: 450,
      deepSleepMinutes: 80,
      remSleepMinutes: 90,
      lightSleepMinutes: 250,
      awakeMinutes: 30,
      avgHeartRate: 72,
      maxHeartRate: 140,
      heartSamples: const [],
      spo2Samples: const [],
    );

    final scored = const ScoreEngine().scoreDays([day]).single;
    expect(scored.recoveryScore, isNotNull);
    expect(scored.strainScore, isNotNull);
    expect(scored.sleepScore, isNotNull);
    expect(scored.stressScore, isNotNull);
    expect(scored.readinessScore, isNotNull);
    expect(scored.insights, isNotEmpty);
    expect(scored.strainScore! <= 21, isTrue);

    final weekly = const ScoreEngine().buildWeeklyReport([scored]);
    expect(weekly.avgRecovery, greaterThan(0));

    final analysis = const AdvancedAnalysis();
    final sleep = analysis.sleep(scored);
    expect(sleep.efficiencyPercent, greaterThan(0));
    expect(sleep.restorativeMinutes, greaterThan(0));

    final sync = analysis.assessSync(
      days: [scored],
      lastSyncedAt: DateTime.now(),
      isLive: true,
    );
    expect(sync.message, isNotEmpty);
  });
}
