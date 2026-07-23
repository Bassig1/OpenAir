import '../models/day_summary.dart';
import '../models/user_profile.dart';

/// Daily / week / month rollups for recovery, sleep performance, and HRV.
class PeriodAnalytics {
  const PeriodAnalytics();

  PeriodSummary daily(DaySummary day, UserProfile profile) {
    final sleep = _sleepPerf(day, profile);
    return PeriodSummary(
      label: 'Daily',
      start: day.date,
      end: day.date,
      dayCount: 1,
      avgRecovery: day.recoveryScore ?? 0,
      avgStrain: day.strainScore ?? 0,
      avgSleepPerformance: sleep,
      avgSleepMinutes: day.sleepMinutes.toDouble(),
      avgHrv: day.hrvMs,
      avgRhr: day.restingHeartRate,
      avgReadiness: day.readinessScore ?? 0,
      avgStress: day.stressScore ?? 0,
      totalSteps: day.steps,
      totalWorkouts: day.exercises.length,
      hrvTrend: '—',
      recoveryTrend: '—',
      sleepTrend: '—',
      summary:
          'Today · recovery ${(day.recoveryScore ?? 0).toStringAsFixed(0)} · '
          'sleep perf ${sleep.toStringAsFixed(0)}% · '
          'HRV ${day.hrvMs?.toStringAsFixed(0) ?? '—'} ms',
    );
  }

  PeriodSummary week(List<DaySummary> days, UserProfile profile) {
    return _build(days, profile, label: 'Week', take: 7);
  }

  PeriodSummary month(List<DaySummary> days, UserProfile profile) {
    return _build(days, profile, label: 'Month', take: 30);
  }

  List<TrendPoint> hrvSeries(List<DaySummary> days, {int take = 30}) {
    final slice = _slice(days, take);
    return [
      for (final d in slice)
        if (d.hrvMs != null)
          TrendPoint(date: d.date, value: d.hrvMs!),
    ];
  }

  List<TrendPoint> sleepPerformanceSeries(
    List<DaySummary> days,
    UserProfile profile, {
    int take = 30,
  }) {
    final slice = _slice(days, take);
    return [
      for (final d in slice)
        TrendPoint(date: d.date, value: _sleepPerf(d, profile)),
    ];
  }

  List<TrendPoint> recoverySeries(List<DaySummary> days, {int take = 30}) {
    final slice = _slice(days, take);
    return [
      for (final d in slice)
        TrendPoint(date: d.date, value: d.recoveryScore ?? 0),
    ];
  }

  HrvTrendReport hrvReport(List<DaySummary> days) {
    final withHrv = days.where((d) => d.hrvMs != null).toList();
    if (withHrv.isEmpty) {
      return const HrvTrendReport(
        latest: null,
        weekAvg: null,
        monthAvg: null,
        baseline: null,
        weekDelta: null,
        monthDelta: null,
        trendLabel: 'No HRV yet',
        summary: 'HRV appears after your wearable syncs overnight data.',
      );
    }
    final latest = withHrv.last.hrvMs!;
    final week = _avg(withHrv.length > 7
        ? withHrv.sublist(withHrv.length - 7)
        : withHrv);
    final month = _avg(withHrv.length > 30
        ? withHrv.sublist(withHrv.length - 30)
        : withHrv);
    final baseline = _avg(withHrv.length > 14
        ? withHrv.sublist(0, withHrv.length - 1)
        : withHrv);
    final weekDelta = week == null ? null : latest - week;
    final monthDelta = month == null ? null : latest - month;
    final trend = weekDelta == null
        ? 'stable'
        : weekDelta > 3
            ? 'rising'
            : weekDelta < -3
                ? 'falling'
                : 'stable';
    return HrvTrendReport(
      latest: latest,
      weekAvg: week,
      monthAvg: month,
      baseline: baseline,
      weekDelta: weekDelta,
      monthDelta: monthDelta,
      trendLabel: trend,
      summary:
          'HRV ${latest.toStringAsFixed(0)} ms · 7d avg ${week?.toStringAsFixed(0) ?? '—'} · '
          '30d avg ${month?.toStringAsFixed(0) ?? '—'} · trend $trend vs your baseline '
          '${baseline?.toStringAsFixed(0) ?? '—'} ms.',
    );
  }

  PeriodSummary _build(
    List<DaySummary> days,
    UserProfile profile, {
    required String label,
    required int take,
  }) {
    final slice = _slice(days, take);
    if (slice.isEmpty) {
      final now = DateTime.now();
      return PeriodSummary(
        label: label,
        start: now,
        end: now,
        dayCount: 0,
        avgRecovery: 0,
        avgStrain: 0,
        avgSleepPerformance: 0,
        avgSleepMinutes: 0,
        avgHrv: null,
        avgRhr: null,
        avgReadiness: 0,
        avgStress: 0,
        totalSteps: 0,
        totalWorkouts: 0,
        hrvTrend: '—',
        recoveryTrend: '—',
        sleepTrend: '—',
        summary: 'No data for this period yet.',
      );
    }

    double avg(double Function(DaySummary d) f) =>
        slice.map(f).reduce((a, b) => a + b) / slice.length;

    final hrvVals = slice.where((d) => d.hrvMs != null).map((d) => d.hrvMs!);
    final rhrVals =
        slice.where((d) => d.restingHeartRate != null).map((d) => d.restingHeartRate!);

    final recoveryTrend = _trendLabel(slice.map((d) => d.recoveryScore ?? 0).toList());
    final sleepTrend =
        _trendLabel(slice.map((d) => _sleepPerf(d, profile)).toList());
    final hrvTrend = _trendLabel(hrvVals.toList());

    final avgSleepPerf = avg((d) => _sleepPerf(d, profile));
    final avgHrv = hrvVals.isEmpty
        ? null
        : hrvVals.reduce((a, b) => a + b) / hrvVals.length;
    final avgRhr = rhrVals.isEmpty
        ? null
        : rhrVals.reduce((a, b) => a + b) / rhrVals.length;

    return PeriodSummary(
      label: label,
      start: slice.first.date,
      end: slice.last.date,
      dayCount: slice.length,
      avgRecovery: _r(avg((d) => d.recoveryScore ?? 0)),
      avgStrain: _r(avg((d) => d.strainScore ?? 0)),
      avgSleepPerformance: _r(avgSleepPerf),
      avgSleepMinutes: avg((d) => d.sleepMinutes.toDouble()),
      avgHrv: avgHrv == null ? null : _r(avgHrv),
      avgRhr: avgRhr == null ? null : _r(avgRhr),
      avgReadiness: _r(avg((d) => d.readinessScore ?? 0)),
      avgStress: _r(avg((d) => d.stressScore ?? 0)),
      totalSteps: slice.fold<int>(0, (a, d) => a + d.steps),
      totalWorkouts: slice.fold<int>(0, (a, d) => a + d.exercises.length),
      hrvTrend: hrvTrend,
      recoveryTrend: recoveryTrend,
      sleepTrend: sleepTrend,
      summary:
          '$label · recovery ${_r(avg((d) => d.recoveryScore ?? 0)).toStringAsFixed(0)} · '
          'sleep perf ${_r(avgSleepPerf).toStringAsFixed(0)}% · '
          'HRV ${avgHrv?.toStringAsFixed(0) ?? '—'} ms ($hrvTrend)',
    );
  }

  List<DaySummary> _slice(List<DaySummary> days, int take) {
    final sorted = [...days]..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.length <= take) return sorted;
    return sorted.sublist(sorted.length - take);
  }

  double _sleepPerf(DaySummary day, UserProfile profile) {
    final need = day.sleepNeededMinutes ?? profile.sleepNeedBaselineMinutes;
    if (need <= 0) return 0;
    return ((day.sleepMinutes / need) * 100).clamp(0.0, 100.0);
  }

  double? _avg(List<DaySummary> days) {
    final vals = days.where((d) => d.hrvMs != null).map((d) => d.hrvMs!).toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  String _trendLabel(List<double> values) {
    if (values.length < 2) return 'stable';
    final mid = values.length ~/ 2;
    final first = values.sublist(0, mid);
    final second = values.sublist(mid);
    if (first.isEmpty || second.isEmpty) return 'stable';
    final a = first.reduce((x, y) => x + y) / first.length;
    final b = second.reduce((x, y) => x + y) / second.length;
    final delta = b - a;
    if (delta > 2) return 'rising';
    if (delta < -2) return 'falling';
    return 'stable';
  }

  double _r(double v) => double.parse(v.toStringAsFixed(1));
}

class PeriodSummary {
  const PeriodSummary({
    required this.label,
    required this.start,
    required this.end,
    required this.dayCount,
    required this.avgRecovery,
    required this.avgStrain,
    required this.avgSleepPerformance,
    required this.avgSleepMinutes,
    required this.avgHrv,
    required this.avgRhr,
    required this.avgReadiness,
    required this.avgStress,
    required this.totalSteps,
    required this.totalWorkouts,
    required this.hrvTrend,
    required this.recoveryTrend,
    required this.sleepTrend,
    required this.summary,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final int dayCount;
  final double avgRecovery;
  final double avgStrain;
  final double avgSleepPerformance;
  final double avgSleepMinutes;
  final double? avgHrv;
  final double? avgRhr;
  final double avgReadiness;
  final double avgStress;
  final int totalSteps;
  final int totalWorkouts;
  final String hrvTrend;
  final String recoveryTrend;
  final String sleepTrend;
  final String summary;
}

class TrendPoint {
  const TrendPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

class HrvTrendReport {
  const HrvTrendReport({
    required this.latest,
    required this.weekAvg,
    required this.monthAvg,
    required this.baseline,
    required this.weekDelta,
    required this.monthDelta,
    required this.trendLabel,
    required this.summary,
  });

  final double? latest;
  final double? weekAvg;
  final double? monthAvg;
  final double? baseline;
  final double? weekDelta;
  final double? monthDelta;
  final String trendLabel;
  final String summary;
}
