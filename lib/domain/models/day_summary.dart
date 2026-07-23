import 'health_extras.dart';

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
    this.zoneMinutes = 0,
    this.distanceMeters,
    this.floors,
    this.respiratoryRate,
    this.totalCalories,
    this.sedentaryMinutes,
    this.skinTempDeviation,
    this.heartRateZones,
    this.vo2Max,
    this.recoveryScore,
    this.strainScore,
    this.sleepScore,
    this.sleepNeededMinutes,
    this.sleepDebtMinutes,
    this.recoveryBreakdown,
    this.stressScore,
    this.readinessScore,
    this.stressManagementScore,
    this.cardioFitnessScore,
    this.exercises = const [],
    this.insights = const [],
  });

  final DateTime date;
  final int steps;
  final double activeCalories;
  final double? totalCalories;
  final int activeMinutes;
  final int zoneMinutes;
  final int? sedentaryMinutes;
  final double? distanceMeters;
  final int? floors;
  final double? restingHeartRate;
  final double? hrvMs;
  final double? spo2Percent;
  final double? respiratoryRate;
  final double? skinTempDeviation;
  final HeartRateZones? heartRateZones;
  final double? vo2Max;
  final int sleepMinutes;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final int lightSleepMinutes;
  final int awakeMinutes;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final List<MetricSample> heartSamples;
  final List<MetricSample> spo2Samples;
  final List<ExerciseSession> exercises;
  final double? recoveryScore;
  final double? strainScore;
  final double? sleepScore;
  final int? sleepNeededMinutes;
  final int? sleepDebtMinutes;
  final RecoveryBreakdown? recoveryBreakdown;
  final double? stressScore;
  final double? readinessScore;
  final double? stressManagementScore;
  final double? cardioFitnessScore;
  final List<InsightItem> insights;

  DaySummary copyWith({
    double? recoveryScore,
    double? strainScore,
    double? sleepScore,
    int? sleepNeededMinutes,
    int? sleepDebtMinutes,
    RecoveryBreakdown? recoveryBreakdown,
    List<ExerciseSession>? exercises,
    HeartRateZones? heartRateZones,
    double? vo2Max,
    double? totalCalories,
    int? sedentaryMinutes,
    double? skinTempDeviation,
    double? stressScore,
    double? readinessScore,
    double? stressManagementScore,
    double? cardioFitnessScore,
    List<InsightItem>? insights,
  }) {
    return DaySummary(
      date: date,
      steps: steps,
      activeCalories: activeCalories,
      totalCalories: totalCalories ?? this.totalCalories,
      activeMinutes: activeMinutes,
      zoneMinutes: zoneMinutes,
      sedentaryMinutes: sedentaryMinutes ?? this.sedentaryMinutes,
      distanceMeters: distanceMeters,
      floors: floors,
      restingHeartRate: restingHeartRate,
      hrvMs: hrvMs,
      spo2Percent: spo2Percent,
      respiratoryRate: respiratoryRate,
      skinTempDeviation: skinTempDeviation ?? this.skinTempDeviation,
      heartRateZones: heartRateZones ?? this.heartRateZones,
      vo2Max: vo2Max ?? this.vo2Max,
      sleepMinutes: sleepMinutes,
      deepSleepMinutes: deepSleepMinutes,
      remSleepMinutes: remSleepMinutes,
      lightSleepMinutes: lightSleepMinutes,
      awakeMinutes: awakeMinutes,
      avgHeartRate: avgHeartRate,
      maxHeartRate: maxHeartRate,
      heartSamples: heartSamples,
      spo2Samples: spo2Samples,
      exercises: exercises ?? this.exercises,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      strainScore: strainScore ?? this.strainScore,
      sleepScore: sleepScore ?? this.sleepScore,
      sleepNeededMinutes: sleepNeededMinutes ?? this.sleepNeededMinutes,
      sleepDebtMinutes: sleepDebtMinutes ?? this.sleepDebtMinutes,
      recoveryBreakdown: recoveryBreakdown ?? this.recoveryBreakdown,
      stressScore: stressScore ?? this.stressScore,
      readinessScore: readinessScore ?? this.readinessScore,
      stressManagementScore:
          stressManagementScore ?? this.stressManagementScore,
      cardioFitnessScore: cardioFitnessScore ?? this.cardioFitnessScore,
      insights: insights ?? this.insights,
    );
  }

  Map<String, dynamic> toCoachJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'recovery': recoveryScore,
      'readiness': readinessScore,
      'strain': strainScore,
      'sleepScore': sleepScore,
      'stress': stressScore,
      'stressManagement': stressManagementScore,
      'cardioFitness': cardioFitnessScore,
      'sleepNeededMinutes': sleepNeededMinutes,
      'sleepDebtMinutes': sleepDebtMinutes,
      'steps': steps,
      'activeCalories': activeCalories,
      'totalCalories': totalCalories,
      'activeMinutes': activeMinutes,
      'zoneMinutes': zoneMinutes,
      'sedentaryMinutes': sedentaryMinutes,
      'distanceMeters': distanceMeters,
      'floors': floors,
      'restingHeartRate': restingHeartRate,
      'hrvMs': hrvMs,
      'spo2Percent': spo2Percent,
      'respiratoryRate': respiratoryRate,
      'skinTempDeviation': skinTempDeviation,
      'vo2Max': vo2Max,
      'sleepMinutes': sleepMinutes,
      'deepSleepMinutes': deepSleepMinutes,
      'remSleepMinutes': remSleepMinutes,
      'lightSleepMinutes': lightSleepMinutes,
      'awakeMinutes': awakeMinutes,
      'avgHeartRate': avgHeartRate,
      'maxHeartRate': maxHeartRate,
      'heartRateZones': heartRateZones == null
          ? null
          : {
              'fatBurn': heartRateZones!.fatBurnMinutes,
              'cardio': heartRateZones!.cardioMinutes,
              'peak': heartRateZones!.peakMinutes,
            },
      'exercises': exercises.map((e) => e.toCoachJson()).toList(),
      'insights': insights.map((i) => {'title': i.title, 'body': i.body}).toList(),
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

  final String role;
  final String text;
}
