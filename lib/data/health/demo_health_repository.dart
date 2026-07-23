import 'dart:math';

import '../../domain/models/day_summary.dart';
import '../../domain/models/health_extras.dart';

class DemoHealthRepository {
  DemoHealthRepository({Random? random}) : _random = random ?? Random(42);

  final Random _random;

  Future<HealthDemoBundle> loadBundle({int days = 14}) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayList = List.generate(days, (i) {
      final date = today.subtract(Duration(days: days - 1 - i));
      return _dayFor(date, i);
    });
    return HealthDemoBundle(
      days: dayList,
      body: BodySnapshot(
        weightKg: 78.4,
        bodyFatPercent: 18.2,
        vo2Max: 44.5,
        heightCm: 178,
        measuredAt: today.subtract(const Duration(days: 2)),
      ),
      devices: const [
        PairedDeviceInfo(
          id: 'demo-fitbit',
          name: 'Fitbit Air',
          model: 'Fitbit',
        ),
      ],
    );
  }

  Future<List<DaySummary>> loadRecentDays({int days = 14}) async {
    final bundle = await loadBundle(days: days);
    return bundle.days;
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
    final zoneMinutes =
        (activeMinutes * (0.45 + _random.nextDouble() * 0.4)).round();
    final fatBurn = (zoneMinutes * 0.55).round();
    final cardio = (zoneMinutes * 0.3).round();
    final peak = (zoneMinutes - fatBurn - cardio).clamp(0, 200);

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

    final exercises = <ExerciseSession>[];
    if (weekdayBoost > 0.8 && _random.nextBool()) {
      final start = date.add(Duration(hours: 17 + _random.nextInt(2)));
      exercises.add(
        ExerciseSession(
          id: 'demo-$index',
          name: _random.nextBool() ? 'Run' : 'Weight Training',
          start: start,
          end: start.add(Duration(minutes: 28 + _random.nextInt(40))),
          calories: 180 + _random.nextDouble() * 320,
          distanceMeters: 3000 + _random.nextDouble() * 5000,
          avgHeartRate: 125 + _random.nextDouble() * 25,
          maxHeartRate: maxHr,
          steps: 2000 + _random.nextInt(4000),
        ),
      );
    }

    return DaySummary(
      date: date,
      steps: steps,
      activeCalories: double.parse(calories.toStringAsFixed(0)),
      totalCalories: double.parse((calories + 1400).toStringAsFixed(0)),
      activeMinutes: activeMinutes,
      zoneMinutes: zoneMinutes,
      sedentaryMinutes: 400 + _random.nextInt(200),
      distanceMeters: double.parse(distance.toStringAsFixed(0)),
      floors: floors,
      restingHeartRate: double.parse(rhr.toStringAsFixed(1)),
      hrvMs: double.parse(hrv.toStringAsFixed(1)),
      spo2Percent: double.parse(spo2.toStringAsFixed(1)),
      respiratoryRate: double.parse(resp.toStringAsFixed(1)),
      skinTempDeviation: double.parse(
        ((_random.nextDouble() - 0.5) * 0.8).toStringAsFixed(2),
      ),
      vo2Max: double.parse((40 + _random.nextDouble() * 10).toStringAsFixed(1)),
      heartRateZones: HeartRateZones(
        fatBurnMinutes: fatBurn,
        cardioMinutes: cardio,
        peakMinutes: peak,
      ),
      sleepMinutes: sleepMinutes,
      deepSleepMinutes: deep,
      remSleepMinutes: rem,
      lightSleepMinutes: light,
      awakeMinutes: awake,
      avgHeartRate: double.parse(avgHr.toStringAsFixed(1)),
      maxHeartRate: double.parse(maxHr.toStringAsFixed(1)),
      heartSamples: heartSamples,
      spo2Samples: spo2Samples,
      exercises: exercises,
    );
  }
}

class HealthDemoBundle {
  const HealthDemoBundle({
    required this.days,
    this.body,
    this.devices = const [],
  });

  final List<DaySummary> days;
  final BodySnapshot? body;
  final List<PairedDeviceInfo> devices;
}
