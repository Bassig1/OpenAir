import 'dart:math' as math;

import '../models/day_summary.dart';
import '../models/health_extras.dart';
import '../models/user_profile.dart';

/// Advanced recovery analysis derived from wearable cloud metrics.
class AdvancedAnalysis {
  const AdvancedAnalysis();

  SleepAnalysis sleep(
    DaySummary day, {
    UserProfile profile = UserProfile.empty,
    List<DaySummary> history = const [],
  }) {
    final asleep = day.deepSleepMinutes +
        day.remSleepMinutes +
        day.lightSleepMinutes;
    final totalInBed = asleep + day.awakeMinutes;
    final efficiency = totalInBed <= 0
        ? 0.0
        : (asleep / totalInBed * 100).clamp(0.0, 100.0);
    final restorative = day.deepSleepMinutes + day.remSleepMinutes;
    final restorativePct =
        asleep <= 0 ? 0.0 : (restorative / asleep * 100).clamp(0.0, 100.0);
    final need = day.sleepNeededMinutes ?? profile.sleepNeedBaselineMinutes;
    // Primary sleep performance (hours asleep vs need), capped at 100.
    final hoursVsNeed =
        need <= 0 ? 0.0 : (day.sleepMinutes / need * 100).clamp(0.0, 100.0);
    final consistency = _sleepConsistency(day, history);
    // Composite mirrors multi-factor coaching: duration + efficiency + stages + consistency.
    final performance = double.parse(
      ((hoursVsNeed * 0.55) +
              (efficiency * 0.20) +
              (restorativePct * 0.15) +
              (consistency * 0.10))
          .clamp(0.0, 100.0)
          .toStringAsFixed(1),
    );
    return SleepAnalysis(
      efficiencyPercent: double.parse(efficiency.toStringAsFixed(1)),
      restorativeMinutes: restorative,
      restorativePercent: double.parse(restorativePct.toStringAsFixed(1)),
      deepPercent: asleep <= 0
          ? 0
          : double.parse(
              ((day.deepSleepMinutes / asleep) * 100).toStringAsFixed(1),
            ),
      remPercent: asleep <= 0
          ? 0
          : double.parse(
              ((day.remSleepMinutes / asleep) * 100).toStringAsFixed(1),
            ),
      lightPercent: asleep <= 0
          ? 0
          : double.parse(
              ((day.lightSleepMinutes / asleep) * 100).toStringAsFixed(1),
            ),
      awakePercent: totalInBed <= 0
          ? 0
          : double.parse(
              ((day.awakeMinutes / totalInBed) * 100).toStringAsFixed(1),
            ),
      disturbanceCount: (day.awakeMinutes / 8).round().clamp(0, 30),
      performance: performance,
      hoursVsNeedPercent: double.parse(hoursVsNeed.toStringAsFixed(1)),
      consistencyPercent: double.parse(consistency.toStringAsFixed(1)),
      neededMinutes: need,
      debtMinutes: day.sleepDebtMinutes ?? (need - day.sleepMinutes),
      consistencyLabel: consistency >= 85
          ? 'Excellent consistency'
          : consistency >= 70
              ? 'Solid overnight consistency'
              : consistency >= 55
                  ? 'Fair — schedule drifting'
                  : 'Poor continuity — stabilize bedtime',
      summary: _sleepSummary(
        day: day,
        efficiency: efficiency,
        restorativePct: restorativePct,
        asleep: asleep,
        hoursVsNeed: hoursVsNeed,
        performance: performance,
      ),
    );
  }

  double _sleepConsistency(DaySummary day, List<DaySummary> history) {
    final recent = [
      ...history.where((d) => d.sleepMinutes > 0).map((d) => d.sleepMinutes),
      if (day.sleepMinutes > 0) day.sleepMinutes,
    ];
    if (recent.length < 2) return 75;
    final avg = recent.reduce((a, b) => a + b) / recent.length;
    final variance = recent
            .map((m) => (m - avg) * (m - avg))
            .reduce((a, b) => a + b) /
        recent.length;
    final std = variance <= 0 ? 0.0 : math.sqrt(variance);
    // Lower variance → higher consistency. ~45 min std ≈ mid score.
    final score = (100 - (std / 60 * 55)).clamp(20.0, 100.0);
    return score;
  }

  String _sleepSummary({
    required DaySummary day,
    required double efficiency,
    required double restorativePct,
    required int asleep,
    required double hoursVsNeed,
    required double performance,
  }) {
    final hrs = day.sleepMinutes ~/ 60;
    final mins = day.sleepMinutes % 60;
    final debt = day.sleepDebtMinutes ?? 0;
    final debtText = debt >= 15
        ? ' Sleep debt ~${debt}m.'
        : debt <= -15
            ? ' Banked ~${(-debt)}m.'
            : '';
    return 'You slept ${hrs}h ${mins.toString().padLeft(2, '0')}m '
        '(${hoursVsNeed.toStringAsFixed(0)}% of need) · '
        'Sleep performance ${performance.toStringAsFixed(0)}% · '
        'Efficiency ${efficiency.toStringAsFixed(0)}% · '
        'Restorative ${restorativePct.toStringAsFixed(0)}% '
        '(deep ${day.deepSleepMinutes}m / REM ${day.remSleepMinutes}m).'
        '$debtText';
  }

  WorkoutAnalysis workout(ExerciseSession session, {double? dayStrain}) {
    final duration = session.durationMinutes.clamp(1, 600);
    final intensity = session.avgHeartRate == null
        ? (session.perceivedExertion ?? 5) / 10.0
        : ((session.avgHeartRate! - 60) / 100).clamp(0.2, 1.2);
    final calorieFactor =
        session.calories == null ? duration * 7.0 : session.calories!;
    final strainDelta = double.parse(
      ((duration / 60.0) * intensity * 4.5 + (calorieFactor / 220))
          .clamp(0.3, 12.0)
          .toStringAsFixed(1),
    );
    final avgPace = session.paceMinPerKm;
    return WorkoutAnalysis(
      strainContribution: strainDelta,
      intensityLabel: intensity >= 0.85
          ? 'High intensity'
          : intensity >= 0.55
              ? 'Moderate intensity'
              : 'Easy / recovery',
      calorieEstimate: session.calories ?? calorieFactor,
      paceLabel: avgPace == null
          ? null
          : '${avgPace.floor()}:${((avgPace % 1) * 60).round().toString().padLeft(2, '0')}/km',
      distanceKm: session.distanceMeters == null
          ? null
          : session.distanceMeters! / 1000.0,
      recoveryTip: strainDelta >= 8
          ? 'Large load — prioritize sleep and easy movement next.'
          : strainDelta >= 4
              ? 'Solid session — keep hydration and protein on track.'
              : 'Light load — good for active recovery.',
      dayStrainAfter: dayStrain == null
          ? null
          : double.parse((dayStrain + strainDelta).clamp(0, 21).toStringAsFixed(1)),
    );
  }

  UnusualHeartEvent? detectUnusualHeart({
    required DaySummary day,
    required List<DaySummary> history,
  }) {
    final baselines = history
        .where((d) => d.restingHeartRate != null)
        .map((d) => d.restingHeartRate!)
        .toList();
    if (baselines.isEmpty && day.restingHeartRate == null) return null;
    final baseline = baselines.isEmpty
        ? day.restingHeartRate!
        : baselines.reduce((a, b) => a + b) / baselines.length;

    double? spike;
    for (final s in day.heartSamples) {
      if (s.value >= baseline + 35 && (spike == null || s.value > spike)) {
        spike = s.value;
      }
    }
    if (day.restingHeartRate != null &&
        day.restingHeartRate! >= baseline + 12) {
      spike = day.restingHeartRate;
    }
    if (spike == null) return null;
    return UnusualHeartEvent(
      bpm: spike,
      baselineBpm: baseline,
      reason: spike >= baseline + 35
          ? 'Elevated reading vs your recent resting baseline'
          : 'Resting HR elevated vs your recent average',
    );
  }

  HeartbeatAnalysis heartbeat(DaySummary day, List<DaySummary> history) {
    final samples = day.heartSamples;
    double? minHr;
    double? maxHr;
    if (samples.isNotEmpty) {
      minHr = samples.map((s) => s.value).reduce((a, b) => a < b ? a : b);
      maxHr = samples.map((s) => s.value).reduce((a, b) => a > b ? a : b);
    }
    final hrvTrend = _trend(
      history.where((d) => d.hrvMs != null).map((d) => d.hrvMs!).toList(),
    );
    final rhrTrend = _trend(
      history
          .where((d) => d.restingHeartRate != null)
          .map((d) => d.restingHeartRate!)
          .toList(),
    );
    return HeartbeatAnalysis(
      restingHr: day.restingHeartRate,
      avgHr: day.avgHeartRate,
      maxHr: maxHr ?? day.maxHeartRate,
      minHr: minHr ?? day.minHeartRate,
      hrvMs: day.hrvMs,
      hrvTrend: hrvTrend,
      rhrTrend: rhrTrend,
      zoneMinutes: day.zoneMinutes,
      fatBurnMinutes: day.heartRateZones?.fatBurnMinutes ?? 0,
      cardioMinutes: day.heartRateZones?.cardioMinutes ?? 0,
      peakMinutes: day.heartRateZones?.peakMinutes ?? 0,
    );
  }

  OxygenAnalysis oxygen(DaySummary day) {
    final samples = day.spo2Samples;
    double? min;
    double? max;
    if (samples.isNotEmpty) {
      min = samples.map((s) => s.value).reduce((a, b) => a < b ? a : b);
      max = samples.map((s) => s.value).reduce((a, b) => a > b ? a : b);
    }
    final avg = day.spo2Percent;
    final status = avg == null
        ? 'No data'
        : avg >= 97
            ? 'Optimal'
            : avg >= 95
                ? 'Normal'
                : avg >= 93
                    ? 'Low-normal'
                    : 'Low — verify sensor reading';
    return OxygenAnalysis(
      averagePercent: avg,
      minPercent: min,
      maxPercent: max,
      sampleCount: samples.length,
      statusLabel: status,
      respiratoryRate: day.respiratoryRate,
    );
  }

  /// Day strain breakdown — what drove the 0–21 score and what capacity remains.
  StrainDayAnalysis strain(DaySummary day, {UserProfile profile = UserProfile.empty}) {
    final score = day.strainScore ?? 0;
    final remaining = (21 - score).clamp(0.0, 21.0);
    final zone = score >= 14
        ? 'High'
        : score >= 8
            ? 'Moderate'
            : score >= 3
                ? 'Low'
                : 'Rest';
    final fromZones = (day.zoneMinutes / 45) * 8;
    final fromCalories = (day.activeCalories / 600) * 5;
    final fromSteps = (day.steps / 12000) * 3;
    final fromMinutes = (day.activeMinutes / 120) * 3;
    final fromWorkouts = (day.exercises.length * 1.8).clamp(0.0, 5.0);
    final parts = <({String label, double value, String detail})>[
      (
        label: 'Active zone min',
        value: fromZones.clamp(0, 21),
        detail: '${day.zoneMinutes} AZM',
      ),
      (
        label: 'Active calories',
        value: fromCalories.clamp(0, 21),
        detail: '${day.activeCalories.round()} kcal',
      ),
      (
        label: 'Steps',
        value: fromSteps.clamp(0, 21),
        detail: '${day.steps} steps',
      ),
      (
        label: 'Active minutes',
        value: fromMinutes.clamp(0, 21),
        detail: '${day.activeMinutes} min',
      ),
      (
        label: 'Workouts',
        value: fromWorkouts,
        detail: day.exercises.isEmpty
            ? 'None logged'
            : '${day.exercises.length} session(s)',
      ),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final hasSignal = day.steps > 0 ||
        day.activeCalories > 0 ||
        day.zoneMinutes > 0 ||
        day.activeMinutes > 0 ||
        day.exercises.isNotEmpty;

    final summary = !hasSignal
        ? 'No activity synced from Google Health for this day yet. '
            'Open the Fitbit app, wait for sync, then pull to refresh.'
        : 'Strain ${score.toStringAsFixed(1)} / 21 ($zone). '
            'Top drivers: ${parts.take(2).map((p) => '${p.label} (${p.detail})').join(', ')}. '
            '${remaining.toStringAsFixed(1)} strain capacity left'
            '${score < 8 ? ' — room for a focused session.' : score < 14 ? ' — train with intent.' : ' — prioritize recovery.'}';

    return StrainDayAnalysis(
      score: score,
      remaining: double.parse(remaining.toStringAsFixed(1)),
      zoneLabel: zone,
      summary: summary,
      hasActivity: hasSignal,
      contributions: parts
          .map(
            (p) => StrainContribution(
              label: p.label,
              points: double.parse(p.value.toStringAsFixed(1)),
              detail: p.detail,
            ),
          )
          .toList(),
    );
  }

  SyncHealth assessSync({
    required List<DaySummary> days,
    required DateTime? lastSyncedAt,
    required bool connected,
  }) {
    if (!connected) {
      return SyncHealth(
        status: SyncStatus.disconnected,
        message: 'Connect Google Health once — OpenAir will remember your session.',
        missingDayCount: 0,
        dataLag: null,
        lastSyncedAt: lastSyncedAt,
      );
    }
    if (days.isEmpty) {
      return SyncHealth(
        status: SyncStatus.gap,
        message:
            'Connected, waiting for cloud days. Open the Fitbit app near your watch, then pull to refresh.',
        missingDayCount: 14,
        dataLag: null,
        lastSyncedAt: lastSyncedAt,
      );
    }

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    var missing = 0;
    for (var i = 0; i < 7; i++) {
      final d = todayDay.subtract(Duration(days: i));
      final has = days.any(
        (x) =>
            x.date.year == d.year &&
            x.date.month == d.month &&
            x.date.day == d.day &&
            (x.steps > 0 || x.sleepMinutes > 0 || x.hrvMs != null || x.restingHeartRate != null),
      );
      if (!has) missing++;
    }

    DateTime? latestPoint = lastSyncedAt;
    for (final day in days) {
      for (final s in day.heartSamples) {
        if (latestPoint == null || s.time.isAfter(latestPoint)) {
          latestPoint = s.time;
        }
      }
      if (day.exercises.isNotEmpty) {
        for (final e in day.exercises) {
          if (latestPoint == null || e.end.isAfter(latestPoint)) {
            latestPoint = e.end;
          }
        }
      }
    }

    final lag = latestPoint == null ? null : today.difference(latestPoint);
    final stale = lag != null && lag > const Duration(hours: 12);
    final status = missing >= 4 || stale ? SyncStatus.gap : SyncStatus.ok;
    final message = status == SyncStatus.ok
        ? 'Summary from your Google Health cloud feed.'
        : stale
            ? 'Last cloud update looks old (${lag.inHours}h). Open Fitbit near your watch, then refresh.'
            : 'Thin coverage on $missing of the last 7 days — sync Fitbit, then refresh.';

    return SyncHealth(
      status: status,
      message: message,
      missingDayCount: missing,
      dataLag: lag,
      lastSyncedAt: lastSyncedAt,
      latestDataAt: latestPoint,
    );
  }

  /// Deep daily coaching brief derived from Google Health aggregates.
  DayBriefing briefing({
    required DaySummary day,
    required List<DaySummary> history,
    UserProfile profile = UserProfile.empty,
  }) {
    final sleep = this.sleep(day, profile: profile, history: history);
    final heart = heartbeat(day, history);
    final recovery = day.recoveryScore ?? 0;
    final strain = day.strainScore ?? 0;
    final stress = day.stressScore ?? 40;
    final readiness = day.readinessScore ?? recovery;
    final remainingStrain = (21 - strain).clamp(0.0, 21.0);

    final hrvBaseline = _avgOrNull(
      history.where((d) => d.hrvMs != null).map((d) => d.hrvMs!),
    );
    final rhrBaseline = _avgOrNull(
      history.where((d) => d.restingHeartRate != null).map((d) => d.restingHeartRate!),
    );

    final recoveryZone = recovery >= 67
        ? 'Green'
        : recovery >= 34
            ? 'Yellow'
            : 'Red';
    final strainTarget = recovery >= 67
        ? 'Aim up to ${(strain + remainingStrain * 0.85).clamp(8.0, 18.0).toStringAsFixed(0)} strain'
        : recovery >= 34
            ? 'Cap near ${(8 + remainingStrain * 0.35).clamp(5.0, 12.0).toStringAsFixed(0)} strain'
            : 'Keep strain light — prioritize recovery work';

    final headline = recovery >= 67
        ? 'Recovered and ready to push.'
        : recovery >= 34
            ? 'Mixed recovery — train with intent.'
            : 'Body needs restoration today.';

    final coaching = StringBuffer()
      ..writeln(
        'Recovery zone: $recoveryZone '
        '(${recovery.toStringAsFixed(0)} / 100, readiness ${readiness.toStringAsFixed(0)}).',
      )
      ..writeln(
        'Sleep: ${_hm(day.sleepMinutes)} vs ${_hm(sleep.neededMinutes)} need '
        '(${sleep.hoursVsNeedPercent.toStringAsFixed(0)}% of target). '
        'Performance ${sleep.performance.toStringAsFixed(0)}% · '
        'efficiency ${sleep.efficiencyPercent.toStringAsFixed(0)}% · '
        'restorative ${sleep.restorativePercent.toStringAsFixed(0)}% '
        '(deep ${day.deepSleepMinutes}m / REM ${day.remSleepMinutes}m). '
        '${sleep.consistencyLabel}.',
      );
    if (hrvBaseline != null && day.hrvMs != null) {
      final delta = day.hrvMs! - hrvBaseline;
      coaching.writeln(
        'Autonomic: HRV ${day.hrvMs!.round()} ms '
        '(${delta >= 0 ? '+' : ''}${delta.round()} vs baseline '
        '${hrvBaseline.round()} ms) · ${heart.hrvTrend}.',
      );
    } else if (day.hrvMs != null) {
      coaching.writeln(
        'Autonomic: HRV ${day.hrvMs!.round()} ms · ${heart.hrvTrend}.',
      );
    }
    if (rhrBaseline != null && day.restingHeartRate != null) {
      final delta = day.restingHeartRate! - rhrBaseline;
      coaching.writeln(
        'Resting HR ${day.restingHeartRate!.round()} bpm '
        '(${delta >= 0 ? '+' : ''}${delta.round()} vs baseline) · ${heart.rhrTrend}.',
      );
    } else if (day.restingHeartRate != null) {
      coaching.writeln(
        'Resting HR ${day.restingHeartRate!.round()} bpm · ${heart.rhrTrend}.',
      );
    }
    if (day.spo2Percent != null || day.respiratoryRate != null) {
      final bits = <String>[
        if (day.spo2Percent != null)
          'SpO₂ ${day.spo2Percent!.toStringAsFixed(1)}%',
        if (day.respiratoryRate != null)
          'resp ${day.respiratoryRate!.toStringAsFixed(1)} br/min',
        if (day.skinTempDeviation != null)
          'skin Δ ${day.skinTempDeviation!.toStringAsFixed(2)}°',
      ];
      coaching.writeln('Overnight vitals: ${bits.join(' · ')}.');
    }
    coaching.writeln(
      'Strain ${strain.toStringAsFixed(1)} / 21 '
      '(${remainingStrain.toStringAsFixed(1)} remaining) · '
      'stress ${stress.toStringAsFixed(0)}. $strainTarget.',
    );

    final actions = <String>[
      if (recovery < 34)
        'Keep intensity easy; walk, mobility, or short Zone 2 only.'
      else if (recovery < 67)
        'One quality session is fine — avoid stacking hard intervals + late nights.'
      else
        'Green light for a key workout if sleep stays on track tonight.',
      if (sleep.debtMinutes >= 45)
        'Protect bedtime tonight — sleep debt is ~${sleep.debtMinutes}m.'
      else if (sleep.performance < 70)
        'Raise sleep performance: consistent lights-out and less late caffeine.',
      if (stress >= 65)
        'High stress load — add a wind-down (walk, breathwork, earlier dinner).',
      if (day.exercises.isEmpty && recovery >= 50)
        'No workout logged yet — a structured session can use remaining strain capacity.',
      if ((day.sedentaryMinutes ?? 0) > 600)
        'Break up long sedentary blocks with short walks.',
    ];

    while (actions.length < 3) {
      actions.add('Hydrate and keep tonight’s bedtime within 30 minutes of your usual.');
      if (actions.length >= 3) break;
    }

    final drivers = <BriefDriver>[
      BriefDriver(
        label: 'Sleep',
        score: sleep.performance,
        detail:
            '${_hm(day.sleepMinutes)} · eff ${sleep.efficiencyPercent.toStringAsFixed(0)}% · '
            'restorative ${sleep.restorativePercent.toStringAsFixed(0)}%',
      ),
      BriefDriver(
        label: 'HRV',
        score: heart.hrvMs == null
            ? 50
            : hrvBaseline == null || hrvBaseline <= 0
                ? 60
                : ((heart.hrvMs! / hrvBaseline) * 70).clamp(15, 95),
        detail: heart.hrvMs == null
            ? 'No HRV yet'
            : '${heart.hrvMs!.round()} ms · ${heart.hrvTrend}',
      ),
      BriefDriver(
        label: 'Resting HR',
        score: heart.restingHr == null
            ? 50
            : rhrBaseline == null
                ? 60
                : (50 + (rhrBaseline - heart.restingHr!) * 3).clamp(15, 95),
        detail: heart.restingHr == null
            ? 'No RHR yet'
            : '${heart.restingHr!.round()} bpm · ${heart.rhrTrend}',
      ),
      BriefDriver(
        label: 'Strain left',
        score: (remainingStrain / 21 * 100).clamp(5, 99),
        detail:
            '${strain.toStringAsFixed(1)} used · ${remainingStrain.toStringAsFixed(1)} remaining',
      ),
    ];

    return DayBriefing(
      headline: headline,
      coaching: coaching.toString().trim(),
      recoveryZone: recoveryZone,
      strainTarget: strainTarget,
      remainingStrain: double.parse(remainingStrain.toStringAsFixed(1)),
      sleepPerformance: sleep.performance,
      readiness: readiness,
      stress: stress,
      actions: actions.take(4).toList(),
      drivers: drivers,
    );
  }

  double? _avgOrNull(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _trend(List<double> values) {
    if (values.length < 2) return 'stable';
    final recent = values.sublist(values.length - 2);
    final delta = recent.last - recent.first;
    if (delta > 2) return 'rising';
    if (delta < -2) return 'falling';
    return 'stable';
  }
}

class SleepAnalysis {
  const SleepAnalysis({
    required this.efficiencyPercent,
    required this.restorativeMinutes,
    required this.restorativePercent,
    required this.deepPercent,
    required this.remPercent,
    required this.lightPercent,
    required this.awakePercent,
    required this.disturbanceCount,
    required this.performance,
    required this.hoursVsNeedPercent,
    required this.consistencyPercent,
    required this.neededMinutes,
    required this.debtMinutes,
    required this.consistencyLabel,
    required this.summary,
  });

  final double efficiencyPercent;
  final int restorativeMinutes;
  final double restorativePercent;
  final double deepPercent;
  final double remPercent;
  final double lightPercent;
  /// Awake as % of time in bed (asleep + awake).
  final double awakePercent;
  final int disturbanceCount;
  final double performance;
  final double hoursVsNeedPercent;
  final double consistencyPercent;
  final int neededMinutes;
  final int debtMinutes;
  final String consistencyLabel;
  final String summary;
}

class HeartbeatAnalysis {
  const HeartbeatAnalysis({
    required this.restingHr,
    required this.avgHr,
    required this.maxHr,
    required this.minHr,
    required this.hrvMs,
    required this.hrvTrend,
    required this.rhrTrend,
    required this.zoneMinutes,
    required this.fatBurnMinutes,
    required this.cardioMinutes,
    required this.peakMinutes,
  });

  final double? restingHr;
  final double? avgHr;
  final double? maxHr;
  final double? minHr;
  final double? hrvMs;
  final String hrvTrend;
  final String rhrTrend;
  final int zoneMinutes;
  final int fatBurnMinutes;
  final int cardioMinutes;
  final int peakMinutes;
}

class OxygenAnalysis {
  const OxygenAnalysis({
    required this.averagePercent,
    required this.minPercent,
    required this.maxPercent,
    required this.sampleCount,
    required this.statusLabel,
    required this.respiratoryRate,
  });

  final double? averagePercent;
  final double? minPercent;
  final double? maxPercent;
  final int sampleCount;
  final String statusLabel;
  final double? respiratoryRate;
}

class StrainDayAnalysis {
  const StrainDayAnalysis({
    required this.score,
    required this.remaining,
    required this.zoneLabel,
    required this.summary,
    required this.hasActivity,
    required this.contributions,
  });

  final double score;
  final double remaining;
  final String zoneLabel;
  final String summary;
  final bool hasActivity;
  final List<StrainContribution> contributions;
}

class StrainContribution {
  const StrainContribution({
    required this.label,
    required this.points,
    required this.detail,
  });

  final String label;
  final double points;
  final String detail;
}

enum SyncStatus { ok, gap, disconnected }

class SyncHealth {
  const SyncHealth({
    required this.status,
    required this.message,
    required this.missingDayCount,
    required this.dataLag,
    required this.lastSyncedAt,
    this.latestDataAt,
  });

  final SyncStatus status;
  final String message;
  final int missingDayCount;
  final Duration? dataLag;
  final DateTime? lastSyncedAt;
  final DateTime? latestDataAt;
}

class DayBriefing {
  const DayBriefing({
    required this.headline,
    required this.coaching,
    required this.recoveryZone,
    required this.strainTarget,
    required this.remainingStrain,
    required this.sleepPerformance,
    required this.readiness,
    required this.stress,
    required this.actions,
    required this.drivers,
  });

  final String headline;
  final String coaching;
  final String recoveryZone;
  final String strainTarget;
  final double remainingStrain;
  final double sleepPerformance;
  final double readiness;
  final double stress;
  final List<String> actions;
  final List<BriefDriver> drivers;
}

class BriefDriver {
  const BriefDriver({
    required this.label,
    required this.score,
    required this.detail,
  });

  final String label;
  final double score;
  final String detail;
}

class WorkoutAnalysis {
  const WorkoutAnalysis({
    required this.strainContribution,
    required this.intensityLabel,
    required this.calorieEstimate,
    required this.paceLabel,
    required this.distanceKm,
    required this.recoveryTip,
    required this.dayStrainAfter,
  });

  final double strainContribution;
  final String intensityLabel;
  final double calorieEstimate;
  final String? paceLabel;
  final double? distanceKm;
  final String recoveryTip;
  final double? dayStrainAfter;
}

class UnusualHeartEvent {
  const UnusualHeartEvent({
    required this.bpm,
    required this.baselineBpm,
    required this.reason,
  });

  final double bpm;
  final double baselineBpm;
  final String reason;
}
