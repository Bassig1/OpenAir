import 'package:flutter_test/flutter_test.dart';
import 'package:openair/domain/models/day_summary.dart';
import 'package:openair/domain/models/user_profile.dart';
import 'package:openair/domain/scores/advanced_analysis.dart';
import 'package:openair/domain/scores/period_analytics.dart';
import 'package:openair/domain/scores/score_engine.dart';

void main() {
  test('Profile-aware scoring, sleep performance, and period trends', () {
    final profile = const UserProfile(
      ageYears: 28,
      heightCm: 178,
      weightKg: 78,
      sex: BiologicalSex.male,
    );
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

    final scored = const ScoreEngine().scoreDays([day], profile: profile).single;
    expect(scored.recoveryScore, isNotNull);
    expect(scored.sleepNeededMinutes, greaterThan(400));

    final sleep = const AdvancedAnalysis().sleep(
      scored,
      profile: profile,
      history: [scored],
    );
    expect(sleep.hoursVsNeedPercent, greaterThan(0));
    expect(sleep.performance, greaterThan(0));
    expect(sleep.consistencyPercent, greaterThan(0));

    final periods = const PeriodAnalytics();
    expect(periods.daily(scored, profile).avgSleepPerformance, greaterThan(0));
    expect(periods.week([scored], profile).dayCount, 1);
    expect(periods.hrvReport([scored]).latest, 42);
  });
}
