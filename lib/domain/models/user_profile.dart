class UserProfile {
  const UserProfile({
    this.displayName,
    this.ageYears,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.useMetric = true,
  });

  final String? displayName;
  final int? ageYears;
  final BiologicalSex? sex;
  final double? heightCm;
  final double? weightKg;
  final bool useMetric;

  static const empty = UserProfile(useMetric: true);

  bool get isComplete =>
      ageYears != null && heightCm != null && weightKg != null;

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final m = heightCm! / 100.0;
    return weightKg! / (m * m);
  }

  /// Fox formula used for zone / strain estimates.
  double? get estimatedMaxHeartRate {
    if (ageYears == null) return null;
    return (220 - ageYears!).toDouble();
  }

  /// Age-adjusted sleep need baseline (minutes).
  int get sleepNeedBaselineMinutes {
    final age = ageYears ?? 30;
    if (age < 18) return 9 * 60;
    if (age < 26) return 8 * 60 + 30;
    if (age < 65) return 8 * 60;
    return 7 * 60 + 30;
  }

  UserProfile copyWith({
    String? displayName,
    int? ageYears,
    BiologicalSex? sex,
    double? heightCm,
    double? weightKg,
    bool? useMetric,
    bool clearSex = false,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      ageYears: ageYears ?? this.ageYears,
      sex: clearSex ? null : (sex ?? this.sex),
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      useMetric: useMetric ?? this.useMetric,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'ageYears': ageYears,
        'sex': sex?.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'useMetric': useMetric,
      };

  factory UserProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    final sexName = json['sex'] as String?;
    BiologicalSex? sex;
    if (sexName != null) {
      for (final value in BiologicalSex.values) {
        if (value.name == sexName) sex = value;
      }
    }
    return UserProfile(
      displayName: json['displayName'] as String?,
      ageYears: (json['ageYears'] as num?)?.toInt(),
      sex: sex,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      useMetric: json['useMetric'] as bool? ?? true,
    );
  }
}

enum BiologicalSex { female, male, other }
