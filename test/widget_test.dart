import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openair/domain/models/day_summary.dart';
import 'package:openair/domain/scores/score_engine.dart';
import 'package:openair/features/today/today_screen.dart';
import 'package:openair/state/app_controller.dart';
import 'package:openair/theme/openair_theme.dart';
import 'package:provider/provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('ScoreEngine produces recovery strain sleep and sleep need', () {
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
    expect(scored.sleepNeededMinutes, isNotNull);
    expect(scored.recoveryBreakdown, isNotNull);
    expect(scored.strainScore! <= 21, isTrue);
  });

  testWidgets('Today screen shows OpenAir title and rings', (tester) async {
    final controller = AppController();
    controller.loading = false;
    controller.useDemoData = true;
    controller.days = const ScoreEngine().scoreDays([
      DaySummary(
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
        heartSamples: [],
        spo2Samples: [],
      ),
    ]);
    controller.selectedIndex = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          theme: OpenAirTheme.dark(),
          home: const TodayScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('OpenAir'), findsOneWidget);
    expect(find.text('RECOVERY'), findsOneWidget);
    expect(find.text('Sleep need'), findsOneWidget);
  });
}
