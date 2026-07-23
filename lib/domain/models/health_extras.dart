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
    this.minHeartRate,
    this.steps,
    this.elevationGainMeters,
    this.zoneMinutes,
    this.speedMetersPerSecond,
    this.isManual = false,
    this.notes,
    this.perceivedExertion,
  });

  final String id;
  final String name;
  final DateTime start;
  final DateTime end;
  final double? calories;
  final double? distanceMeters;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final double? minHeartRate;
  final int? steps;
  final double? elevationGainMeters;
  final int? zoneMinutes;
  final double? speedMetersPerSecond;
  final bool isManual;
  final String? notes;
  final int? perceivedExertion;

  int get durationMinutes {
    final secs = end.difference(start).inSeconds.abs();
    return (secs / 60).ceil().clamp(1, 24 * 60);
  }

  double? get paceMinPerKm {
    if (distanceMeters == null || distanceMeters! <= 0 || durationMinutes <= 0) {
      return null;
    }
    final km = distanceMeters! / 1000.0;
    return durationMinutes / km;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'calories': calories,
        'distanceMeters': distanceMeters,
        'avgHeartRate': avgHeartRate,
        'maxHeartRate': maxHeartRate,
        'minHeartRate': minHeartRate,
        'steps': steps,
        'elevationGainMeters': elevationGainMeters,
        'zoneMinutes': zoneMinutes,
        'speedMetersPerSecond': speedMetersPerSecond,
        'isManual': isManual,
        'notes': notes,
        'perceivedExertion': perceivedExertion,
      };

  factory ExerciseSession.fromJson(Map<String, dynamic> json) {
    return ExerciseSession(
      id: json['id'] as String? ?? 'manual-${json['start']}',
      name: json['name'] as String? ?? 'Workout',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      calories: (json['calories'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      avgHeartRate: (json['avgHeartRate'] as num?)?.toDouble(),
      maxHeartRate: (json['maxHeartRate'] as num?)?.toDouble(),
      minHeartRate: (json['minHeartRate'] as num?)?.toDouble(),
      steps: (json['steps'] as num?)?.toInt(),
      elevationGainMeters: (json['elevationGainMeters'] as num?)?.toDouble(),
      zoneMinutes: (json['zoneMinutes'] as num?)?.toInt(),
      speedMetersPerSecond: (json['speedMetersPerSecond'] as num?)?.toDouble(),
      isManual: json['isManual'] as bool? ?? true,
      notes: json['notes'] as String?,
      perceivedExertion: (json['perceivedExertion'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toCoachJson() => {
        ...toJson(),
        'durationMinutes': durationMinutes,
        'paceMinPerKm': paceMinPerKm,
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

  Map<String, dynamic> toJson() => {
        'outOfRangeMinutes': outOfRangeMinutes,
        'fatBurnMinutes': fatBurnMinutes,
        'cardioMinutes': cardioMinutes,
        'peakMinutes': peakMinutes,
      };

  factory HeartRateZones.fromJson(Map<String, dynamic> json) {
    return HeartRateZones(
      outOfRangeMinutes: (json['outOfRangeMinutes'] as num?)?.toInt() ?? 0,
      fatBurnMinutes: (json['fatBurnMinutes'] as num?)?.toInt() ??
          (json['fatBurn'] as num?)?.toInt() ??
          0,
      cardioMinutes: (json['cardioMinutes'] as num?)?.toInt() ??
          (json['cardio'] as num?)?.toInt() ??
          0,
      peakMinutes: (json['peakMinutes'] as num?)?.toInt() ??
          (json['peak'] as num?)?.toInt() ??
          0,
    );
  }
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

  Map<String, dynamic> toJson() => {
        'weightKg': weightKg,
        'bodyFatPercent': bodyFatPercent,
        'vo2Max': vo2Max,
        'heightCm': heightCm,
        'measuredAt': measuredAt?.toIso8601String(),
      };

  factory BodySnapshot.fromJson(Map<String, dynamic> json) {
    return BodySnapshot(
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
      vo2Max: (json['vo2Max'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      measuredAt: DateTime.tryParse('${json['measuredAt'] ?? ''}'),
    );
  }
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'lastSync': lastSync?.toIso8601String(),
      };

  factory PairedDeviceInfo.fromJson(Map<String, dynamic> json) {
    return PairedDeviceInfo(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Device'}',
      model: json['model']?.toString(),
      lastSync: DateTime.tryParse('${json['lastSync'] ?? ''}'),
    );
  }
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

  Map<String, dynamic> toJson() => {
        'sleepContribution': sleepContribution,
        'hrvContribution': hrvContribution,
        'rhrContribution': rhrContribution,
        'spo2Contribution': spo2Contribution,
        'sleepNeededMinutes': sleepNeededMinutes,
        'sleepDebtMinutes': sleepDebtMinutes,
      };

  factory RecoveryBreakdown.fromJson(Map<String, dynamic> json) {
    return RecoveryBreakdown(
      sleepContribution: (json['sleepContribution'] as num?)?.toDouble() ?? 0,
      hrvContribution: (json['hrvContribution'] as num?)?.toDouble() ?? 0,
      rhrContribution: (json['rhrContribution'] as num?)?.toDouble() ?? 0,
      spo2Contribution: (json['spo2Contribution'] as num?)?.toDouble() ?? 0,
      sleepNeededMinutes: (json['sleepNeededMinutes'] as num?)?.toInt() ?? 480,
      sleepDebtMinutes: (json['sleepDebtMinutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class InsightItem {
  const InsightItem({
    required this.title,
    required this.body,
    required this.category,
  });

  final String title;
  final String body;
  final String category; // recovery | sleep | strain | stress | cardio

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'category': category,
      };

  factory InsightItem.fromJson(Map<String, dynamic> json) {
    return InsightItem(
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      category: '${json['category'] ?? 'recovery'}',
    );
  }
}

class WeeklyReport {
  const WeeklyReport({
    required this.start,
    required this.end,
    required this.avgRecovery,
    required this.avgStrain,
    required this.avgSleepScore,
    required this.avgSleepMinutes,
    required this.totalSteps,
    required this.totalWorkouts,
    required this.avgStress,
    required this.avgReadiness,
    required this.bestRecoveryDay,
    required this.hardestStrainDay,
    required this.insights,
  });

  final DateTime start;
  final DateTime end;
  final double avgRecovery;
  final double avgStrain;
  final double avgSleepScore;
  final double avgSleepMinutes;
  final int totalSteps;
  final int totalWorkouts;
  final double avgStress;
  final double avgReadiness;
  final String bestRecoveryDay;
  final String hardestStrainDay;
  final List<InsightItem> insights;
}

class JournalEntry {
  const JournalEntry({
    required this.dateKey,
    this.alcohol = false,
    this.caffeineLate = false,
    this.lateMeal = false,
    this.highStress = false,
    this.hydrated = false,
    this.meditated = false,
    this.sick = false,
    this.travel = false,
    this.menstrual = false,
    this.notes = '',
  });

  final String dateKey;
  final bool alcohol;
  final bool caffeineLate;
  final bool lateMeal;
  final bool highStress;
  final bool hydrated;
  final bool meditated;
  final bool sick;
  final bool travel;
  final bool menstrual;
  final String notes;

  JournalEntry copyWith({
    bool? alcohol,
    bool? caffeineLate,
    bool? lateMeal,
    bool? highStress,
    bool? hydrated,
    bool? meditated,
    bool? sick,
    bool? travel,
    bool? menstrual,
    String? notes,
  }) {
    return JournalEntry(
      dateKey: dateKey,
      alcohol: alcohol ?? this.alcohol,
      caffeineLate: caffeineLate ?? this.caffeineLate,
      lateMeal: lateMeal ?? this.lateMeal,
      highStress: highStress ?? this.highStress,
      hydrated: hydrated ?? this.hydrated,
      meditated: meditated ?? this.meditated,
      sick: sick ?? this.sick,
      travel: travel ?? this.travel,
      menstrual: menstrual ?? this.menstrual,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'alcohol': alcohol,
        'caffeineLate': caffeineLate,
        'lateMeal': lateMeal,
        'highStress': highStress,
        'hydrated': hydrated,
        'meditated': meditated,
        'sick': sick,
        'travel': travel,
        'menstrual': menstrual,
        'notes': notes,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      dateKey: '${json['dateKey']}',
      alcohol: json['alcohol'] == true,
      caffeineLate: json['caffeineLate'] == true,
      lateMeal: json['lateMeal'] == true,
      highStress: json['highStress'] == true,
      hydrated: json['hydrated'] == true,
      meditated: json['meditated'] == true,
      sick: json['sick'] == true,
      travel: json['travel'] == true,
      menstrual: json['menstrual'] == true,
      notes: '${json['notes'] ?? ''}',
    );
  }

  static String keyFor(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class GuidedProgram {
  const GuidedProgram({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.durationLabel,
    required this.category,
  });

  final String id;
  final String title;
  final String subtitle;
  final String durationLabel;
  final String category;
}
