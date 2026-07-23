import 'dart:math';

import '../../domain/models/day_summary.dart';

class DemoHealthRepository {
  DemoHealthRepository({Random? random}) : _random = random ?? Random(42);

  final Random _random;

  Future<List<DaySummary>> loadRecentDays({int days = 14}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final date = today.subtract(Duration(days: days - 1 - i));
      return _dayFor(date, i);
    });
  }

  DaySummary _dayFor(DateTime date, int index) {
    final weekdayBoost = date.weekday >= 6 ? 0.7 : 1.0;
    final sleepMinutes = 390 + _random.nextInt(120);
    final deep = (sleepMinutes * (0.14 + _random.nextDouble() * 0.08)).round();
    final rem = (sleepMinutes * (0.18 + _random.nextDouble() * 0.08)).round();
    final awake = 12 + _random.nextInt(35);
    final light = (sleepMinutes - deep - rem - awake).clamp(60, sleepMinutes);
    final steps = (5200 + _random.nextInt(9000) * weekdayBoost).round();
    final activeMinutes = (18 + _random.nextInt(70) * weekdayBoost).round();
    final calories = 220 + _random.nextDouble() * 520 * weekdayBoost;
    final rhr = 52 + _random.nextDouble() * 12;
    final hrv = 28 + _random.nextDouble() * 35;
    final spo2 = 95 + _random.nextDouble() * 3.5;
    final resp = 12 + _random.nextDouble() * 5;
    final avgHr = 68 + _random.nextDouble() * 18;
    final maxHr = 110 + _random.nextDouble() * 55 * weekdayBoost;
    final distance = steps * (0.72 + _random.nextDouble() * 0.15);
    final floors = (_random.nextInt(18) * weekdayBoost).round();
    final zoneMinutes = (activeMinutes * (0.45 + _random.nextDouble() * 0.4))
        .round();

    final heartSamples = List.generate(24, (h) {
      final wobble = sin(h / 3.2) * 8 + _random.nextDouble() * 6;
      return MetricSample(
        time: date.add(Duration(hours: h)),
        value: (avgHr + wobble).clamp(48, 165),
      );
    });

    final spo2Samples = List.generate(8, (i) {
      return MetricSample(
        time: date.add(Duration(hours: 22 + (i ~/ 4), minutes: (i % 4) * 15)),
        value: (spo2 + (_random.nextDouble() - 0.5)).clamp(93, 99),
      );
    });

    return DaySummary(
      date: date,
      steps: steps,
      activeCalories: double.parse(calories.toStringAsFixed(0)),
      activeMinutes: activeMinutes,
      zoneMinutes: zoneMinutes,
      distanceMeters: double.parse(distance.toStringAsFixed(0)),
      floors: floors,
      restingHeartRate: double.parse(rhr.toStringAsFixed(1)),
      hrvMs: double.parse(hrv.toStringAsFixed(1)),
      spo2Percent: double.parse(spo2.toStringAsFixed(1)),
      respiratoryRate: double.parse(resp.toStringAsFixed(1)),
      sleepMinutes: sleepMinutes,
      deepSleepMinutes: deep,
      remSleepMinutes: rem,
      lightSleepMinutes: light,
      awakeMinutes: awake,
      avgHeartRate: double.parse(avgHr.toStringAsFixed(1)),
      maxHeartRate: double.parse(maxHr.toStringAsFixed(1)),
      heartSamples: heartSamples,
      spo2Samples: spo2Samples,
    );
  }
}
