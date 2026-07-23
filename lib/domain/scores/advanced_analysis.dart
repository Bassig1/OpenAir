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
    return 'Sleep performance ${performance.toStringAsFixed(0)}% · '
        'hours vs need ${hoursVsNeed.toStringAsFixed(0)}% · '
        '${hrs}h ${mins.toString().padLeft(2, '0')}m · '
        'eff ${efficiency.toStringAsFixed(0)}% · '
        'restorative ${restorativePct.toStringAsFixed(0)}% '
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
      minHr: minHr,
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

  SyncHealth assessSync({
    required List<DaySummary> days,
    required DateTime? lastSyncedAt,
    required bool isLive,
  }) {
    if (!isLive) {
      return SyncHealth(
        status: SyncStatus.demo,
        message: 'Demo mode — connect cloud sync for live wearable data.',
        missingDayCount: 0,
        dataLag: null,
        lastSyncedAt: lastSyncedAt,
      );
    }
    if (days.isEmpty) {
      return SyncHealth(
        status: SyncStatus.gap,
        message: 'No cloud days yet. Open the Fitbit app to sync your device.',
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
            (x.steps > 0 || x.sleepMinutes > 0 || x.heartSamples.isNotEmpty),
      );
      if (!has) missing++;
    }

    DateTime? latestPoint;
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
    final stale = lag != null && lag > const Duration(hours: 3);
    final status = missing >= 3 || stale ? SyncStatus.gap : SyncStatus.live;
    final message = status == SyncStatus.live
        ? 'Live sync — matching your cloud fitness feed.'
        : stale
            ? 'Cloud data looks stale (${lag.inHours}h lag). Open your Fitbit app near the device.'
            : 'Missing $missing of last 7 days. Sync Fitbit app, then pull to refresh.';

    return SyncHealth(
      status: status,
      message: message,
      missingDayCount: missing,
      dataLag: lag,
      lastSyncedAt: lastSyncedAt,
      latestDataAt: latestPoint,
    );
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

enum SyncStatus { live, gap, demo }

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
