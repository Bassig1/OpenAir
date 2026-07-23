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
    final day = app.selectedDay;

    return RefreshIndicator(
      color: OpenAirColors.recovery,
      onRefresh: app.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverAppBar(pinned: true, title: Text('OpenAir')),
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
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                              ? 'Demo data — connect Google Health in Settings for live Fitbit numbers.'
                              : 'Live Fitbit cloud data via Google Health${app.lastSyncedAt == null ? '' : ' · synced ${DateFormat.jm().format(app.lastSyncedAt!)}'}.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        const SizedBox(height: 22),
                        DayStrip(
                          days: app.days,
                          selected: day,
                          onSelected: app.selectDay,
                        ),
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
                        if (day.recoveryBreakdown != null) ...[
                          const SectionHeader('Recovery breakdown'),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: OpenAirColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: OpenAirColors.border),
                            ),
                            child: Column(
                              children: [
                                ContributionBar(
                                  label: 'Sleep',
                                  value: day.recoveryBreakdown!.sleepContribution,
                                  color: OpenAirColors.sleep,
                                ),
                                ContributionBar(
                                  label: 'HRV',
                                  value: day.recoveryBreakdown!.hrvContribution,
                                  color: OpenAirColors.recovery,
                                ),
                                ContributionBar(
                                  label: 'Resting HR',
                                  value: day.recoveryBreakdown!.rhrContribution,
                                  color: OpenAirColors.heart,
                                ),
                                ContributionBar(
                                  label: 'SpO₂',
                                  value: day.recoveryBreakdown!.spo2Contribution,
                                  color: OpenAirColors.spo2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
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
                              accent: OpenAirColors.sleep,
                            ),
                            MetricTile(
                              label: 'Debt',
                              value: formatMinutes(
                                (day.sleepDebtMinutes ?? 0).abs(),
                              ),
                              hint: (day.sleepDebtMinutes ?? 0) >= 0
                                  ? 'behind'
                                  : 'ahead',
                              accent: OpenAirColors.strain,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader('At a glance'),
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
                              value: NumberFormat.decimalPattern().format(day.steps),
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
                          ],
                        ),
                        if (day.exercises.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const SectionHeader('Workouts'),
                          const SizedBox(height: 12),
                          ...day.exercises.map((e) => WorkoutTile(session: e)),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'OpenAir scores are transparent heuristics from Fitbit cloud metrics. '
                          'Raw vitals aim to match Google Health / Fitbit reconciled wearable data.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: OpenAirColors.textSecondary,
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
