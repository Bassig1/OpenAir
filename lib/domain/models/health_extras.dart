class ExerciseSession {
  const ExerciseSession({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.calories,
    this.distanceMeters,
    this.avgHeartRate,
    this.maxHeartRate,
    this.steps,
  });

  final String id;
  final String name;
  final DateTime start;
  final DateTime end;
  final double? calories;
  final double? distanceMeters;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final int? steps;

  int get durationMinutes => end.difference(start).inMinutes.abs();

  Map<String, dynamic> toCoachJson() => {
        'name': name,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'durationMinutes': durationMinutes,
        'calories': calories,
        'distanceMeters': distanceMeters,
        'avgHeartRate': avgHeartRate,
        'maxHeartRate': maxHeartRate,
        'steps': steps,
      };
}

class HeartRateZones {
  const HeartRateZones({
    this.outOfRangeMinutes = 0,
    this.fatBurnMinutes = 0,
    this.cardioMinutes = 0,
    this.peakMinutes = 0,
  });

  final int outOfRangeMinutes;
  final int fatBurnMinutes;
  final int cardioMinutes;
  final int peakMinutes;

  int get total =>
      outOfRangeMinutes + fatBurnMinutes + cardioMinutes + peakMinutes;
}

class BodySnapshot {
  const BodySnapshot({
    this.weightKg,
    this.bodyFatPercent,
    this.vo2Max,
    this.heightCm,
    this.measuredAt,
  });

  final double? weightKg;
  final double? bodyFatPercent;
  final double? vo2Max;
  final double? heightCm;
  final DateTime? measuredAt;
}

class PairedDeviceInfo {
  const PairedDeviceInfo({
    required this.id,
    required this.name,
    this.model,
    this.lastSync,
  });

  final String id;
  final String name;
  final String? model;
  final DateTime? lastSync;
}

class RecoveryBreakdown {
  const RecoveryBreakdown({
    required this.sleepContribution,
    required this.hrvContribution,
    required this.rhrContribution,
    required this.spo2Contribution,
    required this.sleepNeededMinutes,
    required this.sleepDebtMinutes,
  });

  final double sleepContribution;
  final double hrvContribution;
  final double rhrContribution;
  final double spo2Contribution;
  final int sleepNeededMinutes;
  final int sleepDebtMinutes;
}
