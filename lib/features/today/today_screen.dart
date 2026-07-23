import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
              child: app.loading || day == null
                  ? const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            LiveBadge(live: app.isLive, syncing: app.syncing),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                app.lastSyncedAt == null
                                    ? ''
                                    : 'Updated ${DateFormat.jm().format(app.lastSyncedAt!)}',
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          DateFormat('EEEE, MMM d').format(day.date),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _headline(day.recoveryScore ?? 0),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          app.syncHealth.message,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colors.textMuted,
                              ),
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
                        const SizedBox(height: 22),
                        DayStrip(
                          days: app.days,
                          selected: day,
                          onSelected: app.selectDay,
                        ),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final ring =
                                ((constraints.maxWidth - 12) / 3).clamp(86.0, 108.0);
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ScoreRing(
                                  label: 'Recovery',
                                  value: day.recoveryScore ?? 0,
                                  max: 100,
                                  color: colors.green,
                                  subtitle: _recoveryLabel(day.recoveryScore ?? 0),
                                  size: ring,
                                ),
                                ScoreRing(
                                  label: 'Strain',
                                  value: day.strainScore ?? 0,
                                  max: 21,
                                  color: colors.strain,
                                  subtitle: '0–21 load',
                                  size: ring,
                                ),
                                ScoreRing(
                                  label: 'Sleep',
                                  value: day.sleepScore ?? 0,
                                  max: 100,
                                  color: colors.sleep,
                                  subtitle: formatMinutes(day.sleepMinutes),
                                  size: ring,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        if (day.recoveryBreakdown != null) ...[
                          const SectionHeader('Recovery contributors'),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.border),
                            ),
                            child: Column(
                              children: [
                                ContributionBar(
                                  label: 'Sleep',
                                  value: day.recoveryBreakdown!.sleepContribution,
                                  color: colors.sleep,
                                ),
                                ContributionBar(
                                  label: 'HRV',
                                  value: day.recoveryBreakdown!.hrvContribution,
                                  color: colors.green,
                                ),
                                ContributionBar(
                                  label: 'Resting HR',
                                  value: day.recoveryBreakdown!.rhrContribution,
                                  color: colors.heart,
                                ),
                                ContributionBar(
                                  label: 'SpO₂',
                                  value: day.recoveryBreakdown!.spo2Contribution,
                                  color: colors.spo2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        const SectionHeader('Daily scores'),
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
                              value: day.readinessScore?.toStringAsFixed(0) ?? '—',
                              hint: '/100',
                              accent: colors.green,
                            ),
                            MetricTile(
                              label: 'Stress',
                              value: day.stressScore?.toStringAsFixed(0) ?? '—',
                              hint: '/100',
                              accent: colors.heart,
                            ),
                            MetricTile(
                              label: 'Stress mgmt',
                              value: day.stressManagementScore?.toStringAsFixed(0) ??
                                  '—',
                              hint: '/100',
                              accent: colors.sleep,
                            ),
                            MetricTile(
                              label: 'Cardio fit',
                              value: day.cardioFitnessScore?.toStringAsFixed(0) ?? '—',
                              hint: day.vo2Max == null
                                  ? '/100'
                                  : 'VO₂ ${day.vo2Max!.toStringAsFixed(1)}',
                              accent: colors.strain,
                            ),
                          ],
                        ),
                        if (day.insights.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          SectionHeader(
                            'Insights',
                            trailing: TextButton(
                              onPressed: () => context.push('/insights'),
                              child: const Text('See all'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            day.insights.first.body,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: const Text('Start workout'),
                              onPressed: () => context.push('/workouts'),
                            ),
                            ActionChip(
                              label: const Text('Weekly'),
                              onPressed: () => context.push('/weekly'),
                            ),
                            ActionChip(
                              label: const Text('Journal'),
                              onPressed: () => context.push('/journal'),
                            ),
                            ActionChip(
                              label: const Text('Stress'),
                              onPressed: () => context.push('/stress'),
                            ),
                            ActionChip(
                              label: const Text('Coach'),
                              onPressed: () => context.push('/coach'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader('Sleep need'),
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
                              label: 'Needed',
                              value: formatMinutes(day.sleepNeededMinutes ?? 480),
                              accent: colors.sleep,
                            ),
                            MetricTile(
                              label: 'Debt',
                              value: formatMinutes(
                                (day.sleepDebtMinutes ?? 0).abs(),
                              ),
                              hint: (day.sleepDebtMinutes ?? 0) >= 0
                                  ? 'behind'
                                  : 'ahead',
                              accent: colors.strain,
                            ),
                            MetricTile(
                              label: 'Asleep',
                              value: formatMinutes(day.sleepMinutes),
                              hint:
                                  'Deep ${day.deepSleepMinutes}m · REM ${day.remSleepMinutes}m',
                              accent: colors.sleep,
                            ),
                            MetricTile(
                              label: 'Efficiency',
                              value: app.sleepAnalysis == null
                                  ? '—'
                                  : '${app.sleepAnalysis!.efficiencyPercent.toStringAsFixed(0)}%',
                              hint: app.sleepAnalysis?.consistencyLabel,
                              accent: colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader('Vitals detail'),
                        const SizedBox(height: 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.2,
                          children: [
                            MetricTile(
                              label: 'Resting HR',
                              value: day.restingHeartRate == null
                                  ? '—'
                                  : day.restingHeartRate!.toStringAsFixed(1),
                              hint: 'bpm · avg ${day.avgHeartRate?.toStringAsFixed(0) ?? '—'}',
                              accent: colors.heart,
                            ),
                            MetricTile(
                              label: 'HRV',
                              value: day.hrvMs == null
                                  ? '—'
                                  : day.hrvMs!.toStringAsFixed(1),
                              hint: 'ms · ${app.heartbeatAnalysis?.hrvTrend ?? '—'}',
                              accent: colors.green,
                            ),
                            MetricTile(
                              label: 'SpO₂',
                              value: day.spo2Percent == null
                                  ? '—'
                                  : '${day.spo2Percent!.toStringAsFixed(2)}%',
                              hint: app.oxygenAnalysis?.statusLabel,
                              accent: colors.spo2,
                            ),
                            MetricTile(
                              label: 'Steps',
                              value: NumberFormat.decimalPattern().format(day.steps),
                              hint: day.distanceMeters == null
                                  ? null
                                  : '${(day.distanceMeters! / 1000).toStringAsFixed(2)} km',
                              accent: colors.green,
                            ),
                            MetricTile(
                              label: 'Active kcal',
                              value: day.activeCalories.toStringAsFixed(0),
                              hint: day.totalCalories == null
                                  ? '${day.activeMinutes} active min'
                                  : 'total ${day.totalCalories!.toStringAsFixed(0)}',
                              accent: colors.strain,
                            ),
                            MetricTile(
                              label: 'Zones',
                              value: day.zoneMinutes.toString(),
                              hint: day.heartRateZones == null
                                  ? 'min'
                                  : 'F${day.heartRateZones!.fatBurnMinutes}/C${day.heartRateZones!.cardioMinutes}/P${day.heartRateZones!.peakMinutes}',
                              accent: colors.strain,
                            ),
                            MetricTile(
                              label: 'Resp. rate',
                              value: day.respiratoryRate == null
                                  ? '—'
                                  : day.respiratoryRate!.toStringAsFixed(2),
                              hint: 'breaths/min',
                              accent: colors.sleep,
                            ),
                            MetricTile(
                              label: 'Skin temp Δ',
                              value: day.skinTempDeviation == null
                                  ? '—'
                                  : '${day.skinTempDeviation!.toStringAsFixed(2)}°',
                              hint: 'vs baseline',
                              accent: colors.heart,
                            ),
                          ],
                        ),
                        if (day.exercises.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          SectionHeader(
                            'Workouts',
                            trailing: TextButton(
                              onPressed: () => context.push('/workouts'),
                              child: const Text('Open'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...day.exercises.map((e) => WorkoutTile(session: e)),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'OpenAir refreshes cloud data every minute while open. Keep the Fitbit app syncing your device — third-party Bluetooth is not available.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

  String _headline(double recovery) {
    if (recovery >= 67) return 'Green light. Train hard.';
    if (recovery >= 34) return 'Yellow. Push with intent.';
    return 'Prioritize recovery today.';
  }

  String _recoveryLabel(double recovery) {
    if (recovery >= 67) return 'High';
    if (recovery >= 34) return 'Moderate';
    return 'Low';
  }
}
