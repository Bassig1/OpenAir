import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/units.dart';
import '../../state/app_controller.dart';
import '../../theme/openair_theme.dart';
import '../../widgets/metric_widgets.dart';
import '../../widgets/score_ring.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final day = app.selectedDay;
    final colors = OpenAirColors.of(context);
    final brief = app.dayBriefing;

    return RefreshIndicator(
      color: colors.green,
      onRefresh: app.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/branding/icon.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (_, error, stackTrace) => Icon(
                      Icons.favorite,
                      color: colors.green,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('OpenAir'),
              ],
            ),
            actions: [
              if (app.syncing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: app.loading && day == null
                  ? const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : !app.isConnected && day == null
                      ? _ConnectCard(app: app, colors: colors)
                      : day == null
                          ? _EmptyConnected(app: app, colors: colors)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!app.isConnected)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ConnectCard(app: app, colors: colors),
                                  ),
                                if (app.isConnected &&
                                    (app.profile.heightCm == null ||
                                        app.profile.weightKg == null))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _BodyImportCard(
                                      app: app,
                                      colors: colors,
                                    ),
                                  ),
                                Text(
                                  DateFormat('EEEE, MMM d').format(day.date),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(color: colors.textSecondary),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  brief?.headline ??
                                      _headline(day.recoveryScore ?? 0),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  app.lastSyncedAt == null
                                      ? app.syncHealth.message
                                      : '${app.syncHealth.message} · Updated ${DateFormat.jm().format(app.lastSyncedAt!)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: colors.textMuted),
                                ),
                                if (app.errorMessage != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    app.errorMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: colors.heart),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                DayStrip(
                                  days: app.days,
                                  selected: day,
                                  onSelected: app.selectDay,
                                ),
                                const SizedBox(height: 28),
                                Center(
                                  child: ScoreRing(
                                    label: 'Recovery',
                                    value: day.recoveryScore ?? 0,
                                    max: 100,
                                    color: colors.green,
                                    subtitle: brief?.recoveryZone ??
                                        _recoveryLabel(day.recoveryScore ?? 0),
                                    size: 148,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ScoreRing(
                                        label: 'Strain',
                                        value: day.strainScore ?? 0,
                                        max: 21,
                                        color: colors.strain,
                                        subtitle: brief == null
                                            ? '0–21'
                                            : '${brief.remainingStrain} left',
                                        size: 104,
                                      ),
                                    ),
                                    Expanded(
                                      child: ScoreRing(
                                        label: 'Sleep',
                                        value: app.sleepAnalysis?.performance ??
                                            day.sleepScore ??
                                            0,
                                        max: 100,
                                        color: colors.sleep,
                                        subtitle: formatMinutes(day.sleepMinutes),
                                        size: 104,
                                      ),
                                    ),
                                  ],
                                ),
                                if (brief != null) ...[
                                  const SizedBox(height: 28),
                                  const SectionHeader('What this means'),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Text(
                                      brief.coaching,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    brief.strainTarget,
                                    style: TextStyle(
                                      color: colors.green,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...brief.actions.map(
                                    (a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                            color: colors.green,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              a,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (app.geminiReady) ...[
                                  const SizedBox(height: 24),
                                  SectionHeader(
                                    'Deeper analysis',
                                    trailing: TextButton(
                                      onPressed: app.aiAnalysisLoading
                                          ? null
                                          : () => app.refreshAiAnalysis(
                                                force: true,
                                              ),
                                      child: Text(
                                        app.aiAnalysisLoading
                                            ? 'Writing…'
                                            : 'Refresh',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Same Fitbit → Google Health numbers, explained with exact percentages.',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: colors.border),
                                    ),
                                    child: Text(
                                      (app.aiAnalysis ?? '').trim().isNotEmpty
                                          ? app.aiAnalysis!
                                          : (app.aiAnalysisError ??
                                              (app.aiAnalysisLoading
                                                  ? 'Writing your daily analysis from Google Health…'
                                                  : 'Tap Refresh to generate analysis.')),
                                      style: TextStyle(
                                        color: app.aiAnalysisError != null &&
                                                (app.aiAnalysis ?? '')
                                                    .trim()
                                                    .isEmpty
                                            ? colors.heart
                                            : colors.textSecondary,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const SectionHeader('Ask Gemini'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ask for a summary or dive into sleep, recovery, or vitals.',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final q in const [
                                        'Summarize my health today with exact percentages',
                                        'Break down my sleep stages and efficiency',
                                        'Summarize the last 7 days of recovery and HRV',
                                        'What should I train today based on recovery?',
                                      ])
                                        ActionChip(
                                          label: Text(q),
                                          onPressed: () async {
                                            await app.askCoach(q);
                                            if (context.mounted) {
                                              context.push('/coach');
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => context.push('/coach'),
                                      child: const Text('Open Coach chat'),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          context.push('/insights'),
                                      child: const Text('Full insights'),
                                    ),
                                  ),
                                ],
                                if (app.sleepAnalysis != null) ...[
                                  const SizedBox(height: 12),
                                  SectionHeader(
                                    'Sleep architecture',
                                    trailing: TextButton(
                                      onPressed: () => context.push('/sleep'),
                                      child: const Text('Details'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.35,
                                    children: [
                                      MetricTile(
                                        label: 'Performance',
                                        value:
                                            '${app.sleepAnalysis!.performance.toStringAsFixed(1)}%',
                                        hint:
                                            'vs need ${app.sleepAnalysis!.hoursVsNeedPercent.toStringAsFixed(1)}%',
                                        accent: colors.sleep,
                                      ),
                                      MetricTile(
                                        label: 'Efficiency',
                                        value:
                                            '${app.sleepAnalysis!.efficiencyPercent.toStringAsFixed(1)}%',
                                        hint: 'asleep / in bed',
                                        accent: colors.sleep,
                                      ),
                                      MetricTile(
                                        label: 'Deep',
                                        value:
                                            '${app.sleepAnalysis!.deepPercent.toStringAsFixed(1)}%',
                                        hint: '${day.deepSleepMinutes}m',
                                        accent: colors.sleep,
                                      ),
                                      MetricTile(
                                        label: 'REM',
                                        value:
                                            '${app.sleepAnalysis!.remPercent.toStringAsFixed(1)}%',
                                        hint: '${day.remSleepMinutes}m',
                                        accent: colors.sleep,
                                      ),
                                      MetricTile(
                                        label: 'Light',
                                        value:
                                            '${app.sleepAnalysis!.lightPercent.toStringAsFixed(1)}%',
                                        hint: '${day.lightSleepMinutes}m',
                                      ),
                                      MetricTile(
                                        label: 'Awake',
                                        value:
                                            '${app.sleepAnalysis!.awakePercent.toStringAsFixed(1)}%',
                                        hint: '${day.awakeMinutes}m of in-bed',
                                        accent: colors.heart,
                                      ),
                                      MetricTile(
                                        label: 'Restorative',
                                        value:
                                            '${app.sleepAnalysis!.restorativePercent.toStringAsFixed(1)}%',
                                        hint:
                                            '${app.sleepAnalysis!.restorativeMinutes}m deep+REM',
                                        accent: colors.green,
                                      ),
                                      MetricTile(
                                        label: 'Consistency',
                                        value:
                                            '${app.sleepAnalysis!.consistencyPercent.toStringAsFixed(1)}%',
                                        hint:
                                            app.sleepAnalysis!.consistencyLabel,
                                      ),
                                    ],
                                  ),
                                ],
                                if (brief != null) ...[
                                  const SizedBox(height: 12),
                                  const SectionHeader('What drove today'),
                                  const SizedBox(height: 12),
                                  ...brief.drivers.map(
                                    (d) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: ContributionBar(
                                        label: d.label,
                                        value: d.score,
                                        color: _driverColor(colors, d.label),
                                      ),
                                    ),
                                  ),
                                  ...brief.drivers.map(
                                    (d) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '${d.label}: ${d.detail}',
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                const SectionHeader('Activity'),
                                const SizedBox(height: 12),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.35,
                                  children: [
                                    MetricTile(
                                      label: 'Steps',
                                      value: NumberFormat.decimalPattern()
                                          .format(day.steps),
                                      hint: day.steps <= 0
                                          ? 'sync Fitbit then refresh'
                                          : null,
                                      accent: colors.green,
                                    ),
                                    MetricTile(
                                      label: 'Distance',
                                      value: day.distanceMeters == null
                                          ? '—'
                                          : Units.distanceMeters(
                                              day.distanceMeters,
                                              metric: app.profile.useMetric,
                                            ),
                                      accent: colors.green,
                                    ),
                                    MetricTile(
                                      label: 'Active min',
                                      value: '${day.activeMinutes}',
                                      hint: '${day.zoneMinutes} zone min',
                                      accent: colors.strain,
                                    ),
                                    MetricTile(
                                      label: 'Active kcal',
                                      value: day.activeCalories
                                          .toStringAsFixed(0),
                                      hint: day.totalCalories == null
                                          ? null
                                          : 'total ${day.totalCalories!.toStringAsFixed(0)}',
                                      accent: colors.strain,
                                    ),
                                    if (day.floors != null)
                                      MetricTile(
                                        label: 'Floors',
                                        value: '${day.floors}',
                                      ),
                                    MetricTile(
                                      label: 'Sedentary',
                                      value: day.sedentaryMinutes == null
                                          ? '—'
                                          : formatMinutes(day.sedentaryMinutes!),
                                      hint: 'today',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const SectionHeader('Readiness snapshot'),
                                const SizedBox(height: 12),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.35,
                                  children: [
                                    MetricTile(
                                      label: 'Readiness',
                                      value: day.readinessScore == null
                                          ? '—'
                                          : day.readinessScore!
                                              .toStringAsFixed(1),
                                      hint: 'composite',
                                      accent: colors.green,
                                    ),
                                    MetricTile(
                                      label: 'Stress',
                                      value: day.stressScore == null
                                          ? '—'
                                          : day.stressScore!.toStringAsFixed(1),
                                      hint: 'lower is calmer',
                                      accent: colors.strain,
                                    ),
                                    MetricTile(
                                      label: 'SpO₂',
                                      value: day.spo2Percent == null
                                          ? '—'
                                          : '${day.spo2Percent!.toStringAsFixed(1)}%',
                                      hint: () {
                                        final ox = app.oxygenAnalysis;
                                        if (ox?.minPercent != null &&
                                            ox?.maxPercent != null) {
                                          return 'range ${ox!.minPercent!.toStringAsFixed(1)}–${ox.maxPercent!.toStringAsFixed(1)}%';
                                        }
                                        return 'overnight avg';
                                      }(),
                                      accent: colors.spo2,
                                    ),
                                    MetricTile(
                                      label: 'HRV',
                                      value: day.hrvMs == null
                                          ? '—'
                                          : day.hrvMs!.toStringAsFixed(1),
                                      hint: 'ms',
                                      accent: colors.green,
                                    ),
                                    MetricTile(
                                      label: 'Resting HR',
                                      value: day.restingHeartRate == null
                                          ? '—'
                                          : day.restingHeartRate!
                                              .toStringAsFixed(1),
                                      hint: 'bpm',
                                      accent: colors.heart,
                                    ),
                                    MetricTile(
                                      label: 'Avg HR',
                                      value: day.avgHeartRate == null
                                          ? '—'
                                          : day.avgHeartRate!
                                              .toStringAsFixed(0),
                                      hint: 'bpm',
                                      accent: colors.heart,
                                    ),
                                    MetricTile(
                                      label: 'Min / Max HR',
                                      value: [
                                        day.minHeartRate?.toStringAsFixed(0) ??
                                            '—',
                                        day.maxHeartRate?.toStringAsFixed(0) ??
                                            '—',
                                      ].join(' / '),
                                      hint: 'bpm',
                                      accent: colors.heart,
                                    ),
                                    MetricTile(
                                      label: 'VO₂ max',
                                      value: day.vo2Max == null
                                          ? (app.effectiveBody.vo2Max == null
                                              ? '—'
                                              : app.effectiveBody.vo2Max!
                                                  .toStringAsFixed(1))
                                          : day.vo2Max!.toStringAsFixed(1),
                                      hint: 'ml/kg/min',
                                      accent: colors.green,
                                    ),
                                    MetricTile(
                                      label: 'Resp. rate',
                                      value: day.respiratoryRate == null
                                          ? '—'
                                          : day.respiratoryRate!
                                              .toStringAsFixed(1),
                                      hint: 'br/min',
                                      accent: colors.sleep,
                                    ),
                                    MetricTile(
                                      label: 'Skin temp Δ',
                                      value: day.skinTempDeviation == null
                                          ? '—'
                                          : '${day.skinTempDeviation!.toStringAsFixed(2)}°',
                                      hint: 'vs baseline',
                                      accent: colors.strain,
                                    ),
                                    MetricTile(
                                      label: 'Sleep need',
                                      value: formatMinutes(
                                        day.sleepNeededMinutes ??
                                            app.profile
                                                .sleepNeedBaselineMinutes,
                                      ),
                                      hint: day.sleepDebtMinutes == null
                                          ? null
                                          : 'debt ${day.sleepDebtMinutes}m',
                                      accent: colors.sleep,
                                    ),
                                    MetricTile(
                                      label: 'Body',
                                      value: Units.weight(
                                        app.effectiveBody.weightKg,
                                        metric: true,
                                      ),
                                      hint: [
                                        Units.height(
                                          app.effectiveBody.heightCm,
                                          metric: true,
                                        ),
                                        if (app.effectiveBody.bodyFatPercent !=
                                            null)
                                          'fat ${app.effectiveBody.bodyFatPercent!.toStringAsFixed(1)}%',
                                      ].join(' · '),
                                    ),
                                  ],
                                ),
                                if (day.heartRateZones != null) ...[
                                  const SizedBox(height: 24),
                                  const SectionHeader('Heart rate zones'),
                                  const SizedBox(height: 12),
                                  GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.45,
                                    children: [
                                      MetricTile(
                                        label: 'Out of range',
                                        value:
                                            '${day.heartRateZones!.outOfRangeMinutes}m',
                                        hint:
                                            '${day.heartRateZones!.percentOf(day.heartRateZones!.outOfRangeMinutes)}%',
                                        accent: colors.textMuted,
                                      ),
                                      MetricTile(
                                        label: 'Fat burn',
                                        value:
                                            '${day.heartRateZones!.fatBurnMinutes}m',
                                        hint:
                                            '${day.heartRateZones!.percentOf(day.heartRateZones!.fatBurnMinutes)}%',
                                        accent: colors.strain,
                                      ),
                                      MetricTile(
                                        label: 'Cardio',
                                        value:
                                            '${day.heartRateZones!.cardioMinutes}m',
                                        hint:
                                            '${day.heartRateZones!.percentOf(day.heartRateZones!.cardioMinutes)}%',
                                        accent: colors.heart,
                                      ),
                                      MetricTile(
                                        label: 'Peak',
                                        value:
                                            '${day.heartRateZones!.peakMinutes}m',
                                        hint:
                                            '${day.heartRateZones!.percentOf(day.heartRateZones!.peakMinutes)}%',
                                        accent: colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                                if (day.recoveryBreakdown != null) ...[
                                  const SizedBox(height: 24),
                                  const SectionHeader('Recovery mix'),
                                  const SizedBox(height: 12),
                                  ContributionBar(
                                    label: 'Sleep',
                                    value: day
                                        .recoveryBreakdown!.sleepContribution,
                                    color: colors.sleep,
                                  ),
                                  ContributionBar(
                                    label: 'HRV',
                                    value:
                                        day.recoveryBreakdown!.hrvContribution,
                                    color: colors.green,
                                  ),
                                  ContributionBar(
                                    label: 'Resting HR',
                                    value:
                                        day.recoveryBreakdown!.rhrContribution,
                                    color: colors.heart,
                                  ),
                                  ContributionBar(
                                    label: 'SpO₂',
                                    value:
                                        day.recoveryBreakdown!.spo2Contribution,
                                    color: colors.spo2,
                                  ),
                                ],
                                if (day.insights.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  SectionHeader(
                                    'Insights',
                                    trailing: TextButton(
                                      onPressed: () =>
                                          context.push('/insights'),
                                      child: const Text('All'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...day.insights.take(3).map(
                                        (i) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: colors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: colors.border,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  i.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  i.body,
                                                  style: TextStyle(
                                                    color: colors.textSecondary,
                                                    height: 1.35,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                ],
                                if (day.exercises.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  SectionHeader(
                                    'Workouts',
                                    trailing: TextButton(
                                      onPressed: () =>
                                          context.push('/workouts'),
                                      child: const Text('Open'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...day.exercises
                                      .map((e) => WorkoutTile(session: e)),
                                ],
                                const SizedBox(height: 20),
                                Text(
                                  'Pull to refresh after the Fitbit app syncs. OpenAir summarizes Google Health cloud data — it does not stream Bluetooth heart rate.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.textSecondary,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Color _driverColor(OpenAirColors colors, String label) {
    switch (label) {
      case 'Sleep':
        return colors.sleep;
      case 'Resting HR':
        return colors.heart;
      case 'Strain left':
        return colors.strain;
      default:
        return colors.green;
    }
  }

  String _headline(double recovery) {
    if (recovery >= 67) return 'Green light. Train hard.';
    if (recovery >= 34) return 'Yellow. Push with intent.';
    return 'Prioritize recovery today.';
  }

  String _recoveryLabel(double recovery) {
    if (recovery >= 67) return 'Green';
    if (recovery >= 34) return 'Yellow';
    return 'Red';
  }
}

class _BodyImportCard extends StatelessWidget {
  const _BodyImportCard({required this.app, required this.colors});

  final AppController app;
  final OpenAirColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finish body profile',
            style: TextStyle(
              color: colors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import height & weight from Google Health (cm / kg) so recovery and strain stay accurate.',
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: () async {
                  final ok = await app.importBodyFromGoogleHealth();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Imported body from Google Health'
                            : (app.errorMessage ??
                                'No body metrics found yet'),
                      ),
                    ),
                  );
                },
                child: const Text('Import now'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push('/profile'),
                child: const Text('Edit profile'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.app, required this.colors});

  final AppController app;
  final OpenAirColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect Fitbit via Google Health',
            style: TextStyle(
              color: colors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in with the Google account linked to Fitbit. OpenAir pulls sleep, heart, steps, calories, and more from Google Health.',
            style: TextStyle(color: colors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: app.syncing ? null : app.connectGoogle,
            icon: const Icon(Icons.watch),
            label: const Text('Connect Fitbit / Google Health'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.accessibility_new),
            label: const Text('Import body profile'),
          ),
        ],
      ),
    );
  }
}

class _EmptyConnected extends StatelessWidget {
  const _EmptyConnected({required this.app, required this.colors});

  final AppController app;
  final OpenAirColors colors;

  @override
  Widget build(BuildContext context) {
    final body = app.effectiveBody;
    final hasBody = body.weightKg != null || body.heightCm != null;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Waiting for Google Health data',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            app.syncHealth.message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, height: 1.4),
          ),
          if (app.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              app.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.heart),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: app.syncing ? null : app.refresh,
            icon: const Icon(Icons.sync),
            label: const Text('Refresh Fitbit data'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.accessibility_new),
            label: Text(
              hasBody
                  ? 'Review body profile (${Units.height(body.heightCm, metric: true)})'
                  : 'Import body profile from Google Health',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: app.syncing ? null : app.connectGoogle,
            icon: const Icon(Icons.watch),
            label: const Text('Reconnect Fitbit account'),
          ),
        ],
      ),
    );
  }
}
