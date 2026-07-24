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
    this.minHeartRate,
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
  final double? minHeartRate;
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
      minHeartRate: minHeartRate,
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
    final asleep =
        deepSleepMinutes + remSleepMinutes + lightSleepMinutes;
    final inBed = asleep + awakeMinutes;
    double pct(int part, int whole) => whole <= 0
        ? 0
        : double.parse(((part / whole) * 100).toStringAsFixed(1));
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
      'sleepStagePercentsOfAsleep': {
        'deep': pct(deepSleepMinutes, asleep),
        'rem': pct(remSleepMinutes, asleep),
        'light': pct(lightSleepMinutes, asleep),
      },
      'awakePercentOfTimeInBed': pct(awakeMinutes, inBed),
      'sleepEfficiencyPercent': pct(asleep, inBed),
      'avgHeartRate': avgHeartRate,
      'maxHeartRate': maxHeartRate,
      'minHeartRate': minHeartRate,
      'heartRateZones': heartRateZones?.toJson(),
      'exercises': exercises.map((e) => e.toCoachJson()).toList(),
      'insights': insights.map((i) => {'title': i.title, 'body': i.body}).toList(),
    };
  }

  /// Compact persistence for offline reopen (skips dense sample series).
  Map<String, dynamic> toCacheJson() {
    return {
      'date': date.toIso8601String(),
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
      'minHeartRate': minHeartRate,
      'heartRateZones': heartRateZones?.toJson(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'recoveryScore': recoveryScore,
      'strainScore': strainScore,
      'sleepScore': sleepScore,
      'sleepNeededMinutes': sleepNeededMinutes,
      'sleepDebtMinutes': sleepDebtMinutes,
      'recoveryBreakdown': recoveryBreakdown?.toJson(),
      'stressScore': stressScore,
      'readinessScore': readinessScore,
      'stressManagementScore': stressManagementScore,
      'cardioFitnessScore': cardioFitnessScore,
      'insights': insights.map((i) => i.toJson()).toList(),
      'latestHeart': heartSamples.isEmpty
          ? null
          : {
              'time': heartSamples.last.time.toIso8601String(),
              'value': heartSamples.last.value,
            },
    };
  }

  factory DaySummary.fromCacheJson(Map<String, dynamic> json) {
    final latest = json['latestHeart'] as Map<String, dynamic>?;
    final samples = <MetricSample>[];
    if (latest != null) {
      final t = DateTime.tryParse('${latest['time']}');
      final v = (latest['value'] as num?)?.toDouble();
      if (t != null && v != null) {
        samples.add(MetricSample(time: t, value: v));
      }
    }
    final zonesRaw = json['heartRateZones'];
    final breakdownRaw = json['recoveryBreakdown'];
    final insightsRaw = json['insights'] as List<dynamic>? ?? const [];
    final exercisesRaw = json['exercises'] as List<dynamic>? ?? const [];
    return DaySummary(
      date: DateTime.parse(json['date'] as String),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      activeCalories: (json['activeCalories'] as num?)?.toDouble() ?? 0,
      totalCalories: (json['totalCalories'] as num?)?.toDouble(),
      activeMinutes: (json['activeMinutes'] as num?)?.toInt() ?? 0,
      zoneMinutes: (json['zoneMinutes'] as num?)?.toInt() ?? 0,
      sedentaryMinutes: (json['sedentaryMinutes'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      floors: (json['floors'] as num?)?.toInt(),
      restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble(),
      hrvMs: (json['hrvMs'] as num?)?.toDouble(),
      spo2Percent: (json['spo2Percent'] as num?)?.toDouble(),
      respiratoryRate: (json['respiratoryRate'] as num?)?.toDouble(),
      skinTempDeviation: (json['skinTempDeviation'] as num?)?.toDouble(),
      vo2Max: (json['vo2Max'] as num?)?.toDouble(),
      sleepMinutes: (json['sleepMinutes'] as num?)?.toInt() ?? 0,
      deepSleepMinutes: (json['deepSleepMinutes'] as num?)?.toInt() ?? 0,
      remSleepMinutes: (json['remSleepMinutes'] as num?)?.toInt() ?? 0,
      lightSleepMinutes: (json['lightSleepMinutes'] as num?)?.toInt() ?? 0,
      awakeMinutes: (json['awakeMinutes'] as num?)?.toInt() ?? 0,
      avgHeartRate: (json['avgHeartRate'] as num?)?.toDouble(),
      maxHeartRate: (json['maxHeartRate'] as num?)?.toDouble(),
      minHeartRate: (json['minHeartRate'] as num?)?.toDouble(),
      heartSamples: samples,
      spo2Samples: const [],
      heartRateZones: zonesRaw is Map
          ? HeartRateZones.fromJson(Map<String, dynamic>.from(zonesRaw))
          : null,
      exercises: exercisesRaw
          .map((e) => ExerciseSession.fromJson(e as Map<String, dynamic>))
          .toList(),
      recoveryScore: (json['recoveryScore'] as num?)?.toDouble(),
      strainScore: (json['strainScore'] as num?)?.toDouble(),
      sleepScore: (json['sleepScore'] as num?)?.toDouble(),
      sleepNeededMinutes: (json['sleepNeededMinutes'] as num?)?.toInt(),
      sleepDebtMinutes: (json['sleepDebtMinutes'] as num?)?.toInt(),
      recoveryBreakdown: breakdownRaw is Map
          ? RecoveryBreakdown.fromJson(Map<String, dynamic>.from(breakdownRaw))
          : null,
      stressScore: (json['stressScore'] as num?)?.toDouble(),
      readinessScore: (json['readinessScore'] as num?)?.toDouble(),
      stressManagementScore:
          (json['stressManagementScore'] as num?)?.toDouble(),
      cardioFitnessScore: (json['cardioFitnessScore'] as num?)?.toDouble(),
      insights: insightsRaw
          .map((e) => InsightItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
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
