import '../models/day_summary.dart';
import '../models/health_extras.dart';

/// Whoop-style advanced analysis derived from Fitbit/Google Health metrics.
class AdvancedAnalysis {
  const AdvancedAnalysis();

  SleepAnalysis sleep(DaySummary day) {
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
      performance: day.sleepScore ?? 0,
      neededMinutes: day.sleepNeededMinutes ?? 480,
      debtMinutes: day.sleepDebtMinutes ?? 0,
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
                    : 'Low — check Fitbit reading';
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
        message: 'Demo mode — connect Google Health for live Fitbit cloud data.',
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
        ? 'Live with Google Health — matching Fitbit cloud feed.'
        : stale
            ? 'Cloud data looks stale (${lag!.inHours}h lag). Open Fitbit app near your device.'
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
    required this.neededMinutes,
    required this.debtMinutes,
  });

  final double efficiencyPercent;
  final int restorativeMinutes;
  final double restorativePercent;
  final double deepPercent;
  final double remPercent;
  final double lightPercent;
  final int disturbanceCount;
  final double performance;
  final int neededMinutes;
  final int debtMinutes;
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
