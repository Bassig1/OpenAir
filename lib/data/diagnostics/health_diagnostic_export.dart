import 'dart:convert';

import '../../domain/models/day_summary.dart';
import '../../domain/models/health_extras.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/scores/advanced_analysis.dart';
import '../../domain/scores/health_insights_engine.dart';

/// Builds a single JSON dump the user can paste into Cursor so we can audit
/// display accuracy and Whoop-style analysis without manual UI checking.
class HealthDiagnosticExport {
  const HealthDiagnosticExport();

  Map<String, dynamic> build({
    required List<DaySummary> days,
    required UserProfile profile,
    BodySnapshot? body,
    List<PairedDeviceInfo> devices = const [],
    String? aiAnalysis,
    String? aiAnalysisError,
    DateTime? lastSyncedAt,
    Map<String, dynamic>? rawGoogleHealth,
    bool googleConnected = false,
  }) {
    const analysis = AdvancedAnalysis();
    const insights = HealthInsightsEngine();
    final latest = days.isEmpty ? null : days.last;

    final sanity = <Map<String, dynamic>>[];
    for (final day in days) {
      sanity.addAll(_daySanity(day));
    }
    if (body != null) sanity.addAll(_bodySanity(body));

    return {
      'exportVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'purpose':
          'OpenAir diagnostic dump for Cursor — verify Google Health parsing, '
          'UI metrics, and recovery-style analysis.',
      'privacyNote':
          'Contains personal health metrics. Do not post publicly. '
          'Safe to share privately with your OpenAir coding agent.',
      'connection': {
        'googleConnected': googleConnected,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'dayCount': days.length,
        'hasBody': body != null,
        'deviceCount': devices.length,
        'hasGeminiAnalysis': (aiAnalysis ?? '').trim().isNotEmpty,
        'geminiError': aiAnalysisError,
      },
      'profile': {
        'ageYears': profile.ageYears,
        'sex': profile.sex?.name,
        'heightCm': profile.heightCm,
        'weightKg': profile.weightKg,
        'useMetric': profile.useMetric,
        'sleepNeedBaselineMinutes': profile.sleepNeedBaselineMinutes,
      },
      'bodyFromGoogleHealth': body?.toJson(),
      'devices': devices.map((d) => d.toJson()).toList(),
      'days': days.map((d) => d.toCoachJson()).toList(),
      'whoopStyleAnalysis': latest == null
          ? null
          : _whoopStyleBundle(
              day: latest,
              history: days,
              profile: profile,
              analysis: analysis,
              insights: insights,
              aiAnalysis: aiAnalysis,
            ),
      'sanityFlags': sanity,
      'rawGoogleHealth': rawGoogleHealth,
    };
  }

  String encodePretty(Map<String, dynamic> dump) =>
      const JsonEncoder.withIndent('  ').convert(dump);

  Map<String, dynamic> _whoopStyleBundle({
    required DaySummary day,
    required List<DaySummary> history,
    required UserProfile profile,
    required AdvancedAnalysis analysis,
    required HealthInsightsEngine insights,
    String? aiAnalysis,
  }) {
    final sleep = analysis.sleep(day, profile: profile, history: history);
    final heart = analysis.heartbeat(day, history);
    final oxygen = analysis.oxygen(day);
    final briefing = analysis.briefing(
      day: day,
      history: history,
      profile: profile,
    );
    final cards = insights.build(
      day: day,
      history: history,
      profile: profile,
    );

    return {
      'focusDate': day.date.toIso8601String().split('T').first,
      'recovery': day.recoveryScore,
      'strain': day.strainScore,
      'sleepPerformance': sleep.performance,
      'sleepEfficiency': sleep.efficiencyPercent,
      'sleepNeedMinutes': sleep.neededMinutes,
      'sleepDebtMinutes': sleep.debtMinutes,
      'sleepSummary': sleep.summary,
      'restorativePercent': sleep.restorativePercent,
      'deepPercent': sleep.deepPercent,
      'remPercent': sleep.remPercent,
      'lightPercent': sleep.lightPercent,
      'rhr': heart.restingHr,
      'hrvMs': heart.hrvMs,
      'hrvTrend': heart.hrvTrend,
      'spo2': oxygen.averagePercent,
      'spo2Label': oxygen.statusLabel,
      'readiness': day.readinessScore,
      'stress': day.stressScore,
      'briefing': briefing.coaching,
      'insightCards': cards
          .map((c) => {
                'title': c.title,
                'body': c.body,
                'score': c.score,
                'category': c.category,
              })
          .toList(),
      'geminiNarrative': aiAnalysis,
      'localInsights': day.insights
          .map((i) => {'title': i.title, 'body': i.body, 'category': i.category})
          .toList(),
    };
  }

  List<Map<String, dynamic>> _daySanity(DaySummary day) {
    final flags = <Map<String, dynamic>>[];
    final date = day.date.toIso8601String().split('T').first;
    final stageSum =
        day.deepSleepMinutes + day.remSleepMinutes + day.lightSleepMinutes;
    if (day.sleepMinutes > 0 &&
        stageSum > 0 &&
        (day.sleepMinutes - stageSum).abs() > 45) {
      flags.add({
        'date': date,
        'field': 'sleepMinutes',
        'severity':
            'Asleep minutes (${day.sleepMinutes}) diverge from stage sum ($stageSum) by >45m',
        'sleepMinutes': day.sleepMinutes,
        'stageSum': stageSum,
        'awakeMinutes': day.awakeMinutes,
      });
    }
    if (day.spo2Percent != null &&
        (day.spo2Percent! < 70 || day.spo2Percent! > 100)) {
      flags.add({
        'date': date,
        'field': 'spo2Percent',
        'severity': 'SpO₂ outside physiological 70–100% range',
        'value': day.spo2Percent,
      });
    }
    if (day.restingHeartRate != null &&
        (day.restingHeartRate! < 30 || day.restingHeartRate! > 120)) {
      flags.add({
        'date': date,
        'field': 'restingHeartRate',
        'severity': 'RHR outside typical wearable range',
        'value': day.restingHeartRate,
      });
    }
    if (day.hrvMs != null && (day.hrvMs! < 5 || day.hrvMs! > 300)) {
      flags.add({
        'date': date,
        'field': 'hrvMs',
        'severity': 'HRV outside typical ms range',
        'value': day.hrvMs,
      });
    }
    return flags;
  }

  List<Map<String, dynamic>> _bodySanity(BodySnapshot body) {
    final flags = <Map<String, dynamic>>[];
    if (body.weightKg != null &&
        (body.weightKg! < 30 || body.weightKg! > 250)) {
      flags.add({
        'field': 'weightKg',
        'severity': 'Weight looks wrong (possible grams/pounds unit bug)',
        'value': body.weightKg,
      });
    }
    if (body.heightCm != null &&
        (body.heightCm! < 100 || body.heightCm! > 250)) {
      flags.add({
        'field': 'heightCm',
        'severity': 'Height looks wrong (possible mm/m unit bug)',
        'value': body.heightCm,
      });
    }
    return flags;
  }
}
