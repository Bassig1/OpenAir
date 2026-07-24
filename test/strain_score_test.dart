import 'package:flutter_test/flutter_test.dart';
import 'package:openair/domain/models/day_summary.dart';
import 'package:openair/domain/models/user_profile.dart';
import 'package:openair/domain/scores/advanced_analysis.dart';
import 'package:openair/domain/scores/score_engine.dart';

void main() {
  test('strain uses Google Health activity and explains drivers', () {
    final day = DaySummary(
      date: DateTime(2026, 7, 23),
      steps: 3895,
      activeCalories: 265,
      activeMinutes: 128,
      zoneMinutes: 19,
      restingHeartRate: 58,
      hrvMs: 68,
      spo2Percent: 96.4,
      sleepMinutes: 480,
      deepSleepMinutes: 60,
      remSleepMinutes: 90,
      lightSleepMinutes: 330,
      awakeMinutes: 20,
      avgHeartRate: 93,
      maxHeartRate: 135,
      minHeartRate: 63,
      heartSamples: const [],
      spo2Samples: const [],
    );

    final scored = const ScoreEngine()
        .scoreDays(
          [day],
          profile: const UserProfile(ageYears: 30, useMetric: true),
        )
        .single;

    expect(scored.strainScore, greaterThan(3));
    expect(scored.strainScore, lessThan(21));

    final analysis = const AdvancedAnalysis().strain(scored);
    expect(analysis.hasActivity, isTrue);
    expect(analysis.summary, contains('Strain'));
    expect(analysis.contributions, isNotEmpty);
  });
}
