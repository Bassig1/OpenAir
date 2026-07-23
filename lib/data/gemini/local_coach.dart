import '../../domain/models/day_summary.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/scores/advanced_analysis.dart';
import '../../domain/scores/period_analytics.dart';

/// On-device fallback when Gemini is unavailable.
class LocalCoach {
  const LocalCoach();

  String answer({
    required String question,
    required List<DaySummary> recentDays,
    required UserProfile profile,
  }) {
    final q = question.toLowerCase();
    if (recentDays.isEmpty) {
      return 'No metrics loaded yet. Connect Google Health and pull to refresh, then ask again.';
    }

    final day = recentDays.last;
    final sleep = const AdvancedAnalysis().sleep(
      day,
      profile: profile,
      history: recentDays,
    );
    final hrv = const PeriodAnalytics().hrvReport(recentDays);
    final week = const PeriodAnalytics().week(recentDays, profile);

    if (q.contains('sleep')) {
      return 'Sleep performance ${sleep.performance.toStringAsFixed(0)}% '
          '(hours vs need ${sleep.hoursVsNeedPercent.toStringAsFixed(0)}%). '
          'Efficiency ${sleep.efficiencyPercent.toStringAsFixed(0)}%, '
          'consistency ${sleep.consistencyPercent.toStringAsFixed(0)}%. '
          'Deep ${day.deepSleepMinutes}m / REM ${day.remSleepMinutes}m. '
          '${sleep.summary}';
    }
    if (q.contains('hrv') || q.contains('heart') || q.contains('recovery')) {
      return 'Recovery ${(day.recoveryScore ?? 0).toStringAsFixed(0)} · '
          'readiness ${(day.readinessScore ?? 0).toStringAsFixed(0)}. '
          '${hrv.summary} '
          'Resting HR ${day.restingHeartRate?.toStringAsFixed(0) ?? '—'} bpm.';
    }
    if (q.contains('strain') || q.contains('workout') || q.contains('train')) {
      return 'Today strain ${(day.strainScore ?? 0).toStringAsFixed(1)} / 21 with '
          '${day.exercises.length} workout(s) and ${day.zoneMinutes} zone minutes. '
          'Week avg strain ${week.avgStrain.toStringAsFixed(1)}. '
          '${(day.recoveryScore ?? 0) >= 67 ? 'Green light to push.' : (day.recoveryScore ?? 0) >= 34 ? 'Train with intent; watch recovery.' : 'Bias toward recovery today.'}';
    }
    if (q.contains('week') || q.contains('month') || q.contains('trend')) {
      return 'Week: recovery ${week.avgRecovery.toStringAsFixed(0)}, '
          'sleep perf ${week.avgSleepPerformance.toStringAsFixed(0)}%, '
          'HRV ${week.avgHrv?.toStringAsFixed(0) ?? '—'} ms (${week.hrvTrend}). '
          '${week.summary}';
    }

    final insight = day.insights.isEmpty
        ? 'Keep sleep and HRV trending up while managing strain.'
        : day.insights.first.body;
    return 'Recovery ${(day.recoveryScore ?? 0).toStringAsFixed(0)} · '
        'strain ${(day.strainScore ?? 0).toStringAsFixed(1)} · '
        'sleep perf ${sleep.performance.toStringAsFixed(0)}%. '
        '$insight';
  }
}
