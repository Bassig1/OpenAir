import 'package:flutter/material.dart';
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
    final day = app.today;

    return RefreshIndicator(
      color: OpenAirColors.recovery,
      onRefresh: app.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('OpenAir'),
            actions: [
              if (app.syncing)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
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
                        Text(
                          DateFormat('EEEE, MMM d').format(day.date),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: OpenAirColors.textSecondary,
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
                          app.useDemoData
                              ? 'Demo data — connect Google Health in Settings for your Fitbit.'
                              : 'Synced from Google Health (Fitbit cloud).',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: OpenAirColors.textMuted,
                                  ),
                        ),
                        if (app.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            app.errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: OpenAirColors.heart),
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ScoreRing(
                              label: 'Recovery',
                              value: day.recoveryScore ?? 0,
                              max: 100,
                              color: OpenAirColors.recovery,
                              subtitle: _recoveryLabel(day.recoveryScore ?? 0),
                            ),
                            ScoreRing(
                              label: 'Strain',
                              value: day.strainScore ?? 0,
                              max: 21,
                              color: OpenAirColors.strain,
                              subtitle: '0–21 load',
                            ),
                            ScoreRing(
                              label: 'Sleep',
                              value: day.sleepScore ?? 0,
                              max: 100,
                              color: OpenAirColors.sleep,
                              subtitle: formatMinutes(day.sleepMinutes),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        DayStrip(days: app.days, selected: day),
                        const SizedBox(height: 24),
                        const SectionHeader('Today at a glance'),
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
                              label: 'Resting HR',
                              value: day.restingHeartRate == null
                                  ? '—'
                                  : '${day.restingHeartRate!.round()} bpm',
                              accent: OpenAirColors.heart,
                            ),
                            MetricTile(
                              label: 'HRV',
                              value: day.hrvMs == null
                                  ? '—'
                                  : '${day.hrvMs!.round()} ms',
                              accent: OpenAirColors.recovery,
                            ),
                            MetricTile(
                              label: 'SpO₂',
                              value: day.spo2Percent == null
                                  ? '—'
                                  : '${day.spo2Percent!.toStringAsFixed(1)}%',
                              accent: OpenAirColors.spo2,
                            ),
                            MetricTile(
                              label: 'Steps',
                              value: NumberFormat.decimalPattern()
                                  .format(day.steps),
                              accent: OpenAirColors.strain,
                            ),
                            MetricTile(
                              label: 'Zone min',
                              value: '${day.zoneMinutes}',
                              accent: OpenAirColors.strain,
                            ),
                            MetricTile(
                              label: 'Resp. rate',
                              value: day.respiratoryRate == null
                                  ? '—'
                                  : day.respiratoryRate!.toStringAsFixed(1),
                              hint: 'br/min',
                              accent: OpenAirColors.sleep,
                            ),
                            MetricTile(
                              label: 'Distance',
                              value: day.distanceMeters == null
                                  ? '—'
                                  : '${(day.distanceMeters! / 1000).toStringAsFixed(2)} km',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: OpenAirColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: OpenAirColors.border),
                          ),
                          child: Text(
                            'OpenAir scores are transparent heuristics from sleep, HRV, '
                            'resting heart rate, SpO₂, and activity — inspired by Whoop-style '
                            'UX, not Whoop’s proprietary model.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: OpenAirColors.textSecondary,
                                      height: 1.4,
                                    ),
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
