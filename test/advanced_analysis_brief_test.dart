import 'package:flutter_test/flutter_test.dart';
import 'package:openair/domain/models/day_summary.dart';
import 'package:openair/domain/models/user_profile.dart';
import 'package:openair/domain/scores/advanced_analysis.dart';

void main() {
  test('briefing includes sleep architecture and recovery zone', () {
    final day = DaySummary(
      date: DateTime(2026, 7, 23),
      steps: 739,
      activeCalories: 120,
      activeMinutes: 18,
      restingHeartRate: 58,
      hrvMs: 68.7,
      spo2Percent: 96.4,
      sleepMinutes: 586,
      deepSleepMinutes: 56,
      remSleepMinutes: 150,
      lightSleepMinutes: 380,
      awakeMinutes: 60,
      avgHeartRate: 72,
      maxHeartRate: 118,
      heartSamples: const [],
      spo2Samples: const [],
      recoveryScore: 72,
      strainScore: 4.2,
      readinessScore: 74,
      stressScore: 28,
      sleepNeededMinutes: 480,
    );

    final brief = const AdvancedAnalysis().briefing(
      day: day,
      history: [day],
      profile: const UserProfile(
        ageYears: 30,
        sex: BiologicalSex.male,
      ),
    );

    expect(brief.recoveryZone, 'Green');
    expect(brief.coaching, contains('Sleep:'));
    expect(brief.coaching, contains('HRV'));
    expect(brief.coaching, contains('SpO₂'));
    expect(brief.actions, isNotEmpty);
    expect(brief.sleepPerformance, greaterThan(50));
  });
}
