class DaySummary {
  const DaySummary({
    required this.date,
    required this.steps,
    required this.activeCalories,
    required this.activeMinutes,
    required this.restingHeartRate,
    required this.hrvMs,
    required this.spo2Percent,
    required this.sleepMinutes,
    required this.deepSleepMinutes,
    required this.remSleepMinutes,
    required this.lightSleepMinutes,
    required this.awakeMinutes,
    required this.avgHeartRate,
    required this.maxHeartRate,
    required this.heartSamples,
    required this.spo2Samples,
    this.recoveryScore,
    this.strainScore,
    this.sleepScore,
  });

  final DateTime date;
  final int steps;
  final double activeCalories;
  final int activeMinutes;
  final double? restingHeartRate;
  final double? hrvMs;
  final double? spo2Percent;
  final int sleepMinutes;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int lightSleepMinutes;
  final int awakeMinutes;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final List<MetricSample> heartSamples;
  final List<MetricSample> spo2Samples;
  final double? recoveryScore;
  final double? strainScore;
  final double? sleepScore;

  DaySummary copyWith({
    double? recoveryScore,
    double? strainScore,
    double? sleepScore,
  }) {
    return DaySummary(
      date: date,
      steps: steps,
      activeCalories: activeCalories,
      activeMinutes: activeMinutes,
      restingHeartRate: restingHeartRate,
      hrvMs: hrvMs,
      spo2Percent: spo2Percent,
      sleepMinutes: sleepMinutes,
      deepSleepMinutes: deepSleepMinutes,
      remSleepMinutes: remSleepMinutes,
      lightSleepMinutes: lightSleepMinutes,
      awakeMinutes: awakeMinutes,
      avgHeartRate: avgHeartRate,
      maxHeartRate: maxHeartRate,
      heartSamples: heartSamples,
      spo2Samples: spo2Samples,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      strainScore: strainScore ?? this.strainScore,
      sleepScore: sleepScore ?? this.sleepScore,
    );
  }

  Map<String, dynamic> toCoachJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'recovery': recoveryScore,
      'strain': strainScore,
      'sleepScore': sleepScore,
      'steps': steps,
      'activeCalories': activeCalories,
      'activeMinutes': activeMinutes,
      'restingHeartRate': restingHeartRate,
      'hrvMs': hrvMs,
      'spo2Percent': spo2Percent,
      'sleepMinutes': sleepMinutes,
      'deepSleepMinutes': deepSleepMinutes,
      'remSleepMinutes': remSleepMinutes,
      'lightSleepMinutes': lightSleepMinutes,
      'awakeMinutes': awakeMinutes,
      'avgHeartRate': avgHeartRate,
      'maxHeartRate': maxHeartRate,
    };
  }
}

class MetricSample {
  const MetricSample({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  final String role; // user | assistant
  final String text;
}
